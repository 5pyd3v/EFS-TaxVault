import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/scanner/data/document_repository_impl.dart';
import 'package:fbr_taxvault/features/scanner/data/image_compression_service.dart';
import 'package:fbr_taxvault/features/scanner/data/ocr_service.dart';
import 'package:fbr_taxvault/features/scanner/data/scanner_service_impl.dart';
import 'package:fbr_taxvault/features/scanner/domain/document_repository.dart';
import 'package:fbr_taxvault/features/scanner/domain/scanner_service.dart';

final scannerServiceProvider = Provider<ScannerService>(
  (ref) => ScannerServiceImpl(),
);

final imageCompressionServiceProvider = Provider<ImageCompressionService>(
  (ref) => ImageCompressionServiceImpl(),
);

/// Holds a native ML Kit recognizer, so it's disposed with the provider
/// rather than leaked for the app's lifetime.
final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = OcrServiceImpl();
  ref.onDispose(service.dispose);
  return service;
});

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepositoryImpl(
    ref.watch(supabaseClientProvider),
    ref.watch(imageCompressionServiceProvider),
    ref.watch(ocrServiceProvider),
  );
});
