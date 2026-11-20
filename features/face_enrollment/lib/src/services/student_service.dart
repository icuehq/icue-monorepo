import 'package:api_client/api_client.dart';
import 'package:face_enrollment/src/models/student.dart';
import 'package:face_enrollment/src/models/student_embedding.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

/// Student photo, standard and embedding endpoints.
/// Organization, zone and branch ids are injected by [ApiClient].
@lazySingleton
class StudentService {
  StudentService(this._apiClient);

  final ApiClient _apiClient;

  /// [hasPhoto] true/false filters on photo presence; null returns all.
  Future<StudentPage> getStudentPhotos({
    required int classId,
    required int pageNumber,
    required int pageSize,
    bool? hasPhoto,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/v1.0/getStudentPhotos',
      data: {
        'ClassId': classId,
        'StudentPhoto': ?hasPhoto?.toString(),
        'PageNumber': pageNumber,
        'PageSize': pageSize,
      },
    );
    return StudentPage.fromJson(response.data!);
  }

  /// Uploads [embeddings]; true when the server accepted them.
  Future<bool> updateStuEmbeddings(List<StudentEmbedding> embeddings) async {
    final response = await _apiClient.post<dynamic>(
      '/v2.0/updateStuEmbeddings',
      data: {'Embeddings': embeddings.map((e) => e.toJson()).toList()},
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) return true;
    return data['err'] == false ||
        data['error'] == false ||
        data['message'] == 'success';
  }

  /// Server embeddings; [classIdFor] resolves a standard name to its class id.
  Future<List<StudentEmbedding>> getStuEmbeddings({
    required int Function(String standard) classIdFor,
    List<int>? studentIds,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/v2.0/getStuEmbeddings',
      data: {
        if (studentIds != null && studentIds.isNotEmpty)
          'StudentIds': studentIds,
      },
    );
    final body = response.data!;
    if (body['err'] as bool) throw Exception(body['message']);
    return (body['data'] as List<dynamic>).map((item) {
      final map = item as Map<String, dynamic>;
      return StudentEmbedding.fromJson({
        ...map,
        'ClassId': classIdFor(map['Standard'] as String),
      });
    }).toList();
  }

  /// STUDENT standards only.
  Future<List<Standard>> getStandards() async {
    final response = await _apiClient.post<List<dynamic>>('/v1.0/getStandards');
    return response.data!
        .cast<Map<String, dynamic>>()
        .where((e) => e['StandardType'] == 'STUDENT')
        .map(Standard.fromJson)
        .toList();
  }

  /// Downloads [url] to a temp file and returns its path. The photo host is
  /// not ours, so no auth token or session context is sent.
  Future<String> downloadPhoto(String url, String fileName) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/$fileName';
    await _apiClient.dio.download(
      url,
      path,
      options: Options(extra: {'no_auth': true, 'no_context': true}),
    );
    return path;
  }
}
