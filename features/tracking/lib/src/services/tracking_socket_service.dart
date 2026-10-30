import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

@lazySingleton
class TrackingSocketService {
  io.Socket? _socket;
  final StreamController<Map<String, dynamic>> _routeStatsController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onRouteStats => _routeStatsController.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Initializes the real-time websocket connection for route stats.
  void connect({
    required String baseUrl,
    required int zoneId,
    required int branchId,
    required int organizationId,
  }) {
    disconnect();

    // Use port 3002 if baseUrl does not specify a port
    final uri = Uri.tryParse(baseUrl);
    final socketUrl = (uri != null && uri.hasPort) ? baseUrl : '$baseUrl:3002';

    final authPayload = <String, dynamic>{
      'ZoneId': zoneId,
      'BranchId': branchId,
      'OrganizationId': organizationId,
    };

    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket
      ?..connect()
      ..onConnect((_) {
        debugPrint('[TrackingSocket] Connected to $socketUrl');
        _socket?.emitWithAck('routeStats', authPayload);
      })
      ..onDisconnect((_) {
        debugPrint('[TrackingSocket] Disconnected');
      })
      ..onConnectError((err) {
        debugPrint('[TrackingSocket] Connect error: $err');
      })
      ..onError((err) {
        debugPrint('[TrackingSocket] Error: $err');
      })
      ..on('sendRouteStatsEvent', (data) {
        if (data is Map && data['routeStats'] is Map) {
          _routeStatsController.add(
            Map<String, dynamic>.from(data['routeStats'] as Map),
          );
        }
      });
  }

  /// Disconnects and releases the current socket instance.
  void disconnect() {
    if (_socket != null) {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
    }
  }

  @disposeMethod
  void dispose() {
    disconnect();
    _routeStatsController.close();
  }
}
