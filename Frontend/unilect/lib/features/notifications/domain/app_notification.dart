import '../../../core/models/json.dart';

enum NotificationType {
  deviceChangeApproved,
  deviceChangeRejected,
  newContent,
  contentReviewed,
  reportUpdated,
  system,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.data = const {},
  });

  factory AppNotification.fromJson(Json json) => AppNotification(
    id: idOf(json['id']),
    type: switch (json['type']) {
      'device_change_approved' => NotificationType.deviceChangeApproved,
      'device_change_rejected' => NotificationType.deviceChangeRejected,
      'new_content' => NotificationType.newContent,
      'content_review' => NotificationType.contentReviewed,
      'report_update' => NotificationType.reportUpdated,
      _ => NotificationType.system,
    },
    title: json['title'] as String,
    body: json['body'] as String? ?? '',
    isRead: json['is_read'] as bool? ?? false,
    createdAt: parseDate(json['created_at']),
    data: (json['data'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, v.toString()),
    ),
  );

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, String> data;

  AppNotification markRead() => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    isRead: true,
    createdAt: createdAt,
    data: data,
  );
}

class NotificationPage {
  const NotificationPage({required this.page, required this.unreadCount});

  final Paged<AppNotification> page;
  final int unreadCount;
}
