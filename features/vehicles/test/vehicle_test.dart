import 'package:api_client/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vehicles/vehicles.dart';

class MockVehicleService implements VehicleService {
  List<Vehicle> mockVehicles = [];
  List<VehicleData> mockVehiclesData = [];
  VehicleDetails? mockDetails;
  Docs? mockDoc;

  bool getVehiclesCalled = false;
  bool getVehiclesDataCalled = false;
  bool createVehicleCalled = false;
  bool updateVehicleCalled = false;
  bool deleteVehicleCalled = false;
  bool getVehicleDocsCalled = false;

  @override
  Future<List<Vehicle>> getVehicles() async {
    getVehiclesCalled = true;
    return mockVehicles;
  }

  @override
  Future<List<VehicleData>> getVehiclesData() async {
    getVehiclesDataCalled = true;
    return mockVehiclesData;
  }

  @override
  Future<VehicleDetails?> getVehicleDetails(String vehicleNumber) async {
    return mockDetails;
  }

  @override
  Future<void> createVehicle(AddVehicleRequest request) async {
    createVehicleCalled = true;
  }

  @override
  Future<void> updateVehicle(AddVehicleRequest request) async {
    updateVehicleCalled = true;
  }

  @override
  Future<void> deleteVehicle(int vehicleId) async {
    deleteVehicleCalled = true;
  }

  @override
  Future<Docs?> getVehicleDocs({required int id, required String type}) async {
    getVehicleDocsCalled = true;
    return mockDoc;
  }

  @override
  Future<void> uploadVehicleDocs(FormData formData) async {}

  @override
  Future<void> deleteVehicleDoc({required int id, required String type}) async {}

  @override
  Future<bool> checkVehicleNumber(String number) async {
    return number == 'TS09EA1234';
  }
}

void main() {
  group('Vehicle Models Serialization', () {
    test('Vehicle deserializes and serializes successfully', () {
      final json = <String, dynamic>{
        'Id': 50,
        'Number': 'AP28TV9999',
        'DriverId': 12,
        'DriverName': 'Ramesh',
        'DriverNumber': '9876543210',
        'Capacity': 40,
        'FuelType': 'Diesel',
        'Price': '95.50',
      };

      final vehicle = Vehicle.fromJson(json);
      expect(vehicle.id, equals(50));
      expect(vehicle.number, equals('AP28TV9999'));
      expect(vehicle.driverName, equals('Ramesh'));
      expect(vehicle.fuelType, equals('Diesel'));

      final serialized = vehicle.toJson();
      expect(serialized['Id'], equals(50));
      expect(serialized['Number'], equals('AP28TV9999'));
    });

    test('VehicleData deserializes and serializes with first aid kit', () {
      final json = <String, dynamic>{
        'Id': 100,
        'Number': 'TS09EA1234',
        'DriverId': 5,
        'DriverName': 'Suresh',
        'DriverNumber': '9123456780',
        'Capacity': 32,
        'Colour': 'Yellow',
        'Make': 'Tata',
        'Model': 'Starbus',
        'Year': '2022',
        'FuelType': 'Diesel',
        'InsuranceNumber': 'INS-9901',
        'InsuranceExpiryDate': '2026-12-31',
        'RCNumber': 'RC-5544',
        'RCExpiryDate': '2028-06-30',
        'FitnessNumber': 'FIT-1122',
        'FitnessExpiryDate': '2027-01-15',
        'RoadTaxNumber': 'TAX-7788',
        'RoadTaxExpiryDate': '2026-03-31',
        'PollutionNumber': 'PUC-3344',
        'PollutionExpiryDate': '2025-09-30',
        'PermitNumber': 'PER-6677',
        'PermitExpiryDate': '2027-11-20',
        'FirstAidKit': [
          {
            'Id': 1,
            'MedicineDetails': 'Bandages & Antiseptic',
            'MedicineExpiryDate': '2026-05-01',
          }
        ],
        'routes': ['Route 1', 'Route 2'],
      };

      final vehicleData = VehicleData.fromJson(json);
      expect(vehicleData.id, equals(100));
      expect(vehicleData.number, equals('TS09EA1234'));
      expect(vehicleData.make, equals('Tata'));
      expect(vehicleData.firstAidKit.length, equals(1));
      expect(vehicleData.firstAidKit.first.medicineDetails, contains('Bandages'));
      expect(vehicleData.routes.length, equals(2));

      final serialized = vehicleData.toJson();
      expect(serialized['Id'], equals(100));
      expect(serialized['Make'], equals('Tata'));
      expect(serialized['routes'], contains('Route 1'));
    });

    test('AddVehicleRequest serializes properly', () {
      const request = AddVehicleRequest(
        number: 'KA01AB1122',
        fuelType: 'CNG',
        capacity: '30',
        make: 'Ashok Leyland',
        year: '2021',
        chasisNumber: 'CHASIS998877',
      );

      final json = request.toJson();
      expect(json['Source'], equals('adminapp'));
      expect(json['Number'], equals('KA01AB1122'));
      expect(json['FuelType'], equals('CNG'));
      expect(json['Make'], equals('Ashok Leyland'));
    });

    test('VehicleDocs and Docs deserializes properly', () {
      final json = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'docs': {
          'RecordId': 100,
          'Type': 'Insurance',
          'DocUrl': 'https://example.com/insurance.pdf',
          'ContentType': 'application/pdf',
          'InsuranceNumber': 'INS-12345',
          'InsuranceExpiryDate': '2026-10-10',
        },
      };

      final vehicleDocs = VehicleDocs.fromJson(json);
      expect(vehicleDocs.err, isFalse);
      expect(vehicleDocs.docs, isNotNull);
      expect(vehicleDocs.docs!.type, equals('Insurance'));
      expect(vehicleDocs.docs!.docUrl, contains('insurance.pdf'));
    });
  });

  group('VehicleProvider state management', () {
    late MockVehicleService mockService;
    late VehicleProvider provider;

    setUp(() {
      mockService = MockVehicleService();
      provider = VehicleProvider(mockService);
    });

    test('fetchVehicles loads vehicle numbers and updates state', () async {
      mockService.mockVehicles = [
        const Vehicle(id: 1, number: 'AP01AA1111'),
        const Vehicle(id: 2, number: 'AP01AA2222'),
      ];

      expect(provider.isLoading, isFalse);
      final future = provider.fetchVehicles();
      expect(provider.isLoading, isTrue);
      await future;

      expect(provider.isLoading, isFalse);
      expect(provider.vehicles.length, equals(2));
      expect(mockService.getVehiclesCalled, isTrue);
    });

    test('fetchVehiclesData loads fleet vehicles', () async {
      mockService.mockVehiclesData = [
        const VehicleData(id: 10, number: 'TS01AB1234'),
      ];

      await provider.fetchVehiclesData();
      expect(provider.vehiclesData.length, equals(1));
      expect(provider.vehiclesData.first.number, equals('TS01AB1234'));
      expect(mockService.getVehiclesDataCalled, isTrue);
    });

    test('addVehicle calls service and refreshes fleet', () async {
      const request = AddVehicleRequest(number: 'TS01AB9999', fuelType: 'Diesel');
      final result = await provider.addVehicle(request);

      expect(result, isTrue);
      expect(mockService.createVehicleCalled, isTrue);
      expect(mockService.getVehiclesDataCalled, isTrue);
    });

    test('deleteVehicle removes vehicle by ID', () async {
      mockService.mockVehiclesData = [
        const VehicleData(id: 10, number: 'TS01AB1234'),
        const VehicleData(id: 20, number: 'TS01AB5678'),
      ];
      await provider.fetchVehiclesData();
      expect(provider.vehiclesData.length, equals(2));

      final result = await provider.deleteVehicle(10);
      expect(result, isTrue);
      expect(mockService.deleteVehicleCalled, isTrue);
      expect(provider.vehiclesData.length, equals(1));
      expect(provider.vehiclesData.first.id, equals(20));
    });

    test('fetchVehicleDoc loads document into docs map', () async {
      mockService.mockDoc = const Docs(
        recordId: 10,
        type: 'RC',
        docUrl: 'https://example.com/rc.jpg',
        contentType: 'image/jpeg',
      );

      await provider.fetchVehicleDoc(id: 10, type: 'RC');
      expect(mockService.getVehicleDocsCalled, isTrue);
      expect(provider.vehicleDocs['RC'], isNotNull);
      expect(provider.vehicleDocs['RC']!.docUrl, contains('rc.jpg'));
    });
  });
}
