import 'package:api_client/api_client.dart';
import 'package:injectable/injectable.dart';
import 'package:students/src/models/parent_role_action.dart';
import 'package:students/src/models/student_route_details.dart';

@lazySingleton
class StudentsService {
  const StudentsService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ParentRoleAction>> getRoleActions(int studentId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getActionsByRole',
      data: <String, dynamic>{'StudentId': studentId},
    );
    final actions =
        (response.data as List<dynamic>)
            .map((e) => ParentRoleAction.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.tabOrder.compareTo(b.tabOrder));
    return actions;
  }

  Future<StudentRouteDetails> getRouteDetails(int studentId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getStuRtDetails',
      data: <String, dynamic>{'StudentId': studentId},
    );
    return StudentRouteDetails.fromJson(response.data as Map<String, dynamic>);
  }

  /// URL for a web link feature (e.g. mess), or null when the server has none.
  Future<String?> getLinkUrl(int studentId, String linkType) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getStuLinkUrl',
      data: <String, dynamic>{'StudentId': studentId, 'LinkType': linkType},
    );
    final data = response.data as Map<String, dynamic>;
    return data['err'] == false ? data['linkUrl'] as String? : null;
  }
}
