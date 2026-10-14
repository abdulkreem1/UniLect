# UniLect — Test data & test scenarios

Backend: Django on the laptop, database `unilect_demo` (created by `python manage.py seed_demo`).
Phone: the debug app connects to `http://127.0.0.1:8000/api/v1`, tunnelled to the laptop over USB
(`adb reverse tcp:8000 tcp:8000`). Keep the cable plugged in.

## 1. Accounts — password for all: `UniLect#2026`

| Email | Role | Name | Details | State |
|---|---|---|---|---|
| `admin@unilect.test` | Admin | مدير النظام | — | active |
| `library@unilect.test` | Library | مكتبة الهندسة - دمشق | scope: all of جامعة دمشق | active |
| `library.aleppo@unilect.test` | Library | مكتبة المعلوماتية - حلب | scope: كلية الهندسة المعلوماتية (حلب) only | active |
| `student@unilect.test` | Student | أحمد خالد | 2023104512 · جامعة دمشق | **no device yet** — first sign-in binds your phone |
| `student2@unilect.test` | Student | سارة يوسف | 2022109876 · جامعة دمشق | bound to another phone (Samsung SM-A546) |
| `nour@unilect.test` | Student | نور الحسن | 2023100777 · جامعة دمشق | bound to an iPhone, **pending** device-change request (Xiaomi 13) |
| `disabled@unilect.test` | Student | ليث منصور | 2021100001 · جامعة دمشق | **disabled** |

**Accounts for friends** (one per person — a student account binds to the first phone that signs in):
`friend1@unilect.test` … `friend10@unilect.test`, password `UniLect#2026`, students of جامعة دمشق.

**Shared APK** (`Desktop\UniLect-test.apk`) talks to a temporary Cloudflare address
(`https://totals-regardless-funeral-communist.trycloudflare.com`). It only works while the laptop's backend
and that tunnel are running; a new tunnel has a new address and needs a new APK.

## 2. Academic structure

| University | Faculty | Year | Subjects (code) |
|---|---|---|---|
| جامعة دمشق | كلية الهندسة المعلوماتية | السنة الأولى | برمجة 1 (ITE101), رياضيات 1 (ITE102), فيزياء (ITE103), مقدمة في الحاسوب |
| | | السنة الثالثة | قواعد البيانات (ITE301), هندسة البرمجيات 1 *(هندسة البرمجيات)*, شبكات الحاسوب *(الشبكات والنظم)* |
| | كلية الطب البشري | السنة الأولى | علم التشريح |
| جامعة حلب | كلية الهندسة المعلوماتية | السنة الأولى | برمجة 1 |
| جامعة تشرين | — | — | — |
| جامعة البعث | **inactive** (students must not see it) | | |

- Each faculty has years 1–5 and semesters: الفصل الأول، الفصل الثاني، الفصل الصيفي.
- Specializations (دمشق / معلوماتية): هندسة البرمجيات، الذكاء الصنعي، الشبكات والنظم.
- Doctors: د. سامر الخطيب (برمجة 1، هندسة البرمجيات 1) · د. رنا العلي (برمجة 1، قواعد البيانات) ·
  د. محمد الأحمد (رياضيات 1) · د. لينا حداد (شبكات الحاسوب، مقدمة في الحاسوب) · د. عمر السيد (برمجة 1 – حلب).
- Lecture categories: نظري، عملي، ملخص · Exam types: الدورة الأولى، الدورة الثانية، الدورة التكميلية.

## 3. Content (all uploaded by `library@unilect.test`)

| Type | Subject | Doctor | # / Year | Title | Status |
|---|---|---|---|---|---|
| Lecture | برمجة 1 | سامر الخطيب | 1 | مقدمة في البرمجة والخوارزميات | published |
| Lecture | برمجة 1 | سامر الخطيب | 2 | المتحولات وأنماط البيانات | published |
| Lecture | برمجة 1 | سامر الخطيب | 3 | التعليمات الشرطية | published |
| Lecture | برمجة 1 | سامر الخطيب | 4 | الحلقات التكرارية | published |
| Lecture | برمجة 1 | سامر الخطيب | 5 | التوابع | **draft** (hidden from students) |
| Lecture | برمجة 1 | رنا العلي | 1 | مدخل إلى لغة C++ | published (has an open report) |
| Lecture | برمجة 1 | رنا العلي | 2 | المؤشرات والمصفوفات | published |
| Lecture | برمجة 1 | رنا العلي | 3 | نسخة قديمة - مقدمة | **archived** |
| Lecture | رياضيات 1 | محمد الأحمد | 1 | النهايات والاستمرار | published |
| Lecture | قواعد البيانات | رنا العلي | 1 | النموذج العلائقي | published |
| Lecture | قواعد البيانات | رنا العلي | 2 | لغة SQL | **pending review** |
| Exam | برمجة 1 | سامر الخطيب | 2023 | أسئلة برمجة 1 - الدورة الأولى 2023 | published |
| Exam | برمجة 1 | سامر الخطيب | 2024 | أسئلة برمجة 1 - الدورة الأولى 2024 | published |
| Exam | برمجة 1 | — | 2024 | أسئلة برمجة 1 - الدورة الثانية 2024 | published (**image**) |
| Exam | برمجة 1 | رنا العلي | 2025 | أسئلة برمجة 1 - الدورة التكميلية 2025 | published |
| Exam | رياضيات 1 | — | 2024 | أسئلة رياضيات 1 - 2024 | published |

Settings: max upload 50 MB · allowed `pdf, jpg, jpeg, png, webp` · review not required.

**Files for upload tests** are on the phone in **Downloads › UniLect-test**:
`lecture-6-functions.pdf`, `exam-2025-first-session.pdf`, `exam-scan.png`, and `not-really-a.pdf`
(a text file renamed to `.pdf` — the server must reject it).

## 4. Test scenarios (expected result in *italics*)

### Student — `student@unilect.test`
1. Sign in → *your phone is bound; home shows the universities (جامعة البعث is not listed).*
2. جامعة دمشق › كلية الهندسة المعلوماتية › السنة الأولى › برمجة 1 → *tabs "Doctors" and "Exams".*
3. د. سامر الخطيب → *4 lectures in order 1–4; «التوابع» (draft) is not shown.*
4. Open lecture 1 → details (subject, doctor, category نظري, file size) → **Open file** →
   *PDF viewer with a «UL-…» watermark; screenshots are blocked; no download/share button.*
5. Exams tab → filter year 2024 → *2 exams*; open «الدورة الثانية 2024» → *image viewer.*
6. Search «الحلقات» → *«الحلقات التكرارية»*; search «التوابع» → *no results.*
7. Add a lecture to favorites → Favorites tab shows it; remove it.
8. On برمجة 1 tap **Follow** → later, when the library publishes a new lecture in برمجة 1, *a notification arrives.*
9. Report a lecture (⋮ › Report) → *sent*; report the same lecture again → *refused (already open).*
10. Profile → name is locked, phone editable; change password; switch to English → *LTR layout.*

### Second device — `student2@unilect.test`
1. Sign in on your phone → *"account linked to another device" screen.*
2. Send a device-change request with a reason → *"request submitted".*
3. Sign in as admin → Devices → approve it → sign in again as `student2` → *works on your phone.*

### Disabled account — `disabled@unilect.test`
1. Sign in → *message that the account is disabled.*

### Library — `library@unilect.test`
1. Dashboard → *counts: published, draft, pending review, archived; recent content.*
2. Upload lecture → pickers only offer **جامعة دمشق** (scope) → برمجة 1 › د. سامر الخطيب ›
   category نظري › number 6 › file `lecture-6-functions.pdf` → Preview → Publish →
   *published; the student sees it and gets a notification if following.*
3. Upload exam → برمجة 1 › year 2025 › الفصل الأول › الدورة الأولى › `exam-2025-first-session.pdf` → publish.
4. Upload with `not-really-a.pdf` → *rejected: file content does not match its type.*
5. Open «التوابع» (draft) › Publish → *published*. Archive a lecture → *students no longer see it*; Restore → draft.
6. Edit a lecture › replace the file → *Versions list shows v2 (current) and v1.*
7. Sign in as `library.aleppo@unilect.test` → pickers offer **only جامعة حلب**.

### Admin — `admin@unilect.test`
1. Dashboard → *needs action: 1 device request, 1 pending review, 1 open report.*
2. Devices → approve or reject نور الحسن's request (Xiaomi 13); Device log tab shows the history.
3. More › All content › review queue → approve or reject «لغة SQL» (reject asks for a note; the library sees it).
4. More › Reports → report on «مدخل إلى لغة C++» → In review → Resolved (*reporter is notified*).
5. Users › New user → student (university + student number + temporary password) → sign in with it on the phone →
   *forced to change the password first.*
6. Users › open a student → **Unbind device** / **Set a new password** / **Disable**.
7. Structure → add a university/faculty/year/subject, link a doctor to subjects, drag to reorder, switch off "visible".
8. Structure › Libraries → edit a library's scope. More › Settings → turn on "require review", then upload as the
   library → *goes to pending review.*
9. More › Audit log → filter by category.

## 5. Start everything again later

From `backend/`:

```bash
set DATABASE_URL=postgres://unilect:unilect-dev-only@127.0.0.1:5432/unilect_demo
python manage.py runserver 0.0.0.0:8000
```

With the phone plugged in:

```bash
adb reverse tcp:8000 tcp:8000
```

To reset the demo data: drop and recreate the `unilect_demo` database, then run
`python manage.py migrate` and `python manage.py seed_demo` with the same `DATABASE_URL`.
