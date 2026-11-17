import 'package:announcements/src/models/parent_announcement.dart';
import 'package:announcements/src/services/parent_announcement_service.dart';
import 'package:api_client/api_client.dart';
import 'package:auth/auth.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ParentAnnouncementsProvider extends ChangeNotifier {
  ParentAnnouncementsProvider(this._service, this._auth);

  final ParentAnnouncementService _service;
  final ParentAuthProvider _auth;

  List<ParentAnnouncement> announcements = <ParentAnnouncement>[];
  bool loading = false;

  Future<void> load() async {
    final studentId = _auth.selectedStudent?.id;
    if (studentId == null) return;
    announcements = <ParentAnnouncement>[];
    loading = true;
    notifyListeners();
    try {
      announcements = await _service.getForStudent(studentId);
    } on ApiException {
      // Message already shown by ApiClient.
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
