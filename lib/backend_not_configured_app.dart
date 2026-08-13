import 'package:flutter/material.dart';
import 'package:fbr_taxvault/core/constants/app_constants.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/core/theme/app_theme.dart';

/// Shown instead of crashing when no Supabase project is configured yet
/// (see [EnvConfig]) — lets the UI/design system be reviewed on-device
/// before a backend exists, with an honest explanation instead of a stack
/// trace.
class BackendNotConfiguredApp extends StatelessWidget {
  const BackendNotConfiguredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Backend not configured',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Run the app with your Supabase project credentials:\n\n'
                    'flutter run \\\n'
                    '  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \\\n'
                    '  --dart-define=SUPABASE_ANON_KEY=xxxx',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
