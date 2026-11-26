import 'package:dio/dio.dart';
import 'package:dio_web_adapter/dio_web_adapter.dart';

/// Every JSON request is preflighted and the API handles it, so Dio's
/// per-request warning is noise. Real CORS failures still surface as errors.
void disableCorsWarning(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is BrowserHttpClientAdapter) adapter.enableCORSWarning = false;
}
