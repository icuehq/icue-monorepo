import 'package:api_client/api_client.dart';
import 'package:gatepass/src/models/create_gatepass_request.dart';
import 'package:gatepass/src/models/gatepass_request.dart';
import 'package:gatepass/src/models/gatepass_type.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GatePassService {
  const GatePassService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches available gate pass categories and types.
  Future<List<GatePassType>> getGatePassTypes() async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getGatePassTypes',
      data: <String, dynamic>{},
    );

    if (response.data is Map<String, dynamic>) {
      final parsed = GatePassTypesResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      return parsed.data;
    }
    return <GatePassType>[];
  }

  /// Fetches gate pass requests requested for a particular date (yyyy-MM-dd).
  Future<List<GatePassRequest>> getGatePassRequests(String date) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getRequestedGatePass',
      data: <String, dynamic>{'Date': date},
    );

    if (response.data is Map<String, dynamic>) {
      final parsed = GatePassRequestsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      return parsed.data;
    }
    return <GatePassRequest>[];
  }

  /// Creates and issues a new gate pass for a person/student.
  Future<bool> issueGatePass(CreateGatePassRequest request) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/createGatePass',
      data: request.toJson(),
    );

    if (response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      final err = map['err'] as bool? ?? false;
      return !err;
    }
    return true;
  }

  /// Approves or rejects a pending gate pass request ('APPROVE' or 'REJECT').
  Future<bool> updateGatePassStatus({
    required int id,
    required int personId,
    required String date,
    required String status,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/approveGPRequest',
      data: <String, dynamic>{
        'Id': id,
        'PersonId': personId,
        'RequestDate': date,
        'Status': status,
      },
    );

    if (response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      final err = map['err'] as bool? ?? false;
      return !err;
    }
    return true;
  }
}
