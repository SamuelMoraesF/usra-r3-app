import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact, offline compass for the map overlay.
///
/// The needle rotates with the map, so north always points to the correct side
/// of the screen while the cardinal labels remain readable. The azimuth below
/// it is the current map bearing.
class MapCompass extends StatelessWidget {
  const MapCompass({super.key, required this.bearing, this.onTap});

  final double bearing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final normalizedBearing = normalizeBearing(bearing);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Semantics(
      button: onTap != null,
      label: 'Bússola, azimute ${normalizedBearing.round()} graus',
      child: Material(
        color: colors.surface.withValues(alpha: 0.94),
        elevation: 3,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 88,
                  height: 84,
                  child: CustomPaint(
                    painter: _CompassPainter(
                      bearing: normalizedBearing,
                      colors: colors,
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ),
                Text(
                  '${normalizedBearing.round().toString().padLeft(3, '0')}°',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double normalizeBearing(double bearing) {
  if (!bearing.isFinite) return 0;
  final normalized = bearing % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

class _CompassPainter extends CustomPainter {
  const _CompassPainter({
    required this.bearing,
    required this.colors,
    required this.textDirection,
  });

  final double bearing;
  final ColorScheme colors;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final outline = Paint()
      ..color = colors.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, outline);

    final north = Paint()
      ..color = colors.error
      ..style = PaintingStyle.fill;
    final south = Paint()
      ..color = colors.onSurfaceVariant
      ..style = PaintingStyle.fill;
    // Keep the cardinal labels readable and rotate only the needle. With a
    // map bearing of 90 degrees, north is on the left side of the screen.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-bearing * math.pi / 180);
    final arrowTip = Offset(0, -radius + 4);
    final arrowPath = Path()
      ..moveTo(arrowTip.dx, arrowTip.dy)
      ..lineTo(-5, 2)
      ..lineTo(0, -1)
      ..lineTo(5, 2)
      ..close();
    canvas.drawPath(arrowPath, north);
    canvas.drawLine(Offset.zero, Offset(0, radius - 4), south..strokeWidth = 2);
    canvas.restore();
    canvas.drawCircle(center, 2.5, north);

    _drawLabel(canvas, 'N', Offset(center.dx, 6), colors.error, 12);
    _drawLabel(canvas, '0°', Offset(center.dx, 19), colors.onSurfaceVariant, 8);
    _drawLabel(
      canvas,
      'L',
      Offset(size.width - 8, center.dy - 5),
      colors.onSurface,
      11,
    );
    _drawLabel(
      canvas,
      '90°',
      Offset(size.width - 14, center.dy + 9),
      colors.onSurfaceVariant,
      8,
    );
    _drawLabel(
      canvas,
      'S',
      Offset(center.dx, size.height - 15),
      colors.onSurface,
      11,
    );
    _drawLabel(
      canvas,
      '180°',
      Offset(center.dx, size.height - 3),
      colors.onSurfaceVariant,
      8,
    );
    _drawLabel(canvas, 'O', Offset(8, center.dy - 5), colors.onSurface, 11);
    _drawLabel(
      canvas,
      '270°',
      Offset(14, center.dy + 9),
      colors.onSurfaceVariant,
      8,
    );
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double fontSize,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) =>
      oldDelegate.bearing != bearing ||
      oldDelegate.colors != colors ||
      oldDelegate.textDirection != textDirection;
}
