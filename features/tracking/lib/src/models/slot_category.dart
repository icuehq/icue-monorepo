import 'package:flutter/foundation.dart';
import 'package:tracking/src/models/vehicle_slot_item.dart';

@immutable
class SlotCategory {
  const SlotCategory({
    this.notStarted = const <VehicleSlotItem>[],
    this.inProgress = const <VehicleSlotItem>[],
    this.completed = const <VehicleSlotItem>[],
  });

  factory SlotCategory.fromJson({
    dynamic notStartedJson,
    dynamic inProgressJson,
    dynamic completedJson,
  }) =>
      SlotCategory(
        notStarted: (notStartedJson as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(VehicleSlotItem.fromJson)
                .toList() ??
            const <VehicleSlotItem>[],
        inProgress: (inProgressJson as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(VehicleSlotItem.fromJson)
                .toList() ??
            const <VehicleSlotItem>[],
        completed: (completedJson as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(VehicleSlotItem.fromJson)
                .toList() ??
            const <VehicleSlotItem>[],
      );

  final List<VehicleSlotItem> completed;
  final List<VehicleSlotItem> inProgress;
  final List<VehicleSlotItem> notStarted;

  Map<String, dynamic> toJson() => {
        'notStarted': notStarted.map((x) => x.toJson()).toList(),
        'inProgress': inProgress.map((x) => x.toJson()).toList(),
        'completed': completed.map((x) => x.toJson()).toList(),
      };
}
