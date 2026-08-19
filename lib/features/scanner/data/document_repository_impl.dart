import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/scanner/data/image_compression_service.dart';
import 'package:fbr_taxvault/features/scanner/data/ocr_service.dart';
import 'package:fbr_taxvault/features/scanner/domain/document.dart';
import 'package:fbr_taxvault/features/scanner/domain/document_repository.dart';
import 'package:fbr_taxvault/features/scanner/domain/scanned_page.dart';
import 'package:fbr_taxvault/shared/domain/document_type.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl(this._client, this._compression, this._ocr);

  final SupabaseClient _client;
  final ImageCompressionService _compression;
  final OcrService _ocr;

  static const _bucket = 'documents';

  @override
  Future<Result<Document>> uploadScannedDocument({
    required String organizationId,
    required List<ScannedPage> pages,
    required DocumentType documentType,
    void Function(int uploadedPages, int totalPages)? onProgress,
  }) async {
    if (pages.isEmpty) {
      return const Result.err(ValidationFailure('No pages to upload.'));
    }

    try {
      final uploadedBy = _client.auth.currentUser!.id;

      // Row created first (storage_path/document_hash filled in once the
      // id — and therefore the storage prefix — is known) so a failed
      // upload never leaves an orphaned storage object with no DB record.
      final inserted = await _client
          .from('documents')
          .insert({
            'organization_id': organizationId,
            'uploaded_by': uploadedBy,
            'storage_path': '',
            'mime_type': 'image/jpeg',
            'page_count': pages.length,
            'document_type': documentType.value,
            'capture_source': 'camera',
          })
          .select('id')
          .single();
      final documentId = inserted['id'] as String;
      final storagePrefix = '$organizationId/$documentId';

      // OCR runs FIRST, before any compression or upload, for two reasons:
      // it reads the ORIGINAL files at full fidelity (compression targets
      // upload size, OCR wants maximum legibility), and its result decides
      // how hard the stored copies can be compressed below.
      //
      // Deliberately not fatal — a null result (unreadable photo, unusual
      // layout) just leaves ocr_text null, and extraction falls back to
      // sending the image exactly as before.
      String? ocrText;
      try {
        ocrText = await _ocr.recognizeText([for (final p in pages) p.localPath]);
      } catch (_) {
        ocrText = null;
      }

      // With text already captured, the uploaded images are display-only —
      // nothing machine-readable depends on them, so they compress harder.
      final displayOnly = ocrText != null;

      // Pages are compressed and uploaded concurrently rather than one
      // after another. Uploads are network-bound and independent, so a
      // multi-page scan finishes in roughly the time of its slowest page
      // instead of the sum of all of them.
      var completed = 0;
      final results = await Future.wait([
        for (var i = 0; i < pages.length; i++)
          () async {
            final bytes = await _compression.compress(
              pages[i].localPath,
              displayOnly: displayOnly,
            );
            await _client.storage
                .from(_bucket)
                .uploadBinary(
                  '$storagePrefix/page_${i + 1}.jpg',
                  bytes,
                  fileOptions: const FileOptions(
                    contentType: 'image/jpeg',
                    upsert: true,
                  ),
                );
            // Reports pages as they land. Concurrency means completion
            // order isn't page order, so this counts finished pages rather
            // than indexing into them — the UI only shows "x of n".
            onProgress?.call(++completed, pages.length);
            return bytes;
          }(),
      ]);

      // Hash the first page specifically, not whichever finished first, so
      // the same document always produces the same hash and duplicate
      // detection stays stable.
      final documentHash = sha256.convert(results.first).toString();
      final totalBytes = results.fold<int>(0, (sum, b) => sum + b.length);

      await _client
          .from('documents')
          .update({
            'storage_path': storagePrefix,
            'document_hash': documentHash,
            'file_size_bytes': totalBytes,
            'ocr_text': ocrText,
          })
          .eq('id', documentId);

      // No client-side ai_processing_jobs row here on purpose: that table
      // is service-role-write-only (spec §7 — AI requests are server-side
      // only), and the extract-invoice Edge Function creates its own job
      // row if one doesn't already exist when it's invoked next.

      return Result.ok(
        Document(
          id: documentId,
          organizationId: organizationId,
          storagePathPrefix: storagePrefix,
          pageCount: pages.length,
          documentType: documentType,
        ),
      );
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on StorageException catch (e) {
      return Result.err(ServerFailure(e.message));
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
