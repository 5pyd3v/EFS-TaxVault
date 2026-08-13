import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/fbr/domain/fbr_submission.dart';
import 'package:fbr_taxvault/features/fbr/domain/fbr_submit_outcome.dart';

abstract interface class FbrRepository {
  /// Null if the invoice has never had a submission attempt.
  Future<Result<FbrSubmission?>> getSubmission(String invoiceId);

  /// Runs the mock TaxAuthorityService pipeline (spec §5-6) via the
  /// `submit-to-fbr` Edge Function — the only place that talks to an
  /// "FBR adapter", which today is a labeled mock, never a real filing.
  Future<Result<FbrSubmitOutcome>> submit(
    String invoiceId, {
    bool force = false,
  });
}
