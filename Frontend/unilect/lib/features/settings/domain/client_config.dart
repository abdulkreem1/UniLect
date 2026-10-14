import '../../../core/models/json.dart';

/// Server-managed settings relevant to the client (FR-069): `GET config/`
/// for every role, `admin/settings/` (with [notifyFollowersOnPublish]) for
/// administrators.
///
/// Watermarking and screen-capture protection are not settings: the server
/// always issues a watermark code and the viewer always protects the screen.
class ClientConfig {
  const ClientConfig({
    required this.maxUploadSizeMb,
    required this.allowedExtensions,
    required this.requireContentReview,
    this.notifyFollowersOnPublish = true,
  });

  factory ClientConfig.fromJson(Json json) => ClientConfig(
    maxUploadSizeMb: json['max_upload_size_mb'] as int,
    allowedExtensions: parseStringList(json['allowed_extensions']),
    requireContentReview: json['require_content_review'] as bool? ?? false,
    notifyFollowersOnPublish:
        json['notify_followers_on_publish'] as bool? ?? true,
  );

  /// Extensions the server can ever accept; admins choose a subset.
  static const supportedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

  /// Server hard limit for `max_upload_size_mb`.
  static const maxUploadSizeLimitMb = 200;

  final int maxUploadSizeMb;
  final List<String> allowedExtensions;
  final bool requireContentReview;
  final bool notifyFollowersOnPublish;

  int get maxUploadBytes => maxUploadSizeMb * 1024 * 1024;

  ClientConfig copyWith({
    int? maxUploadSizeMb,
    List<String>? allowedExtensions,
    bool? requireContentReview,
    bool? notifyFollowersOnPublish,
  }) => ClientConfig(
    maxUploadSizeMb: maxUploadSizeMb ?? this.maxUploadSizeMb,
    allowedExtensions: allowedExtensions ?? this.allowedExtensions,
    requireContentReview: requireContentReview ?? this.requireContentReview,
    notifyFollowersOnPublish:
        notifyFollowersOnPublish ?? this.notifyFollowersOnPublish,
  );

  /// Body of `PATCH admin/settings/`.
  Json toJson() => {
    'max_upload_size_mb': maxUploadSizeMb,
    'allowed_extensions': allowedExtensions,
    'require_content_review': requireContentReview,
    'notify_followers_on_publish': notifyFollowersOnPublish,
  };
}
