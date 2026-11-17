import 'package:api_client/api_client.dart';
import 'package:injectable/injectable.dart';
import 'package:school_connect/src/models/complaint.dart';
import 'package:school_connect/src/models/event_payment.dart';
import 'package:school_connect/src/models/school_event.dart';

@lazySingleton
class SchoolConnectService {
  const SchoolConnectService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ComplaintType>> getComplaintTypes(int studentId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getFeedbackComplaintTypes',
      data: <String, dynamic>{'StudentId': studentId},
    );
    return (response.data as List<dynamic>)
        .map((e) => ComplaintType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Complaint>> getComplaints({
    required int studentId,
    required String? primaryContact,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getFeedbackComplaintsByParent',
      data: <String, dynamic>{
        'StudentId': studentId,
        // Sic: the server spells this key without the second "r".
        'PrimayContact': primaryContact,
      },
    );
    return (response.data as List<dynamic>)
        .map((e) => Complaint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> postComplaint({
    required int studentId,
    required String? primaryContact,
    required String query,
    required int type,
    required String typeDescription,
  }) => _apiClient.post<dynamic>(
    '/v1.0/postFeedbackComplaints',
    data: <String, dynamic>{
      'StudentId': studentId,
      'PrimaryContact': primaryContact,
      'Query': query,
      'ComplaintType': type,
      'ComplaintDesc': typeDescription,
    },
  );

  Future<List<SchoolEvent>> getEvents({
    required int studentId,
    required String? loggedInContact,
    required String admissionNumber,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/showEventsToParents',
      data: <String, dynamic>{
        'StudentId': studentId,
        'LoggedInContact': loggedInContact,
        'AdmissionNumber': admissionNumber,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (data['Events'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => SchoolEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> getEntryQrCode({
    required int studentId,
    required String admissionNumber,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/genParentQRCodeForSchoolEvents',
      data: <String, dynamic>{
        'StudentId': studentId,
        'AdmissionNumber': admissionNumber,
      },
    );
    final data =
        (response.data as Map<String, dynamic>)['data']
            as Map<String, dynamic>?;
    return data?['QRCode'] as String?;
  }

  Future<EventPaymentPage> getEventPayments({
    required int studentId,
    required String admissionNumber,
    required int page,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getStuEventPyments',
      data: <String, dynamic>{
        'StudentId': studentId,
        'AdmissionNumber': admissionNumber,
        'PageNumber': page,
        'PageSize': pageSize,
      },
    );
    return EventPaymentPage.fromJson(response.data as Map<String, dynamic>);
  }
}
