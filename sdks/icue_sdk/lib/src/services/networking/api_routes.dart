part of 'api_client.dart';

/// Central place for backend REST endpoint paths used by the SDK.
abstract class ApiRoutes {
  static const String validateUserAuth = '/v2.0/validateUserAuth';
  static const String routeNotifications = '/v1.0/getRouteNotifications';
  static const String announcements = '/v1.0/getAnnouncementsByStudent';
  static const String updateRegTokens = '/v1.0/updateRegTokens';
  static const String removeRegTokens = '/v1.0/removeRegToken';
  static const String logout = '/v1.0/logout';
  static const String vehicleLocation = '/v1.0/getVehicleLocation';
  static const String routeCoordinate = '/v1.0/getRouteCoordinate';
  static const String traceDate = '/v1.0/getTraceDate';
  static const String pingConnStats = '/v1.0/pingConnStats';
}
