class AppUser {
  const AppUser({required this.id, required this.email, this.fullName});

  final String id;
  final String email;
  final String? fullName;

  String get displayName => fullName?.trim().isNotEmpty == true ? fullName! : email;
}
