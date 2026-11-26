import 'package:announcements/src/models/parent_announcement.dart';
import 'package:api_client/api_client.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ParentAnnouncementService {
  const ParentAnnouncementService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ParentAnnouncement>> getForStudent(int studentId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getAnnouncementsByStudent',
      data: <String, dynamic>{'StudentId': studentId},
    );
    return _apiClient.parse(
      response,
      (payload) => (payload as List<dynamic>)
          .map((e) => ParentAnnouncement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
