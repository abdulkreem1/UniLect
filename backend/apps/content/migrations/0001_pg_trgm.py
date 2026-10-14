from django.contrib.postgres.operations import TrigramExtension
from django.db import migrations


class Migration(migrations.Migration):
    """pg_trgm powers Arabic-friendly substring search indexes (FR-031). It is a trusted extension."""

    dependencies = []

    operations = [TrigramExtension()]
