import 'package:auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:icue_firebase/icue_firebase.dart';
import 'package:icue_ui/icue_ui.dart';
import 'package:inventory/inventory.dart';
import 'package:provider/provider.dart';

/// Who may request a top-level category's items and who approves those
/// requests: Node roles, each approving role optionally narrowed to people.
class CategoryAccessSection extends StatefulWidget {
  const CategoryAccessSection({
    required this.requesterRoleIds,
    required this.approvers,
    required this.onRequesterRolesChanged,
    required this.onApproversChanged,
    super.key,
  });

  final List<int> requesterRoleIds;
  final List<CategoryApprover> approvers;
  final ValueChanged<List<int>> onRequesterRolesChanged;
  final ValueChanged<List<CategoryApprover>> onApproversChanged;

  @override
  State<CategoryAccessSection> createState() => _CategoryAccessSectionState();
}

class _CategoryAccessSectionState extends State<CategoryAccessSection> {
  List<OrgRole> _roles = [];

  /// People of each approving role (Node `listOrgEmployees`); absent while loading.
  final Map<int, List<RoleUser>> _employees = {};
  final Set<int> _loadingRoles = {};
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRoles();
    for (final approver in widget.approvers) {
      _loadEmployees(approver.roleId);
    }
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await context.read<AuthProvider>().orgRoles();
      if (mounted) setState(() => _roles = roles);
    } catch (error, stack) {
      logError(error, stack, 'Loading roles');
      if (mounted) setState(() => _errorMessage = 'Could not load the roles');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEmployees(int roleId) async {
    if (_employees.containsKey(roleId) || !_loadingRoles.add(roleId)) return;
    try {
      final employees = await context.read<AuthProvider>().orgEmployees(roleId);
      if (mounted) setState(() => _employees[roleId] = employees);
    } catch (error, stack) {
      logError(error, stack, 'Loading role employees');
      if (mounted) {
        setState(() => _errorMessage = 'Could not load the people of a role');
      }
    } finally {
      _loadingRoles.remove(roleId);
      if (mounted) setState(() {});
    }
  }

  String _roleName(int id) =>
      _roles.where((role) => role.id == id).firstOrNull?.name ?? 'Role $id';

  void _setApproverRoles(List<OrgRole> roles) {
    for (final role in roles) {
      _loadEmployees(role.id);
    }
    widget.onApproversChanged([
      for (final role in roles)
        widget.approvers
                .where((approver) => approver.roleId == role.id)
                .firstOrNull ??
            CategoryApprover(roleId: role.id, userIds: const []),
    ]);
  }

  void _removeApproverRole(int roleId) => widget.onApproversChanged([
    for (final approver in widget.approvers)
      if (approver.roleId != roleId) approver,
  ]);

  void _setApproverUsers(int roleId, List<RoleUser> users) =>
      widget.onApproversChanged([
        for (final approver in widget.approvers)
          approver.roleId == roleId
              ? CategoryApprover(
                  roleId: roleId,
                  userIds: [for (final user in users) '${user.id}'],
                )
              : approver,
      ]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),
        IcueFormSectionCard(
          title: 'Who can request',
          icon: Icons.person_add_alt_outlined,
          children: [
            Text(
              'Only these roles see this category when requesting items. '
              'Leave empty to let all staff request.',
              style: note,
            ),
            IcueMultiAutocomplete<OrgRole>(
              options: _roles,
              selected: [
                for (final role in _roles)
                  if (widget.requesterRoleIds.contains(role.id)) role,
              ],
              labelOf: (role) => role.name,
              onChanged: (roles) => widget.onRequesterRolesChanged([
                for (final role in roles) role.id,
              ]),
              label: 'Requester roles',
              hintText: 'Type to find a role (empty: all staff)',
              icon: Icons.groups_outlined,
            ),
          ],
        ),
        IcueFormSectionCard(
          title: 'Approvers',
          icon: Icons.how_to_reg_outlined,
          children: [
            Text(
              widget.approvers.isEmpty
                  ? "No approver roles: requests go to the requester's "
                        'default approver.'
                  : 'Requests go to everyone in a role, or only to the '
                        'people picked under it.',
              style: note,
            ),
            IcueMultiAutocomplete<OrgRole>(
              options: _roles,
              selected: [
                for (final approver in widget.approvers)
                  ..._roles.where((role) => role.id == approver.roleId),
              ],
              labelOf: (role) => role.name,
              onChanged: _setApproverRoles,
              // Each picked role shows as a tile below instead of a chip.
              showChips: false,
              label: 'Approver roles',
              hintText: 'Type to find a role',
              icon: Icons.how_to_reg_outlined,
            ),
            for (final approver in widget.approvers)
              _ApproverRoleTile(
                key: ValueKey(approver.roleId),
                roleName: _roleName(approver.roleId),
                employees: _employees[approver.roleId] ?? const [],
                loading: _loadingRoles.contains(approver.roleId),
                userIds: approver.userIds,
                onChanged: (users) => _setApproverUsers(approver.roleId, users),
                onRemove: () => _removeApproverRole(approver.roleId),
              ),
          ],
        ),
      ],
    );
  }
}

/// One approving role: everyone in it, or only the people picked.
class _ApproverRoleTile extends StatelessWidget {
  const _ApproverRoleTile({
    required this.roleName,
    required this.employees,
    required this.loading,
    required this.userIds,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final String roleName;
  final List<RoleUser> employees;
  final bool loading;
  final List<String> userIds;
  final ValueChanged<List<RoleUser>> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  roleName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove role',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onRemove,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: loading
                ? const LinearProgressIndicator()
                : IcueMultiAutocomplete<RoleUser>(
                    options: employees,
                    selected: [
                      for (final employee in employees)
                        if (userIds.contains('${employee.id}')) employee,
                    ],
                    labelOf: (employee) => employee.displayName,
                    onChanged: onChanged,
                    label: 'People',
                    hintText: employees.isEmpty
                        ? 'Nobody holds this role yet'
                        : 'Type a name (empty: everyone in this role)',
                    icon: Icons.person_outline,
                  ),
          ),
        ],
      ),
    );
  }
}
