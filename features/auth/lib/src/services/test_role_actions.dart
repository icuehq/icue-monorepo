import 'package:auth/src/models/role_actions.dart';

// TEMP: mimics Node's `/v1.0/getActionsByRole` for Inventory until Node returns
// it (docs/inventory-library-node-actions.md). Delete this file and the
// `withTestRoleActions` call in AuthService.getRoleActions then.

const _inventorySubActions = <(int, String, String)>[
  (310, 'Inventory Settings', 'settings'),
  (311, 'Manage Items', 'items.manage'),
  (312, 'View Items', 'items.view'),
  (313, 'View Stock', 'stock.view'),
  (314, 'Operate Stock', 'stock.operate'),
  (315, 'Request Issue', 'issue.request'),
  (316, 'Approve Issue', 'issue.approve'),
  (317, 'Approve Stock Adjustment', 'adjustment.approve'),
  (318, 'Request Purchase', 'purchaserequest.request'),
  (319, 'Approve Purchase', 'purchaserequest.approve'),
  (320, 'Procurement', 'procure.operate'),
  (321, 'Manage Vendors', 'vendors.manage'),
  (322, 'Manage Assets', 'assets.manage'),
  (323, 'View Assets', 'assets.view'),
  (324, 'Inventory Reports', 'reports.view'),
];

RoleActions _module(
  int id,
  String displayName,
  String route,
  int tabOrder,
  List<(int, String, String)> subActions,
) => RoleActions(
  id: id,
  name: '$displayName - Admin App',
  routeState: 'layout.$route',
  icon: '',
  tabOrder: tabOrder,
  displayName: displayName,
  subActionItems: [
    for (final (index, (subId, title, key)) in subActions.indexed)
      RoleActions(
        id: subId,
        name: title,
        routeState: 'layout.$route.$key',
        icon: '',
        tabOrder: index + 1,
        displayName: title,
      ),
  ],
);

/// [actions] plus Inventory (with all sub-actions) when missing.
List<RoleActions> withTestRoleActions(List<RoleActions> actions) => [
  ...actions,
  if (!actions.any((a) => a.routeState == 'layout.inventory'))
    _module(300, 'Inventory', 'inventory', 100, _inventorySubActions),
];
