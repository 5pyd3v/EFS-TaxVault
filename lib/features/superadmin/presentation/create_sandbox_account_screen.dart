import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/superadmin/domain/platform_organization.dart';
import 'package:fbr_taxvault/features/superadmin/presentation/superadmin_controller.dart';
import 'package:fbr_taxvault/shared/utils/validators.dart';
import 'package:fbr_taxvault/shared/widgets/app_segmented_toggle.dart';

enum _GeminiKeyChoice { skip, setNow }

/// Platform-admin only. Creates a clean, working individual account for a
/// prospective customer to test the app before buying — on success, shows
/// the generated email + password exactly once (see _CredentialsRevealSheet).
class CreateSandboxAccountScreen extends ConsumerStatefulWidget {
  const CreateSandboxAccountScreen({super.key});

  @override
  ConsumerState<CreateSandboxAccountScreen> createState() =>
      _CreateSandboxAccountScreenState();
}

class _CreateSandboxAccountScreenState
    extends ConsumerState<CreateSandboxAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _orgNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _geminiKeyController = TextEditingController();
  // Same toggle pattern as Add Team Member's Gemini key choice — a
  // sandbox account defaults to no key (the prospect adds their own from
  // Profile, same as any new individual account), but a platform admin
  // can pre-configure one so the demo is instantly ready to scan without
  // asking the prospect for their own key first.
  _GeminiKeyChoice _geminiKeyChoice = _GeminiKeyChoice.skip;

  @override
  void dispose() {
    _nameController.dispose();
    _orgNameController.dispose();
    _emailController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final credentials = await ref
        .read(superadminControllerProvider.notifier)
        .createSandboxAccount(
          fullName: _nameController.text.trim(),
          organizationName: _orgNameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          geminiApiKey: _geminiKeyChoice == _GeminiKeyChoice.setNow
              ? _geminiKeyController.text.trim()
              : null,
        );
    if (!mounted || credentials == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (context) => _CredentialsRevealSheet(credentials: credentials),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controllerState = ref.watch(superadminControllerProvider);
    final isSaving = controllerState.isLoading;

    ref.listen(superadminControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null && next is! AsyncLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Create sandbox account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A clean, fully working individual account for a prospect to try the app — not tied to any real customer data.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: "Prospect's name"),
                validator: Validators.required,
                enabled: !isSaving,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _orgNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Account label',
                  hintText: 'e.g. "Trial — Acme Traders"',
                ),
                validator: Validators.required,
                enabled: !isSaving,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'Leave blank to auto-generate one',
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  return Validators.email(trimmed);
                },
                enabled: !isSaving,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Gemini API key', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              AppSegmentedToggle<_GeminiKeyChoice>(
                segments: const [
                  AppToggleSegment(
                    value: _GeminiKeyChoice.skip,
                    label: 'Skip',
                  ),
                  AppToggleSegment(
                    value: _GeminiKeyChoice.setNow,
                    label: 'Set a key now',
                  ),
                ],
                selected: _geminiKeyChoice,
                onChanged: isSaving
                    ? (_) {}
                    : (choice) => setState(() => _geminiKeyChoice = choice),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_geminiKeyChoice == _GeminiKeyChoice.skip)
                Text(
                  'The prospect adds their own key from Profile before their first scan — same as any new individual account.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else ...[
                Text(
                  'Pre-configures the sandbox so it can scan immediately, without asking the prospect for a key first.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _geminiKeyController,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API key',
                    hintText: 'AIza...',
                  ),
                  validator: (value) {
                    if (_geminiKeyChoice != _GeminiKeyChoice.setNow) return null;
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.length < 10) {
                      return 'Enter a valid Gemini API key';
                    }
                    return null;
                  },
                  enabled: !isSaving,
                ),
              ],
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _submit,
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CredentialsRevealSheet extends StatelessWidget {
  const _CredentialsRevealSheet({required this.credentials});

  final NewSandboxCredentials credentials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          AppSpacing.xl,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Sandbox account ready',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'They sign in on the same screen as everyone else — the "Email" tab (not "Team PIN"), using these credentials.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _DetailRow(label: 'Email', value: credentials.email),
            const SizedBox(height: AppSpacing.xs),
            _DetailRow(label: 'Password', value: credentials.password),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This password is shown only once. Copy it now — it can\'t be shown again.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text:
                              'Email: ${credentials.email}\nPassword: ${credentials.password}',
                        ),
                      );
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
