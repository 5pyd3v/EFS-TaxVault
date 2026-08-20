import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/ai_key/domain/gemini_key_status.dart';
import 'package:fbr_taxvault/features/ai_key/presentation/ai_key_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';

const _geminiStudioUrl = 'https://aistudio.google.com/app/apikey';

/// Lets a non-admin team member add or replace their OWN Gemini API key —
/// the org-level equivalent of AiKeySettingsScreen, which only an
/// owner/admin can reach. Setting a personal key here is optional: if none
/// is set, extraction falls back to the organization's key automatically
/// (see supabase/functions/_shared/gemini_key.ts).
class MyAiKeySettingsScreen extends ConsumerStatefulWidget {
  const MyAiKeySettingsScreen({super.key});

  @override
  ConsumerState<MyAiKeySettingsScreen> createState() =>
      _MyAiKeySettingsScreenState();
}

class _MyAiKeySettingsScreenState extends ConsumerState<MyAiKeySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  bool _obscure = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save(String organizationId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final result = await ref
        .read(userAiKeyRepositoryProvider)
        .setApiKey(organizationId, _apiKeyController.text.trim());

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      (_) {
        ref.invalidate(myGeminiKeyStatusProvider(organizationId));
        _apiKeyController.clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('API key saved.')));
      },
      (failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message))),
    );
  }

  void _copyStudioUrl() {
    Clipboard.setData(const ClipboardData(text: _geminiStudioUrl));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final organization = ref.watch(currentOrganizationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Gemini API Key')),
      body: organization == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Consumer(
                    builder: (context, ref, _) {
                      final statusAsync = ref.watch(
                        myGeminiKeyStatusProvider(organization.id),
                      );
                      return AsyncValueView<GeminiKeyStatus>(
                        value: statusAsync,
                        onRetry: () => ref.invalidate(
                          myGeminiKeyStatusProvider(organization.id),
                        ),
                        loading: (_) => const _StatusCardSkeleton(),
                        data: (status) => _StatusCard(status: status),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'This is optional. If you don\'t set your own key, your scans use your organization\'s Gemini key automatically.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _apiKeyController,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Gemini API key',
                        hintText: 'AIza...',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.length < 10) {
                          return 'Enter a valid Gemini API key';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () => _save(organization.id),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save key'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Get a key from Google AI Studio',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _geminiStudioUrl,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Copy link',
                          onPressed: _copyStudioUrl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatusCardSkeleton extends StatelessWidget {
  const _StatusCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final GeminiKeyStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final (color, icon) = !status.hasKey
        ? (theme.colorScheme.primary, Icons.apartment_rounded)
        : status.isValid
        ? (semantic.success, Icons.verified_user_rounded)
        : (theme.colorScheme.error, Icons.error_outline_rounded);

    // Explicitly says whose key is in effect — "Configured"/"Not
    // configured" on their own don't tell a team member whether scans are
    // running on the org's shared key or a personal one they set.
    final label = !status.hasKey
        ? 'Using your organization\'s key'
        : status.isValid
        ? 'Using your own key'
        : status.lastError == 'quota_exceeded'
        ? 'Your key needs attention — quota exceeded'
        : 'Your key needs attention — invalid';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
                if (status.needsAttention)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      status.lastError == 'quota_exceeded'
                          ? 'This key has run out of quota. Paste a new one below, or wait a while and try again.'
                          : 'This key was rejected by Gemini. Paste a new one below.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
