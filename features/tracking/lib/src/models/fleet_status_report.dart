import 'package:flutter/foundation.dart';
import 'package:tracking/src/models/slot_category.dart';
import 'package:tracking/src/models/vehicle_slot_item.dart';

@immutable
class SlotName {
  const SlotName({required this.slot, required this.slotName});

  factory SlotName.fromJson(Map<String, dynamic> json) => SlotName(
    slot: json['Slot'] as String? ?? '',
    slotName: json['SlotName'] as String? ?? '',
  );

  final String slot;
  final String slotName;

  Map<String, dynamic> toJson() => {'Slot': slot, 'SlotName': slotName};
}

@immutable
class FleetStatusReport {
  const FleetStatusReport({
    this.totalSlots = 0,
    this.activeSlot = 'Slot1',
    this.slotNames = const <SlotName>[],
    this.slot1 = const SlotCategory(),
    this.slot2 = const SlotCategory(),
    this.slot3 = const SlotCategory(),
  });

  factory FleetStatusReport.fromJson(Map<String, dynamic> json) {
    return FleetStatusReport(
      totalSlots: (json['TotalSlots'] as num?)?.toInt() ?? 0,
      activeSlot: json['ActiveSlot'] as String? ?? 'Slot1',
      slotNames:
          (json['SlotNames'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(SlotName.fromJson)
              .toList() ??
          const <SlotName>[],
      slot1: SlotCategory.fromJson(
        notStartedJson: json['Slot1NotStarted'],
        inProgressJson: json['Slot1InProgress'],
        completedJson: json['Slot1Completed'],
      ),
      slot2: SlotCategory.fromJson(
        notStartedJson: json['Slot2NotStarted'],
        inProgressJson: json['Slot2InProgress'],
        completedJson: json['Slot2Completed'],
      ),
      slot3: SlotCategory.fromJson(
        notStartedJson: json['Slot3NotStarted'],
        inProgressJson: json['Slot3InProgress'],
        completedJson: json['Slot3Completed'],
      ),
    );
  }

  final String activeSlot;
  final SlotCategory slot1;
  final SlotCategory slot2;
  final SlotCategory slot3;
  final List<SlotName> slotNames;
  final int totalSlots;

  /// Returns all vehicles currently in progress across all slots.
  List<VehicleSlotItem> get allInProgress => [
    ...slot1.inProgress,
    ...slot2.inProgress,
    ...slot3.inProgress,
  ];

  Map<String, dynamic> toJson() => {
    'TotalSlots': totalSlots,
    'ActiveSlot': activeSlot,
    'SlotNames': slotNames.map((x) => x.toJson()).toList(),
    'Slot1NotStarted': slot1.notStarted.map((x) => x.toJson()).toList(),
    'Slot1InProgress': slot1.inProgress.map((x) => x.toJson()).toList(),
    'Slot1Completed': slot1.completed.map((x) => x.toJson()).toList(),
    'Slot2NotStarted': slot2.notStarted.map((x) => x.toJson()).toList(),
    'Slot2InProgress': slot2.inProgress.map((x) => x.toJson()).toList(),
    'Slot2Completed': slot2.completed.map((x) => x.toJson()).toList(),
    'Slot3NotStarted': slot3.notStarted.map((x) => x.toJson()).toList(),
    'Slot3InProgress': slot3.inProgress.map((x) => x.toJson()).toList(),
    'Slot3Completed': slot3.completed.map((x) => x.toJson()).toList(),
  };
}
