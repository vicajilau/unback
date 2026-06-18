import 'package:flutter/material.dart';

/// A custom clipper to show either the left or right portion of a widget.
class _SplitClipper extends CustomClipper<Rect> {
  final double splitRatio;
  final bool clipLeft; // If true, keeps left side. If false, keeps right side.

  _SplitClipper({required this.splitRatio, required this.clipLeft});

  @override
  Rect getClip(Size size) {
    if (clipLeft) {
      return Rect.fromLTRB(0, 0, size.width * splitRatio, size.height);
    } else {
      return Rect.fromLTRB(size.width * splitRatio, 0, size.width, size.height);
    }
  }

  @override
  bool shouldReclip(covariant _SplitClipper oldClipper) {
    return oldClipper.splitRatio != splitRatio || oldClipper.clipLeft != clipLeft;
  }
}

/// A widget that displays two overlapping children (typically original and processed images)
/// and allows the user to slide a divider horizontally to compare them.
class SplitSlider extends StatefulWidget {
  final Widget original;
  final Widget processed;
  final double aspectRatio;

  const SplitSlider({
    super.key,
    required this.original,
    required this.processed,
    required this.aspectRatio,
  });

  @override
  State<SplitSlider> createState() => _SplitSliderState();
}

class _SplitSliderState extends State<SplitSlider> {
  double _splitRatio = 0.5; // Starts in the middle

  void _handleDrag(DragUpdateDetails details, double width) {
    setState(() {
      _splitRatio = (_splitRatio + details.delta.dx / width).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the actual size of the comparison container based on aspect ratio
        final containerWidth = constraints.maxWidth;
        final containerHeight = containerWidth / widget.aspectRatio;

        // If the height is too large for the parent constraints, shrink to fit height
        double finalWidth = containerWidth;
        double finalHeight = containerHeight;
        if (containerHeight > constraints.maxHeight &&
            constraints.maxHeight > 0) {
          finalHeight = constraints.maxHeight;
          finalWidth = finalHeight * widget.aspectRatio;
        }

        return Center(
          child: SizedBox(
            width: finalWidth,
            height: finalHeight,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) =>
                  _handleDrag(details, finalWidth),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Original Image (Right side / Clipped Background)
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _SplitClipper(splitRatio: _splitRatio, clipLeft: false),
                      child: widget.original,
                    ),
                  ),

                  // 2. Processed Image (Left side / Clipped Foreground)
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _SplitClipper(splitRatio: _splitRatio, clipLeft: true),
                      child: widget.processed,
                    ),
                  ),

                  // 3. Slider Divider Line
                  Positioned(
                    left: finalWidth * _splitRatio - 1.5,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 3, color: Colors.white),
                  ),

                  // 4. Slider Handle Button
                  Positioned(
                    left: finalWidth * _splitRatio - 20,
                    top: finalHeight / 2 - 20,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(80),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.unfold_more_rounded,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
