import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/core/theme/app_theme.dart';
import 'package:fbr_taxvault/features/ai_key/presentation/ai_key_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/scanner/presentation/scanner_controller.dart';

class ScannerScreen extends ConsumerWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(scannerControllerProvider);
    final controller = ref.read(scannerControllerProvider.notifier);
    final organization = ref.watch(currentOrganizationProvider);

    ref.listen(scannerControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
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
        child: organization == null
            ? const Center(child: CircularProgressIndicator())
            : ref
                  .watch(geminiKeyStatusProvider(organization.id))
                  .when(
                    data: (status) => status.hasKey
                        ? _ScanContent(
                            theme: theme,
                            state: state,
                            controller: controller,
                          )
                        : const _NoApiKeyPrompt(),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _NoApiKeyPromptError(
                      onRetry: () => ref.invalidate(
                        geminiKeyStatusProvider(organization.id),
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _ScanContent extends StatelessWidget {
  const _ScanContent({
    required this.theme,
    required this.state,
    required this.controller,
  });

  final ThemeData theme;
  final ScannerState state;
  final ScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppTheme.brandTint(theme.brightness == Brightness.dark),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.document_scanner_outlined,
            color: theme.colorScheme.primary,
            size: 38,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Scan an invoice',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Line the document up and TaxVault will detect its edges automatically.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
              onPressed: () {
                HapticFeedback.lightImpact();
                controller.scanDocument();
              },
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan Document'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                controller.importFromGallery();
              },
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Import from Gallery'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shown instead of the scan/import buttons when the organization hasn't
/// configured a Gemini API key yet — scanning is blocked entirely rather
/// than silently falling back to a shared key, so this is the only way
/// forward from here.
class _NoApiKeyPrompt extends StatelessWidget {
  const _NoApiKeyPrompt();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.key_off_outlined,
            color: theme.colorScheme.error,
            size: 38,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Add your Gemini API key to start scanning',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Each organization uses its own Gemini API key so scanning can run under its own quota.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.aiKeySettings),
            icon: const Icon(Icons.vpn_key_outlined),
            label: const Text('Add API Key'),
          ),
        ),
      ],
    );
  }
}

class _NoApiKeyPromptError extends StatelessWidget {
  const _NoApiKeyPromptError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 40,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Could not check your API key status',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Please check your connection and try again.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
