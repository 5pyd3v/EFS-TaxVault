import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/shared/providers/document_storage_providers.dart';

/// Full-screen viewer for the original scanned page image(s) behind an
/// invoice or bank transaction — separate from the AI-extracted fields
/// shown on the review screen, so the user can always check the source.
/// Pushed directly (not a GoRouter path route) since the caller already
/// has `storagePath`/`pageCount` in hand from the invoice/transaction
/// detail it just loaded — no need for a second round trip by document id.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({
    super.key,
    required this.storagePath,
    required this.pageCount,
    this.title = 'Original document',
  });

  final String storagePath;
  final int pageCount;
  final String title;

  @override
  ConsumerState<DocumentViewerScreen> createState() =>
      _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final urlsAsync = ref.watch(
      documentPageUrlsProvider((
        storagePath: widget.storagePath,
        pageCount: widget.pageCount,
      )),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          urlsAsync.valueOrNull != null && urlsAsync.valueOrNull!.length > 1
              ? '${widget.title} (${_currentPage + 1}/${urlsAsync.valueOrNull!.length})'
              : widget.title,
        ),
      ),
      body: urlsAsync.when(
        data: (urls) => PageView.builder(
          itemCount: urls.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) => InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                urls[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white70,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Could not load the original document',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: () => ref.invalidate(
                    documentPageUrlsProvider((
                      storagePath: widget.storagePath,
                      pageCount: widget.pageCount,
                    )),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
