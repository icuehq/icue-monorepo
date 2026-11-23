import 'package:api_client/api_client.dart';
import 'package:gatepass/src/models/gatepass_type.dart';
import 'package:gatepass/src/models/parent_gatepass_request.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:injectable/injectable.dart';

/// Parent-side gate pass endpoints; dates go to the server as `MM/dd/yyyy`.
@lazySingleton
class ParentGatePassService {
  const ParentGatePassService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<GatePassType>> getTypes(int studentId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getGatePassTypes',
      data: <String, dynamic>{'StudentId': studentId},
    );
    return _apiClient.parse(
      response,
      (data) =>
          GatePassTypesResponse.fromJson(data as Map<String, dynamic>).data,
    );
  }

  /// Requests a gate pass for today; the server answers `err: true` with a message on refusal.
  Future<({bool ok, String? message})> request({
    required int studentId,
    required String category,
    required DateTime today,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/requestGatePass',
      data: <String, dynamic>{
        'StudentId': studentId,
        'PersonId': studentId,
        'GatePassDate': today.toUsDate(),
        'GatePassType': category,
      },
    );
    return _apiClient.parse(response, (data) {
      final map = data as Map<String, dynamic>?;
      return (ok: map?['err'] != true, message: map?['message'] as String?);
    });
  }

  Future<List<ParentGatePassRequest>> getRequests({
    required int studentId,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getStuGatePass',
      data: <String, dynamic>{
        'StudentId': studentId,
        'ReportMode': 'byperiod',
        'FromDate': from?.toUsDate(),
        'ToDate': to?.toUsDate(),
        'PageNumber': 1,
        'PageSize': 50,
      },
    );
    return _apiClient.parse(
      response,
      (data) => ((data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [])
          .map((e) => ParentGatePassRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
