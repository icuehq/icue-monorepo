/// An event a parent can book through the school's web page (`/showEventsToParents`).
class SchoolEvent {
  const SchoolEvent({
    required this.name,
    required this.link,
    required this.startDate,
    required this.endDate,
  });

  factory SchoolEvent.fromJson(Map<String, dynamic> json) => SchoolEvent(
    name: json['EventName'] as String? ?? '',
    link: json['Link'] as String? ?? '',
    startDate: json['StartDt'] as String? ?? '',
    endDate: json['EndDt'] as String? ?? '',
  );

  final String name;
  final String link;

  /// `dd-MMM-yyyy`.
  final String startDate;
  final String endDate;
}
