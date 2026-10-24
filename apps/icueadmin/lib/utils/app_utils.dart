import 'dart:developer';

import 'package:flutter/material.dart';

import '../models/routes.dart';
import '../utils/navigation/app_router.dart';
import '../widgets/loading_dialog.dart';

export 'app_date_utils.dart';

class AppUtils {
  static void showLoadingDialog(BuildContext context, String msg) {
    showDialog(
      context: context,
      // barrierDismissible: false,
      builder: (context) => LoadingDialog(msg: msg),
    );
  }

  static void hideLoadingDialog(BuildContext? context) {
    try {
      // Try to use the provided context if it's valid
      if (context != null) {
        // Check if context is still mounted before using it
        final navigator = Navigator.maybeOf(context, rootNavigator: true);
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }
      }

      // Fallback to using navigatorKey if context is invalid
      final safeContext = navigatorKey.currentContext;
      if (safeContext != null) {
        final navigator = Navigator.maybeOf(safeContext, rootNavigator: true);
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
          return;
        }
      }

      log(
        'Could not hide loading dialog: no valid context or navigator available',
      );
    } catch (e) {
      log('Error hiding loading dialog: $e');
    }
  }

  //Scaffold message
  static void showSucessMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final snackBar = SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.green,
      content: Text(
        msg,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static void showErrorMessage(BuildContext context, String? msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final snackBar = SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.red,
      content: Text(
        msg ?? 'Something went wrong',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static Map<Mode, Map<String, String>> mapModesToRoutes(
    Map<String, dynamic> data,
  ) {
    final modes = List<Mode>.from(data['mode']);
    final routes = List<String>.from(data['routes']);
    final routeIds = List<String>.from(data['routeIds'] ?? []);

    final Map<Mode, Map<String, String>> output = {};

    if (routeIds.isEmpty) return output;

    for (int i = 0; i < modes.length; i++) {
      if (!output.keys.contains(modes[i])) {
        output[modes[i]] = {'route': routes[i], 'routeId': routeIds[i]};
      }
    }

    return output;
  }

  static Future<DateTime?> selectDate({
    required BuildContext context,
    bool allowFutureDates = false,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate:
          firstDate ?? (!allowFutureDates ? DateTime(1900) : DateTime.now()),
      lastDate:
          lastDate ??
          (allowFutureDates
              ? DateTime(DateTime.now().year + 10)
              : DateTime.now()),
    );
  }

  static Future<TimeOfDay?> selectTime({
    required BuildContext context,
    TimeOfDay? initialTime,
  }) async {
    return showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );
  }

  static String? checkLicenseStatus(String title, DateTime? licenseExpiryDate) {
    if (licenseExpiryDate == null) return null;
    final currentDate = DateTime.now();
    final difference = licenseExpiryDate.difference(currentDate).inDays;

    if (difference > 30) {
      return null;
    } else if (difference > 0 && difference <= 30) {
      return '$title will expire in $difference days';
    } else if (difference == 0) {
      return '$title expires today';
    } else {
      return '$title expired ${difference.abs()} days ago';
    }
  }
}

extension TimeOfDayConverter on TimeOfDay {
  String to24hours() {
    final hour = this.hour.toString().padLeft(2, '0');
    final min = minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }
}

List<T> removeNullValues<T>(List<T?> list) {
  return list.whereType<T>().toList();
}

/// Utility function to remove all null and empty values from a Map.
Map<String, dynamic> removeEmptyAndNullValues(Map<String, dynamic> data) {
  // Create a copy of the original map to avoid modifying the original.
  final cleanedData = Map<String, dynamic>.from(data);

  // Remove entries where the value is null or empty (String, List, Map).
  cleanedData.removeWhere(
    (key, value) =>
        value == null ||
        (value is String && value.isEmpty) ||
        (value is List && value.isEmpty) ||
        (value is Map && value.isEmpty),
  );

  return cleanedData;
}
