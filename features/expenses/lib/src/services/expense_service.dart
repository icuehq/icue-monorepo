import 'package:api_client/api_client.dart';
import 'package:expenses/src/models/expense_category.dart';
import 'package:expenses/src/models/expense_requests.dart';
import 'package:expenses/src/models/expense_type.dart';
import 'package:expenses/src/models/fuel_storage.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ExpenseService {
  ExpenseService(this._apiClient);

  final ApiClient _apiClient;

  /// Fetches expense types and dynamic field schemas.
  Future<List<ExpenseType>> getExpenseTypes() async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getExpenseTypeDetails',
    );
    return parseList(response.data, ExpenseType.fromJson);
  }

  /// Fetches primary expense categories.
  Future<List<Detail>> getExpenseCategories() async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getExpenseCategories',
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final parsed = ExpenseCategoryResponse.fromJson(data);
      return parsed.record;
    }
    return <Detail>[];
  }

  /// Fetches sub-categories for a chosen primary category ID.
  Future<List<Detail>> getExpenseSubCategories(int categoryId) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getExpenseSubCategories',
      data: {'CategoryId': categoryId},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final parsed = ExpenseCategoryResponse.fromJson(data);
      final list = List<Detail>.from(parsed.record);
      list.add(const Detail(id: 'others', name: 'Others'));
      return list;
    }
    return <Detail>[];
  }

  /// Fetches fuel storage tanks and pumps for a given fuel type.
  Future<List<Storage>> getFuelStorages(String? fuelType) async {
    final response = await _apiClient.post<dynamic>(
      '/v1.0/getFuelStorages',
      data: {'FuelType': ?fuelType},
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final parsed = FuelStorageResponse.fromJson(data);
      return parsed.data;
    }
    return <Storage>[];
  }

  /// Updates start or end status for self-filling fuel pump.
  Future<bool> updateSelfFillingStatus(SelfFillingStatusRequest request) async {
    final date = request.transDate ?? DateTime.now().toIso8601String();

    String? imgUpload;
    if (request.gaugeFileBytes != null && request.billFileBytes != null) {
      imgUpload = 'ALL';
    } else if (request.gaugeFileBytes != null) {
      imgUpload = 'GAUGE';
    } else if (request.billFileBytes != null) {
      imgUpload = 'BILL';
    }

    final formMap = <String, dynamic>{
      'FuelType': request.fuelType,
      'GaugeMode': request.gaugeMode,
      'StartReading': ?request.startReading,
      'EndReading': ?request.endReading,
      'TransDate': date,
      'ImgUpload': ?imgUpload,
    };

    if (request.gaugeFileBytes != null) {
      formMap['GaugeFile'] = MultipartFile.fromBytes(
        request.gaugeFileBytes!,
        filename: request.gaugeFileName ?? 'gauge.jpg',
      );
    }
    if (request.billFileBytes != null) {
      formMap['BillFile'] = MultipartFile.fromBytes(
        request.billFileBytes!,
        filename: request.billFileName ?? 'bill.jpg',
      );
    }

    final response = await _apiClient.post<dynamic>(
      '/v1.0/updateSelfFillingStatus',
      data: FormData.fromMap(formMap),
    );

    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['err'] != true;
    }
    return response.statusCode == 200;
  }

  /// Generates a reference number before submitting final expense details.
  Future<Map<String, dynamic>?> generateRefNo(
    Map<String, dynamic> data, {
    List<int>? odometerBytes,
    String? odometerName,
  }) async {
    final map = Map<String, dynamic>.from(data);
    if (odometerBytes != null) {
      map['File'] = MultipartFile.fromBytes(
        odometerBytes,
        filename: odometerName ?? 'odometer.jpg',
      );
    }

    final response = await _apiClient.post<dynamic>(
      '/v1.0/addExpense',
      data: FormData.fromMap(map),
    );

    if (response.data is Map<String, dynamic>) {
      final resMap = response.data as Map<String, dynamic>;
      if (resMap['err'] != true && resMap['data'] is Map<String, dynamic>) {
        return resMap['data'] as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Generates a unique Bill Number if user left it blank.
  Future<String?> generateBillNo(String billDate) async {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final response = await _apiClient.post<dynamic>(
      '/v1.0/generateBillNo',
      data: {'InitiatedDate': billDate, 'InitiatedTime': timeStr},
    );

    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['BillNo'] as String?;
    }
    return null;
  }

  /// Stores the full expense record.
  Future<bool> storeExpense(StoreExpenseRequest request) async {
    final baseData = <String, dynamic>{
      'VehicleNumber': request.vehicleNumber,
      'ExpenseType': request.expenseType.expenseType.toString(),
      'BillDate': request.billDate,
      'BillAmount': request.billAmount,
      'Amount': request.billAmount,
      'Status': request.status,
      'BillNo': ?request.billNo,
      'VendorName': ?request.vendorName,
      'ExpenseDesc': ?request.description,
      'Mode': ?request.mode,
      'FuelType': ?request.fuelType,
      'Speedometer': ?request.speedometer,
      ...request.extraFields,
    };

    final addExpenseRes = await generateRefNo(
      baseData,
      odometerBytes: request.odometerFileBytes,
      odometerName: request.odometerFileName,
    );

    String? effectiveBillNo = request.billNo;
    if (effectiveBillNo == null || effectiveBillNo.trim().isEmpty) {
      effectiveBillNo = await generateBillNo(request.billDate);
    }

    final refNo = addExpenseRes?['RefNo'];
    final effectiveBillAmount = request.billAmount.isNotEmpty
        ? request.billAmount
        : addExpenseRes?['BillAmount']?.toString();

    final formDataMap = <String, dynamic>{
      ...baseData,
      'BillNo': effectiveBillNo,
      'IsMode': 'true',
      'RefNo': ?refNo,
      'BillAmount': effectiveBillAmount,
      'Amount': effectiveBillAmount,
    };

    if (request.billFileBytes != null) {
      formDataMap['File'] = MultipartFile.fromBytes(
        request.billFileBytes!,
        filename: request.billFileName ?? 'bill.jpg',
      );
    }

    formDataMap.removeWhere((_, value) => value == null);

    final response = await _apiClient.post<dynamic>(
      '/v1.0/storeExpense',
      data: FormData.fromMap(formDataMap),
    );

    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['err'] != true;
    }
    return response.statusCode == 200;
  }
}
