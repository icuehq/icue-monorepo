import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide network state. Create once, `await init()` before `runApp`, and
/// share via Provider / GetIt. Reports whether a network *interface* is up
/// (wifi, mobile, ethernet...), not that the internet is reachable;
/// the API client still surfaces real request failures.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Future<void> init() async {
    if (_sub != null) return;
    _sub = _connectivity.onConnectivityChanged.listen(_update);
    try {
      _update(await _connectivity.checkConnectivity());
    } catch (_) {
      // Unknown state: stay optimistic rather than block the user.
    }
  }

  /// Re-reads the current state (e.g. a "Retry" button).
  Future<bool> refresh() async {
    _update(await _connectivity.checkConnectivity());
    return _isOnline;
  }

  void _update(List<ConnectivityResult> results) {
    final online =
        results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
