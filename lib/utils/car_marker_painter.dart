import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A Widget that renders an Uber-style top-down car icon.
/// Use directly as the `child` of a flutter_map `Marker`.
///
/// Example:
/// ```dart
/// Marker(
///   point: driverLatLng,
///   width: 60,
///   height: 60,
///   child: CarMarkerWidget(heading: driverBearing),
/// )
/// ```
class CarMarkerWidget extends StatelessWidget {
  final double heading; // degrees, 0 = north
  final Color color;
  final double size;

  const CarMarkerWidget({
    super.key,
    this.heading = 0,
    this.color = const Color(0xFF1A1A1A),
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * math.pi / 180,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CarPainter(color: color),
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  final Color color;
  const _CarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size s) {
    final double w  = s.width  * 0.36;
    final double h  = s.height * 0.70;
    final double ox = (s.width  - w) / 2;
    final double oy = (s.height - h) / 2;

    // Drop-shadow
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(ox + 4, oy + 8, w, h),
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
        bottomLeft: const Radius.circular(9),
        bottomRight: const Radius.circular(9),
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Car body
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(ox, oy, w, h),
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
        bottomLeft: const Radius.circular(9),
        bottomRight: const Radius.circular(9),
      ),
      Paint()..color = color,
    );

    // Roof / cabin
    final roofColor = Color.lerp(color, Colors.white, 0.18)!;
    final roofW = w * 0.72;
    final roofH = h * 0.36;
    final roofX = ox + (w - roofW) / 2;
    final roofY = oy + h * 0.24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(roofX, roofY, roofW, roofH), const Radius.circular(7)),
      Paint()..color = roofColor,
    );

    // Windshields
    final glassPaint = Paint()..color = const Color(0xFF7EC8E3).withOpacity(0.80);
    final windW = roofW * 0.80;
    final windH = roofH * 0.36;
    final windX = ox + (w - windW) / 2;
    // front
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(windX, roofY - windH + 3, windW, windH),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
        bottomLeft: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      ),
      glassPaint,
    );
    // rear
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(windX, roofY + roofH - 2, windW, windH * 0.88),
        topLeft: const Radius.circular(2),
        topRight: const Radius.circular(2),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      glassPaint,
    );

    // Headlights
    final hlPaint = Paint()..color = const Color(0xFFFFFDE7);
    final hlW = w * 0.20;
    final hlH = s.height * 0.042;
    final hlY = oy + s.height * 0.022;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox + w * 0.07, hlY, hlW, hlH), const Radius.circular(3)), hlPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox + w - w * 0.07 - hlW, hlY, hlW, hlH), const Radius.circular(3)), hlPaint);

    // Tail-lights
    final tlPaint = Paint()..color = const Color(0xFFEF4444);
    final tlY = oy + h - hlH - s.height * 0.022;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox + w * 0.07, tlY, hlW, hlH), const Radius.circular(3)), tlPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(ox + w - w * 0.07 - hlW, tlY, hlW, hlH), const Radius.circular(3)), tlPaint);

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF111111);
    final rimPaint   = Paint()..color = const Color(0xFF555555);
    final double whlW = w * 0.16;
    final double whlH = h * 0.13;
    final double whlOffX = -whlW * 0.45;
    for (final r in [
      Rect.fromLTWH(ox + whlOffX,            oy + h * 0.13, whlW, whlH),
      Rect.fromLTWH(ox + w - whlOffX - whlW, oy + h * 0.13, whlW, whlH),
      Rect.fromLTWH(ox + whlOffX,            oy + h * 0.73, whlW, whlH),
      Rect.fromLTWH(ox + w - whlOffX - whlW, oy + h * 0.73, whlW, whlH),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), wheelPaint);
      canvas.drawOval(Rect.fromCenter(center: r.center, width: r.width * 0.55, height: r.height * 0.55), rimPaint);
    }

    // Gold WEGO accent stripe
    canvas.drawRect(
      Rect.fromLTWH(ox + w * 0.10, oy + h * 0.615, w * 0.80, s.height * 0.016),
      Paint()..color = const Color(0xFFFFDC71),
    );

    // Direction arrow at nose
    final arrowPath = Path()
      ..moveTo(s.width / 2, oy - s.height * 0.025)
      ..lineTo(s.width / 2 - w * 0.16, oy + s.height * 0.018)
      ..lineTo(s.width / 2 + w * 0.16, oy + s.height * 0.018)
      ..close();
    canvas.drawPath(arrowPath, Paint()..color = Colors.white.withOpacity(0.70));
  }

  @override
  bool shouldRepaint(_CarPainter old) => old.color != color;
}
