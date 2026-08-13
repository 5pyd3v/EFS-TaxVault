import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/features/scanner/data/scanner_service_impl.dart';
import 'package:fbr_taxvault/features/scanner/domain/scanned_page.dart';
import 'package:fbr_taxvault/features/scanner/presentation/scanner_providers.dart';
import 'package:fbr_taxvault/shared/domain/document_type.dart';

class ScannerState {
  const ScannerState({
    this.pages = const [],
    this.isProcessing = false,
    this.isUploading = false,
    this.uploadedPages = 0,
    this.errorMessage,
  });

  final List<ScannedPage> pages;
  final bool isProcessing;
  final bool isUploading;
  final int uploadedPages;
  final String? errorMessage;

  ScannerState copyWith({
    List<ScannedPage>? pages,
    bool? isProcessing,
    bool? isUploading,
    int? uploadedPages,
    String? errorMessage,
  }) {
    return ScannerState(
      pages: pages ?? this.pages,
      isProcessing: isProcessing ?? this.isProcessing,
      isUploading: isUploading ?? this.isUploading,
      uploadedPages: uploadedPages ?? this.uploadedPages,
      errorMessage: errorMessage,
    );
  }
}

/// Holds the in-progress capture session (pages not yet uploaded) and
/// drives the upload. A plain [Notifier] rather than [AsyncNotifier]
/// because the page list itself is ordinary mutable state — only the final
/// upload is async, and its progress/error live as fields on [ScannerState]
/// rather than wrapping the whole state in [AsyncValue].
class ScannerController extends Notifier<ScannerState> {
  @override
  ScannerState build() => const ScannerState();

  Future<void> scanDocument() async {
    state = ScannerState(pages: state.pages, isProcessing: true);
    try {
      final newPages = await ref.read(scannerServiceProvider).scanDocument();
      state = ScannerState(pages: [...state.pages, ...newPages]);
    } on ScannerException catch (e) {
      state = ScannerState(pages: state.pages, errorMessage: e.message);
    } catch (_) {
      state = ScannerState(
        pages: state.pages,
        errorMessage: 'Could not open the scanner.',
      );
    }
  }

  Future<void> importFromGallery() async {
    state = ScannerState(pages: state.pages, isProcessing: true);
    try {
      final newPages = await ref.read(scannerServiceProvider).pickFromGallery();
      state = ScannerState(pages: [...state.pages, ...newPages]);
    } catch (_) {
      state = ScannerState(
        pages: state.pages,
        errorMessage: 'Could not open the gallery.',
      );
    }
  }

  void removePage(String id) {
    state = ScannerState(pages: state.pages.where((p) => p.id != id).toList());
  }

  /// Matches [ReorderableListView.onReorderItem] semantics: [newIndex] is
  /// already adjusted for the item's removal at [oldIndex].
  void reorderPages(int oldIndex, int newIndex) {
    final pages = [...state.pages];
    final page = pages.removeAt(oldIndex);
    pages.insert(newIndex, page);
    state = ScannerState(pages: pages);
  }

  void reset() => state = const ScannerState();

  /// Returns the created document's id on success, or null on failure
  /// (in which case [ScannerState.errorMessage] is set).
  Future<String?> confirmUpload({
    required String organizationId,
    required DocumentType documentType,
  }) async {
    if (state.pages.isEmpty) return null;

    state = ScannerState(pages: state.pages, isUploading: true);
    final result = await ref
        .read(documentRepositoryProvider)
        .uploadScannedDocument(
          organizationId: organizationId,
          pages: state.pages,
          documentType: documentType,
          onProgress: (uploaded, total) {
            state = ScannerState(
              pages: state.pages,
              isUploading: true,
              uploadedPages: uploaded,
            );
          },
        );

    return result.fold(
      (document) {
        state = const ScannerState();
        return document.id;
      },
      (failure) {
        state = ScannerState(pages: state.pages, errorMessage: failure.message);
        return null;
      },
    );
  }
}

final scannerControllerProvider =
    NotifierProvider<ScannerController, ScannerState>(ScannerController.new);
