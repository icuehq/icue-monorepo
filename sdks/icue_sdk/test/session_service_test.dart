import 'package:flutter_test/flutter_test.dart';
import 'package:icue_sdk/icue_sdk.dart';
import 'package:icue_sdk/src/models/user.dart';
import 'package:icue_sdk/src/services/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('setConfig stores configuration correctly', () {
      final session = SessionService();
      const config = IcueSdkConfig(
        apiKey: 'test-api-key',
        apiUser: 'test-user',
        env: IcueEnvironment.dev,
      );

      session.setConfig(config);
      expect(session.config, equals(config));
      expect(session.apiKey, equals('test-api-key'));
      expect(session.apiUser, equals('test-user'));
    });

    test('setUser and token getter behavior', () {
      final session = SessionService();
      expect(session.user, isNull);
      expect(session.token, isNull);

      final user = User(
        organizationId: 1,
        branchId: 1,
        zoneId: 1,
        id: 101,
        name: 'Test Student',
        rollNo: '12',
        admissionNumber: 'ST101',
        classId: 5,
        standard: 'V',
        section: 'A',
        gender: 'Male',
        parentName: 'Parent',
        pickPoint: 'Stop A',
        pickArea: 'Area A',
        dropArea: 'Area B',
        dropPoint: 'Stop B',
        isMessOpted: false,
        isTransportOpted: true,
        schoolName: 'Test School',
        schoolPoint: [17.4, 78.4],
        token: 'sample-bearer-token',
      );

      session.setUser(user);
      expect(session.user, equals(user));
      expect(session.token, equals('sample-bearer-token'));
    });

    test('clearSession clears student state while preserving device token',
        () async {
      final session = SessionService();
      await session.setIdentificationNo('student-123');

      final user = User(
        organizationId: 1,
        branchId: 1,
        zoneId: 1,
        id: 101,
        name: 'Test Student',
        rollNo: '12',
        admissionNumber: 'ST101',
        classId: 5,
        standard: 'V',
        section: 'A',
        gender: 'Male',
        parentName: 'Parent',
        pickPoint: 'Stop A',
        pickArea: 'Area A',
        dropArea: 'Area B',
        dropPoint: 'Stop B',
        isMessOpted: false,
        isTransportOpted: true,
        schoolName: 'Test School',
        schoolPoint: [17.4, 78.4],
        token: 'sample-bearer-token',
      );

      session.setUser(user);
      await session.setFcmToken('test-device-fcm-token');

      expect(session.user, isNotNull);
      expect(session.fcmToken, equals('test-device-fcm-token'));
      expect(session.identificationNo, equals('student-123'));

      await session.clearSession();

      expect(session.user, isNull);
      expect(session.identificationNo, isNull);

      // Student user persistence cleared
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('icue_default_user_student-123'), isFalse);

      // Global device token is preserved across session clears
      expect(
        prefs.getString('icue_device_fcm_token'),
        equals('test-device-fcm-token'),
      );

      // clearAllPersistence clears device token as well
      await session.clearAllPersistence();
      expect(session.fcmToken, isNull);
      expect(prefs.containsKey('icue_device_fcm_token'), isFalse);
    });

    test('clearFcmToken removes the device token only', () async {
      final session = SessionService();
      final prefs = await SharedPreferences.getInstance();

      await session.setFcmToken('device-token-to-delete');
      await session.setIdentificationNo('student-token-clear');
      session.setUser(
        User.fromJson({'Id': 42, 'Token': 'student-auth-token'}),
      );

      await session.clearFcmToken();

      expect(session.fcmToken, isNull);
      expect(prefs.containsKey('icue_device_fcm_token'), isFalse);
      expect(session.identificationNo, equals('student-token-clear'));
      expect(session.token, equals('student-auth-token'));
    });

    test(
        'student switching preserves global device token and isolates student data',
        () async {
      final session = SessionService();
      await session.setFcmToken('global-fcm-token-999');

      await session.setIdentificationNo('student-1');
      final user1 = User(
        organizationId: 1,
        branchId: 1,
        zoneId: 1,
        id: 1,
        name: 'Student One',
        rollNo: '1',
        admissionNumber: 'ST1',
        classId: 1,
        standard: 'I',
        section: 'A',
        gender: 'Male',
        parentName: 'P1',
        pickPoint: 'A',
        pickArea: 'A',
        dropArea: 'A',
        dropPoint: 'A',
        isMessOpted: false,
        isTransportOpted: true,
        schoolName: 'School',
        schoolPoint: [17.4, 78.4],
        token: 'token-student-1',
      );
      session.setUser(user1);

      // Switch to Student 2
      await session.setIdentificationNo('student-2');
      expect(session.identificationNo, equals('student-2'));
      expect(session.user, isNull); // Student 2 has no stored user yet
      expect(
        session.fcmToken,
        equals('global-fcm-token-999'),
      ); // Device token retained

      // Switch back to Student 1
      await session.setIdentificationNo('student-1');
      expect(session.identificationNo, equals('student-1'));
      expect(session.user?.id, equals(1)); // Restored from SharedPreferences
      expect(session.token, equals('token-student-1'));
    });

    test(
        'restoreLastIdentificationNo restores last active student ID and session',
        () async {
      final session1 = SessionService();
      await session1.setIdentificationNo('student-last-active');
      session1.setUser(
        User.fromJson({
          'Id': 555,
          'AdmissionNumber': 'student-last-active',
          'Token': 'token-555',
        }),
      );

      // Create new session service instance simulating app restart
      final session2 = SessionService();
      expect(session2.identificationNo, isNull);
      expect(session2.user, isNull);

      await session2.restoreLastIdentificationNo();
      expect(session2.identificationNo, equals('student-last-active'));
      expect(session2.user?.id, equals(555));
      expect(session2.token, equals('token-555'));

      // Clear session should remove active student ID
      await session2.clearSession();
      final session3 = SessionService();
      await session3.restoreLastIdentificationNo();
      expect(session3.identificationNo, isNull);
    });
  });
}
