import 'package:api_client/api_client.dart';
import 'package:auth/src/models/parent_user.dart';
import 'package:auth/src/services/parent_auth_service.dart';
import 'package:auth/src/storage/parent_session_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Session state of the signed-in parent: token, students and the student
/// whose data every parent screen shows.
@lazySingleton
class ParentAuthProvider extends ChangeNotifier {
  ParentAuthProvider(this._service, this._storage);

  final ParentAuthService _service;
  final ParentSessionStorage _storage;

  List<ParentStudent> _students = <ParentStudent>[];
  ParentStudent? _selected;
  bool _busy = false;

  bool get isSignedIn => _storage.token?.isNotEmpty ?? false;
  bool get busy => _busy;
  List<ParentStudent> get students => _students;
  ParentStudent? get selectedStudent => _selected;
  String? get mobile => _storage.mobile;
  int? get parentId => _storage.parentId;

  /// Loads the persisted session; call after [ParentSessionStorage.init].
  void restore() {
    _students = _storage.students;
    _selected = _storage.selected;
  }

  Future<T?> _guard<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } on ApiException {
      return null; // ApiClient already showed the message.
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<({ParentOtpResult result, String? message})?> requestOtp(
    String mobile,
  ) => _guard(() => _service.generateOtp(mobile));

  Future<bool> login(String mobile, String otp) async {
    final user = await _guard(() => _service.login(mobile, otp));
    if (user == null) return false;
    await _apply(user, mobile: mobile);
    return true;
  }

  /// Re-fetches the student list (and token) from the server.
  Future<void> refreshStudents() async {
    final mobile = this.mobile;
    if (mobile == null) return;
    final user = await _guard(
      () => _service.getStudentsList(
        mobile: mobile,
        studentId: (_selected ?? _students.firstOrNull)?.id,
      ),
    );
    if (user != null) await _apply(user);
  }

  Future<void> _apply(ParentUser user, {String? mobile}) async {
    await _storage.saveSession(
      token: user.token,
      mobile: mobile,
      parentId: user.id,
    );
    await _storage.saveStudents(user.students);
    _students = user.students;
    final selectedId = _selected?.id;
    _selected = user.students.where((s) => s.id == selectedId).firstOrNull;
    if (_selected != null) await _storage.saveSelected(_selected!);
    notifyListeners();
  }

  Future<void> selectStudent(ParentStudent student) async {
    await _storage.saveSelected(student);
    _selected = student;
    notifyListeners();
  }

  Future<void> registerPushToken(String deviceToken) async {
    try {
      await _service.updateRegistrationToken(
        deviceToken: deviceToken,
        studentIds: _students.map((s) => s.id).toList(),
        studentId: (_selected ?? _students.firstOrNull)?.id,
      );
    } on ApiException {
      // Push registration is best effort.
    }
  }

  /// Tells the server, then clears the local session either way.
  Future<void> logout({String? deviceToken}) async {
    await _guard(
      () => _service.logout(
        studentId: _selected?.id,
        deviceToken: deviceToken,
        mobile: _selected?.primaryContact ?? mobile,
      ),
    );
    await clearSession();
  }

  /// Local-only sign-out (e.g. after a 401).
  Future<void> clearSession() async {
    await _storage.clear();
    _students = <ParentStudent>[];
    _selected = null;
    notifyListeners();
  }
}
