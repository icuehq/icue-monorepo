/// Node role IDs (`/v1.0/getUsersByRole`). Hardcoded until Node exposes them.
class RoleIds {
  const RoleIds._();

  static const int librarian = 43;
  static const int storeManager = 44;
}

/// A user holding a role, as returned by `/v1.0/getUsersByRole`.
class RoleUser {
  const RoleUser({required this.id, required this.displayName});

  factory RoleUser.fromJson(Map<String, dynamic> json) => RoleUser(
    id: json['Id'] as int? ?? 0,
    displayName: json['DisplayName'] as String? ?? '',
  );

  final int id;
  final String displayName;
}

/// An organization role, as returned by `/v1.0/listOrgRoles`.
class OrgRole {
  const OrgRole({required this.id, required this.name});

  factory OrgRole.fromJson(Map<String, dynamic> json) =>
      OrgRole(id: json['Id'] as int? ?? 0, name: json['Name'] as String? ?? '');

  final int id;
  final String name;
}
