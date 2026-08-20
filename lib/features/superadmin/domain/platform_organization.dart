import 'package:fbr_taxvault/features/auth/domain/organization.dart';

/// One row from `list_all_organizations` — account-metadata only (name,
/// type, owner, member count, status). Deliberately carries nothing about
/// the org's actual invoices/documents/bank_transactions — a platform
/// admin manages accounts, not customer financial data.
class PlatformOrganization {
  const PlatformOrganization({
    required this.organizationId,
    required this.name,
    required this.type,
    required this.ownerName,
    required this.ownerEmail,
    required this.memberCount,
    required this.isBlocked,
    required this.isSandbox,
    required this.createdAt,
  });

  final String organizationId;
  final String name;
  final OrganizationType type;
  final String? ownerName;
  final String ownerEmail;
  final int memberCount;
  final bool isBlocked;
  final bool isSandbox;
  final DateTime createdAt;

  factory PlatformOrganization.fromMap(Map<String, dynamic> map) {
    return PlatformOrganization(
      organizationId: map['organization_id'] as String,
      name: map['name'] as String,
      type: OrganizationType.values.byName(map['type'] as String),
      ownerName: map['owner_name'] as String?,
      ownerEmail: map['owner_email'] as String,
      memberCount: (map['member_count'] as num).toInt(),
      isBlocked: map['is_blocked'] as bool? ?? false,
      isSandbox: map['is_sandbox'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// One row from `list_incomplete_signups` — a real account (auth.users +
/// profiles row exists) that never finished onboarding, so it has no
/// organization and is otherwise invisible to `list_all_organizations`
/// (which is org-centric, not user-centric).
class IncompleteSignup {
  const IncompleteSignup({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.createdAt,
  });

  final String userId;
  final String? fullName;
  final String email;
  final DateTime createdAt;

  factory IncompleteSignup.fromMap(Map<String, dynamic> map) {
    return IncompleteSignup(
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String?,
      email: map['email'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// One-time reveal payload from create-sandbox-account — the password is
/// never retrievable again after this response, same discipline as a
/// generated team-member PIN.
class NewSandboxCredentials {
  const NewSandboxCredentials({
    required this.userId,
    required this.organizationId,
    required this.email,
    required this.password,
  });

  final String userId;
  final String organizationId;
  final String email;
  final String password;

  factory NewSandboxCredentials.fromMap(Map<String, dynamic> map) {
    return NewSandboxCredentials(
      userId: map['user_id'] as String,
      organizationId: map['organization_id'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
    );
  }
}
