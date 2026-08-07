import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/scanner/domain/document.dart';
import 'package:fbr_taxvault/features/scanner/domain/scanned_page.dart';
import 'package:fbr_taxvault/shared/domain/document_type.dart';

abstract interface class DocumentRepository {
  /// Compresses, uploads, and records a captured/imported document.
  /// Extraction is not queued here — the `extract-invoice` Edge Function
  /// creates its own `ai_processing_jobs` row (service-role only) when it's
  /// invoked next.
  Future<Result<Document>> uploadScannedDocument({
    required String organizationId,
    required List<ScannedPage> pages,
    required DocumentType documentType,
    void Function(int uploadedPages, int totalPages)? onProgress,
  });
}
