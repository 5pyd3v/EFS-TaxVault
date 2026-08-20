import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/onboarding_screen.dart';
import 'package:fbr_taxvault/features/auth/presentation/sign_in_screen.dart';
import 'package:fbr_taxvault/features/auth/presentation/sign_up_screen.dart';
import 'package:fbr_taxvault/features/ai/presentation/processing_screen.dart';
import 'package:fbr_taxvault/features/ai_key/presentation/ai_key_settings_screen.dart';
import 'package:fbr_taxvault/features/ai_key/presentation/my_ai_key_settings_screen.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_processing_screen.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_review_screen.dart';
import 'package:fbr_taxvault/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fbr_taxvault/features/disputes/presentation/dispute_queue_screen.dart';
import 'package:fbr_taxvault/features/invoices/presentation/invoice_review_screen.dart';
import 'package:fbr_taxvault/features/notifications/presentation/notifications_screen.dart';
import 'package:fbr_taxvault/features/profile/presentation/profile_screen.dart';
import 'package:fbr_taxvault/features/reports/presentation/reports_screen.dart';
import 'package:fbr_taxvault/features/scanner/presentation/review_pages_screen.dart';
import 'package:fbr_taxvault/features/scanner/presentation/scanner_screen.dart';
import 'package:fbr_taxvault/features/superadmin/presentation/create_sandbox_account_screen.dart';
import 'package:fbr_taxvault/features/superadmin/presentation/superadmin_dashboard_screen.dart';
import 'package:fbr_taxvault/features/superadmin/presentation/superadmin_providers.dart';
import 'package:fbr_taxvault/features/team/presentation/add_team_member_screen.dart';
import 'package:fbr_taxvault/features/team/presentation/team_screen.dart';
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
    ref.listen(platformAdminStatusProvider, (_, _) => notifyListeners());
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
        path: AppRoutes.myAiKeySettings,
        builder: (_, _) => const MyAiKeySettingsScreen(),
      ),
      GoRoute(path: AppRoutes.team, builder: (_, _) => const TeamScreen()),
      GoRoute(
        path: AppRoutes.addTeamMember,
        builder: (_, _) => const AddTeamMemberScreen(),
      ),
      GoRoute(
        path: AppRoutes.disputeQueue,
        builder: (_, _) => const DisputeQueueScreen(),
      ),
      GoRoute(
        path: AppRoutes.superadmin,
        builder: (_, _) => const SuperadminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.createSandboxAccount,
        builder: (_, _) => const CreateSandboxAccountScreen(),
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

  final atSuperadmin = state.matchedLocation.startsWith(AppRoutes.superadmin);

  // Read the raw AsyncValue rather than isPlatformAdminProvider's
  // `.valueOrNull ?? false` — that default is exactly what let a brand-new
  // platform admin fall through to onboarding on their very first sign-in:
  // this check hadn't resolved yet, so it silently read as "not an admin"
  // and the org-empty branch below sent them to onboarding, which looks
  // like an ordinary setup screen — completable, not obviously wrong. Here,
  // an unresolved check holds at splash instead of guessing.
  final platformAdminStatus = ref.read(platformAdminStatusProvider);
  if (platformAdminStatus.isLoading) {
    return atSplash ? null : AppRoutes.splash;
  }
  final isPlatformAdmin = platformAdminStatus.valueOrNull ?? false;

  // Checked before any org-based branch, and unconditionally — not just
  // when `orgs.isEmpty` — so this stays authoritative even for an admin
  // account that already has a stray organization (e.g. from the race
  // above, before this fix landed).
  if (isPlatformAdmin) {
    return atSuperadmin ? null : AppRoutes.superadmin;
  }

  final organizations = ref.read(myOrganizationsProvider);
  return organizations.when(
    data: (orgs) {
      if (orgs.isEmpty) {
        // A PIN-managed team member never provisions their own
        // organization — onboarding is an email/password-signup concept.
        // Zero orgs for one of these accounts means an admin removed them
        // (remove_team_member deletes their organization_members row) —
        // sign them out and send them back to sign-in rather than letting
        // them create a brand-new org for themselves. Deferred to a
        // microtask since _redirect must return synchronously and signOut
        // is async; the resulting auth-state change re-triggers this
        // function, which then correctly falls into the `user == null`
        // branch above.
        if (user.isPinManaged) {
          Future.microtask(() => ref.read(authRepositoryProvider).signOut());
          return atAuthScreen ? null : AppRoutes.signIn;
        }
        return atOnboarding ? null : AppRoutes.onboarding;
      }

      // Blocked org: every member is signed out and refused sign-in until
      // a platform admin unblocks it — same microtask-deferred signOut
      // pattern as the removed-PIN-member case above, since _redirect must
      // return synchronously and signOut is async.
      if (orgs.first.isBlocked) {
        Future.microtask(() => ref.read(authRepositoryProvider).signOut());
        return atAuthScreen ? null : AppRoutes.signIn;
      }

      if (atAuthScreen || atSplash || atOnboarding) {
        return AppRoutes.home;
      }

      // A normal (org-scoped) user has no business at /superadmin — the
      // RPCs behind it already reject them server-side, this just avoids
      // rendering a screen that would immediately error out.
      if (atSuperadmin) {
        return AppRoutes.home;
      }

      // Team management and the disputes queue are business-org
      // owner/admin only. The RPCs/RLS behind these screens already
      // enforce this server-side — this is a belt-and-suspenders UI-level
      // gate so a non-approver (or an individual-account user) never even
      // sees the screen render before an error comes back.
      final atTeamManagement =
          state.matchedLocation.startsWith(AppRoutes.team) ||
          state.matchedLocation == AppRoutes.disputeQueue;
      if (atTeamManagement) {
        final org = orgs.first;
        final isApprover =
            org.role == OrganizationRole.owner ||
            org.role == OrganizationRole.admin;
        if (org.type != OrganizationType.business || !isApprover) {
          return AppRoutes.home;
        }
      }

      return null;
    },
    loading: () => atSplash ? null : AppRoutes.splash,
    error: (_, _) => atSplash ? AppRoutes.home : null,
  );
}
