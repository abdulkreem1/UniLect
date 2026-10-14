from django.core.management.base import BaseCommand

from apps.maintenance import services


class Command(BaseCommand):
    help = (
        "Apply retention policies: delete ended sessions, old read notifications, (optionally) old audit "
        "logs, and prune old file versions. Defaults come from settings.RETENTION; 0 disables a rule. "
        "Schedule daily (cron / Kubernetes CronJob)."
    )

    def add_arguments(self, parser):
        parser.add_argument("--sessions-days", type=int, dest="ended_sessions_days")
        parser.add_argument("--notifications-days", type=int, dest="read_notifications_days")
        parser.add_argument("--audit-days", type=int, dest="audit_logs_days")
        parser.add_argument("--keep-file-versions", type=int, dest="old_file_versions")

    def handle(self, *args, **options):
        overrides = {
            key: options[key]
            for key in (
                "ended_sessions_days",
                "read_notifications_days",
                "audit_logs_days",
                "old_file_versions",
            )
            if options.get(key) is not None
        }
        report = services.run_all(overrides)
        for name, count in report.counts.items():
            self.stdout.write(f"{name}: {count} removed")
