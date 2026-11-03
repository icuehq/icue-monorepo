import 'dart:async';

import 'package:api_client/api_client.dart';
import 'package:drop_boarding/src/models/vehicle_arrival.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

@lazySingleton
class DropBoardingSocketService {
  io.Socket? _socket;
  String? _currentSocketUrl;
  final StreamController<List<VehicleArrival>> _arrivalsController =
      StreamController<List<VehicleArrival>>.broadcast();

  Stream<List<VehicleArrival>> get onArrivalsUpdated =>
      _arrivalsController.stream;

  bool get isConnected => _socket?.connected ?? false;

  @visibleForTesting
  String? get currentSocketUrl => _currentSocketUrl;

  /// Connects to real-time socket and registers to the vehicleArrivalStatus room.
  void connect({String? baseUrl, required int branchId}) {
    disconnect();

    final socketUrl = baseUrl ?? ApiEnvironment.fromEnvironment().baseUrl;
    _currentSocketUrl = socketUrl;

    final roomPayload = <String, dynamic>{
      'roomName': 'vehicleArrivalStatus-$branchId',
      'eventName': 'vehicleArrivalStatus',
    };

    _socket = io.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket
      ?..connect()
      ..onConnect((_) {
        debugPrint('[DropBoardingSocket] Connected to $socketUrl');
        _socket?.emitWithAck('routeStats', roomPayload);
      })
      ..onDisconnect((_) {
        debugPrint('[DropBoardingSocket] Disconnected');
      })
      ..onConnectError((err) {
        debugPrint('[DropBoardingSocket] Connect error: $err');
      })
      ..onError((err) {
        debugPrint('[DropBoardingSocket] Error: $err');
      })
      ..on('vehicleArrivalStatus', (data) {
        if (data is List) {
          final arrivals = data
              .whereType<Map<String, dynamic>>()
              .map(VehicleArrival.fromJson)
              .toList();
          _arrivalsController.add(arrivals);
        }
      });
  }

  /// Disconnects and releases the current socket instance.
  void disconnect() {
    _currentSocketUrl = null;
    if (_socket != null) {
      _socket?.disconnect();
      _socket?.dispose();
      _socket = null;
    }
  }

  @disposeMethod
  void dispose() {
    disconnect();
    _arrivalsController.close();
  }
}
