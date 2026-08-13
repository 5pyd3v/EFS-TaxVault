import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/fbr/data/fbr_repository_impl.dart';
import 'package:fbr_taxvault/features/fbr/domain/fbr_repository.dart';
import 'package:fbr_taxvault/features/fbr/domain/fbr_submission.dart';

final fbrRepositoryProvider = Provider<FbrRepository>((ref) {
  return FbrRepositoryImpl(ref.watch(supabaseClientProvider));
});

final fbrSubmissionProvider = FutureProvider.family<FbrSubmission?, String>((
  ref,
  invoiceId,
) async {
  final result = await ref
      .watch(fbrRepositoryProvider)
      .getSubmission(invoiceId);
  return result.fold((submission) => submission, (failure) => throw failure);
});
