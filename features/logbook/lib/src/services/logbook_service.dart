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
    if (response.data is Map<String, dynamic>) {
      return ComplaintsDashboardResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const ComplaintsDashboardResponse();
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
    if (response.data is Map<String, dynamic>) {
      return ComplaintDataResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const ComplaintDataResponse();
  }

  /// Fetches available complaint categories.
  Future<List<ComplaintCategory>> getComplaintCategories() async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVhComplaintCategories',
      data: {'IsActive': 'true'},
    );
    if (response.data is Map<String, dynamic>) {
      final parsed = ComplaintCategoriesResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      return parsed.data;
    }
    return <ComplaintCategory>[];
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

    if (request.photoBytes != null) {
      formMap['Images'] = MultipartFile.fromBytes(
        request.photoBytes!,
        filename: request.photoName ?? 'complaint.jpg',
      );
    }

    final response = await _apiClient.post<dynamic>(
      '/v1.0/submitVhComplaint',
      data: FormData.fromMap(formMap),
    );

    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['err'] != true;
    }
    return response.statusCode == 200;
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

    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['err'] != true;
    }
    return response.statusCode == 200;
  }

  /// Fetches list of inspectable vehicle cleaning parts (interior, exterior, tyres, glass).
  Future<List<CleaningPart>> getVehicleCleaningParts() async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getVhCleaningParts',
      data: {'IsActive': true},
    );
    if (response.data is Map<String, dynamic>) {
      final parsed = VehicleCleaningPartsResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      return parsed.data;
    }
    return <CleaningPart>[];
  }

  /// Submits batch cleaning inspection data for one or more vehicles.
  Future<CleaningSubmissionResult> submitVehicleCleaning(
    SubmitCleaningDataRequest request,
  ) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/submitMultiVhCleanedData',
      data: request.toJson(),
    );

    if (response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      final failedCount = (map['failedCnt'] as num?)?.toInt() ?? 0;
      final failedData =
          (map['failedData'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];

      return CleaningSubmissionResult(
        success: map['err'] != true,
        failedCount: failedCount,
        failedMessages: failedData,
      );
    }

    return CleaningSubmissionResult(success: response.statusCode == 200);
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

    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['err'] != true;
    }
    return response.statusCode == 200;
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
    if (response.data is Map<String, dynamic>) {
      return AlcoholTestResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const AlcoholTestResponse();
  }
}
