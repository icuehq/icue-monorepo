/// An announcement shown to a parent (`/getAnnouncementsByStudent`).
class ParentAnnouncement {
  const ParentAnnouncement({
    required this.title,
    required this.description,
    required this.date,
    required this.time,
  });

  factory ParentAnnouncement.fromJson(Map<String, dynamic> json) =>
      ParentAnnouncement(
        title: json['Title'] as String? ?? '',
        description: json['Description'] as String? ?? '',
        date: json['AnnouncementDate'] as String? ?? '',
        time: json['AnnouncementTime'] as String? ?? '',
      );

  final String title;
  final String description;
  final String date;
  final String time;
}
