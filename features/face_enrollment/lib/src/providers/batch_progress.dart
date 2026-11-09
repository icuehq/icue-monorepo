import 'package:flutter/foundation.dart';

/// Progress of a batch embedding run. Kept apart from `StudentProvider` so
/// only the progress dialog rebuilds on each step, not the student list.
class BatchProgress extends ChangeNotifier {
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  bool _cancelRequested = false;
  bool get cancelRequested => _cancelRequested;

  int _total = 0;
  int get total => _total;

  int _succeeded = 0;
  int get succeeded => _succeeded;

  int _failed = 0;
  int get failed => _failed;

  String _message = '';
  String get message => _message;

  double get fraction => _total == 0 ? 0 : (_succeeded + _failed) / _total;

  void begin(String message) {
    _isRunning = true;
    _cancelRequested = false;
    _total = 0;
    _succeeded = 0;
    _failed = 0;
    _message = message;
    notifyListeners();
  }

  void setTotal(int total) {
    _total = total;
    notifyListeners();
  }

  void say(String message) {
    _message = message;
    notifyListeners();
  }

  void record({required int succeeded, int failed = 0}) {
    _succeeded += succeeded;
    _failed += failed;
    notifyListeners();
  }

  void requestCancel() {
    _cancelRequested = true;
    _message = 'Cancelling batch process...';
    notifyListeners();
  }

  void finish(String message) {
    _isRunning = false;
    _message = message;
    notifyListeners();
  }
}
