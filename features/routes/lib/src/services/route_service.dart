import 'package:api_client/api_client.dart';
import 'package:injectable/injectable.dart';
import 'package:routes/src/models/route_change_requests.dart';
import 'package:routes/src/models/routes.dart';
import 'package:routes/src/models/standards.dart';
import 'package:routes/src/models/student.dart';

@lazySingleton
class RouteService {
  RouteService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches all routes and points optionally filtered by pickup or drop mode.
  Future<List<Routee>> getRoutesAndPoints(RouteMode? mode) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getRoutesAndPoints',
      data: mode != null ? {'Mode': mode.label} : null,
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final routesResponse = RoutesResponse.fromJson(data);
      return routesResponse.routes;
    }
    return <Routee>[];
  }

  /// Fetches standards and their sections.
  Future<List<Standards>> getStandards() async {
    final response = await _apiClient.post<dynamic>('/v1.0/getStandards');
    final data = response.data;
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Standards.fromJson)
          .toList();
    }
    return <Standards>[];
  }

  /// Fetches students for a specific class and sections with pagination.
  Future<Student> getStudents({
    required int classId,
    required List<String> sections,
    required int pageNo,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v2.0/getStudents',
      data: {
        'ClassId': classId,
        'Sections': sections,
        'PageNumber': pageNo,
        'PageSize': 100,
      },
    );
    final data = response.data;
    if (data is List && data.isNotEmpty) {
      return Student.fromJson(data.first as Map<String, dynamic>);
    }
    return const Student();
  }

  /// Searches for students matching a query string.
  Future<List<StudentData>> searchStudent({
    required String search,
    int? classId,
    List<String>? sections,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v2.0/searchStudent',
      data: {
        'searchText': search,
        'ClassId': ?classId,
        'Sections': ?sections,
      },
    );
    final data = response.data;
    if (data is List) {
      final students = data
          .whereType<Map<String, dynamic>>()
          .map(StudentData.fromJson)
          .toList();
      students.sort((a, b) {
        final rollA = int.tryParse(a.rollNo) ?? 0;
        final rollB = int.tryParse(b.rollNo) ?? 0;
        return rollA.compareTo(rollB);
      });
      return students;
    }
    return <StudentData>[];
  }

  /// Changes a single pickup or drop route for a student.
  Future<bool> changeStudentRoute(ChangeRouteRequest request) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/changeStudentRoute',
      data: request.toJson(),
    );
    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['err'] != true;
    }
    return true;
  }

  /// Changes both pickup and drop routes simultaneously for a student.
  Future<bool> changeBothRoutes(ChangeBothRoutesRequest request) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/changeStudentRoutes',
      data: request.toJson(),
    );
    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['err'] != true;
    }
    return true;
  }

  /// Updates start time for one or all routes in a mode.
  Future<bool> updateStartTimeForRoutes(UpdateRouteTimeRequest request) async {
    final response = await _apiClient.post<dynamic>(
      '/v2.0/updateStartTimeForRoutes',
      data: request.toJson(),
    );
    return response.statusCode == 200;
  }
}
