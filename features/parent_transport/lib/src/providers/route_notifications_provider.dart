import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:parent_transport/src/models/route_notification.dart';
import 'package:parent_transport/src/services/parent_transport_service.dart';

/// Messages sent to the parent during the current bus run.
@lazySingleton
class RouteNotificationsProvider extends ChangeNotifier {
  RouteNotificationsProvider(this._service, this._auth);

  final ParentTransportService _service;
  final ParentAuthProvider _auth;

  List<RouteNotification> messages = <RouteNotification>[];
  bool loading = false;

  Future<void> load(int routeTrackId) async {
    final id = _auth.selectedStudent?.id;
    if (id == null) return;
    loading = true;
    notifyListeners();
    try {
      messages = await _service.getRouteNotifications(
        studentId: id,
        routeTrackId: routeTrackId,
      );
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
