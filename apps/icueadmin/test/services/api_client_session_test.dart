import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:icueadmin/config/dev_config.dart';
import 'package:icueadmin/config/env.dart';
import 'package:icueadmin/models/branches.dart';
import 'package:icueadmin/models/user_info.dart';
import 'package:icueadmin/services/api_client.dart';
import 'package:icueadmin/services/crashlytics_service.dart';
import 'package:icueadmin/services/hrms_api_client.dart';

class FakeCrashlyticsService extends Fake implements CrashlyticsService {
  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late FakeCrashlyticsService fakeCrashlytics;
  late Box<UserInfo> userBox;
  late Box<Branch> zonalBranchBox;

  UserInfo createTestUser({
    required int id,
    required String token,
    required int branchId,
  }) {
    return UserInfo(
      id: id,
      name: 'Test User $id',
      userName: 'user$id',
      organizationId: 1,
      zoneId: 1,
      branchId: branchId,
      roles: [],
      classes: [],
      mobile: '1234567890',
      sesid: 'session-$id',
      isCorporate: false,
      isLogistics: false,
      orgType: 'School',
      typeOfBusiness: 'K12',
      loginType: 'admin',
      wardId: 0,
      token: token,
      isFirstLogin: false,
    );
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('api_client_session_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(UserInfoAdapter());
    }
    if (!Hive.isAdapterRegistered(22)) {
      Hive.registerAdapter(BranchAdapter());
    }

    userBox = await Hive.openBox<UserInfo>('userInfo-v2');
    zonalBranchBox = await Hive.openBox<Branch>('zonalBranch-v2');
  });

  tearDownAll(() async {
    await userBox.close();
    await zonalBranchBox.close();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await userBox.clear();
    await zonalBranchBox.clear();
    fakeCrashlytics = FakeCrashlyticsService();
    Env().config = DevConfig();
  });

  group('ApiClient Dynamic Session Handling', () {
    test('currentUser returns null when no user is in Hive', () {
      final client = ApiClient(fakeCrashlytics);
      expect(client.currentUser, isNull);
      expect(client.currentBranchId, isNull);
    });

    test('currentUser dynamically updates when user logs in and out', () async {
      final client = ApiClient(fakeCrashlytics);

      // 1. Initial state: not logged in
      expect(client.currentUser, isNull);

      // 2. User 1 logs in
      final user1 = createTestUser(
        id: 101,
        token: 'token-user-1',
        branchId: 17,
      );
      await userBox.add(user1);

      expect(client.currentUser?.id, 101);
      expect(client.currentUser?.token, 'token-user-1');
      expect(client.currentBranchId, 17);

      // 3. User 1 logs out (clears Hive)
      await userBox.clear();

      expect(client.currentUser, isNull);
      expect(client.currentBranchId, isNull);

      // 4. User 2 logs in with new token
      final user2 = createTestUser(
        id: 202,
        token: 'token-user-2',
        branchId: 25,
      );
      await userBox.add(user2);

      // Must immediately return user2 without using any stale cached token
      expect(client.currentUser?.id, 202);
      expect(client.currentUser?.token, 'token-user-2');
      expect(client.currentBranchId, 25);
    });

    test(
      'currentBranchId reflects newly selected zonal branch immediately',
      () async {
        final client = ApiClient(fakeCrashlytics);
        final user = createTestUser(id: 101, token: 'token-101', branchId: 10);
        await userBox.add(user);

        expect(client.currentBranchId, 10);

        // Zonal admin selects branch 99
        final branch99 = Branch(
          id: 99,
          schoolName: 'Branch 99',
          schoolShortName: 'B99',
        );
        await zonalBranchBox.put('selected', branch99);

        expect(client.currentBranchId, 99);

        // Clear selection
        await zonalBranchBox.clear();
        expect(client.currentBranchId, 10);
      },
    );

    test('HrmsApiClient also reflects current user dynamically', () async {
      final hrmsClient = HrmsApiClient(fakeCrashlytics);
      expect(hrmsClient.currentUser, isNull);

      final user = createTestUser(id: 303, token: 'token-hrms', branchId: 12);
      await userBox.add(user);

      expect(hrmsClient.currentUser?.id, 303);
      expect(hrmsClient.currentUser?.token, 'token-hrms');
    });

    test('onRequest does not inject token on login endpoints', () async {
      final client = ApiClient(fakeCrashlytics);
      final user = createTestUser(id: 101, token: 'token-101', branchId: 10);
      await userBox.add(user);

      // Setup dio adapter to intercept options
      final dio = client.dio;
      RequestOptions? interceptedOptions;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            interceptedOptions = options;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
              ),
            );
          },
        ),
      );

      // Request to /v2.0/login should NOT have token header
      try {
        await client.post('/v2.0/login', data: {'username': 'test'});
      } catch (_) {}

      expect(interceptedOptions?.headers['token'], isNull);

      // Request to other endpoint should have token header
      try {
        await client.post('/v1.0/getActionsByRole');
      } catch (_) {}

      expect(interceptedOptions?.headers['token'], 'token-101');
    });
  });
}
