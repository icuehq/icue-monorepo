import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:icue_firebase/src/crashlytics_service.dart';

Object? _lastLogged;

/// The one place handled errors are logged. Every build records a non-fatal in Crashlytics; debug builds also print the error type, Firebase code, full
/// message (a missing-index error carries its console link) and stack to the console. [where] names the failed action, e.g. `Loan list`.
/// Call it from every `catch` that turns an error into a message or state, before showing that message.
void logError(Object error, [StackTrace? stack, String? where]) {
  if (identical(error, _lastLogged)) {
    return; // a rebuild re-reading the same failure
  }
  _lastLogged = error;
  CrashlyticsService.instance.recordError(error, stack, reason: where);
  if (!kDebugMode) return;
  final (code, detail) = switch (error) {
    FirebaseFunctionsException(:final code, :final message, :final details) => (
      ' [functions/$code]',
      details == null ? message : '$message ($details)',
    ),
    FirebaseException(:final plugin, :final code, :final message) => (
      ' [$plugin/$code]',
      message,
    ),
    _ => ('', '$error'),
  };
  log(
    '[icue error]${where == null ? '' : ' $where:'} '
    '${error.runtimeType}$code $detail'
    '${stack == null ? '' : '\n$stack'}',
  );
}
