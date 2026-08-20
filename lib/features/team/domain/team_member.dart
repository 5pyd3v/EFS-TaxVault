import 'package:fbr_taxvault/features/auth/domain/organization.dart';

/// One row from `list_team_members` — a business org's staff, each signing
/// in via phone + PIN rather than email/password.
class TeamMember {
  const TeamMember({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isPinManaged,
    required this.memberSince,
    this.lastLoginAt,
  });

  final String userId;
  final String? fullName;
  final String? phone;
  final OrganizationRole role;
  final bool isPinManaged;
  final DateTime memberSince;
  final DateTime? lastLoginAt;

  String get displayName => fullName?.trim().isNotEmpty == true
      ? fullName!
      : (phone ?? 'Team member');

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      role: OrganizationRole.values.byName(map['role'] as String),
      isPinManaged: map['is_pin_managed'] as bool? ?? false,
      memberSince: DateTime.parse(map['member_since'] as String),
      lastLoginAt: map['last_login_at'] == null
          ? null
          : DateTime.tryParse(map['last_login_at'] as String),
    );
  }
}

/// One-time reveal payload from create-team-member — the PIN is never
/// retrievable again after this response, so the caller must show it once
/// and make sure the admin has shared it before navigating away.
class NewTeamMemberCredentials {
  const NewTeamMemberCredentials({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.pin,
  });

  final String userId;
  final String fullName;
  final String phone;
  final OrganizationRole role;
  final String pin;

  factory NewTeamMemberCredentials.fromMap(Map<String, dynamic> map) {
    return NewTeamMemberCredentials(
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String,
      phone: map['phone'] as String,
      role: OrganizationRole.values.byName(map['role'] as String),
      pin: map['pin'] as String,
    );
  }
}
