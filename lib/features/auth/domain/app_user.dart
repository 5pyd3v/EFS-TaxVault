class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.isPinManaged = false,
  });

  final String id;
  final String email;
  final String? fullName;

  /// True for a business team member created by an admin via Team
  /// management — they sign in with phone + PIN, not email + password, and
  /// [email] is an internal-only address they never see.
  final bool isPinManaged;

  String get displayName =>
      fullName?.trim().isNotEmpty == true ? fullName! : email;
}
