// Foundation smoke tests. Screens that depend on an initialized Supabase
// client (dashboard, onboarding, anything behind the router's redirect
// logic) aren't exercised here — that needs an integration-test harness
// with a mocked/live backend, not a plain widget test. These cover what
// can be verified without one: the theme builds, the "backend not
// configured" fallback renders, and the sign-in screen (which doesn't
// touch Supabase until submit) shows its expected fields.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fbr_taxvault/backend_not_configured_app.dart';
import 'package:fbr_taxvault/core/theme/app_theme.dart';
import 'package:fbr_taxvault/features/auth/presentation/sign_in_screen.dart';

void main() {
  test('AppTheme builds distinct light and dark themes', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.extensions, isNotEmpty);
    expect(AppTheme.dark.extensions, isNotEmpty);
  });

  testWidgets('BackendNotConfiguredApp explains missing Supabase config', (tester) async {
    await tester.pumpWidget(const BackendNotConfiguredApp());
    await tester.pumpAndSettle();

    expect(find.text('Backend not configured'), findsOneWidget);
  });

  testWidgets('SignInScreen shows email, password, and submit action', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SignInScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });
}
