"""Demo dataset for local development, manual QA and the mobile app's live API tests.

Everything goes through the real services (device binding, content creation and upload
validation, workflow transitions, reports), so the data is exactly what production code would
produce: audit entries, search documents, file versions and notifications included.

All demo accounts share one password and are created WITHOUT ``must_change_password``. The
command therefore refuses to run unless DEBUG is on or ``--allow-non-debug`` is given.
"""

from datetime import timedelta

from django.conf import settings
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from apps.academics.models import (
    Course,
    CourseInstructor,
    Faculty,
    Instructor,
    Level,
    Semester,
    Specialization,
    University,
)
from apps.accounts.models import Role, User
from apps.content import services as content_services
from apps.content.models import ContentItem, ExamType, LectureCategory
from apps.devices import services as device_services
from apps.devices.utils import hash_installation_id
from apps.libraries.models import Library
from apps.notifications import services as notifications
from apps.reports import services as report_services

PASSWORD = "UniLect#2026"  # noqa: S105 (public demo password, DEBUG only)

ADMIN = "admin@unilect.test"
LIBRARY = "library@unilect.test"
LIBRARY_ALEPPO = "library.aleppo@unilect.test"
STUDENT = "student@unilect.test"  # not bound yet: the first sign-in binds the device
STUDENT_OTHER_DEVICE = "student2@unilect.test"  # bound to another device (device_not_bound flow)
STUDENT_DISABLED = "disabled@unilect.test"
STUDENT_PENDING = "nour@unilect.test"  # bound, with a pending device-change request

LECTURE_TITLES = [
    "مقدمة في البرمجة والخوارزميات",
    "المتحولات وأنماط البيانات",
    "التعليمات الشرطية",
    "الحلقات التكرارية",
    "التوابع",
]


def sample_pdf(title: str, pages: int = 4) -> bytes:
    """Small valid PDF with readable ASCII text (built-in Helvetica)."""

    def text(x: int, y: int, size: int, s: str) -> str:
        s = "".join(ch for ch in s if 32 <= ord(ch) < 127)
        s = s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
        return f"/F1 {size} Tf 1 0 0 1 {x} {y} Tm ({s}) Tj"

    objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "",
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    kids = []
    for i in range(1, pages + 1):
        page_id, content_id = len(objects) + 1, len(objects) + 2
        kids.append(f"{page_id} 0 R")
        lines = [
            text(56, 760, 26, "UniLect"),
            text(56, 720, 16, title),
            text(56, 690, 11, "Demo document created by `manage.py seed_demo`."),
            *(
                text(56, 650 - n * 22, 11, f"Page {i} - line {n + 1}: lorem ipsum dolor sit amet.")
                for n in range(22)
            ),
            text(280, 40, 10, f"{i} / {pages}"),
        ]
        stream = "BT\n" + "\n".join(lines) + "\nET"
        objects.append(
            f"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
            f"/Resources << /Font << /F1 3 0 R >> >> /Contents {content_id} 0 R >>"
        )
        objects.append(f"<< /Length {len(stream)} >>\nstream\n{stream}\nendstream")
    objects[1] = f"<< /Type /Pages /Kids [{' '.join(kids)}] /Count {pages} >>"

    out = "%PDF-1.4\n"
    offsets = []
    for n, body in enumerate(objects, start=1):
        offsets.append(len(out))
        out += f"{n} 0 obj\n{body}\nendobj\n"
    xref = len(out)
    out += f"xref\n0 {len(objects) + 1}\n0000000000 65535 f \n"
    out += "".join(f"{o:010d} 00000 n \n" for o in offsets)
    out += f"trailer\n<< /Size {len(objects) + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n"
    return out.encode("latin-1")


def sample_png() -> bytes:
    import io

    from PIL import Image, ImageDraw

    image = Image.new("RGB", (480, 640), (4, 40, 120))
    draw = ImageDraw.Draw(image)
    for y in range(0, 640, 40):
        for x in range(0, 480, 40):
            if (x // 40 + y // 40) % 2:
                draw.rectangle([x, y, x + 39, y + 39], fill=(14, 80 + y // 8, 160))
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


class Command(BaseCommand):
    help = f"Create a demo catalog, accounts (password: {PASSWORD}) and content. Development only."

    def add_arguments(self, parser):
        parser.add_argument(
            "--allow-non-debug",
            action="store_true",
            help="Run even when DEBUG is off (never on a production database: the accounts are public).",
        )

    def handle(self, *args, **options):
        if not settings.DEBUG and not options["allow_non_debug"]:
            raise CommandError("Refusing to seed demo accounts with DEBUG off (see --allow-non-debug).")
        if User.objects.filter(email=ADMIN).exists():
            self.stdout.write(self.style.WARNING("Demo data already present; nothing to do."))
            return
        with transaction.atomic():
            self._seed()
        self.stdout.write(self.style.SUCCESS(f"Demo data created. Password for every account: {PASSWORD}"))
        for email in (ADMIN, LIBRARY, LIBRARY_ALEPPO, STUDENT, STUDENT_OTHER_DEVICE, STUDENT_DISABLED):
            self.stdout.write(f"  {email}")

    # ------------------------------------------------------------------------------------------ data

    def _seed(self) -> None:
        now = timezone.now()

        # Catalog
        dam = University.objects.create(name="جامعة دمشق", code="DU", sort_order=1)
        alp = University.objects.create(name="جامعة حلب", code="AU", sort_order=2)
        University.objects.create(name="جامعة تشرين", code="TU", sort_order=3)
        University.objects.create(name="جامعة البعث", code="BU", sort_order=4, is_active=False)

        dam_ite = Faculty.objects.create(university=dam, name="كلية الهندسة المعلوماتية", sort_order=1)
        dam_med = Faculty.objects.create(university=dam, name="كلية الطب البشري", sort_order=2)
        alp_ite = Faculty.objects.create(university=alp, name="كلية الهندسة المعلوماتية", sort_order=1)

        year_names = ["السنة الأولى", "السنة الثانية", "السنة الثالثة", "السنة الرابعة", "السنة الخامسة"]
        levels = {
            faculty.pk: [
                Level.objects.create(faculty=faculty, name=name, number=i, sort_order=i)
                for i, name in enumerate(year_names, start=1)
            ]
            for faculty in (dam_ite, dam_med, alp_ite)
        }
        semesters = {
            faculty.pk: [
                Semester.objects.create(faculty=faculty, name=name, number=i, sort_order=i)
                for i, name in enumerate(["الفصل الأول", "الفصل الثاني", "الفصل الصيفي"], start=1)
            ]
            for faculty in (dam_ite, dam_med, alp_ite)
        }
        se = Specialization.objects.create(faculty=dam_ite, name="هندسة البرمجيات", sort_order=1)
        Specialization.objects.create(faculty=dam_ite, name="الذكاء الصنعي", sort_order=2)
        net = Specialization.objects.create(faculty=dam_ite, name="الشبكات والنظم", sort_order=3)

        def course(faculty, year, name, order, code="", specs=()):
            c = Course.objects.create(
                level=levels[faculty.pk][year - 1],
                semester=semesters[faculty.pk][0],
                name=name,
                code=code,
                sort_order=order,
            )
            c.specializations.set(specs)
            return c

        prog1 = course(dam_ite, 1, "برمجة 1", 1, "ITE101")
        math1 = course(dam_ite, 1, "رياضيات 1", 2, "ITE102")
        course(dam_ite, 1, "فيزياء", 3, "ITE103")
        intro = course(dam_ite, 1, "مقدمة في الحاسوب", 4)
        db = course(dam_ite, 3, "قواعد البيانات", 1, "ITE301")
        se1 = course(dam_ite, 3, "هندسة البرمجيات 1", 2, specs=[se])
        networks = course(dam_ite, 3, "شبكات الحاسوب", 3, specs=[net])
        alp_prog = course(alp_ite, 1, "برمجة 1", 1)
        course(dam_med, 1, "علم التشريح", 1)

        def instructor(name, university, courses, order):
            i = Instructor.objects.create(full_name=name, title="د.", university=university, sort_order=order)
            for n, c in enumerate(courses):
                CourseInstructor.objects.create(course=c, instructor=i, sort_order=n)
            return i

        samer = instructor("سامر الخطيب", dam, [prog1, se1], 1)
        rana = instructor("رنا العلي", dam, [prog1, db], 2)
        mhd = instructor("محمد الأحمد", dam, [math1], 3)
        instructor("لينا حداد", dam, [networks, intro], 4)
        instructor("عمر السيد", alp, [alp_prog], 5)

        theory = LectureCategory.objects.create(name="نظري", sort_order=1)
        LectureCategory.objects.create(name="عملي", sort_order=2)
        LectureCategory.objects.create(name="ملخص", sort_order=3)
        first = ExamType.objects.create(name="الدورة الأولى", sort_order=1)
        second = ExamType.objects.create(name="الدورة الثانية", sort_order=2)
        supplementary = ExamType.objects.create(name="الدورة التكميلية", sort_order=3)

        # Libraries and accounts
        dam_library = Library.objects.create(name="مكتبة الهندسة - دمشق", contact_email=LIBRARY)
        dam_library.scope_universities.set([dam])
        alp_library = Library.objects.create(name="مكتبة المعلوماتية - حلب", contact_email=LIBRARY_ALEPPO)
        alp_library.scope_faculties.set([alp_ite])

        def account(email, name, role, **extra):
            return User.objects.create_user(
                email=email, password=PASSWORD, full_name=name, role=role, must_change_password=False, **extra
            )

        User.objects.create_superuser(email=ADMIN, password=PASSWORD, full_name="مدير النظام")
        library_user = account(LIBRARY, "مكتبة الهندسة - دمشق", Role.LIBRARY, library=dam_library)
        account(LIBRARY_ALEPPO, "مكتبة المعلوماتية - حلب", Role.LIBRARY, library=alp_library)
        student = account(STUDENT, "أحمد خالد", Role.STUDENT, university=dam, student_number="2023104512")
        sara = account(
            STUDENT_OTHER_DEVICE, "سارة يوسف", Role.STUDENT, university=dam, student_number="2022109876"
        )
        account(
            STUDENT_DISABLED,
            "ليث منصور",
            Role.STUDENT,
            university=dam,
            student_number="2021100001",
            is_active=False,
        )
        nour = account(
            STUDENT_PENDING, "نور الحسن", Role.STUDENT, university=dam, student_number="2023100777"
        )

        def device(installation_id, platform, model):
            return device_services.DeviceInfo(
                installation_id_hash=hash_installation_id(installation_id),
                platform=platform,
                model_name=model,
            )

        device_services.resolve_login_device(
            sara, device("seed-device-0000-sara", "android", "Samsung SM-A546")
        )
        device_services.resolve_login_device(nour, device("seed-device-1111-nour", "ios", "iPhone15,3"))
        device_services.create_change_request(
            nour,
            device("seed-device-2222-nour", "android", "Xiaomi 13"),
            "تعطّل جهازي السابق واشتريت جهازاً جديداً",
        )

        # Content (created by the library, published through the normal workflow)
        def content(kind, title, course_obj, days_ago, *, status="published", image=False, **fields):
            name = f"{title}.png" if image else f"{title}.pdf"
            label = fields.pop("ascii", title)
            data = sample_png() if image else sample_pdf(label)
            upload = SimpleUploadedFile(name, data, content_type="image/png" if image else "application/pdf")
            item = content_services.create_content(
                actor=library_user,
                data={"kind": kind, "title": title, "course": course_obj, **fields},
                upload=upload,
            )
            if status in ("published", "archived"):
                item = content_services.submit(item=item, actor=library_user)
            if status == "archived":
                item = content_services.archive(item=item, actor=library_user)
            if status == "pending_review":
                ContentItem.objects.filter(pk=item.pk).update(status=ContentItem.Status.PENDING_REVIEW)
            moment = now - timedelta(days=days_ago)
            ContentItem.objects.filter(pk=item.pk).update(
                created_at=moment,
                updated_at=moment,
                published_at=moment if status == "published" else None,
            )
            return item

        for i, title in enumerate(LECTURE_TITLES, start=1):
            content(
                "lecture",
                title,
                prog1,
                40 - i * 6,
                status="draft" if i == 5 else "published",
                description=f"المحاضرة {i} من مقرر برمجة 1 للدكتور سامر الخطيب.",
                instructor=samer,
                category=theory,
                lecture_number=i,
                ascii=f"Programming 1 - Lecture {i}",
            )
        cpp = content(
            "lecture",
            "مدخل إلى لغة C++",
            prog1,
            35,
            instructor=rana,
            category=theory,
            lecture_number=1,
            ascii="C++",
        )
        content(
            "lecture",
            "المؤشرات والمصفوفات",
            prog1,
            28,
            instructor=rana,
            category=theory,
            lecture_number=2,
            ascii="Pointers & Arrays",
        )
        content(
            "lecture",
            "نسخة قديمة - مقدمة",
            prog1,
            300,
            status="archived",
            instructor=rana,
            category=theory,
            lecture_number=3,
            ascii="Old",
        )
        content(
            "lecture",
            "النموذج العلائقي",
            db,
            12,
            instructor=rana,
            category=theory,
            lecture_number=1,
            ascii="Relational Model",
        )
        content(
            "lecture",
            "لغة SQL",
            db,
            5,
            status="pending_review",
            instructor=rana,
            category=theory,
            lecture_number=2,
            ascii="SQL",
        )
        content(
            "lecture",
            "النهايات والاستمرار",
            math1,
            20,
            instructor=mhd,
            category=theory,
            lecture_number=1,
            ascii="Limits",
        )

        term1, _, summer = semesters[dam_ite.pk]
        for title, year, exam_type, term, inst, days, image in [
            ("أسئلة برمجة 1 - الدورة الأولى 2023", 2023, first, term1, samer, 60, False),
            ("أسئلة برمجة 1 - الدورة الأولى 2024", 2024, first, term1, samer, 30, False),
            ("أسئلة برمجة 1 - الدورة الثانية 2024", 2024, second, term1, None, 25, True),
            ("أسئلة برمجة 1 - الدورة التكميلية 2025", 2025, supplementary, summer, rana, 8, False),
        ]:
            content(
                "exam",
                title,
                prog1,
                days,
                image=image,
                instructor=inst,
                exam_year=year,
                exam_type=exam_type,
                semester=term,
                ascii=f"Programming 1 Exam {year}",
            )
        content(
            "exam",
            "أسئلة رياضيات 1 - 2024",
            math1,
            40,
            exam_year=2024,
            exam_type=first,
            semester=term1,
            ascii="Math 1 Exam 2024",
        )

        # Notifications and reports
        with notifications.site_language():
            notifications.notify(
                student,
                "system",
                "مرحباً بك في UniLect",
                "تصفّح محاضرات مقرراتك وأسئلة الدورات بأمان.",
            )
        report_services.create_report(
            content=cpp,
            reporter=sara,
            reason="duplicate",
            message="المحاضرة مكررة مع محاضرة أخرى للدكتور نفسه",
        )
