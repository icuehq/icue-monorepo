/// Maps a JSON array response to [T]s, skipping non-object items.
/// Returns an empty list when [data] is not a list; sorts with [compare] if given.
List<T> parseList<T>(
  dynamic data,
  T Function(Map<String, dynamic>) fromJson, {
  int Function(T a, T b)? compare,
}) {
  if (data is! List) return <T>[];
  final items = data.whereType<Map<String, dynamic>>().map(fromJson).toList();
  if (compare != null) items.sort(compare);
  return items;
}
