import 'dart:math';
import 'package:flutter/material.dart';

/// Draws cute scattered stars, a crescent moon, and small clouds
class StarFieldPainter extends CustomPainter {
  final double animationValue;

  StarFieldPainter({this.animationValue = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42); // fixed seed for consistent positions

    // Draw crescent moon
    _drawMoon(canvas, size);

    // Draw stars
    for (int i = 0; i < 25; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.6;
      final baseSize = 2.0 + random.nextDouble() * 4.0;
      final twinkle = 0.5 + 0.5 * sin(animationValue * 2 * pi + i * 0.8);
      final starSize = baseSize * twinkle;

      final paint = Paint()
        ..color = const Color(0xFFC9B1FF).withOpacity(0.3 + 0.4 * twinkle)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      _drawStar(canvas, Offset(x, y), starSize, paint);
    }

    // Draw small sparkle dots
    for (int i = 0; i < 15; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final twinkle = 0.3 + 0.7 * sin(animationValue * 2 * pi + i * 1.2);

      final paint = Paint()
        ..color = Colors.white.withOpacity(0.2 + 0.3 * twinkle)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      canvas.drawCircle(Offset(x, y), 1.5 * twinkle, paint);
    }

    // Draw small clouds
    _drawCloud(canvas, Offset(size.width * 0.1, size.height * 0.15), 30);
    _drawCloud(canvas, Offset(size.width * 0.85, size.height * 0.08), 22);
    _drawCloud(canvas, Offset(size.width * 0.6, size.height * 0.2), 18);
  }

  void _drawMoon(Canvas canvas, Size size) {
    final moonCenter = Offset(size.width * 0.82, size.height * 0.08);
    const moonRadius = 22.0;

    // Moon glow
    final glowPaint = Paint()
      ..color = const Color(0xFFFFF176).withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(moonCenter, moonRadius + 10, glowPaint);

    // Moon body
    final moonPaint = Paint()
      ..color = const Color(0xFFFFF9C4).withOpacity(0.6);
    canvas.drawCircle(moonCenter, moonRadius, moonPaint);

    // Crescent cutout
    final cutoutPaint = Paint()
      ..blendMode = BlendMode.dstOut;
    // Use saveLayer for blend mode
    canvas.saveLayer(
      Rect.fromCircle(center: moonCenter, radius: moonRadius + 5),
      Paint(),
    );
    canvas.drawCircle(moonCenter, moonRadius, moonPaint);
    canvas.drawCircle(
      moonCenter + const Offset(8, -4),
      moonRadius * 0.8,
      cutoutPaint,
    );
    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = (i * pi / 2) - pi / 4;
      final outerX = center.dx + cos(angle) * size;
      final outerY = center.dy + sin(angle) * size;
      final innerAngle = angle + pi / 4;
      final innerX = center.dx + cos(innerAngle) * size * 0.35;
      final innerY = center.dy + sin(innerAngle) * size * 0.35;

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawCloud(Canvas canvas, Offset center, double size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawCircle(center, size * 0.5, paint);
    canvas.drawCircle(center + Offset(-size * 0.35, size * 0.1), size * 0.35, paint);
    canvas.drawCircle(center + Offset(size * 0.35, size * 0.1), size * 0.38, paint);
    canvas.drawCircle(center + Offset(size * 0.15, -size * 0.15), size * 0.3, paint);
  }

  @override
  bool shouldRepaint(covariant StarFieldPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Draws a circular dB level gauge with a soft gradient arc
class SoundMeterPainter extends CustomPainter {
  final double level;    // 0.0 to 1.0
  final double maxDb;
  final double currentDb;
  final double glowAnimation;

  SoundMeterPainter({
    required this.level,
    required this.maxDb,
    required this.currentDb,
    this.glowAnimation = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    // Background ring
    final bgPaint = Paint()
      ..color = const Color(0xFFC9B1FF).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi * 0.75,
      pi * 1.5,
      false,
      bgPaint,
    );

    // Gradient arc
    final sweepAngle = pi * 1.5 * level.clamp(0.0, 1.0);

    if (sweepAngle > 0.01) {
      final gradient = SweepGradient(
        startAngle: -pi * 0.75,
        endAngle: pi * 0.75,
        colors: const [
          Color(0xFFB2DFDB), // mint
          Color(0xFFC9B1FF), // lavender
          Color(0xFFFFB6C1), // pink
          Color(0xFFFFB74D), // amber (high)
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      );

      final arcPaint = Paint()
        ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi * 0.75,
        sweepAngle,
        false,
        arcPaint,
      );

      // Glow effect on the arc tip
      final tipAngle = -pi * 0.75 + sweepAngle;
      final tipX = center.dx + cos(tipAngle) * radius;
      final tipY = center.dy + sin(tipAngle) * radius;
      final glowPaint = Paint()
        ..color = const Color(0xFFC9B1FF).withOpacity(0.3 + 0.2 * glowAnimation)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(tipX, tipY), 8, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SoundMeterPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.glowAnimation != glowAnimation;
}
