import 'package:doc_scan_flutter/doc_scan.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fbr_taxvault/features/scanner/domain/scanned_page.dart';
import 'package:fbr_taxvault/features/scanner/domain/scanner_service.dart';

/// Thrown for scan/import failures the UI should surface as a message
/// (permission denial, native scanner error). Distinct from [Failure] since
/// this lives at the device-capability boundary, before any repository
/// call — the controller maps it to a Failure when it catches it.
class ScannerException implements Exception {
  ScannerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ScannerServiceImpl implements ScannerService {
  ScannerServiceImpl({ImagePicker? imagePicker}) : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<List<ScannedPage>> scanDocument() async {
    try {
      final paths = await DocumentScanner.scan(format: DocScanFormat.jpeg);
      if (paths == null || paths.isEmpty) return const [];
      return paths.map((path) => ScannedPage(id: path, localPath: path)).toList();
    } on DocumentScannerException catch (e) {
      throw ScannerException(e.message);
    }
  }

  @override
  Future<List<ScannedPage>> pickFromGallery() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 90);
    return files.map((f) => ScannedPage(id: f.path, localPath: f.path)).toList();
  }
}
