import 'package:fbr_taxvault/shared/domain/document_type.dart';

/// A stored document: the uploaded source file(s), not yet AI-processed.
/// Mirrors the `documents` table.
class Document {
  const Document({
    required this.id,
    required this.organizationId,
    required this.storagePathPrefix,
    required this.pageCount,
    required this.documentType,
  });

  final String id;
  final String organizationId;

  /// Storage prefix under the `documents` bucket — individual pages live at
  /// `$storagePathPrefix/page_$n.jpg`.
  final String storagePathPrefix;
  final int pageCount;
  final DocumentType documentType;
}
