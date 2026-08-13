import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/scanner/data/document_repository_impl.dart';
import 'package:fbr_taxvault/features/scanner/data/image_compression_service.dart';
import 'package:fbr_taxvault/features/scanner/data/scanner_service_impl.dart';
import 'package:fbr_taxvault/features/scanner/domain/document_repository.dart';
import 'package:fbr_taxvault/features/scanner/domain/scanner_service.dart';

final scannerServiceProvider = Provider<ScannerService>(
  (ref) => ScannerServiceImpl(),
);

final imageCompressionServiceProvider = Provider<ImageCompressionService>(
  (ref) => ImageCompressionServiceImpl(),
);

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(
    ref.watch(supabaseClientProvider),
    ref.watch(imageCompressionServiceProvider),
  );
});
