import 'package:flutter_test/flutter_test.dart';
import 'package:routes/routes.dart';

class MockRouteService implements RouteService {
  List<Routee> mockRoutes = [];
  List<Standards> mockStandards = [];
  Student mockStudent = const Student();
  List<StudentData> mockSearchResults = [];

  bool getRoutesCalled = false;
  bool getStandardsCalled = false;
  bool getStudentsCalled = false;
  bool searchStudentCalled = false;
  bool changeRouteCalled = false;
  bool changeBothRoutesCalled = false;
  bool updateRouteTimeCalled = false;

  @override
  Future<List<Routee>> getRoutesAndPoints(RouteMode? mode) async {
    getRoutesCalled = true;
    return mockRoutes;
  }

  @override
  Future<List<Standards>> getStandards() async {
    getStandardsCalled = true;
    return mockStandards;
  }

  @override
  Future<Student> getStudents({
    required int classId,
    required List<String> sections,
    required int pageNo,
  }) async {
    getStudentsCalled = true;
    return mockStudent;
  }

  @override
  Future<List<StudentData>> searchStudent({
    required String search,
    int? classId,
    List<String>? sections,
  }) async {
    searchStudentCalled = true;
    return mockSearchResults;
  }

  @override
  Future<bool> changeStudentRoute(ChangeRouteRequest request) async {
    changeRouteCalled = true;
    return true;
  }

  @override
  Future<bool> changeBothRoutes(ChangeBothRoutesRequest request) async {
    changeBothRoutesCalled = true;
    return true;
  }

  @override
  Future<bool> updateStartTimeForRoutes(UpdateRouteTimeRequest request) async {
    updateRouteTimeCalled = true;
    return true;
  }
}

void main() {
  group('Route Models Serialization', () {
    test('Routee deserializes and serializes successfully', () {
      final json = <String, dynamic>{
        'Id': 101,
        'RouteNo': 'R-01',
        'Mode': 'Pickup',
        'VehicleNumber': 'TS09EA1234',
        'RouteStartTime': '07:30 AM',
        'Points': [
          {
            'Name': 'KPHB Colony',
            'StudentIds': [10, 20, 30],
          }
        ],
      };

      final route = Routee.fromJson(json);
      expect(route.id, equals(101));
      expect(route.routeNo, equals('R-01'));
      expect(route.mode, equals(RouteMode.pickup));
      expect(route.points.length, equals(1));
      expect(route.points.first.name, equals('KPHB Colony'));
      expect(route.points.first.studentIds.length, equals(3));

      final serialized = route.toJson();
      expect(serialized['Id'], equals(101));
      expect(serialized['RouteNo'], equals('R-01'));
      expect(serialized['Mode'], equals('Pickup'));
    });

    test('Standards & Sections deserialize and serialize', () {
      final json = <String, dynamic>{
        'Id': 5,
        'Name': 'Class 10',
        'StandardType': 'HighSchool',
        'Sections': [
          {'Id': 1, 'Name': 'A'},
          {'Id': 2, 'Name': 'B'},
        ],
      };

      final standard = Standards.fromJson(json);
      expect(standard.id, equals(5));
      expect(standard.name, equals('Class 10'));
      expect(standard.sections.length, equals(2));
      expect(standard.sections.first.name, equals('A'));

      final serialized = standard.toJson();
      expect(serialized['Id'], equals(5));
      expect(serialized['Name'], equals('Class 10'));
    });

    test('StudentData and Student deserializes with metadata', () {
      final json = <String, dynamic>{
        'metadata': [
          {'total': 150, 'pageNumber': 1, 'pageSize': 100}
        ],
        'data': [
          {
            'Id': 201,
            'Name': 'Aarav Sharma',
            'RollNo': '12',
            'Standard': 'Class 10',
            'ClassId': 5,
            'Section': 'A',
            'PickPoint': 'Main Gate',
            'DropPoint': 'Cross Roads',
            'mode': ['Pickup', 'Drop'],
            'routes': ['R-01', 'R-02'],
            'routeIds': ['101', '102'],
          }
        ],
      };

      final student = Student.fromJson(json);
      expect(student.metadata.length, equals(1));
      expect(student.metadata.first.total, equals(150));
      expect(student.data.length, equals(1));

      final first = student.data.first;
      expect(first.name, equals('Aarav Sharma'));
      expect(first.mode.length, equals(2));
      expect(first.routes.length, equals(2));

      final serialized = first.toJson();
      expect(serialized['Name'], equals('Aarav Sharma'));
      expect(serialized['ClassId'], equals(5));
    });

    test('Request models serialize properly', () {
      const changeRoute = ChangeRouteRequest(
        mode: RouteMode.pickup,
        studentId: 201,
        classId: 5,
        sections: ['A'],
        existingRouteId: 101,
        route: 105,
        point: 'New Stop',
      );
      final jsonRoute = changeRoute.toJson();
      expect(jsonRoute['IsInTransport'], equals('yes'));
      expect(jsonRoute['PickupRouteId'], equals(101));
      expect(jsonRoute['TargetPickupRoute'], equals(105));

      const updateTime = UpdateRouteTimeRequest(
        time: '08:00 AM',
        mode: RouteMode.drop,
        changeMode: 'CUSTOM',
        selectedRouteIds: [101, 102],
      );
      final jsonTime = updateTime.toJson();
      expect(jsonTime['RouteStartTime'], equals('08:00 AM'));
      expect(jsonTime['Mode'], equals('Drop'));
      expect(jsonTime['RouteIds'], contains(101));
    });
  });

  group('RoutesProvider state management', () {
    late MockRouteService mockService;
    late RoutesProvider provider;

    setUp(() {
      mockService = MockRouteService();
      provider = RoutesProvider(mockService);
    });

    test('fetchRoutes loads routes for mode', () async {
      mockService.mockRoutes = [
        const Routee(id: 1, routeNo: 'R-01', mode: RouteMode.pickup),
        const Routee(id: 2, routeNo: 'R-02', mode: RouteMode.pickup),
      ];

      expect(provider.isLoading, isFalse);
      final future = provider.fetchRoutes(RouteMode.pickup);
      expect(provider.isLoading, isTrue);
      await future;

      expect(provider.isLoading, isFalse);
      expect(provider.routes.length, equals(2));
      expect(mockService.getRoutesCalled, isTrue);
    });

    test('fetchStandards loads standards list', () async {
      mockService.mockStandards = [
        const Standards(id: 1, name: 'Grade 1'),
      ];

      await provider.fetchStandards();
      expect(provider.standards.length, equals(1));
      expect(mockService.getStandardsCalled, isTrue);
    });

    test('fetchStudents populates students list and handles pagination flag', () async {
      mockService.mockStudent = const Student(
        metadata: [Metadatum(total: 2)],
        data: [
          StudentData(id: 1, name: 'Student 1'),
          StudentData(id: 2, name: 'Student 2'),
        ],
      );

      await provider.fetchStudents(5, ['A']);
      expect(provider.students.length, equals(2));
      expect(provider.hasNextPage, isFalse);
      expect(mockService.getStudentsCalled, isTrue);
    });

    test('searchStudent updates students and sets hasNextPage to false', () async {
      mockService.mockSearchResults = [
        const StudentData(id: 1, name: 'Aarav'),
      ];

      await provider.searchStudent('Aarav');
      expect(provider.students.length, equals(1));
      expect(provider.hasNextPage, isFalse);
      expect(mockService.searchStudentCalled, isTrue);
    });

    test('updateRouteTime calls service and refreshes routes', () async {
      const request = UpdateRouteTimeRequest(
        time: '07:15 AM',
        mode: RouteMode.pickup,
        changeMode: 'ALL',
      );

      final result = await provider.updateRouteTime(request);
      expect(result, isTrue);
      expect(mockService.updateRouteTimeCalled, isTrue);
      expect(mockService.getRoutesCalled, isTrue);
    });
  });
}
