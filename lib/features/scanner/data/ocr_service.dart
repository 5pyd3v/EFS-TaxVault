import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract interface class OcrService {
  /// Recognizes text in the given local image files, in page order.
  ///
  /// Returns null when too little text was found to be worth sending
  /// instead of the image — callers treat that as "fall back to the
  /// image", never as an error. OCR here is an optimization, not a
  /// precondition for scanning.
  Future<String?> recognizeText(List<String> filePaths);

  /// Releases the underlying native recognizer.
  Future<void> dispose();
}

/// On-device text recognition (ML Kit). Runs locally, needs no network,
/// costs nothing, and is not subject to any API quota — which is the whole
/// point: it moves the expensive part of extraction off the metered path.
///
/// The recognized text is what gets sent to Gemini instead of the page
/// image. A receipt image costs roughly 1,500-2,500 input tokens and takes
/// the slow vision path; the same content as text is ~200 tokens on the
/// fast text path. That cuts both the per-request cost that drives quota
/// throttling and the latency the user waits through.
class OcrServiceImpl implements OcrService {
  OcrServiceImpl() : _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Below this, the recognition almost certainly failed (a dark photo, an
  /// unusual layout, a non-Latin script) rather than genuinely finding a
  /// near-empty receipt. Sending a few stray characters to Gemini would be
  /// strictly worse than sending the image, so the caller falls back.
  static const _minUsefulLength = 40;

  @override
  Future<String?> recognizeText(List<String> filePaths) async {
    final buffer = StringBuffer();

    for (final path in filePaths) {
      try {
        final recognized = await _recognizer.processImage(
          InputImage.fromFilePath(path),
        );
        // ML Kit returns text grouped into blocks and lines in reading
        // order. Emitting one line per newline preserves the top-to-bottom
        // ordering that receipt parsing depends on — "From X" appearing
        // before "To Y" is what lets the sender be identified without the
        // spatial layout the image would have provided.
        for (final block in recognized.blocks) {
          for (final line in block.lines) {
            buffer.writeln(line.text);
          }
        }
      } catch (_) {
        // A single unreadable page shouldn't discard the pages that did
        // work; whatever was gathered is still evaluated below.
        continue;
      }
    }

    final text = buffer.toString().trim();
    return text.length >= _minUsefulLength ? text : null;
  }

  @override
  Future<void> dispose() => _recognizer.close();
}
