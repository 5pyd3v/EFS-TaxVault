import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';

/// Generates short-lived signed URLs for the original scanned page images
/// behind an invoice/bank-transaction — the `documents` Storage bucket is
/// private (see `supabase/migrations/0011_storage.sql`), so the client can
/// never read `page_N.jpg` directly and always needs a signed URL.
class DocumentStorageService {
  DocumentStorageService(this._client);

  final SupabaseClient _client;

  static const _bucket = 'documents';
  static const _signedUrlExpirySeconds = 3600;

  Future<Result<List<String>>> getPageImageUrls({
    required String storagePath,
    required int pageCount,
  }) async {
    if (pageCount <= 0) return const Result.ok([]);
    try {
      final paths = [
        for (var i = 1; i <= pageCount; i++) '$storagePath/page_$i.jpg',
      ];
      final results = await _client.storage
          .from(_bucket)
          .createSignedUrlsResult(paths, _signedUrlExpirySeconds);

      final urls = results
          .whereType<SignedUrlSuccess>()
          .map((r) => r.signedUrl)
          .toList();
      if (urls.isEmpty) {
        return const Result.err(
          NotFoundFailure('The original scanned pages could not be found.'),
        );
      }
      return Result.ok(urls);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on StorageException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
