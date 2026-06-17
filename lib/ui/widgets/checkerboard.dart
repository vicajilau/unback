import 'package:flutter/material.dart';

/// A custom painter that draws a checkerboard background pattern.
class CheckerboardPainter extends CustomPainter {
  final double cellSize;
  final Color color1;
  final Color color2;

  const CheckerboardPainter({
    required this.cellSize,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    for (double y = 0; y < size.height; y += cellSize) {
      final int rowIdx = (y / cellSize).floor();
      final double cellHeight = (y + cellSize > size.height)
          ? (size.height - y)
          : cellSize;

      for (double x = 0; x < size.width; x += cellSize) {
        final int colIdx = (x / cellSize).floor();
        final double cellWidth = (x + cellSize > size.width)
            ? (size.width - x)
            : cellSize;

        final paint = (rowIdx + colIdx) % 2 == 0 ? paint1 : paint2;
        canvas.drawRect(Rect.fromLTWH(x, y, cellWidth, cellHeight), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2;
  }
}

/// A widget that displays a checkerboard pattern background.
/// Perfect for previewing transparent elements.
class Checkerboard extends StatelessWidget {
  final double cellSize;
  final Color? color1;
  final Color? color2;
  final Widget? child;

  const Checkerboard({
    super.key,
    this.cellSize = 12.0,
    this.color1,
    this.color2,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Default to clean, modern, dark slate shades if colors are not specified
    final Color c1 = color1 ?? const Color(0xFF1E293B); // Slate 800
    final Color c2 = color2 ?? const Color(0xFF0F172A); // Slate 900

    return RepaintBoundary(
      child: CustomPaint(
        painter: CheckerboardPainter(
          cellSize: cellSize,
          color1: c1,
          color2: c2,
        ),
        child: child,
      ),
    );
  }
}
