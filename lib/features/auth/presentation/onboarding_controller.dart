import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';

class OnboardingController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> createOrganization({
    required String name,
    required OrganizationType type,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(organizationRepositoryProvider).createOrganization(
          name: name,
          type: type,
        );
    return result.fold(
      (_) {
        state = const AsyncData(null);
        ref.invalidate(myOrganizationsProvider);
        return true;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }
}

final onboardingControllerProvider = AsyncNotifierProvider<OnboardingController, void>(
  OnboardingController.new,
);
