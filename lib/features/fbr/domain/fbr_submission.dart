/// Mirrors one `fbr_submissions` row. Status values match the DB check
/// constraint (spec §21) — a proper lifecycle, not a bare `submitted: bool`.
enum FbrSubmissionStatus {
  notReady('not_ready'),
  ready('ready'),
  queued('queued'),
  submitted('submitted'),
  accepted('accepted'),
  rejected('rejected'),
  failed('failed'),
  retryRequired('retry_required');

  const FbrSubmissionStatus(this.value);
  final String value;

  static FbrSubmissionStatus fromValue(String value) {
    return FbrSubmissionStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => FbrSubmissionStatus.notReady,
    );
  }
}

class FbrSubmission {
  const FbrSubmission({
    required this.status,
    required this.externalReference,
    required this.submittedAt,
    required this.adapterVersion,
  });

  final FbrSubmissionStatus status;
  final String? externalReference;
  final DateTime? submittedAt;
  final String adapterVersion;

  factory FbrSubmission.fromMap(Map<String, dynamic> map) {
    final submittedAt = map['submitted_at'] as String?;
    return FbrSubmission(
      status: FbrSubmissionStatus.fromValue(
        map['status'] as String? ?? 'not_ready',
      ),
      externalReference: map['external_reference'] as String?,
      submittedAt: submittedAt != null ? DateTime.tryParse(submittedAt) : null,
      adapterVersion: map['adapter_version'] as String? ?? 'mock-v1',
    );
  }
}
