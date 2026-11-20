import 'package:api_client/api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@injectable
class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this.apiClient);

  final ApiClient apiClient;

  String get environmentName => apiClient.environment.name.toUpperCase();
  String get baseUrl => apiClient.environment.baseUrl;
  bool get isDev => apiClient.environment.isDev;
}
