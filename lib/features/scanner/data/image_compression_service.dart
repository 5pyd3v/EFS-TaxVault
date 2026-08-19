import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

abstract interface class ImageCompressionService {
  /// Compresses the image at [filePath] for upload. Falls back to the
  /// original file bytes if compression fails rather than blocking the
  /// scan — a slightly larger upload beats losing the user's capture.
  ///
  /// Set [displayOnly] when on-device OCR already succeeded for this
  /// document: extraction will read that text instead of the image, so the
  /// stored copy only ever needs to be legible to a human scrolling the
  /// original scan. That allows noticeably harder compression — smaller
  /// uploads and faster scans — with no effect on extraction accuracy.
  Future<Uint8List> compress(String filePath, {bool displayOnly = false});
}

class ImageCompressionServiceImpl implements ImageCompressionService {
  @override
  Future<Uint8List> compress(String filePath, {bool displayOnly = false}) async {
    // NOTE ON SEMANTICS: minWidth/minHeight are FLOORS, not targets — the
    // image is scaled down only until its smaller dimension reaches this
    // value, and never upscaled. That makes the value easy to set
    // ineffectively: a typical 1080px-wide phone screenshot is untouched by
    // any floor >= 1080, so earlier values of 2200/1600 did no downscaling
    // at all for screenshots (the most common input here).
    //
    // 1100 actually bites: it trims screenshots slightly and cuts
    // oversized camera photos (3000px+) down substantially. That matters
    // because Gemini's vision encoder bills by fixed-size image tiles, so
    // pixel count maps almost directly to input tokens on every scan —
    // and on a rate-limited key, tokens per request drive how often
    // requests get throttled. Deliberately not pushed lower: invoice
    // numbers and tax lines are small print, and lost legibility would
    // trade a token saving for exactly the extraction accuracy this is
    // meant to protect. Quality stays at 90 for the same reason — JPEG
    // quality affects upload size but not token count, so there's nothing
    // to gain by degrading it.
    // Two profiles. The extraction profile stays conservative because
    // Gemini may still have to read this image directly (the fallback when
    // OCR found nothing usable). The display profile applies once OCR has
    // already captured the text: nothing machine-readable depends on these
    // pixels anymore, only a human reviewing the original scan, so the
    // bytes uploaded over mobile data can drop substantially.
    final compressed = await FlutterImageCompress.compressWithFile(
      filePath,
      quality: displayOnly ? 78 : 90,
      minWidth: displayOnly ? 900 : 1100,
      minHeight: displayOnly ? 900 : 1100,
      format: CompressFormat.jpeg,
    );
    if (compressed != null) return compressed;
    return File(filePath).readAsBytes();
  }
}
