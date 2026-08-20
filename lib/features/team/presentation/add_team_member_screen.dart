import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/team/domain/team_member.dart';
import 'package:fbr_taxvault/features/team/presentation/team_controller.dart';
import 'package:fbr_taxvault/shared/utils/validators.dart';
import 'package:fbr_taxvault/shared/widgets/app_segmented_toggle.dart';

/// Admin-only form to add a staff account by name + phone. On success shows
/// the generated PIN exactly once — it's never retrievable again after this
/// screen closes, so the admin must share it with the new team member now.
class AddTeamMemberScreen extends ConsumerStatefulWidget {
  const AddTeamMemberScreen({super.key});

  @override
  ConsumerState<AddTeamMemberScreen> createState() =>
      _AddTeamMemberScreenState();
}

enum _GeminiKeyChoice { organization, own }

class _AddTeamMemberScreenState extends ConsumerState<AddTeamMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _apiKeyController = TextEditingController();
  // Asking this up front — rather than leaving it to a separate "Set
  // Gemini key" step on the Team screen after the fact — means a member
  // never lands on a device unable to scan because nobody set a key for
  // them yet. Defaults to the org key since that's already configured for
  // every business org and needs no extra input.
  _GeminiKeyChoice _geminiKeyChoice = _GeminiKeyChoice.organization;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit(String organizationId) async {
    if (!_formKey.currentState!.validate()) return;
    final credentials = await ref
        .read(teamControllerProvider.notifier)
        .createMember(
          organizationId: organizationId,
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: OrganizationRole.member,
        );
    if (!mounted || credentials == null) return;

    if (_geminiKeyChoice == _GeminiKeyChoice.own) {
      final keySaved = await ref
          .read(teamControllerProvider.notifier)
          .setMemberGeminiKey(
            userId: credentials.userId,
            organizationId: organizationId,
            apiKey: _apiKeyController.text.trim(),
          );
      if (!mounted) return;
      if (!keySaved) {
        // The account itself was created successfully — only the key save
        // failed — so this is a heads-up, not a reason to stop and lose
        // the one-time PIN reveal below. They can set it later from the
        // Team screen's per-row "Set Gemini key" action.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Account created, but the Gemini key couldn\'t be saved. You can set it later from Team.',
              ),
            ),
          );
      }
    }

    await _showPinRevealSheet(credentials);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showPinRevealSheet(NewTeamMemberCredentials credentials) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (context) => _PinRevealSheet(credentials: credentials),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final organization = ref.watch(currentOrganizationProvider);
    final controllerState = ref.watch(teamControllerProvider);
    final isSaving = controllerState.isLoading;

    ref.listen(teamControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null && next is! AsyncLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Add team member')),
      body: organization == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'They’ll sign in with a phone number and a PIN you share with them — no email or password needed.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: Validators.required,
                      enabled: !isSaving,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                      ),
                      validator: Validators.phone,
                      enabled: !isSaving,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Gemini API key', style: theme.textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.sm),
                    AppSegmentedToggle<_GeminiKeyChoice>(
                      segments: const [
                        AppToggleSegment(
                          value: _GeminiKeyChoice.organization,
                          label: 'Use organization\'s',
                        ),
                        AppToggleSegment(
                          value: _GeminiKeyChoice.own,
                          label: 'Set one for them',
                        ),
                      ],
                      selected: _geminiKeyChoice,
                      onChanged: isSaving
                          ? (_) {}
                          : (choice) =>
                                setState(() => _geminiKeyChoice = choice),
                    ),
                    if (_geminiKeyChoice == _GeminiKeyChoice.organization) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'They\'ll use your organization\'s shared key unless you give them their own later.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _apiKeyController,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Gemini API key for this member',
                          hintText: 'AIza...',
                        ),
                        validator: _geminiKeyChoice == _GeminiKeyChoice.own
                            ? (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.length < 10) {
                                  return 'Enter a valid Gemini API key';
                                }
                                return null;
                              }
                            : null,
                        enabled: !isSaving,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxxl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () => _submit(organization.id),
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

class _PinRevealSheet extends StatelessWidget {
  const _PinRevealSheet({required this.credentials});

  final NewTeamMemberCredentials credentials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

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
                  color: semantic.success,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '${credentials.fullName} can now sign in',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'PIN',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    credentials.pin,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      letterSpacing: 6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _DetailRow(label: 'Phone', value: credentials.phone),
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
                      'This PIN is shown only once. Share it with them now — you can generate a new one later, but this one won’t be shown again.',
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
                              'Phone: ${credentials.phone}\nPIN: ${credentials.pin}',
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
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
