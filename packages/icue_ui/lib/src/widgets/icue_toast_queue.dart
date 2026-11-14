import 'package:flutter/foundation.dart';

enum IcueToastSeverity { info, success, warning, error }

class IcueToastItem {
  const IcueToastItem({
    required this.id,
    required this.severity,
    required this.message,
  });

  final int id;
  final IcueToastSeverity severity;
  final String message;
}

/// The toasts currently on screen: at most [maxVisible], oldest dropped first,
/// an identical message replaces the one already showing instead of stacking.
class IcueToastQueue extends ChangeNotifier {
  static const int maxVisible = 3;

  /// How long every toast stays before it closes itself.
  static const Duration visibleFor = Duration(seconds: 3);

  final List<IcueToastItem> _items = [];
  int _nextId = 0;

  List<IcueToastItem> get items => List.unmodifiable(_items);

  void add(IcueToastSeverity severity, String message) {
    _items
      ..removeWhere(
        (item) => item.severity == severity && item.message == message,
      )
      ..add(IcueToastItem(id: _nextId++, severity: severity, message: message));
    while (_items.length > maxVisible) {
      _items.removeAt(0);
    }
    notifyListeners();
  }

  void dismiss(int id) {
    final before = _items.length;
    _items.removeWhere((item) => item.id == id);
    if (_items.length != before) notifyListeners();
  }
}
