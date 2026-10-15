// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_actions.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

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
      id: fields[2] as int,
      name: fields[3] as String,
      routeState: fields[4] as String,
      icon: fields[1] as String,
      tabOrder: fields[6] as int,
      displayName: fields[0] as String,
      subActions: fields[7] as bool?,
      subActionItems: (fields[5] as List?)?.cast<RoleActions>(),
    );
  }

  @override
  void write(BinaryWriter writer, RoleActions obj) {
    writer
      ..writeByte(8)
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
      ..write(obj.tabOrder)
      ..writeByte(7)
      ..write(obj.subActions);
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
