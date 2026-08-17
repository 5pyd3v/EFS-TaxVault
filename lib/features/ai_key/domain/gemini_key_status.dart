class GeminiKeyStatus {
  const GeminiKeyStatus({
    required this.hasKey,
    required this.isValid,
    this.lastError,
    this.lastValidatedAt,
  });

  final bool hasKey;
  final bool isValid;
  final String? lastError;
  final DateTime? lastValidatedAt;

  factory GeminiKeyStatus.fromMap(Map<String, dynamic> map) {
    return GeminiKeyStatus(
      hasKey: map['has_key'] as bool? ?? false,
      isValid: map['is_valid'] as bool? ?? true,
      lastError: map['last_error'] as String?,
      lastValidatedAt: map['last_validated_at'] == null
          ? null
          : DateTime.tryParse(map['last_validated_at'] as String),
    );
  }

  bool get needsAttention => hasKey && !isValid;

  String get statusLabel {
    if (!hasKey) return 'Not configured';
    if (!isValid) {
      return lastError == 'quota_exceeded'
          ? 'Needs attention — quota exceeded'
          : 'Needs attention — key invalid';
    }
    return 'Configured';
  }
}
