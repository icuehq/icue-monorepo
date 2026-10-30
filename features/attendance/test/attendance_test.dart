import 'package:api_client/api_client.dart';
import 'package:attendance/attendance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icue_face_sdk/icue_face_sdk.dart';
import 'package:local_storage/local_storage.dart';

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

class FakeStorageService extends Fake implements StorageService {
  final Map<String, Map<dynamic, dynamic>> _storage = {};

  @override
  bool isBoxOpen(String boxName) => true;

  @override
  Future<Box<T>> openBox<T>(String boxName) async {
    _storage.putIfAbsent(boxName, () => {});
    return FakeBox<T>(_storage[boxName]!);
  }

  @override
  Box<T> getBox<T>(String boxName) {
    _storage.putIfAbsent(boxName, () => {});
    return FakeBox<T>(_storage[boxName]!);
  }

  @override
  bool containsKey(String boxName, dynamic key) {
    return _storage[boxName]?.containsKey(key) ?? false;
  }

  @override
  T? get<T>(String boxName, dynamic key, {T? defaultValue}) {
    final val = _storage[boxName]?[key];
    return (val as T?) ?? defaultValue;
  }

  @override
  Future<void> put<T>(String boxName, dynamic key, T value) async {
    _storage.putIfAbsent(boxName, () => {});
    _storage[boxName]![key] = value;
  }

  @override
  Future<void> delete(String boxName, dynamic key) async {
    _storage[boxName]?.remove(key);
  }
}

class FakeBox<T> extends Fake implements Box<T> {
  FakeBox(this._map);
  final Map<dynamic, dynamic> _map;

  @override
  Iterable<dynamic> get keys => _map.keys;
}

void main() {
  group('Attendance Models Serialization', () {
    test('AttendanceStudent deserializes, copies and serializes properly', () {
      final json = <String, dynamic>{
        'Id': 101,
        'Name': 'Alice Smith',
        'RollNo': '01',
        'AdmissionNumber': 'ADM-101',
        'IsPresent': true,
        'UID': 'UID-101',
        'AttendanceMode': 'FACIAL',
      };

      final student = AttendanceStudent.fromJson(json);
      expect(student.id, 101);
      expect(student.name, 'Alice Smith');
      expect(student.isPresent, true);
      expect(student.attendanceMode, 'FACIAL');

      final toggled = student.copyWith(isPresent: false);
      expect(toggled.isPresent, false);

      final out = toggled.toJson();
      expect(out['Id'], 101);
      expect(out['IsPresent'], false);
    });

    test('CreateAttendance deserializes and serializes with students', () {
      final json = <String, dynamic>{
        'Source': 'adminapp',
        'Students': [
          {
            'Id': 1,
            'Name': 'Bob',
            'RollNo': '02',
            'AdmissionNumber': 'ADM-02',
            'IsPresent': false,
          },
        ],
        'ClassId': 10,
        'Section': 'A',
        'Standard': 'Grade 5',
        'AttendanceDate': '30/10/2026',
        'AttendanceTime': '09:00 AM',
        'Month': 10,
        'Year': 2026,
        'Period': '1',
        'AttendanceMode': 'MANUAL',
      };

      final attendance = CreateAttendance.fromJson(json);
      expect(attendance.classId, 10);
      expect(attendance.section, 'A');
      expect(attendance.students.length, 1);
      expect(attendance.students.first.name, 'Bob');

      final out = attendance.toJson();
      expect(out['ClassId'], 10);
      expect(out['Section'], 'A');
    });

    test('CreateAttendanceResponse parses id and status message', () {
      final json = <String, dynamic>{
        'Id': 777,
        'Standard': 'Grade 5',
        'Section': 'A',
        'Presenties': 25,
        'Absenties': 3,
        'err': false,
        'message': 'Success',
      };

      final res = CreateAttendanceResponse.fromJson(json);
      expect(res.id, 777);
      expect(res.presenties, 25);
      expect(res.absenties, 3);
      expect(res.err, false);
    });
  });

  group('AttendanceSessionManager Logic', () {
    late AttendanceSessionManager sessionManager;

    setUp(() {
      final roster = [
        StudentSessionState(
          personId: '101',
          studentName: 'Alice',
          profileState: ProfileState.ready,
        ),
        StudentSessionState(
          personId: '102',
          studentName: 'Bob',
          profileState: ProfileState.notEnrolled,
        ),
      ];

      sessionManager = AttendanceSessionManager(
        sessionId: 'session_1',
        rosterRevision: 'rev_1',
        modelContractId: 'mfn_v1',
        initialRoster: roster,
        requiredMatchesCount: 2,
        timeWindowDuration: const Duration(seconds: 5),
        minObservationInterval: Duration.zero,
      );
    });

    test('initializes eligible roster correctly', () {
      expect(sessionManager.studentMap.length, 2);
      expect(sessionManager.eligibleRoster.length, 1);
      expect(sessionManager.eligibleRoster.first.personId, '101');
    });

    test(
      'processes observation frames and marks present when threshold met',
      () {
        const box = FaceBoundingBox(
          left: 10,
          top: 10,
          right: 100,
          bottom: 100,
          trackingId: 1,
        );

        const result = FaceRecognitionResult(
          matched: true,
          personId: '101',
          score: 0.95,
          boundingBox: box,
        );

        // Frame 1
        sessionManager.processObservationFrame(
          results: [result],
          frameRosterRevision: 'rev_1',
        );
        expect(sessionManager.studentMap['101']!.isPresent, false);

        // Frame 2 -> meets threshold of 2
        sessionManager.processObservationFrame(
          results: [result],
          frameRosterRevision: 'rev_1',
        );
        expect(sessionManager.studentMap['101']!.isPresent, true);
        expect(sessionManager.studentMap['101']!.markSource, MarkSource.face);
      },
    );

    test('manual override updates student state', () {
      sessionManager.setManualAttendance('102', true);
      expect(sessionManager.studentMap['102']!.isPresent, true);
      expect(sessionManager.studentMap['102']!.markSource, MarkSource.manual);
    });

    test('finalizeSession generates AttendanceResult', () {
      sessionManager.setManualAttendance('101', true);
      final finalResult = sessionManager.finalizeSession(
        mode: AttendanceMode.liveStream,
      );

      expect(finalResult.present.length, 1);
      expect(finalResult.present.first.personId, '101');
      expect(finalResult.absentPersonIds.isEmpty, true);
    });
  });

  group('AttendanceProvider State Management', () {
    late MockApiClient mockApi;
    late AttendanceService service;
    late FakeStorageService storage;
    late AttendanceProvider provider;

    setUp(() {
      mockApi = MockApiClient();
      service = AttendanceService(mockApi);
      storage = FakeStorageService();
      provider = AttendanceProvider(service, storage);
    });

    test(
      'updateAttendance and getOngoingAttendance persist and restore session',
      () async {
        const student = AttendanceStudent(
          id: 1,
          name: 'Student One',
          rollNo: '01',
          admissionNumber: 'ADM-1',
          isPresent: true,
        );

        await provider.updateAttendance(
          classId: 5,
          className: 'Grade 5',
          section: 'A',
          period: '1',
          student: student,
        );

        expect(provider.ongoingAttendance, isNotNull);
        expect(provider.ongoingAttendance!.students.length, 1);

        // Verify restore from storage
        final restored = await provider.getOngoingAttendance();
        expect(restored, isNotNull);
        expect(restored!.classId, 5);
        expect(restored.section, 'A');
      },
    );

    test('toggleStudentAttendance flips student presence flag', () async {
      const student = AttendanceStudent(
        id: 2,
        name: 'Student Two',
        rollNo: '02',
        admissionNumber: 'ADM-2',
        isPresent: true,
      );

      await provider.updateAttendance(
        classId: 5,
        className: 'Grade 5',
        section: 'A',
        period: '1',
        student: student,
      );

      await provider.toggleStudentAttendance(student);
      expect(provider.ongoingAttendance!.students.first.isPresent, false);
    });

    test('deleteOngoingAttendance removes session from storage', () async {
      const student = AttendanceStudent(
        id: 3,
        name: 'Student Three',
        rollNo: '03',
        admissionNumber: 'ADM-3',
        isPresent: true,
      );

      await provider.updateAttendance(
        classId: 5,
        className: 'Grade 5',
        section: 'A',
        period: '1',
        student: student,
      );

      await provider.deleteOngoingAttendance();
      expect(provider.ongoingAttendance, isNull);
      expect(provider.effectiveAttendanceKey, isNull);
    });
  });
}
