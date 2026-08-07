import 'package:flutter/material.dart';
import 'package:fbr_taxvault/core/constants/app_constants.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/core/theme/app_theme.dart';

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
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.brandTint(theme.brightness == Brightness.dark),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 30),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(AppConstants.appName, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xxxl),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
