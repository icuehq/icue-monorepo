import 'dart:io';

import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  group('OTP Response serialization', () {
    test('OtpResponse deserializes username and pin', () {
      final sampleJson = <String, dynamic>{
        'username': '8686914316',
        'pin': '54321',
      };
      final response = OtpResponse.fromJson(sampleJson);
      expect(response.username, equals('8686914316'));
      expect(response.pin, equals('54321'));
    });
  });

  group('UserInfo serialization', () {
    test('UserInfo deserializes successfully', () {
      final sampleResponse = <String, dynamic>{
        'Id': 4093,
        'Name': 'Flutter Admin Test',
        'UserName': '8686914316',
        'OrganizationId': 8,
        'ZoneId': 147,
        'BranchId': 427,
        'Roles': <Map<String, dynamic>>[
          <String, dynamic>{'Id': 8, 'Name': 'Fleet_Admin'},
        ],
        'Token': 'jwt-test-token',
      };

      final response = UserInfo.fromJson(sampleResponse);
      expect(response.id, equals(4093));
      expect(response.name, equals('Flutter Admin Test'));
      expect(response.userName, equals('8686914316'));
      expect(response.roles.length, equals(1));
      expect(response.roles.first.name, equals('Fleet_Admin'));
      expect(response.token, equals('jwt-test-token'));
    });
  });

  group('SessionTokenProvider', () {
    test('manages token lifecycle with persistence backup', () async {
      final fakeStorage = _FakeUserLocalStorage();
      final tokenProvider = SessionTokenProvider(fakeStorage);
      expect(tokenProvider.isAuthenticated, isFalse);

      tokenProvider.setToken('auth-token');
      expect(tokenProvider.isAuthenticated, isTrue);
      expect(await tokenProvider.getAccessToken(), equals('auth-token'));

      await tokenProvider.clear();
      expect(tokenProvider.isAuthenticated, isFalse);
    });

    test('initializes with token from storage if already present', () async {
      final fakeStorage = _FakeUserLocalStorage();
      await fakeStorage.saveUser(
        UserInfo(
          id: 1,
          name: 'Existing User',
          userName: 'existing',
          token: 'restored-token',
        ),
      );

      final tokenProvider = SessionTokenProvider(fakeStorage);
      expect(tokenProvider.isAuthenticated, isTrue);
      expect(await tokenProvider.getAccessToken(), equals('restored-token'));
    });
  });

  group('IndianPhoneValidator', () {
    test('validates 10-digit Indian numbers starting with 6, 7, 8, 9', () {
      expect(IndianPhoneValidator.isValid('9876543210'), isTrue);
      expect(IndianPhoneValidator.isValid('8123456789'), isTrue);
      expect(IndianPhoneValidator.isValid('7012345678'), isTrue);
      expect(IndianPhoneValidator.isValid('6300123456'), isTrue);
      expect(IndianPhoneValidator.validate('9876543210'), isNull);
    });

    test('normalizes country code prefixes (+91, 91, 0) and formatting', () {
      expect(
        IndianPhoneValidator.normalize('+91 98765 43210'),
        equals('9876543210'),
      );
      expect(
        IndianPhoneValidator.normalize('919876543210'),
        equals('9876543210'),
      );
      expect(
        IndianPhoneValidator.normalize('09876543210'),
        equals('9876543210'),
      );
      expect(IndianPhoneValidator.isValid('+91 98765-43210'), isTrue);
    });

    test('rejects empty or whitespace input', () {
      expect(
        IndianPhoneValidator.validate(''),
        equals('Please enter mobile number'),
      );
      expect(
        IndianPhoneValidator.validate('   '),
        equals('Please enter mobile number'),
      );
      expect(IndianPhoneValidator.isValid(null), isFalse);
    });

    test('rejects invalid numbers with a user-friendly message', () {
      expect(
        IndianPhoneValidator.validate('98765'),
        equals('Please enter a valid 10-digit mobile number'),
      );
      expect(
        IndianPhoneValidator.validate('987654321012'),
        equals('Please enter a valid 10-digit mobile number'),
      );
      expect(
        IndianPhoneValidator.validate('5123456789'),
        equals('Please enter a valid 10-digit mobile number'),
      );
      expect(
        IndianPhoneValidator.validate('1234567890'),
        equals('Please enter a valid 10-digit mobile number'),
      );
    });
  });

  group('AuthProvider operations & zonal branch logic', () {
    test('initializes with authenticated state if user in storage', () {
      final fakeStorage = _FakeUserLocalStorage();
      fakeStorage.saveUser(
        UserInfo(
          id: 1,
          name: 'Cached User',
          userName: 'cached_user',
          token: 'stored-jwt',
        ),
      );

      final fakeService = _FakeAuthService(fakeStorage);
      final tokenProvider = SessionTokenProvider(fakeStorage);
      final provider = AuthProvider(fakeService, fakeStorage, tokenProvider);

      expect(provider.isAuthenticated, isTrue);
      expect(provider.step, equals(AuthStep.authenticated));
      expect(provider.username, equals('cached_user'));
    });

    test(
      'sets friendly message when login throws UnauthorizedException',
      () async {
        final fakeStorage = _FakeUserLocalStorage();
        final fakeService = _FakeAuthService(
          fakeStorage,
        )..errorToThrow = const UnauthorizedException(message: 'un authorized');
        final tokenProvider = SessionTokenProvider(fakeStorage);
        final provider = AuthProvider(fakeService, fakeStorage, tokenProvider);

        final result = await provider.verifyOtpAndLogin(otp: '1234');

        expect(result, isFalse);
        expect(
          provider.errorMessage,
          equals('Invalid OTP. Please check and try again.'),
        );
      },
    );

    test('sets friendly message when login throws ApiException with generic un authorized', () async {
      final fakeStorage = _FakeUserLocalStorage();
      final fakeService = _FakeAuthService(fakeStorage)
        ..errorToThrow = const UnknownApiException(message: 'un authorized');
      final tokenProvider = SessionTokenProvider(fakeStorage);
      final provider = AuthProvider(fakeService, fakeStorage, tokenProvider);

      final result = await provider.verifyOtpAndLogin(otp: '1234');

      expect(result, isFalse);
      expect(
        provider.errorMessage,
        equals('Invalid OTP. Please check and try again.'),
      );
    });

    test(
      'resets auth and displays friendly message on session expiration',
      () async {
        final fakeStorage = _FakeUserLocalStorage();
        await fakeStorage.saveUser(
          UserInfo(
            id: 1,
            name: 'Active User',
            userName: 'active',
            token: 'tok-123',
          ),
        );
        final tokenProvider = SessionTokenProvider(fakeStorage);
        final fakeService = _FakeAuthService(fakeStorage);
        final provider = AuthProvider(fakeService, fakeStorage, tokenProvider);

        expect(provider.isAuthenticated, isTrue);

        // Trigger 401 unresolvable auth failure
        await tokenProvider.onAuthFailed();

        expect(provider.isAuthenticated, isFalse);
        expect(provider.step, equals(AuthStep.requestOtp));
        expect(
          provider.errorMessage,
          equals('Session expired. Please log in again.'),
        );
      },
    );

    test(
      'zonal admin login requires branch selection before reaching dashboard',
      () async {
        final fakeStorage = _FakeUserLocalStorage();
        final fakeService = _FakeAuthService(fakeStorage)
          ..mockUser = UserInfo(
            id: 50,
            name: 'Zonal Admin',
            userName: 'zonaladmin',
            token: 'zonal-token',
            roles: <Role>[Role(id: 10, name: 'Fleet_ZonalAdmin')],
          );
        final tokenProvider = SessionTokenProvider(fakeStorage);
        final provider = AuthProvider(fakeService, fakeStorage, tokenProvider);

        final success = await provider.login(
          username: '9876543210',
          password: 'otp',
        );
        expect(success, isTrue);
        expect(provider.isZonalAdminOrSupervisor, isTrue);
        expect(provider.needsBranchSelection, isTrue);

        // Select branch
        final branch = Branch(
          id: 1,
          schoolName: 'Greenwood',
          schoolShortName: 'GW',
        );
        await provider.selectZonalBranch(branch);

        expect(provider.selectedBranch?.schoolName, equals('Greenwood'));
        expect(provider.needsBranchSelection, isFalse);
      },
    );
  });

  group('UserLocalStorage real Hive backward compatibility', () {
    late Directory tempDir;
    late StorageService storageService;
    late UserLocalStorage userLocalStorage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_auth_test_');
      Hive.init(tempDir.path);
      storageService = StorageService();
      userLocalStorage = UserLocalStorage(storageService);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('saveUser and getUser retrieves user and token', () async {
      final user = UserInfo(
        id: 42,
        name: 'Alice',
        userName: 'alice',
        token: 'token-alice',
      );
      await userLocalStorage.saveUser(user);

      final retrieved = userLocalStorage.getUser();
      expect(retrieved, isNotNull);
      expect(retrieved!.name, equals('Alice'));
      expect(userLocalStorage.getToken(), equals('token-alice'));
    });

    test('backwards compatibility: reads existing legacy user stored via box.add()', () async {
      final box = await Hive.openBox<UserInfo>(StorageConstants.userInfoBox);
      final legacyUser = UserInfo(
        id: 99,
        name: 'Legacy User',
        userName: 'legacy',
        token: 'legacy-token',
      );
      // Simulate existing app storing via box.add
      await box.add(legacyUser);

      final retrieved = userLocalStorage.getUser();
      expect(retrieved, isNotNull);
      expect(retrieved!.token, equals('legacy-token'));
      expect(userLocalStorage.getToken(), equals('legacy-token'));
    });

    test('clearUser clears stored user', () async {
      await userLocalStorage.saveUser(
        UserInfo(id: 1, name: 'Bob', userName: 'bob', token: 'token-bob'),
      );
      expect(userLocalStorage.getUser(), isNotNull);

      await userLocalStorage.clearUser();
      expect(userLocalStorage.getUser(), isNull);
      expect(userLocalStorage.getToken(), isNull);
    });

    test('saveFcmToken and getFcmToken', () async {
      await userLocalStorage.saveFcmToken('fcm-token-xyz');
      expect(userLocalStorage.getFcmToken(), equals('fcm-token-xyz'));
    });

    test('saveRoleActions and getRoleActions in Hive', () async {
      final actions = <RoleActions>[
        RoleActions(
          id: 1,
          name: 'Dashboard',
          routeState: '/home',
          icon: 'home',
          tabOrder: 0,
          displayName: 'Home',
        ),
      ];
      await userLocalStorage.saveRoleActions(actions);
      final retrieved = userLocalStorage.getRoleActions();
      expect(retrieved.length, equals(1));
      expect(retrieved.first.displayName, equals('Home'));
    });

    test('saveSelectedBranch and getSelectedBranch in Hive', () async {
      final branch = Branch(
        id: 5,
        schoolName: 'Oakridge',
        schoolShortName: 'OAK',
      );
      await userLocalStorage.saveSelectedBranch(branch);
      final retrieved = userLocalStorage.getSelectedBranch();
      expect(retrieved, isNotNull);
      expect(retrieved!.schoolName, equals('Oakridge'));
    });

    test('savePersonTypes and getPersonTypes in Hive', () async {
      final types = <PersonType>[
        PersonType(id: 1, category: 'Student'),
        PersonType(id: 2, category: 'Staff'),
      ];
      await userLocalStorage.savePersonTypes(types);
      final retrieved = userLocalStorage.getPersonTypes();
      expect(retrieved.length, equals(2));
      expect(retrieved.first.category, equals('Student'));
    });

    test('simulates app reload: opens box via init and restores session into AuthProvider', () async {
      // 1. First session: user logs in and user is saved
      final user = UserInfo(
        id: 777,
        name: 'Persistent User',
        userName: 'persistent',
        token: 'persisted-jwt-123',
      );
      await userLocalStorage.saveUser(user);

      // 2. Simulate app reload/restart: close all Hive boxes
      await Hive.close();

      // 3. New app lifecycle starts: storage engine and user storage initialize
      final reloadedStorageService = StorageService();
      final reloadedUserStorage = UserLocalStorage(reloadedStorageService);
      await reloadedUserStorage.init();

      // 4. AuthProvider boots up and reads from storage
      final tokenProvider = SessionTokenProvider(reloadedUserStorage);
      final authService = _FakeAuthService(reloadedUserStorage);
      final provider = AuthProvider(
        authService,
        reloadedUserStorage,
        tokenProvider,
      );

      // 5. Must be authenticated immediately without showing login
      expect(provider.isAuthenticated, isTrue);
      expect(provider.step, equals(AuthStep.authenticated));
      expect(provider.user?.name, equals('Persistent User'));
      expect(tokenProvider.currentToken, equals('persisted-jwt-123'));
    });
  });
}

class _FakeStorageService implements StorageService {
  @override
  Future<void> init() async {}
  @override
  Future<Box<T>> openBox<T>(String boxName) async => throw UnimplementedError();
  @override
  Box<T> getBox<T>(String boxName) => throw UnimplementedError();
  @override
  bool isBoxOpen(String boxName) => true;
  @override
  Future<void> put<T>(String boxName, dynamic key, T value) async {}
  @override
  T? get<T>(String boxName, dynamic key, {T? defaultValue}) => defaultValue;
  @override
  Future<void> delete(String boxName, dynamic key) async {}
  @override
  bool containsKey(String boxName, dynamic key) => false;
  @override
  List<T> getAll<T>(String boxName) => [];
  @override
  Future<void> clearBox(String boxName) async {}
  @override
  Future<void> clearAll() async {}
  @override
  Future<void> closeAll() async {}
}

class _FakeUserLocalStorage extends UserLocalStorage {
  _FakeUserLocalStorage() : super(_FakeStorageService());

  UserInfo? _user;
  String? _fcmToken;
  Branch? _selectedBranch;
  List<RoleActions> _actions = <RoleActions>[];
  List<PersonType> _personTypes = <PersonType>[];

  @override
  Future<void> saveUser(UserInfo user) async {
    _user = user;
  }

  @override
  UserInfo? getUser() => _user;

  @override
  String? getToken() => _user?.token;

  @override
  Future<void> clearUser() async {
    _user = null;
  }

  @override
  Future<void> saveFcmToken(String token) async {
    _fcmToken = token;
  }

  @override
  String? getFcmToken() => _fcmToken;

  @override
  Future<void> saveSelectedBranch(Branch branch) async {
    _selectedBranch = branch;
  }

  @override
  Branch? getSelectedBranch() => _selectedBranch;

  @override
  Future<void> clearSelectedBranch() async {
    _selectedBranch = null;
  }

  @override
  Future<void> saveRoleActions(List<RoleActions> actions) async {
    _actions = actions;
  }

  @override
  List<RoleActions> getRoleActions() => _actions;

  @override
  Future<void> savePersonTypes(List<PersonType> types) async {
    _personTypes = types;
  }

  @override
  List<PersonType> getPersonTypes() => _personTypes;

  @override
  Future<void> clearAll() async {
    _user = null;
    _fcmToken = null;
    _selectedBranch = null;
    _actions = <RoleActions>[];
    _personTypes = <PersonType>[];
  }
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(UserLocalStorage userLocalStorage)
    : super(
        ApiClient(),
        SessionTokenProvider(userLocalStorage),
        userLocalStorage,
      );

  Exception? errorToThrow;
  UserInfo? mockUser;

  @override
  Future<UserInfo> login({
    required String username,
    required String password,
  }) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return mockUser ??
        UserInfo(
          id: 1,
          name: 'Test',
          userName: '8686914316',
          token: 'jwt-token',
        );
  }

  @override
  Future<List<RoleActions>> getRoleActions() async => <RoleActions>[];

  @override
  Future<List<Branch>> getBranchesByZoneId() async => <Branch>[
    Branch(id: 1, schoolName: 'Branch A', schoolShortName: 'BA'),
  ];

  @override
  Future<List<PersonType>> getPersonTypes() async => <PersonType>[];

  @override
  Future<List<AssignedEntityClass>> getAssignedEntities({
    bool forAttendance = false,
  }) async => <AssignedEntityClass>[];
}
