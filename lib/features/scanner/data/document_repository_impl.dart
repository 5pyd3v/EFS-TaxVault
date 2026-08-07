import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/scanner/data/image_compression_service.dart';
import 'package:fbr_taxvault/features/scanner/domain/document.dart';
import 'package:fbr_taxvault/features/scanner/domain/document_repository.dart';
import 'package:fbr_taxvault/features/scanner/domain/scanned_page.dart';
import 'package:fbr_taxvault/shared/domain/document_type.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  DocumentRepositoryImpl(this._client, this._compression);

  final SupabaseClient _client;
  final ImageCompressionService _compression;

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

      String? documentHash;
      var totalBytes = 0;

      for (var i = 0; i < pages.length; i++) {
        final bytes = await _compression.compress(pages[i].localPath);
        documentHash ??= sha256.convert(bytes).toString();
        totalBytes += bytes.length;

        await _client.storage.from(_bucket).uploadBinary(
              '$storagePrefix/page_${i + 1}.jpg',
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
        onProgress?.call(i + 1, pages.length);
      }

      await _client.from('documents').update({
        'storage_path': storagePrefix,
        'document_hash': documentHash,
        'file_size_bytes': totalBytes,
      }).eq('id', documentId);

      // No client-side ai_processing_jobs row here on purpose: that table
      // is service-role-write-only (spec §7 — AI requests are server-side
      // only), and the extract-invoice Edge Function creates its own job
      // row if one doesn't already exist when it's invoked next.

      return Result.ok(Document(
        id: documentId,
        organizationId: organizationId,
        storagePathPrefix: storagePrefix,
        pageCount: pages.length,
        documentType: documentType,
      ));
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
