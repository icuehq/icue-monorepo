import 'package:announcements/src/models/announcement.dart';
import 'package:announcements/src/models/announcement_title.dart';
import 'package:announcements/src/models/create_announcement_request.dart';
import 'package:api_client/api_client.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AnnouncementService {
  AnnouncementService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches historical and active announcements.
  Future<List<Announcement>> getAnnouncements() async {
    final response = await _apiClient.post<dynamic>('/v1.0/getAnnouncements');
    final data = response.data;
    if (data is List) {
      final list = data
          .whereType<Map<String, dynamic>>()
          .map(Announcement.fromJson)
          .toList();
      list.sort((a, b) {
        if (a.createdDate == null && b.createdDate == null) return 0;
        if (a.createdDate == null) return 1;
        if (b.createdDate == null) return -1;
        return b.createdDate!.compareTo(a.createdDate!);
      });
      return list;
    }
    return <Announcement>[];
  }

  /// Fetches predefined announcement title templates and appends the "Custom" title template.
  Future<List<AnnouncementTitle>> getAnnouncementTitles() async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getAnnouncementTitles',
    );
    final data = response.data;
    final List<AnnouncementTitle> titles = [];
    if (data is Map<String, dynamic>) {
      final parsed = AnnouncementTitlesResponse.fromJson(data);
      titles.addAll(parsed.data);
    }

    if (!titles.any((t) => t.title == 'Custom')) {
      titles.add(
        const AnnouncementTitle(
          type: 1000,
          title: 'Custom',
          descHeader: 'Custom',
          descBody: 'Custom',
          descFooter: 'Custom',
        ),
      );
    }
    return titles;
  }

  /// Creates and broadcasts a fleet announcement.
  Future<bool> createFleetAnnouncement(
    CreateAnnouncementRequest request,
  ) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/createFleetAnnouncement',
      data: request.toJson(),
    );
    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['err'] != true;
    }
    return response.statusCode == 200;
  }
}
