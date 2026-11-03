export 'inventory_masters.g.dart';

/// Tracking method of an item (FRS 10.3).
enum Tracking {
  quantity('Quantity'),
  batch('Batch'),
  asset('Individual asset');

  const Tracking(this.label);

  final String label;

  static Tracking parse(Object? value) => values.firstWhere(
    (tracking) => tracking.name == value,
    orElse: () => quantity,
  );
}
