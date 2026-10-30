import 'package:announcements/src/models/announcement.dart';
import 'package:announcements/src/models/announcement_title.dart';
import 'package:announcements/src/models/create_announcement_request.dart';
import 'package:announcements/src/services/announcement_service.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AnnouncementsProvider extends ChangeNotifier {
  AnnouncementsProvider(this._announcementService);

  final AnnouncementService _announcementService;

  List<Announcement> _announcements = <Announcement>[];
  List<AnnouncementTitle> _announcementTitles = <AnnouncementTitle>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<Announcement> get announcements => List.unmodifiable(_announcements);
  List<AnnouncementTitle> get announcementTitles =>
      List.unmodifiable(_announcementTitles);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetches all announcements.
  Future<void> fetchAnnouncements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _announcements = await _announcementService.getAnnouncements();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches announcement title templates.
  Future<void> fetchAnnouncementTitles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _announcementTitles = await _announcementService.getAnnouncementTitles();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a new fleet announcement and refreshes the announcements list on success.
  Future<bool> postAnnouncement(CreateAnnouncementRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _announcementService.createFleetAnnouncement(
        request,
      );
      if (success) {
        _announcements = await _announcementService.getAnnouncements();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears current error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
