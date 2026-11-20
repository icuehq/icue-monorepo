import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:icue_sdk/src/models/announcements.dart';
import 'package:icue_sdk/src/models/route_notifications.dart';
import 'package:icue_sdk/src/services/networking/api_client.dart';
import 'package:injectable/injectable.dart';

@lazySingleton

/// Fetches route notifications and school announcements for a student.
class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._apiClient);

  List<Announcements> announcements = [];
  bool loading = false;
  List<Msg> msgs = [];

  final ApiClient _apiClient;
  String _errorMessage = '';

  String get errorMessage => _errorMessage;

  /// Loads route notifications for the given [studentId] and [routeTrackId].
  Future<void> getNotifications({
    required int studentId,
    required int routeTrackId,
  }) async {
    loading = true;
    _errorMessage = '';
    notifyListeners();
    try {
      final result = await _apiClient.postJson<RouteNotifications>(
        ApiRoutes.routeNotifications,
        body: {'StudentId': studentId, 'RouteTrackId': routeTrackId},
        decoder: (json) =>
            RouteNotifications.fromJson(json as Map<String, dynamic>),
      );
      if (result.isSuccess && result.data != null) {
        msgs = result.data?.msgs ?? [];
      } else {
        log(
          'getNotifications failed [${result.statusCode}]: ${result.error?.message}',
        );
        _errorMessage =
            result.error?.message ?? 'Something went wrong. Please try again.';
      }
    } on DioException catch (e) {
      log('getNotifications network error', error: e);
      _errorMessage = e.message ?? 'Something went wrong. Please try again.';
    } catch (error, stack) {
      log('getNotifications error', error: error, stackTrace: stack);
      _errorMessage = 'An unexpected error occurred. Please try again.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Loads announcements for the given [studentId].
  Future<void> getAnnouncements({required int studentId}) async {
    announcements.clear();
    loading = true;
    notifyListeners();
    try {
      final result = await _apiClient.postJson<List<Announcements>>(
        ApiRoutes.announcements,
        body: {'StudentId': studentId},
        decoder: (json) => json is List
            ? List<Announcements>.from(
                json.map(
                  (x) => Announcements.fromJson(x as Map<String, dynamic>),
                ),
              )
            : <Announcements>[],
      );
      if (result.isSuccess && result.data != null) {
        announcements = result.data ?? [];
      } else {
        log(
          'getAnnouncements failed [${result.statusCode}]: ${result.error?.message}',
        );
        _errorMessage =
            result.error?.message ?? 'Something went wrong. Please try again.';
      }
    } on DioException catch (e) {
      log('getAnnouncements network error', error: e);
      _errorMessage = e.message ?? 'Something went wrong. Please try again.';
    } catch (error, stack) {
      log('getAnnouncements error', error: error, stackTrace: stack);
      _errorMessage = 'An unexpected error occurred. Please try again.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
