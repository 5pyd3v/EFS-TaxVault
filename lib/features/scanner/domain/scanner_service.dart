import 'package:fbr_taxvault/features/scanner/domain/scanned_page.dart';

/// Wraps device capture capabilities. The native document scanner already
/// provides edge detection, auto-capture, manual capture, flash, crop, and
/// multi-page support (spec §12) — this interface exists so the app never
/// talks to `doc_scan_flutter`/`image_picker` directly, keeping the
/// specific plugin swappable.
abstract interface class ScannerService {
  /// Launches the native document scanner. Returns an empty list if the
  /// user cancels — that is not an error.
  Future<List<ScannedPage>> scanDocument();

  /// Lets the user pick one or more existing photos as invoice pages.
  Future<List<ScannedPage>> pickFromGallery();
}
