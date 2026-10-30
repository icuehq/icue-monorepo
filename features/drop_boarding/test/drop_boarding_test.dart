import 'package:api_client/api_client.dart';
import 'package:drop_boarding/drop_boarding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routes/routes.dart';

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

class FakeSocketService extends Fake implements DropBoardingSocketService {
  bool disconnected = false;

  @override
  void disconnect() {
    disconnected = true;
  }
}

void main() {
  group('Drop & Boarding Models Serialization', () {
    test('VehicleArrival deserializes and serializes properly', () {
      final json = <String, dynamic>{
        'RouteId': 101,
        'RouteNo': 'R-01',
        'VehicleNumber': 'KA01AB1234',
        'Status': 'ARRIVED',
        'BoardingType': 'North Gate',
      };

      final arrival = VehicleArrival.fromJson(json);
      expect(arrival.id, 101);
      expect(arrival.routeNo, 'R-01');
      expect(arrival.vehicleNumber, 'KA01AB1234');
      expect(arrival.status, 'ARRIVED');
      expect(arrival.boardingType, 'North Gate');

      final out = arrival.toJson();
      expect(out['RouteId'], 101);
      expect(out['BoardingType'], 'North Gate');
    });

    test('VehicleArrivalsResponse deserializes correctly', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'data': [
          {
            'RouteId': 102,
            'RouteNo': 'R-02',
            'VehicleNumber': 'KA01AB5678',
            'Status': 'ARRIVED',
          },
        ],
      };

      final response = VehicleArrivalsResponse.fromJson(json);
      expect(response.err, false);
      expect(response.data.length, 1);
      expect(response.data.first.routeNo, 'R-02');
    });

    test('BoardingType deserializes and serializes properly', () {
      final json = <String, dynamic>{'Id': '1', 'Name': 'Bay 1'};

      final type = BoardingType.fromJson(json);
      expect(type.id, '1');
      expect(type.name, 'Bay 1');

      final out = type.toJson();
      expect(out['Id'], '1');
      expect(out['Name'], 'Bay 1');
    });

    test('BoardingTypesResponse deserializes correctly', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'data': [
          {'Id': '1', 'Name': 'Bay 1'},
          {'Id': '2', 'Name': 'Bay 2'},
        ],
      };

      final response = BoardingTypesResponse.fromJson(json);
      expect(response.data.length, 2);
      expect(response.data[1].name, 'Bay 2');
    });
  });

  group('DropBoardingProvider State Management', () {
    late MockApiClient mockApi;
    late DropBoardingService dropBoardingService;
    late FakeSocketService socketService;
    late RouteService routeService;
    late DropBoardingProvider provider;

    setUp(() {
      mockApi = MockApiClient();
      dropBoardingService = DropBoardingService(mockApi);
      socketService = FakeSocketService();
      routeService = RouteService(mockApi);
      provider = DropBoardingProvider(
        dropBoardingService,
        socketService,
        routeService,
      );
    });

    test(
      'fetchInitialData populates arrivals and calculates drop routes',
      () async {
        mockApi.nextResponseData = {
          'err': false,
          'message': 'Success',
          'data': [
            {
              'RouteId': 1,
              'RouteNo': 'R-01',
              'VehicleNumber': 'KA01AA1111',
              'Status': 'ARRIVED',
            },
          ],
        };

        // Both getVehicleArrivals and getRoutesAndPoints will hit mockApi
        await provider.fetchInitialData(
          zoneId: 1,
          branchId: 10,
          organizationId: 100,
        );

        expect(provider.isLoading, false);
        expect(provider.vehicleArrivals.length, 1);
        expect(provider.arrivedVehicles.length, 1);
        expect(provider.arrivedVehicles.first.routeNo, 'R-01');
      },
    );

    test('fetchBoardingTypes loads boarding types into provider', () async {
      mockApi.nextResponseData = {
        'err': false,
        'message': 'Success',
        'data': [
          {'Id': '10', 'Name': 'East Wing'},
          {'Id': '20', 'Name': 'West Wing'},
        ],
      };

      await provider.fetchBoardingTypes(
        zoneId: 1,
        branchId: 10,
        organizationId: 100,
      );

      expect(mockApi.lastPath, '/v1.0/getBoardingTypes');
      expect(provider.boardingTypes.length, 2);
      expect(provider.boardingTypes.first.name, 'East Wing');
    });

    test('updateArrivals dynamically updates vehicle arrivals list', () {
      final arrivals = <VehicleArrival>[
        const VehicleArrival(
          id: 50,
          routeNo: 'R-50',
          vehicleNumber: 'KA01BB5050',
          status: 'ARRIVED',
        ),
      ];

      provider.updateArrivals(arrivals);
      expect(provider.vehicleArrivals.length, 1);
      expect(provider.arrivedVehicles.length, 1);
      expect(provider.arrivedVehicles.first.routeNo, 'R-50');
    });

    test('disconnectSocket invokes disconnect on socket service', () {
      provider.disconnectSocket();
      expect(socketService.disconnected, true);
    });
  });
}
