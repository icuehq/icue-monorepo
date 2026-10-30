import 'package:api_client/api_client.dart';
import 'package:drivers/drivers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Driver Models Serialization', () {
    test('Driver deserializes and serializes successfully', () {
      final sampleJson = <String, dynamic>{
        'Id': 101,
        'FirstName': 'Ramesh',
        'MiddleName': 'Kumar',
        'LastName': 'Sharma',
        'Mobile': '9876543210',
        'AlternateNumber': 9876543211,
        'DateOfBirth': '1985-05-15',
        'DateOfJoining': '2020-01-10',
        'Email': 'ramesh@example.com',
        'Designation': 'Senior Driver',
        'DrivingExperience': '10 years',
        'LicenceNumber': 'DL-0420110012345',
        'LicenceIssuedDate': '2015-01-01',
        'LicenceExpiryDate': '2030-01-01',
        'LicenceCopy': null,
        'HealthRecord': null,
        'PoliceRecord': null,
        'Address': <String, dynamic>{
          'Line1': 'Plot 42, Sector 5',
          'Line2': 'Green Park',
        },
        'City': 'Hyderabad',
        'State': 'Telangana',
        'Country': 'India',
        'Pincode': '500081',
        'IdentificationId': 'AADHAR-1234',
        'IdType': 'Aadhar',
        'EnforceChangePassword': false,
        'UserType': 'Driver',
        'vehicles': <String>['TS09UB1234'],
        'routes': <String>['R-101'],
      };

      final driver = Driver.fromJson(sampleJson);
      expect(driver.id, equals(101));
      expect(driver.firstName, equals('Ramesh'));
      expect(driver.fullName, equals('Ramesh Kumar Sharma'));
      expect(driver.address.line1, equals('Plot 42, Sector 5'));
      expect(driver.vehicles, contains('TS09UB1234'));
      expect(driver.routes, contains('R-101'));

      final jsonOutput = driver.toJson();
      expect(jsonOutput['Id'], equals(101));
      expect(jsonOutput['FirstName'], equals('Ramesh'));
    });

    test('AddDriverRequest serializes properly for POST body', () {
      const request = AddDriverRequest(
        firstName: 'Suresh',
        lastName: 'Rao',
        mobile: '9123456780',
        email: 'suresh@example.com',
        licenceNumber: 'DL-999999',
      );

      final json = request.toJson();
      expect(json['FirstName'], equals('Suresh'));
      expect(json['LastName'], equals('Rao'));
      expect(json['Mobile'], equals('9123456780'));
      expect(json['LicenceNumber'], equals('DL-999999'));
      expect(json['Source'], equals('adminapp'));
    });

    test('DriverDocs deserializes document metadata correctly', () {
      final sampleDocJson = <String, dynamic>{
        'err': false,
        'message': 'Success',
        'docs': <String, dynamic>{
          'RecordId': 55,
          'Type': 'License',
          'DocUrl': 'https://cdn.example.com/license.pdf',
          'FrontPhoto_ImageUrl': 'https://cdn.example.com/front.jpg',
        },
      };

      final response = DriverDocumentResponse.fromJson(sampleDocJson);
      expect(response.err, isFalse);
      expect(response.docs?.recordId, equals(55));
      expect(response.docs?.type, equals('License'));
      expect(response.docs?.docUrl, equals('https://cdn.example.com/license.pdf'));
    });
  });

  group('DriverProvider state management', () {
    test('fetchDrivers updates drivers and handles loading state', () async {
      final fakeService = _FakeDriverService();
      final provider = DriverProvider(fakeService);

      expect(provider.isLoading, isFalse);
      expect(provider.drivers, isEmpty);

      final future = provider.fetchDrivers();
      expect(provider.isLoading, isTrue);

      await future;
      expect(provider.isLoading, isFalse);
      expect(provider.drivers.length, equals(1));
      expect(provider.drivers.first.firstName, equals('Ramesh'));
    });

    test('addDriver adds new driver and refreshes list', () async {
      final fakeService = _FakeDriverService();
      final provider = DriverProvider(fakeService);

      const request = AddDriverRequest(
        firstName: 'New',
        lastName: 'Driver',
        mobile: '9000000000',
      );

      final success = await provider.addDriver(request);
      expect(success, isTrue);
      expect(fakeService.createdDrivers.length, equals(1));
    });

    test('deleteDriver removes driver by ID', () async {
      final fakeService = _FakeDriverService();
      final provider = DriverProvider(fakeService);

      await provider.fetchDrivers();
      expect(provider.drivers.length, equals(1));

      final deleted = await provider.deleteDriver(101);
      expect(deleted, isTrue);
      expect(provider.drivers, isEmpty);
    });
  });
}

class _FakeDriverService extends DriverService {
  _FakeDriverService() : super(_FakeApiClient());

  final List<AddDriverRequest> createdDrivers = <AddDriverRequest>[];
  final List<Driver> _mockDrivers = <Driver>[
    const Driver(
      id: 101,
      firstName: 'Ramesh',
      lastName: 'Sharma',
      mobile: '9876543210',
    ),
  ];

  @override
  Future<List<Driver>> getDrivers() async => List<Driver>.from(_mockDrivers);

  @override
  Future<void> createDriver(AddDriverRequest request) async {
    createdDrivers.add(request);
  }

  @override
  Future<void> updateDriver(AddDriverRequest request) async {}

  @override
  Future<void> deleteDriver(int driverId) async {
    _mockDrivers.removeWhere((d) => d.id == driverId);
  }

  @override
  Future<DriverDocs?> getDriverDocs(int driverId, String docType) async => null;

  @override
  Future<void> uploadDriverDocs(FormData formData) async {}

  @override
  Future<void> deleteDriverDoc(int driverId, String docType) async {}
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(environment: ApiEnvironment.dev);
}
