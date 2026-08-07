/// One captured or imported page, before upload. [localPath] points at a
/// temp file on device (from the native scanner or the gallery picker).
class ScannedPage {
  const ScannedPage({required this.id, required this.localPath});

  /// Stable identity for list operations (reorder/remove) — the local file
  /// path is unique per capture, so it doubles as the id.
  final String id;
  final String localPath;
}
