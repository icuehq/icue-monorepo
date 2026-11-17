import 'package:api_client/api_client.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';
import 'package:safehands/src/models/escort.dart';
import 'package:safehands/src/models/safehands_pin.dart';

@lazySingleton
class SafeHandsService {
  const SafeHandsService(this._apiClient);

  final ApiClient _apiClient;

  /// Creates today's PIN; the server answers with a one-item list.
  Future<SafeHandsPin?> createPin({
    required int studentId,
    required String studentName,
    required String admissionNumber,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/CreateSafeHandsToken',
      data: <String, dynamic>{
        'StudentId': studentId,
        'StudentName': studentName,
        'AdmissionNumber': admissionNumber,
      },
    );
    final list = response.data as List<dynamic>?;
    final first = list?.firstOrNull as Map<String, dynamic>?;
    return first == null ? null : SafeHandsPin.fromJson(first);
  }

  /// The student's current PIN; null when none was generated (empty object).
  Future<SafeHandsPin?> getPin(int studentId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/GetSafeHandsTokenByStudent',
      data: <String, dynamic>{'StudentId': studentId},
    );
    final data = response.data as Map<String, dynamic>?;
    return data == null || data.isEmpty ? null : SafeHandsPin.fromJson(data);
  }

  Future<List<Escort>> getEscorts(int studentId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getEscortPhotos',
      data: <String, dynamic>{'StudentId': studentId},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['Photos'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => Escort.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Uploads a new escort. `ok` is false when the server refused (`err: true`).
  Future<({bool ok, String? message})> saveEscort({
    required int studentId,
    required String? studentMobile,
    required String type,
    required String name,
    required String relation,
    required String escortMobile,
    required IcuePickedFile photo,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final form =
        FormData.fromMap(<String, dynamic>{
            // The server expects this exact value on this endpoint (as in the old app).
            'Source': 'adminapp',
            'StudentId': studentId,
            'Mobile': studentMobile,
            'Type': type,
            'Name': name,
            'Relation': relation,
            'EscMobile': escortMobile,
            if (type == escortTemporary) ...<String, dynamic>{
              'FromDate': fromDate?.toUsDate(),
              'ToDate': toDate?.toUsDate(),
            },
          })
          ..files.add(
            MapEntry(
              'Photo',
              MultipartFile.fromBytes(photo.bytes, filename: photo.name),
            ),
          );
    final response = await _apiClient.post<dynamic>(
      '/v1.0/saveEscortPhoto',
      data: form,
    );
    final data = response.data as Map<String, dynamic>;
    return (ok: data['err'] == false, message: data['message'] as String?);
  }

  Future<void> deleteEscort({required int studentId, required int escortId}) =>
      _apiClient.post<dynamic>(
        '/v1.0/deleteEscortPhoto',
        data: <String, dynamic>{'StudentId': studentId, 'Id': escortId},
      );
}
