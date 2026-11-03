import 'dart:convert';

import 'package:hive/hive.dart';

List<RoleActions> roleActionsFromJson(String str) => List<RoleActions>.from(
  (json.decode(str) as List<dynamic>).map(
    (x) => RoleActions.fromJson(x as Map<String, dynamic>),
  ),
);

String roleActionsToJson(List<RoleActions> data) =>
    json.encode(List<dynamic>.from(data.map((x) => x.toJson())));

@HiveType(typeId: 1)
class RoleActions {
  RoleActions({
    required this.id,
    required this.name,
    required this.routeState,
    required this.icon,
    required this.tabOrder,
    required this.displayName,
    this.subActionItems,
  });

  factory RoleActions.fromJson(Map<String, dynamic> json) => RoleActions(
    id: json['Id'] as int? ?? json['id'] as int? ?? 0,
    name: json['Name'] as String? ?? json['name'] as String? ?? '',
    routeState:
        json['RouteState'] as String? ?? json['routeState'] as String? ?? '',
    icon: json['Icon'] as String? ?? json['icon'] as String? ?? '',
    tabOrder: json['TabOrder'] as int? ?? json['tabOrder'] as int? ?? 0,
    displayName:
        json['DisplayName'] as String? ?? json['displayName'] as String? ?? '',
    subActionItems: json['SubActionItems'] == null
        ? <RoleActions>[]
        : List<RoleActions>.from(
            (json['SubActionItems'] as List<dynamic>).map(
              (x) => RoleActions.fromJson(x as Map<String, dynamic>),
            ),
          ),
  );

  @HiveField(0)
  final String displayName;

  @HiveField(1)
  final String icon;

  @HiveField(2)
  final int id;

  @HiveField(3)
  final String name;

  @HiveField(4)
  final String routeState;

  @HiveField(5)
  final List<RoleActions>? subActionItems;

  @HiveField(6)
  final int tabOrder;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'RouteState': routeState,
    'Icon': icon,
    'TabOrder': tabOrder,
    'DisplayName': displayName,
    'SubActionItems': subActionItems == null
        ? <dynamic>[]
        : List<dynamic>.from(subActionItems!.map((x) => x.toJson())),
  };
}

class RoleActionsAdapter extends TypeAdapter<RoleActions> {
  @override
  final int typeId = 1;

  @override
  RoleActions read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoleActions(
      displayName: fields[0] as String? ?? '',
      icon: fields[1] as String? ?? '',
      id: fields[2] as int? ?? 0,
      name: fields[3] as String? ?? '',
      routeState: fields[4] as String? ?? '',
      subActionItems: (fields[5] as List?)?.cast<RoleActions>(),
      tabOrder: fields[6] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, RoleActions obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.displayName)
      ..writeByte(1)
      ..write(obj.icon)
      ..writeByte(2)
      ..write(obj.id)
      ..writeByte(3)
      ..write(obj.name)
      ..writeByte(4)
      ..write(obj.routeState)
      ..writeByte(5)
      ..write(obj.subActionItems)
      ..writeByte(6)
      ..write(obj.tabOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoleActionsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
