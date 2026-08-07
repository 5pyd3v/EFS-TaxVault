import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/scanner/domain/document.dart';
import 'package:fbr_taxvault/features/scanner/domain/scanned_page.dart';
import 'package:fbr_taxvault/shared/domain/document_type.dart';

abstract interface class DocumentRepository {
  /// Compresses, uploads, and records a captured/imported document. Also
  /// queues an `ai_processing_jobs` row (status `queued`) so the pipeline
  /// has a hook to pick up once AI extraction (Phase 5) exists — no
  /// extraction happens here.
  Future<Result<Document>> uploadScannedDocument({
    required String organizationId,
    required List<ScannedPage> pages,
    required DocumentType documentType,
    void Function(int uploadedPages, int totalPages)? onProgress,
  });
}
