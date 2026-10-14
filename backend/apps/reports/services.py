from django.db import IntegrityError, transaction
from django.utils.translation import gettext as _

from apps.audit import services as audit
from apps.core.exceptions import Conflict, InvalidTransition
from apps.notifications import services as notifications
from apps.notifications.models import Notification

from .models import ContentReport, ReportAction


def create_report(*, content, reporter, reason: str, message: str = "", request=None) -> ContentReport:
    try:
        with transaction.atomic():
            report = ContentReport.objects.create(
                content=content, reporter=reporter, reason=reason, message=message
            )
    except IntegrityError as exc:
        raise Conflict(
            _("You already have an open report for this content."), code="report_already_open"
        ) from exc
    audit.record(
        action="report.created",
        category=audit.Category.REPORT,
        actor=reporter,
        target=report,
        metadata={"content_id": str(content.pk), "reason": reason},
        request=request,
    )
    return report


def transition(
    *, report: ContentReport, actor, to_status: str, note: str = "", request=None
) -> ContentReport:
    with transaction.atomic():
        locked = ContentReport.objects.select_for_update().get(pk=report.pk)
        if to_status not in ContentReport.TRANSITIONS[locked.status]:
            raise InvalidTransition(
                _("Cannot move a report from %(a)s to %(b)s.") % {"a": locked.status, "b": to_status}
            )
        ReportAction.objects.create(
            report=locked, actor=actor, from_status=locked.status, to_status=to_status, note=note
        )
        locked.status = to_status
        locked.handled_by = actor
        locked.save(update_fields=["status", "handled_by", "updated_at"])
        audit.record(
            action="report.status_changed",
            category=audit.Category.REPORT,
            actor=actor,
            target=locked,
            metadata={"to": to_status, "note": note},
            request=request,
        )
        if to_status in (ContentReport.Status.RESOLVED, ContentReport.Status.REJECTED):
            with notifications.site_language():
                notifications.notify(
                    locked.reporter,
                    Notification.Type.REPORT_UPDATE,
                    _("Your report was reviewed"),
                    note,
                    {"report_id": str(locked.pk), "status": to_status},
                )
    return locked


def add_note(*, report: ContentReport, actor, note: str, request=None) -> ReportAction:
    action = ReportAction.objects.create(
        report=report, actor=actor, from_status=report.status, to_status=report.status, note=note
    )
    audit.record(
        action="report.note_added",
        category=audit.Category.REPORT,
        actor=actor,
        target=report,
        request=request,
    )
    return action
