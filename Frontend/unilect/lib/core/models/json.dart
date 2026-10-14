/// Small, strict JSON helpers shared by all models.
library;

typedef Json = Map<String, dynamic>;

DateTime parseDate(Object? value) => DateTime.parse(value! as String).toLocal();

DateTime? parseDateOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toLocal();

List<T> parseList<T>(Object? value, T Function(Json json) fromJson) =>
    (value as List<dynamic>? ?? const [])
        .map((e) => fromJson(e as Json))
        .toList(growable: false);

List<String> parseStringList(Object? value) =>
    (value as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// The API uses integer ids for catalog entities and UUIDs elsewhere; the app
/// treats every id as an opaque string.
String idOf(Object? value) => value!.toString();

String? idOrNull(Object? value) => value?.toString();

/// Converts an opaque id back to the integer the API expects for catalog
/// references (universities, courses, instructors, …).
int? intId(String? id) => id == null ? null : int.parse(id);

/// The API sends blank strings for empty optional text fields.
String? textOrNull(Object? value) {
  final s = value as String?;
  return (s == null || s.trim().isEmpty) ? null : s;
}

/// Page of a server list. The API paginates as
/// `{count, next, previous, results}` with `?page=N&page_size=M`.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory Paged.fromDrf(
    Json json,
    T Function(Json json) fromJson, {
    required int page,
    required int pageSize,
  }) => Paged(
    items: parseList(json['results'], fromJson),
    page: page,
    pageSize: pageSize,
    total: json['count'] as int,
  );

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;

  bool get hasMore => page * pageSize < total;
}

/// Reference to the user who performed an action.
class ActorRef {
  const ActorRef({required this.id, required this.name, this.role});

  final String id;
  final String name;
  final String? role;
}

/// Wrapper that lets `copyWith` distinguish "not provided" from "set to null".
class Nullable<T> {
  const Nullable(this.value);
  final T? value;
}
