import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/onboarding_screen.dart';
import 'package:fbr_taxvault/features/auth/presentation/sign_in_screen.dart';
import 'package:fbr_taxvault/features/auth/presentation/sign_up_screen.dart';
import 'package:fbr_taxvault/features/ai/presentation/processing_screen.dart';
import 'package:fbr_taxvault/features/ai_key/presentation/ai_key_settings_screen.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_processing_screen.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_review_screen.dart';
import 'package:fbr_taxvault/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fbr_taxvault/features/invoices/presentation/invoice_review_screen.dart';
import 'package:fbr_taxvault/features/notifications/presentation/notifications_screen.dart';
import 'package:fbr_taxvault/features/profile/presentation/profile_screen.dart';
import 'package:fbr_taxvault/features/reports/presentation/reports_screen.dart';
import 'package:fbr_taxvault/features/scanner/presentation/review_pages_screen.dart';
import 'package:fbr_taxvault/features/scanner/presentation/scanner_screen.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_screen.dart';
import 'package:fbr_taxvault/shared/widgets/app_shell.dart';
import 'package:fbr_taxvault/shared/widgets/splash_screen.dart';

/// Bridges Riverpod state into go_router's `refreshListenable`: whenever
/// auth state or organization membership changes, the router re-evaluates
/// [_redirect] instead of the UI having to trigger navigation manually.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, _) => notifyListeners());
    ref.listen(myOrganizationsProvider, (_, _) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(path: AppRoutes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.scanReview,
        builder: (_, _) => const ReviewPagesScreen(),
      ),
      GoRoute(
        path: AppRoutes.processingPattern,
        builder: (_, state) =>
            ProcessingScreen(documentId: state.pathParameters['documentId']!),
      ),
      GoRoute(
        path: AppRoutes.invoiceReviewPattern,
        builder: (_, state) =>
            InvoiceReviewScreen(invoiceId: state.pathParameters['invoiceId']!),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiKeySettings,
        builder: (_, _) => const AiKeySettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.bankTransactionProcessingPattern,
        builder: (_, state) => BankTransactionProcessingScreen(
          documentId: state.pathParameters['documentId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.bankTransactionReviewPattern,
        builder: (_, state) => BankTransactionReviewScreen(
          transactionId: state.pathParameters['transactionId']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.vault,
                builder: (_, _) => const VaultScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.scan,
                builder: (_, _) => const ScannerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (_, _) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final atAuthScreen =
      state.matchedLocation == AppRoutes.signIn ||
      state.matchedLocation == AppRoutes.signUp;
  final atSplash = state.matchedLocation == AppRoutes.splash;
  final atOnboarding = state.matchedLocation == AppRoutes.onboarding;

  final user = ref.read(currentUserProvider);
  if (user == null) {
    return atAuthScreen ? null : AppRoutes.signIn;
  }

  final organizations = ref.read(myOrganizationsProvider);
  return organizations.when(
    data: (orgs) {
      if (orgs.isEmpty) {
        return atOnboarding ? null : AppRoutes.onboarding;
      }
      if (atAuthScreen || atSplash || atOnboarding) {
        return AppRoutes.home;
      }
      return null;
    },
    loading: () => atSplash ? null : AppRoutes.splash,
    error: (_, _) => atSplash ? AppRoutes.home : null,
  );
}
