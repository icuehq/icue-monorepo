/// One home-screen action the server enables for a student (`/getActionsByRole`).
class ParentRoleAction {
  const ParentRoleAction({
    required this.id,
    required this.name,
    required this.routeState,
    required this.icon,
    required this.tabOrder,
    required this.displayName,
    required this.colors,
    this.hasSubActions,
    this.subActions = const <ParentRoleAction>[],
  });

  factory ParentRoleAction.fromJson(Map<String, dynamic> json) =>
      ParentRoleAction(
        id: (json['Id'] as num).toInt(),
        name: json['Name'] as String? ?? '',
        routeState: json['RouteState'] as String? ?? '',
        icon: json['Icon'] as String? ?? '',
        tabOrder: json['TabOrder'] as num? ?? 0,
        displayName: json['DisplayName'] as String? ?? '',
        colors: (json['Colors'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => e as String)
            .toList(),
        hasSubActions: json['SubActions'] as bool?,
        subActions: (json['SubActionItems'] as List<dynamic>? ?? <dynamic>[])
            .map((e) => ParentRoleAction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int id;
  final String name;
  final String routeState;
  final String icon;
  final num tabOrder;
  final String displayName;
  final List<String> colors;
  final bool? hasSubActions;
  final List<ParentRoleAction> subActions;

  /// Hidden when the server says it has sub-actions but sent none.
  bool get isVisible => !(hasSubActions == true && subActions.isEmpty);
}
