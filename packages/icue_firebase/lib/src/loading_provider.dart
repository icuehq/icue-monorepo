import 'package:flutter/foundation.dart';
import 'package:icue_firebase/src/branch_data.dart';

/// Loading flag and user-readable error shared by the Inventory and Library providers.
abstract class LoadingProvider extends ChangeNotifier
    implements ErrorReporting {
  bool isLoading = false;
  @override
  String? errorMessage;

  /// Runs [body] with [isLoading] set; a failure becomes [errorMessage] and
  /// the result `null`. [quiet] skips the loading notifications, for fetches
  /// triggered from a widget's build (FutureBuilder).
  Future<T?> run<T>(Future<T> Function() body, {bool quiet = false}) async {
    if (!quiet) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }
    try {
      return await body();
    } catch (error) {
      errorMessage = callableErrorMessage(error);
      return null;
    } finally {
      if (!quiet) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// [run] for a body without a result.
  Future<void> load(Future<void> Function() body) => run(body);
}
