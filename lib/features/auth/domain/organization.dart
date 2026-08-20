enum OrganizationType { individual, business }

enum OrganizationRole { owner, admin, accountant, member, viewer }

/// An organization the current user belongs to, together with their role
/// in it. Mirrors `organizations` joined with `organization_members` —
/// every invoice, document, and FBR submission is scoped to an
/// organization_id, never to a bare user_id (see supabase/migrations).
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.type,
    required this.role,
    this.isBlocked = false,
  });

  final String id;
  final String name;
  final OrganizationType type;
  final OrganizationRole role;

  /// Set by a platform admin (see lib/features/superadmin/) — a blocked
  /// org's members are signed out and refused sign-in (app_router.dart's
  /// `_redirect`) until unblocked.
  final bool isBlocked;

  bool get canEditInvoices => role != OrganizationRole.viewer;

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'] as String,
      name: map['name'] as String,
      type: OrganizationType.values.byName(map['type'] as String),
      role: OrganizationRole.values.byName(map['role'] as String),
      isBlocked: map['is_blocked'] as bool? ?? false,
    );
  }
}
