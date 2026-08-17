import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/shared/data/document_storage_service.dart';

final documentStorageServiceProvider = Provider<DocumentStorageService>((
  ref,
) {
  return DocumentStorageService(ref.watch(supabaseClientProvider));
});

/// Keyed by (storagePath, pageCount) so viewing the same document twice in
/// one session reuses the signed URLs instead of re-requesting them.
final documentPageUrlsProvider =
    FutureProvider.family<List<String>, ({String storagePath, int pageCount})>(
  (ref, args) async {
    final result = await ref
        .watch(documentStorageServiceProvider)
        .getPageImageUrls(
          storagePath: args.storagePath,
          pageCount: args.pageCount,
        );
    return result.fold((urls) => urls, (failure) => throw failure);
  },
);
