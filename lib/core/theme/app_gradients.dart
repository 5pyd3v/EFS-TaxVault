import 'package:flutter/material.dart';

/// Bold, varied gradients for the small set of surfaces that should pop —
/// the dashboard hero and its stat tiles. Each card gets its own hue so the
/// screen reads as colorful and considered (Cash App/Revolut-style) rather
/// than one mood color painted over everything.
abstract final class AppGradients {
  static const blue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7CF6), Color(0xFF17B8A6)],
  );

  static const amber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB020), Color(0xFFFF7A45)],
  );

  static const coral = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF5C7A), Color(0xFFFF8A5B)],
  );

  static const green = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), Color(0xFF17B8A6)],
  );

  static const violet = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9C6BFF), Color(0xFFFF6EC7)],
  );
}
