import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../models/app_settings.dart';
import '../models/country.dart';
import '../services/api_client.dart';
import '../services/hive_service.dart';

@lazySingleton
class CommonProvider extends ChangeNotifier {
  CommonProvider(this._apiClient);

  AppSettings? appSettings;
  List<Country> countries = [];
  bool loading = false;
  List<Place> places = [];

  final ApiClient _apiClient;

  Future<void> getCountries() async {
    loading = true;
    notifyListeners();
    try {
      final response = await _apiClient.get('/v1.0/getCountries');
      countries = List<Country>.from(
        (response.data as List).map(
          (x) => Country.fromJson(x as Map<String, dynamic>),
        ),
      );
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getCountries', error, stack);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> getPlaces(String parentId) async {
    loading = true;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/v1.0/getChildPlaces',
        data: {'ParentId': parentId},
      );
      places = List<Place>.from(
        (response.data as List).map(
          (x) => Place.fromJson(x as Map<String, dynamic>),
        ),
      );
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getChildPlaces', error, stack);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> getAdminAppSettings() async {
    loading = true;
    notifyListeners();
    final userInfo = HiveService.userInfoBox.values.first;
    try {
      final response = await _apiClient.post(
        '/v1.0/getAdminAppSettings',
        data: {'BranchId': userInfo.branchId, 'ZoneId': userInfo.zoneId},
      );
      appSettings = AppSettings.fromJson(response.data as Map<String, dynamic>);
    } catch (error, stack) {
      if (error.runtimeType.toString() != 'DioException') {
        _apiClient.logCrash('/getAdminAppSettings', error, stack);
      }
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
