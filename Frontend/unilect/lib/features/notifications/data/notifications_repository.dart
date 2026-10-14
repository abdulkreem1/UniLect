import '../../../core/models/json.dart';
import '../../../core/network/api_client.dart';
import '../domain/app_notification.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  /// The user's own notifications (FR-072), newest first, with the unread
  /// total across all pages.
  Future<NotificationPage> list({int page = 1}) async {
    final (items, unread) = await (
      _api.getPage(
        '/me/notifications/',
        AppNotification.fromJson,
        page: page,
        pageSize: 30,
      ),
      unreadCount(),
    ).wait;
    return NotificationPage(page: items, unreadCount: unread);
  }

  Future<int> unreadCount() async =>
      (await _api.get<Json>('/me/notifications/unread-count/'))['unread']
          as int;

  Future<void> markRead(String id) =>
      _api.post<void>('/me/notifications/$id/read/');

  Future<void> markAllRead() => _api.post<void>('/me/notifications/read-all/');
}
