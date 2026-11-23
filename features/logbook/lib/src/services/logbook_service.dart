import 'package:api_client/api_client.dart';
import 'package:injectable/injectable.dart';
import 'package:logbook/src/models/alcohol_test.dart';
import 'package:logbook/src/models/cleaning_parts.dart';
import 'package:logbook/src/models/complaint_requests.dart';
import 'package:logbook/src/models/complaints.dart';
import 'package:logbook/src/models/complaints_dashboard.dart';

@lazySingleton
class LogBookService {
  LogBookService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches aggregated complaints stats grouped by Status, Category, or Vehicle.
  Future<ComplaintsDashboardResponse> getComplaintsStats({
    required String countBy,
    int page = 1,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVhComplaintsStats',
      data: {'PageNumber': page, 'PageSize': 10, 'CountsBy': countBy},
    );
    return _apiClient.parse(
      response,
      (data) => data is Map<String, dynamic>
          ? ComplaintsDashboardResponse.fromJson(data)
          : const ComplaintsDashboardResponse(),
    );
  }

  /// Fetches a paginated list of complaints filtered by vehicle, status, or category.
  Future<ComplaintDataResponse> getComplaints({
    int? vehicleId,
    String? status,
    int? categoryId,
    String? action,
    String? complaintNo,
    int page = 1,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVhComplaints',
      data: {
        'VehicleId': ?vehicleId,
        'Status': ?status,
        'CategoryId': ?categoryId,
        'Action': ?action,
        'ComplaintNo': ?complaintNo,
        'PageNumber': page,
        'PageSize': 10,
      },
    );
    return _apiClient.parse(
      response,
      (data) => data is Map<String, dynamic>
          ? ComplaintDataResponse.fromJson(data)
          : const ComplaintDataResponse(),
    );
  }

  /// Fetches available complaint categories.
  Future<List<ComplaintCategory>> getComplaintCategories() async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVhComplaintCategories',
      data: {'IsActive': 'true'},
    );
    return _apiClient.parse(
      response,
      (data) => data is Map<String, dynamic>
          ? ComplaintCategoriesResponse.fromJson(data).data
          : <ComplaintCategory>[],
    );
  }

  /// Submits a new vehicle complaint.
  Future<bool> submitComplaint(CreateComplaintRequest request) async {
    final formMap = <String, dynamic>{
      'VehicleId': request.vehicleId,
      'VehicleNo': request.vehicleNumber,
      'CategoryId': request.categoryId,
      'CategoryName': request.newCategoryName ?? '',
      'Desc': request.description,
    };

    if (request.photos.isNotEmpty) {
      formMap['Images'] = [
        for (final photo in request.photos)
          MultipartFile.fromBytes(photo.bytes, filename: photo.name),
      ];
    }

    final response = await _apiClient.post<dynamic>(
      '/v1.0/submitVhComplaint',
      data: FormData.fromMap(formMap),
    );

    return _apiClient.parse(
      response,
      (data) => data is Map<String, dynamic>
          ? data['err'] != true
          : response.statusCode == 200,
    );
  }

  /// Updates complaint status or resolution details.
  Future<bool> updateComplaint(UpdateComplaintRequest request) async {
    final formMap = <String, dynamic>{
      'Id': request.id,
      'Action': request.action,
      'Status': request.status,
      'Desc': ?request.description,
    };

    if (request.photoBytes != null) {
      formMap['Photos'] = MultipartFile.fromBytes(
        request.photoBytes!,
        filename: request.photoName ?? 'resolution.jpg',
      );
    }

    final response = await _apiClient.post<dynamic>(
      '/v1.0/updateVhComplaint',
      data: FormData.fromMap(formMap),
    );

    return _apiClient.parse(
      response,
      (data) => data is Map<String, dynamic>
          ? data['err'] != true
          : response.statusCode == 200,
    );
  }

  /// Fetches list of inspectable vehicle cleaning parts (interior, exterior, tyres, glass).
  Future<List<CleaningPart>> getVehicleCleaningParts() async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVhCleaningParts',
      data: {'IsActive': true},
    );
    return _apiClient.parse(
      response,
      (data) => data is Map<String, dynamic>
          ? VehicleCleaningPartsResponse.fromJson(data).data
          : <CleaningPart>[],
    );
  }

  /// Submits batch cleaning inspection data for one or more vehicles.
  Future<CleaningSubmissionResult> submitVehicleCleaning(
    SubmitCleaningDataRequest request,
  ) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/submitMultiVhCleanedData',
      data: request.toJson(),
    );

    return _apiClient.parse(response, (payload) {
      if (payload is Map<String, dynamic>) {
        final map = payload;
        final failedCount = (map['FailedCnt'] as num?)?.toInt() ?? 0;
        final failedData = <String>[
          for (final item in map['FailedData'] as List<dynamic>? ?? const [])
            if (item is Map<String, dynamic>)
              '${item['VehicleNo']} (${item['CleanedDate']}): ${item['Msg']}',
        ];

        return CleaningSubmissionResult(
          success: map['err'] != true,
          failedCount: failedCount,
          failedMessages: failedData,
        );
      }

      return CleaningSubmissionResult(success: response.statusCode == 200);
    });
  }

  /// Submits an alcohol breathalyzer test for a driver.
  Future<bool> submitAlcoholTest(AlcoholTestSubmissionRequest request) async {
    final formMap = <String, dynamic>{
      'PrsnType': 'DRIVER',
      'PrsnId': request.personId,
      'PrsnName': request.personName,
      'PrsnMobile': request.personMobile,
      'AlcoholTestReading': request.reading,
      'AlcoholTest': request.status,
    };

    if (request.fileBytes != null) {
      formMap['Images'] = MultipartFile.fromBytes(
        request.fileBytes!,
        filename: request.fileName ?? 'breathalyzer.jpg',
      );
    }

    final response = await _apiClient.post<dynamic>(
      '/v2.0/submitPrsnAlcoholTest',
      data: FormData.fromMap(formMap),
    );

    return _apiClient.parse(
      response,
      (data) => data is Map<String, dynamic>
          ? data['err'] != true
          : response.statusCode == 200,
    );
  }

  /// Fetches past alcohol breathalyzer tests.
  Future<AlcoholTestResponse> getAlcoholTestReport({
    int page = 1,
    int pageSize = 10,
    String? search,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/v2.0/getPrsnAlcoholTest',
      data: {'PageNumber': page, 'PageSize': pageSize, 'Search': ?search},
    );
    return _apiClient.parse(
      response,
      (data) => data is Map<String, dynamic>
          ? AlcoholTestResponse.fromJson(data)
          : const AlcoholTestResponse(),
    );
  }
}
