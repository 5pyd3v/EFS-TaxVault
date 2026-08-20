import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/constants/app_constants.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/core/theme/app_theme.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_controller.dart';
import 'package:fbr_taxvault/shared/utils/validators.dart';
import 'package:fbr_taxvault/shared/widgets/app_segmented_toggle.dart';

enum _SignInMode { email, pin }

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePassword = true;
  _SignInMode _mode = _SignInMode.email;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mode == _SignInMode.email) {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } else {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithPin(
            phone: _phoneController.text.trim(),
            pin: _pinController.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null && next is! AsyncLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxxl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.brandTint(
                      theme.brightness == Brightness.dark,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppConstants.appTagline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Text('Welcome back', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  'Sign in to continue to your vault',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppSegmentedToggle<_SignInMode>(
                  segments: const [
                    AppToggleSegment(value: _SignInMode.email, label: 'Email'),
                    AppToggleSegment(value: _SignInMode.pin, label: 'Team PIN'),
                  ],
                  selected: _mode,
                  onChanged: isLoading
                      ? (_) {}
                      : (mode) => setState(() => _mode = mode),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (_mode == _SignInMode.email) ...[
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: Validators.email,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: Validators.password,
                    enabled: !isLoading,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ] else ...[
                  Text(
                    'Sign in with the phone number and PIN your admin gave you',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                    validator: Validators.phone,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    obscureText: true,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                    ),
                    validator: Validators.pin,
                    enabled: !isLoading,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                if (_mode == _SignInMode.email) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.push(AppRoutes.signUp),
                      child: const Text("Don't have an account? Sign up"),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
