// One-off icon generator, run via:
//   flutter test tool/generate_icon_test.dart
// Renders the EFS TaxVault mark (a verified shield — receipts kept safe,
// AI-checked) straight through dart:ui, no external image tooling needed.
// Not part of the app or its normal test suite.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _brandStart = Color(0xFF2E7CF6);
const _brandEnd = Color(0xFF17B8A6);

void main() {
  testWidgets('generate app icon assets', (tester) async {
    await tester.runAsync(() async {
      await _renderTo('assets/icon/app_icon.png', const _FullIconPainter());
      await _renderTo('assets/icon/app_icon_foreground.png', const _ForegroundIconPainter());
    });
  });
}

Future<void> _renderTo(String path, CustomPainter painter) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, const Size(size, size));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  file.parent.createSync(recursive: true);
  await file.writeAsBytes(byteData!.buffer.asUint8List());
  // ignore: avoid_print
  print('wrote $path');
}

class _FullIconPainter extends CustomPainter {
  const _FullIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandStart, _brandEnd],
        ).createShader(rect),
    );
    paintShieldGlyph(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ForegroundIconPainter extends CustomPainter {
  const _ForegroundIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Android adaptive icons only guarantee the center ~66% survives
    // masking, so the glyph is drawn inset into that safe zone.
    final inset = size.width * 0.18;
    canvas.save();
    canvas.translate(inset, inset);
    paintShieldGlyph(canvas, Size(size.width - inset * 2, size.height - inset * 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A shield (safekeeping) with a checkmark cut out of it (AI-verified) —
/// drawn once, reused for both the full icon and the adaptive foreground.
void paintShieldGlyph(Canvas canvas, Size size) {
  final w = size.width;
  final h = size.height;

  final shield = Path()
    ..moveTo(w * 0.5, h * 0.05)
    ..lineTo(w * 0.80, h * 0.18)
    ..lineTo(w * 0.80, h * 0.52)
    ..cubicTo(w * 0.80, h * 0.72, w * 0.67, h * 0.86, w * 0.5, h * 0.95)
    ..cubicTo(w * 0.33, h * 0.86, w * 0.20, h * 0.72, w * 0.20, h * 0.52)
    ..lineTo(w * 0.20, h * 0.18)
    ..close();

  final check = Path()
    ..moveTo(w * 0.335, h * 0.51)
    ..lineTo(w * 0.445, h * 0.62)
    ..lineTo(w * 0.685, h * 0.375);

  canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());
  canvas.drawPath(shield, Paint()..color = Colors.white);
  canvas.drawPath(
    check,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.clear,
  );
  canvas.restore();
}
