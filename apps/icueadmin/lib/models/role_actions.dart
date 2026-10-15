// To parse this JSON data, do
//
//     final roleActions = roleActionsFromJson(jsonString);

import 'dart:convert';

import 'package:hive/hive.dart';

part 'role_actions.g.dart';

List<RoleActions> roleActionsFromJson(String str) => List<RoleActions>.from(
  json.decode(str).map((x) => RoleActions.fromJson(x)),
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
    this.subActions,
    this.subActionItems,
  });

  factory RoleActions.fromJson(Map<String, dynamic> json) => RoleActions(
    id: json['Id'] is int
        ? json['Id']
        : int.tryParse(json['Id']?.toString() ?? '') ?? 0,
    name: json['Name']?.toString() ?? '',
    routeState: json['RouteState']?.toString() ?? '',
    icon: json['Icon']?.toString() ?? '',
    tabOrder: json['TabOrder'] is int
        ? json['TabOrder']
        : int.tryParse(json['TabOrder']?.toString() ?? '') ?? 0,
    displayName: json['DisplayName']?.toString() ?? '',
    subActions: json['SubActions'] as bool?,
    subActionItems: json['SubActionItems'] == null
        ? []
        : List<RoleActions>.from(
            (json['SubActionItems'] as List).map(
              (x) => x is RoleActions
                  ? x
                  : RoleActions.fromJson(x as Map<String, dynamic>),
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

  @HiveField(7)
  final bool? subActions;

  Map<String, dynamic> toJson() => {
    'Id': id,
    'Name': name,
    'RouteState': routeState,
    'Icon': icon,
    'TabOrder': tabOrder,
    'DisplayName': displayName,
    if (subActions != null) 'SubActions': subActions,
    'SubActionItems': subActionItems == null
        ? []
        : List<dynamic>.from(subActionItems!.map((x) => x.toJson())),
  };
}
