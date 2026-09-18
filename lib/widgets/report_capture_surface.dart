import 'package:flutter/material.dart';

/// Paint the platform view outside the visible area without clipping it away.
/// Opacity(0) suppresses platform-view attachment and leaves a 400x300 canvas.
class ReportCaptureSurface extends StatelessWidget {
  const ReportCaptureSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    clipBehavior: Clip.none,
    children: [
      Positioned(
        left: -10000,
        top: -10000,
        // About 150 DPI at the report's usable A4 width (539 PDF points).
        width: 1124,
        height: 594,
        child: IgnorePointer(child: child),
      ),
    ],
  );
}
