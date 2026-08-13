import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/scanner/presentation/scanner_controller.dart';
import 'package:fbr_taxvault/shared/domain/document_type.dart';

class ReviewPagesScreen extends ConsumerStatefulWidget {
  const ReviewPagesScreen({super.key});

  @override
  ConsumerState<ReviewPagesScreen> createState() => _ReviewPagesScreenState();
}

class _ReviewPagesScreenState extends ConsumerState<ReviewPagesScreen> {
  DocumentType _documentType = DocumentType.invoice;

  Future<void> _save() async {
    HapticFeedback.lightImpact();
    final organization = ref.read(currentOrganizationProvider);
    if (organization == null) return;

    final router = GoRouter.of(context);
    final documentId = await ref
        .read(scannerControllerProvider.notifier)
        .confirmUpload(
          organizationId: organization.id,
          documentType: _documentType,
        );

    if (!mounted) return;
    if (documentId != null) {
      router.pushReplacement(AppRoutes.processing(documentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(scannerControllerProvider);
    final controller = ref.read(scannerControllerProvider.notifier);

    ref.listen(scannerControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Review (${state.pages.length} page${state.pages.length == 1 ? '' : 's'})',
        ),
        actions: [
          TextButton(
            onPressed: state.isUploading
                ? null
                : () {
                    controller.reset();
                    context.pop();
                  },
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: state.pages.isEmpty
          ? const Center(child: Text('No pages captured.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.giant,
              ),
              itemCount: state.pages.length,
              onReorderItem: controller.reorderPages,
              itemBuilder: (context, index) {
                final page = state.pages[index];
                return Container(
                  key: ValueKey(page.id),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(page.localPath),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Page ${index + 1}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: state.isUploading
                            ? null
                            : () => controller.removePage(page.id),
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.isUploading
                          ? null
                          : controller.scanDocument,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Add page'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: DropdownButtonFormField<DocumentType>(
                      initialValue: _documentType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      items: DocumentType.values
                          .map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(_label(t)),
                            ),
                          )
                          .toList(),
                      onChanged: state.isUploading
                          ? null
                          : (value) => setState(
                              () => _documentType = value ?? _documentType,
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (state.isUploading) ...[
                LinearProgressIndicator(
                  value: state.pages.isEmpty
                      ? null
                      : state.uploadedPages / state.pages.length,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Uploading page ${state.uploadedPages} of ${state.pages.length}…',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.isUploading || state.pages.isEmpty
                      ? null
                      : _save,
                  child: const Text('Save to Vault'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _label(DocumentType type) {
    return switch (type) {
      DocumentType.invoice => 'Invoice',
      DocumentType.receipt => 'Receipt',
      DocumentType.taxDocument => 'Tax document',
      DocumentType.other => 'Other',
    };
  }
}
