import factory

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
from apps.libraries.models import Library

DEFAULT_PASSWORD = "Correct-Horse-91"


class UniversityFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = University

    name = factory.Sequence(lambda n: f"University {n}")


class FacultyFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Faculty

    university = factory.SubFactory(UniversityFactory)
    name = factory.Sequence(lambda n: f"Faculty {n}")


class LevelFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Level

    faculty = factory.SubFactory(FacultyFactory)
    name = factory.Sequence(lambda n: f"Year {n}")
    number = factory.Sequence(lambda n: n + 1)


class SemesterFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Semester

    faculty = factory.SubFactory(FacultyFactory)
    name = factory.Sequence(lambda n: f"Semester {n}")
    number = factory.Sequence(lambda n: n + 1)


class SpecializationFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Specialization

    faculty = factory.SubFactory(FacultyFactory)
    name = factory.Sequence(lambda n: f"Specialization {n}")


class CourseFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Course

    level = factory.SubFactory(LevelFactory)
    name = factory.Sequence(lambda n: f"Course {n}")


class InstructorFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Instructor

    full_name = factory.Sequence(lambda n: f"Instructor {n}")
    title = "Dr."


class CourseInstructorFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = CourseInstructor

    course = factory.SubFactory(CourseFactory)
    instructor = factory.SubFactory(InstructorFactory)


class LibraryFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Library

    name = factory.Sequence(lambda n: f"Library {n}")


class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User
        skip_postgeneration_save = True

    email = factory.Sequence(lambda n: f"user{n}@example.com")
    full_name = factory.Sequence(lambda n: f"User {n}")
    role = Role.ADMIN

    @factory.post_generation
    def password(self, create, extracted, **kwargs):
        self.set_password(extracted or DEFAULT_PASSWORD)
        if create:
            self.save(update_fields=["password"])


class AdminFactory(UserFactory):
    role = Role.ADMIN


class StudentFactory(UserFactory):
    role = Role.STUDENT
    university = factory.SubFactory(UniversityFactory)
    student_number = factory.Sequence(lambda n: f"S{n:06d}")


class LibraryUserFactory(UserFactory):
    role = Role.LIBRARY
    library = factory.SubFactory(LibraryFactory)
