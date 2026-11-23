import 'package:flutter/foundation.dart';
import 'package:icue_firebase/src/branch_data.dart';

/// Loading flag and user-readable error shared by the Inventory and Library providers.
abstract class LoadingProvider extends ChangeNotifier
    implements ErrorReporting {
  bool isLoading = false;
  @override
  String? errorMessage;

  /// Runs [body] with [isLoading] set; a failure becomes [errorMessage].
  Future<void> load(Future<void> Function() body) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await body();
    } catch (error) {
      errorMessage = callableErrorMessage(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
