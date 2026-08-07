import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/core/theme/app_theme.dart';
import 'package:fbr_taxvault/features/scanner/presentation/scanner_controller.dart';

class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(scannerControllerProvider);
    final controller = ref.read(scannerControllerProvider.notifier);

    ref.listen(scannerControllerProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.pages.isNotEmpty && (previous?.pages.isEmpty ?? true)) {
        context.push(AppRoutes.scanReview);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.brandTint(theme.brightness == Brightness.dark),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.document_scanner_outlined, color: theme.colorScheme.primary, size: 38),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Scan an invoice', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Line the document up and TaxVault will detect its edges automatically.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxxl),
            if (state.isProcessing)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: CircularProgressIndicator(),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: controller.scanDocument,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan Document'),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.importFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Import from Gallery'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
