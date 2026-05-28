import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Generates an Uber-style top-down car [BitmapDescriptor].
/// Call [CarMarkerPainter.create()] once and cache the result.
class CarMarkerPainter {
  CarMarkerPainter._();

  /// Returns a [BitmapDescriptor] of a top-down car.
  ///
  /// [size]     – canvas size in logical pixels (default 96)
  /// [color]    – car body colour (defaults to near-black like Uber)
  /// [rotation] – heading in degrees, 0 = nose pointing up / north
  static Future<BitmapDescriptor> create({
    double size = 96,
    Color color = const Color(0xFF1A1A1A),
    double rotation = 0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size, size),
    );

    _drawCar(canvas, size, color, rotation);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);
  }

  // ─────────────────────────────────────────────────────────────
  static void _drawCar(
      Canvas canvas,
      double s,
      Color bodyColor,
      double rotateDeg,
      ) {
    // ── Rotate the whole scene around the canvas centre ────────
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate(rotateDeg * math.pi / 180);
    canvas.translate(-s / 2, -s / 2);

    // ── Layout constants ───────────────────────────────────────
    final double w  = s * 0.36;   // car body width
    final double h  = s * 0.70;   // car body height (nose→tail)
    final double ox = (s - w) / 2; // left edge of body
    final double oy = (s - h) / 2; // top edge of body

    // ── 1. Drop-shadow ─────────────────────────────────────────
    final shadowPaint = Paint()
      ..color      = Colors.black.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(ox + 4, oy + 8, w, h),
        topLeft:     const Radius.circular(12),
        topRight:    const Radius.circular(12),
        bottomLeft:  const Radius.circular(9),
        bottomRight: const Radius.circular(9),
      ),
      shadowPaint,
    );

    // ── 2. Car body ────────────────────────────────────────────
    final bodyPaint = Paint()..color = bodyColor;
    final bodyRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(ox, oy, w, h),
      topLeft:     const Radius.circular(12),
      topRight:    const Radius.circular(12),
      bottomLeft:  const Radius.circular(9),
      bottomRight: const Radius.circular(9),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    // ── 3. Roof / cabin ────────────────────────────────────────
    final roofColor = Color.lerp(bodyColor, Colors.white, 0.18)!;
    final roofW = w * 0.72;
    final roofH = h * 0.36;
    final roofX = ox + (w - roofW) / 2;
    final roofY = oy + h * 0.24; // sits in the upper-centre of body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(roofX, roofY, roofW, roofH),
        const Radius.circular(7),
      ),
      Paint()..color = roofColor,
    );

    // ── 4. Roof gloss highlight ────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(roofX + roofW * 0.15, roofY + roofH * 0.08,
            roofW * 0.38, roofH * 0.28),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withOpacity(0.20),
    );

    // ── 5. Front windshield ────────────────────────────────────
    final glassPaint = Paint()
      ..color = const Color(0xFF7EC8E3).withOpacity(0.80);
    final windW = roofW * 0.80;
    final windH = roofH * 0.36;
    final windX = ox + (w - windW) / 2;
    final windY = roofY - windH + 3; // just above roof
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(windX, windY, windW, windH),
        topLeft:     const Radius.circular(6),
        topRight:    const Radius.circular(6),
        bottomLeft:  const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      ),
      glassPaint,
    );

    // ── 6. Rear windshield ─────────────────────────────────────
    final rearY = roofY + roofH - 2;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(windX, rearY, windW, windH * 0.88),
        topLeft:     const Radius.circular(2),
        topRight:    const Radius.circular(2),
        bottomLeft:  const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      glassPaint,
    );

    // ── 7. Headlights (front) ──────────────────────────────────
    final hlPaint = Paint()..color = const Color(0xFFFFFDE7);
    final hlW = w * 0.20;
    final hlH = s * 0.042;
    final hlY = oy + s * 0.022;
    // left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + w * 0.07, hlY, hlW, hlH),
        const Radius.circular(3),
      ),
      hlPaint,
    );
    // right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + w - w * 0.07 - hlW, hlY, hlW, hlH),
        const Radius.circular(3),
      ),
      hlPaint,
    );

    // ── 8. Tail-lights (rear) ──────────────────────────────────
    final tlPaint = Paint()..color = const Color(0xFFEF4444);
    final tlY = oy + h - hlH - s * 0.022;
    // left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + w * 0.07, tlY, hlW, hlH),
        const Radius.circular(3),
      ),
      tlPaint,
    );
    // right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(ox + w - w * 0.07 - hlW, tlY, hlW, hlH),
        const Radius.circular(3),
      ),
      tlPaint,
    );

    // ── 9. Wheels ──────────────────────────────────────────────
    // Wheels sit flush with the body edge (no negative offset).
    final wheelPaint     = Paint()..color = const Color(0xFF111111);
    final rimPaint       = Paint()..color = const Color(0xFF555555);
    final double whlW    = w  * 0.16;
    final double whlH    = h  * 0.13;
    final double whlOffX = -whlW * 0.45; // slightly outside body edges

    final List<Rect> wheels = [
      // front-left
      Rect.fromLTWH(ox + whlOffX,             oy + h * 0.13, whlW, whlH),
      // front-right
      Rect.fromLTWH(ox + w - whlOffX - whlW,  oy + h * 0.13, whlW, whlH),
      // rear-left
      Rect.fromLTWH(ox + whlOffX,             oy + h * 0.73, whlW, whlH),
      // rear-right
      Rect.fromLTWH(ox + w - whlOffX - whlW,  oy + h * 0.73, whlW, whlH),
    ];

    for (final r in wheels) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        wheelPaint,
      );
      // rim dot
      canvas.drawOval(
        Rect.fromCenter(
          center: r.center,
          width:  r.width  * 0.55,
          height: r.height * 0.55,
        ),
        rimPaint,
      );
    }

    // ── 10. Gold accent stripe (WEGO branding) ─────────────────
    // Placed at the mid-body, below the roof — not over the glass.
    canvas.drawRect(
      Rect.fromLTWH(
        ox + w * 0.10,
        oy + h * 0.615,   // just below where roof ends
        w  * 0.80,
        s  * 0.016,
      ),
      Paint()..color = const Color(0xFFFFDC71),
    );

    // ── 11. Direction arrow (nose) ─────────────────────────────
    // A small upward-pointing triangle at the very front to
    // communicate heading — just like the Uber driver marker.
    final arrowPaint = Paint()
      ..color = Colors.white.withOpacity(0.70)
      ..style = PaintingStyle.fill;
    final arrowPath = Path();
    final double arrowCX = s / 2;
    final double arrowTip = oy - s * 0.025; // tip above car nose
    final double arrowBase = oy + s * 0.018;
    final double arrowHalfW = w * 0.16;
    arrowPath
      ..moveTo(arrowCX,              arrowTip)
      ..lineTo(arrowCX - arrowHalfW, arrowBase)
      ..lineTo(arrowCX + arrowHalfW, arrowBase)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    canvas.restore();
  }
}