import 'package:flutter/material.dart';

/// A minimal trend line with a soft gradient fill underneath — the kind of
/// small data-viz touch that reads as "an analyst built this dashboard"
/// rather than a static template. No chart package: a handful of points
/// doesn't need one.
class SparklineChart extends StatelessWidget {
  const SparklineChart({
    super.key,
    required this.values,
    this.lineColor = Colors.white,
    this.height = 44,
  });

  final List<double> values;
  final Color lineColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, lineColor: lineColor),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.lineColor});

  final List<double> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final stepX = size.width / (values.length - 1);
    final topInset = size.height * 0.08;
    final usableHeight = size.height * 0.84;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          i * stepX,
          size.height - topInset - ((values[i] - minV) / range) * usableHeight,
        ),
    ];

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    final fillPath = Path()
      ..moveTo(points.first.dx, size.height)
      ..lineTo(points.first.dx, points.first.dy);

    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      fillPath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    linePath.lineTo(points.last.dx, points.last.dy);
    fillPath.lineTo(points.last.dx, points.last.dy);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.3),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    canvas.drawCircle(
      points.last,
      7,
      Paint()..color = lineColor.withValues(alpha: 0.22),
    );
    canvas.drawCircle(points.last, 3.5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}
