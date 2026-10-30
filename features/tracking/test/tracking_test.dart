import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracking/tracking.dart';

class MockApiClient extends Fake implements ApiClient {
  dynamic nextResponseData;
  String? lastPath;
  dynamic lastData;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastPath = path;
    lastData = data;
    return Response<T>(
      data: nextResponseData as T,
      statusCode: 200,
      requestOptions: RequestOptions(path: path),
    );
  }
}

class FakeSocketService extends Fake implements TrackingSocketService {
  bool disconnected = false;

  @override
  void disconnect() {
    disconnected = true;
  }
}

void main() {
  group('Tracking Models Serialization', () {
    test('VehicleSlotItem deserializes and serializes properly', () {
      final json = <String, dynamic>{
        'VehicleNumber': 'KA01AB1234',
        'DriverName': 'John Driver',
        'DriverNumber': '9876543210',
        'Mode': 'Pickup',
        'RouteNo': 'R-101',
        'RouteDetailsId': 555,
        'RouteStartTime': '07:30 AM',
      };

      final item = VehicleSlotItem.fromJson(json);
      expect(item.vehicleNumber, 'KA01AB1234');
      expect(item.driverName, 'John Driver');
      expect(item.routeNo, 'R-101');
      expect(item.routeDetailsId, 555);
      expect(item.routeStartTime, '07:30 AM');

      final out = item.toJson();
      expect(out['VehicleNumber'], 'KA01AB1234');
      expect(out['RouteDetailsId'], 555);
    });

    test('FleetStatusReport parses slots and computes allInProgress', () {
      final json = <String, dynamic>{
        'TotalSlots': 3,
        'ActiveSlot': 'Slot1',
        'SlotNames': [
          {'Slot': 'Slot1', 'SlotName': 'Morning'},
          {'Slot': 'Slot2', 'SlotName': 'Afternoon'},
          {'Slot': 'Slot3', 'SlotName': 'Evening'},
        ],
        'Slot1NotStarted': [
          {
            'VehicleNumber': 'KA01AB0001',
            'DriverName': 'Driver A',
            'DriverNumber': '111',
            'Mode': 'Pickup',
            'RouteNo': 'R-1',
            'RouteDetailsId': 1,
            'RouteStartTime': '07:00 AM',
          }
        ],
        'Slot1InProgress': [
          {
            'VehicleNumber': 'KA01AB0002',
            'DriverName': 'Driver B',
            'DriverNumber': '222',
            'Mode': 'Pickup',
            'RouteNo': 'R-2',
            'RouteDetailsId': 2,
            'RouteStartTime': '07:15 AM',
          }
        ],
        'Slot1Completed': <Map<String, dynamic>>[],
        'Slot2NotStarted': <Map<String, dynamic>>[],
        'Slot2InProgress': [
          {
            'VehicleNumber': 'KA01AB0003',
            'DriverName': 'Driver C',
            'DriverNumber': '333',
            'Mode': 'Drop',
            'RouteNo': 'R-3',
            'RouteDetailsId': 3,
            'RouteStartTime': '01:00 PM',
          }
        ],
        'Slot2Completed': <Map<String, dynamic>>[],
        'Slot3NotStarted': <Map<String, dynamic>>[],
        'Slot3InProgress': <Map<String, dynamic>>[],
        'Slot3Completed': <Map<String, dynamic>>[],
      };

      final report = FleetStatusReport.fromJson(json);
      expect(report.totalSlots, 3);
      expect(report.activeSlot, 'Slot1');
      expect(report.slotNames.length, 3);
      expect(report.slot1.notStarted.length, 1);
      expect(report.slot1.inProgress.length, 1);
      expect(report.slot2.inProgress.length, 1);

      // Verify computed getter for active running fleet
      final active = report.allInProgress;
      expect(active.length, 2);
      expect(active.first.routeNo, 'R-2');
      expect(active.last.routeNo, 'R-3');
    });
  });

  group('TrackingProvider State Management', () {
    late MockApiClient mockApi;
    late TrackingService service;
    late FakeSocketService socketService;
    late TrackingProvider provider;

    setUp(() {
      mockApi = MockApiClient();
      service = TrackingService(mockApi);
      socketService = FakeSocketService();
      provider = TrackingProvider(service, socketService);
    });

    test('fetchFleetStatus loads slot metrics into provider', () async {
      mockApi.nextResponseData = {
        'TotalSlots': 3,
        'ActiveSlot': 'Slot1',
        'SlotNames': <Map<String, dynamic>>[],
        'Slot1NotStarted': <Map<String, dynamic>>[],
        'Slot1InProgress': [
          {
            'VehicleNumber': 'KA01AB9999',
            'DriverName': 'Driver X',
            'DriverNumber': '999',
            'Mode': 'Pickup',
            'RouteNo': 'R-9',
            'RouteDetailsId': 99,
            'RouteStartTime': '07:00 AM',
          }
        ],
        'Slot1Completed': <Map<String, dynamic>>[],
        'Slot2NotStarted': <Map<String, dynamic>>[],
        'Slot2InProgress': <Map<String, dynamic>>[],
        'Slot2Completed': <Map<String, dynamic>>[],
        'Slot3NotStarted': <Map<String, dynamic>>[],
        'Slot3InProgress': <Map<String, dynamic>>[],
        'Slot3Completed': <Map<String, dynamic>>[],
      };

      await provider.fetchFleetStatus();

      expect(mockApi.lastPath, '/v1.0/getVehicleStartStatusReport');
      expect(provider.fleetStatus, isNotNull);
      expect(provider.activeRunningVehicles.length, 1);
      expect(provider.activeRunningVehicles.first.vehicleNumber, 'KA01AB9999');
      expect(provider.isLoading, false);
    });

    test('resolveLiveTrackUrl fetches map tracking link', () async {
      mockApi.nextResponseData = {
        'err': false,
        'message': 'Success',
        'data': {
          'trackLink': 'https://maps.example.com/track/route_101',
        },
      };

      final url = await provider.resolveLiveTrackUrl(
        routeDetailsId: 101,
        routeNo: 'R-101',
        mode: 'Pickup',
      );

      expect(mockApi.lastPath, '/v1.0/getLiveTrackUrl');
      expect(url, 'https://maps.example.com/track/route_101');
    });

    test('updateFromSocket updates fleet status dynamically', () {
      final socketPayload = <String, dynamic>{
        'TotalSlots': 1,
        'ActiveSlot': 'Slot1',
        'SlotNames': [
          {'Slot': 'Slot1', 'SlotName': 'Morning'}
        ],
        'Slot1NotStarted': <Map<String, dynamic>>[],
        'Slot1InProgress': [
          {
            'VehicleNumber': 'KA01AB5555',
            'DriverName': 'Live Driver',
            'DriverNumber': '555',
            'Mode': 'Pickup',
            'RouteNo': 'R-55',
            'RouteDetailsId': 55,
            'RouteStartTime': '07:30 AM',
          }
        ],
        'Slot1Completed': <Map<String, dynamic>>[],
      };

      provider.updateFromSocket(socketPayload);

      expect(provider.fleetStatus, isNotNull);
      expect(provider.activeRunningVehicles.length, 1);
      expect(provider.activeRunningVehicles.first.routeNo, 'R-55');
    });

    test('disconnectSocket invokes disconnect on socket service', () {
      provider.disconnectSocket();
      expect(socketService.disconnected, true);
    });
  });
}
