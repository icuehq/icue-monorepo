/// A stored code as display text: `partially_paid` -> `Partially paid`. A null value shows an en dash;
/// [overrides] replace the plain wording where it is not clear enough (`dispatched` -> `In transit`).
String humanizeStatus(
  String? value, {
  Map<String, String> overrides = const {},
}) {
  if (value == null) return '–';
  final override = overrides[value];
  if (override != null) return override;
  final words = value.replaceAll('_', ' ');
  return words.isEmpty
      ? words
      : '${words[0].toUpperCase()}${words.substring(1)}';
}
