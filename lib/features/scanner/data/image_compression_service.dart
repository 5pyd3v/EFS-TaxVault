import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

abstract interface class ImageCompressionService {
  /// Compresses the image at [filePath] for upload. Falls back to the
  /// original file bytes if compression fails rather than blocking the
  /// scan — a slightly larger upload beats losing the user's capture.
  Future<Uint8List> compress(String filePath);
}

class ImageCompressionServiceImpl implements ImageCompressionService {
  @override
  Future<Uint8List> compress(String filePath) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      filePath,
      quality: 82,
      minWidth: 1600,
      minHeight: 1600,
      format: CompressFormat.jpeg,
    );
    if (compressed != null) return compressed;
    return File(filePath).readAsBytes();
  }
}
