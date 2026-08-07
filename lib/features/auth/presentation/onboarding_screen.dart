import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_controller.dart';
import 'package:fbr_taxvault/features/auth/presentation/onboarding_controller.dart';
import 'package:fbr_taxvault/shared/utils/validators.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  OrganizationType _type = OrganizationType.individual;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(onboardingControllerProvider.notifier).createOrganization(
          name: _nameController.text.trim(),
          type: _type,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(onboardingControllerProvider);
    final isLoading = state.isLoading;

    ref.listen(onboardingControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null && next is! AsyncLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your vault'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One more step',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Every invoice, document, and report in TaxVault belongs to an organization — '
                  'this keeps your data isolated and ready for team access later.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                SegmentedButton<OrganizationType>(
                  segments: const [
                    ButtonSegment(
                      value: OrganizationType.individual,
                      label: Text('Individual'),
                      icon: Icon(Icons.person_outline_rounded),
                    ),
                    ButtonSegment(
                      value: OrganizationType.business,
                      label: Text('Business'),
                      icon: Icon(Icons.apartment_rounded),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: isLoading
                      ? null
                      : (selection) => setState(() => _type = selection.first),
                ),
                const SizedBox(height: AppSpacing.xxl),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _type == OrganizationType.business
                        ? 'Business name'
                        : 'Display name',
                  ),
                  validator: (v) => Validators.required(v, message: 'This name is required'),
                  enabled: !isLoading,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
