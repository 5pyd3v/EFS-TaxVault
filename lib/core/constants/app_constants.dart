/// App-wide constants that aren't configuration (see [EnvConfig] for that).
abstract final class AppConstants {
  static const String appName = 'EFS TaxVault';
  static const String appTagline = 'Scan Once. File Anytime.';

  /// Current canonical invoice schema version. Bump when the canonical
  /// invoice shape changes; older records keep their original version so
  /// they can be migrated deliberately instead of silently reinterpreted.
  static const String canonicalSchemaVersion = '1.0';

  static const double aiConfidenceReviewThreshold = 0.85;
}
