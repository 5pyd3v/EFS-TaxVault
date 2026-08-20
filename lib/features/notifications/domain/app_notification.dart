class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  /// Present when this notification points at a specific invoice — used to
  /// deep-link straight into the Review screen from the notification list.
  String? get invoiceId => data['invoice_id'] as String?;

  /// Present when this notification points at a specific bank transaction
  /// (verification decisions from the approval flow) — same deep-link
  /// purpose as [invoiceId].
  String? get transactionId => data['transaction_id'] as String?;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final readAt = map['read_at'] as String?;
    return AppNotification(
      id: map['id'] as String,
      type: map['type'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String?,
      data: (map['data'] as Map?)?.cast<String, dynamic>() ?? const {},
      readAt: readAt != null ? DateTime.tryParse(readAt) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
