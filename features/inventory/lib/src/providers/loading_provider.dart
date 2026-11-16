import 'package:flutter/foundation.dart';
import 'package:icue_firebase/icue_firebase.dart';

/// Loading flag and user-readable error shared by the Inventory providers.
abstract class LoadingProvider extends ChangeNotifier {
  String? errorMessage;
  bool isLoading = false;

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
