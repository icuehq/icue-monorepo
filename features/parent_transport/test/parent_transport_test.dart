import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parent_transport/src/models/live_track.dart';
import 'package:parent_transport/src/models/transport_record.dart';
import 'package:parent_transport/src/models/vehicle_location.dart';
import 'package:parent_transport/src/services/parent_transport_service.dart';

class _FakeApiClient extends Fake implements ApiClient {
  @override
  T parse<T>(Response<dynamic> response, T Function(dynamic data) fromJson) =>
      fromJson(response.data);

  int status = 200;
  dynamic body;
  Map<String, dynamic>? lastData;

  @override
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    lastData = data as Map<String, dynamic>?;
    return Response<T>(
      data: body as T,
      statusCode: status,
      requestOptions: RequestOptions(path: path),
    );
  }
}

void main() {
  test('VehicleLocation parses the first-load payload', () {
    final v = VehicleLocation.fromJson({
      'RouteDetailsId': 7,
      'RouteNo': 'R1',
      'RouteTrackId': 99,
      'coordinates': [
        [12, 77.5],
      ],
      'CoordinatesTime': '10:00:00',
      'ServerTime': '10:00:05',
      'MsgAvailable': true,
      'Mode': 'Pickup',
      'DriverData': {'Name': 'A', 'Mobile': 9876543210, 'VehicleNumber': 'X'},
      'routeCoOrdinates': [
        {
          'PickPoint': 'Gate',
          'coordinates': [12.1, 77.6],
        },
      ],
    });
    expect(v.coordinates.first, [12.0, 77.5]);
    expect(v.driver?.mobile, '9876543210');
    expect(v.stops?.single.pickPoint, 'Gate');
  });

  test('LiveTrack accepts numeric or string route track ids', () {
    final t = LiveTrack.fromJson({
      'RouteTrackId': 5,
      'coordinates': [
        [1, 2],
      ],
    });
    expect(t.routeTrackId, '5');
  });

  group('ParentTransportService', () {
    test('getVehicleLocation maps 204 to none', () async {
      final api = _FakeApiClient()..status = 204;
      final result = await ParentTransportService(api)
          .getVehicleLocation(studentId: 1, routeCached: true);
      expect(result, isA<VehicleLocationNone>());
      expect(api.lastData, {
        'StudentId': 1,
        'isCoOrdinatesAvailable': true,
        'updateApp': true,
      });
    });

    test('getVehicleLocation passes a refusal message through', () async {
      final api = _FakeApiClient()
        ..status = 202
        ..body = {'err': true, 'message': 'Not allowed'};
      final result = await ParentTransportService(api)
          .getVehicleLocation(studentId: 1, routeCached: false);
      expect((result as VehicleLocationRefused).message, 'Not allowed');
    });

    test('getTransportRecords sends US dates', () async {
      final api = _FakeApiClient()
        ..body = {
          'data': [
            {
              'Id': 1,
              'RouteNo': 'R1',
              'Mode': 'Pickup',
              'Date': '07/03/2026',
              'Time': '08:00',
              'Msg': 'Boarded',
            },
          ],
        };
      final list = await ParentTransportService(api).getTransportRecords(
        studentId: 2,
        from: DateTime(2026, 3),
        to: DateTime(2026, 3, 7),
      );
      expect(list.single.isPickup, isTrue);
      expect(api.lastData?['FromDate'], '03/01/2026');
      expect(api.lastData?['ToDate'], '03/07/2026');
    });

    test('TransportRecord.isPickup is false for drops', () {
      expect(
        TransportRecord.fromJson({'Id': 1, 'Mode': 'Drop'}).isPickup,
        isFalse,
      );
    });
  });
}
