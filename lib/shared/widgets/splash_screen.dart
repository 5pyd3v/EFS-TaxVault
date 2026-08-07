import 'package:flutter/material.dart';
import 'package:fbr_taxvault/core/constants/app_constants.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.lg),
            Text(AppConstants.appName, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xxxl),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
