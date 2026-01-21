import 'dart:math';
import 'package:flutter/material.dart';
import '../config/app_theme.dart';

enum AtmosphereType {
  none,
  rain,     // For Rain sounds
  fireflies,// For Forest sounds
  breath,   // For Ocean sounds (Breathing guide)
  deep      // For Piano sounds (Darker gradient)
}

class CompassionateBackground extends StatefulWidget {
  final AtmosphereType type;
  final Widget child;

  const CompassionateBackground({
    super.key,
    required this.type,
    required this.child,
  });

  @override
  State<CompassionateBackground> createState() => _CompassionateBackgroundState();
}

class _CompassionateBackgroundState extends State<CompassionateBackground> with TickerProviderStateMixin {
  late AnimationController _rainController;
  late AnimationController _fireflyController;
  late AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _rainController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    _fireflyController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _breathController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rainController.dispose();
    _fireflyController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _getGradientColors(),
            ),
          ),
        ),

        // Animation Layer
        if (widget.type == AtmosphereType.rain)
          AnimatedBuilder(
            animation: _rainController,
            builder: (context, child) => CustomPaint(
              painter: RainPainter(_rainController.value),
              size: Size.infinite,
            ),
          ),

        if (widget.type == AtmosphereType.fireflies)
          AnimatedBuilder(
            animation: _fireflyController,
            builder: (context, child) => CustomPaint(
              painter: FireflyPainter(_fireflyController.value),
              size: Size.infinite,
            ),
          ),

        if (widget.type == AtmosphereType.breath)
          Center(
            child: AnimatedBuilder(
              animation: _breathController,
              builder: (context, child) {
                return Container(
                  width: 200 + (_breathController.value * 50),
                  height: 200 + (_breathController.value * 50),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05 + (_breathController.value * 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 30 + (_breathController.value * 20),
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Content
        widget.child,
      ],
    );
  }

  List<Color> _getGradientColors() {
    switch (widget.type) {
      case AtmosphereType.rain:
        return [const Color(0xFF2C3E50), const Color(0xFF3498DB).withOpacity(0.3)];
      case AtmosphereType.fireflies:
        return [const Color(0xFF1B2631), const Color(0xFF145A32).withOpacity(0.4)];
      case AtmosphereType.breath:
        return [const Color(0xFF2E86C1), const Color(0xFFAED6F1).withOpacity(0.5)];
      case AtmosphereType.deep:
        return [const Color(0xFF17202A), const Color(0xFF512E5F).withOpacity(0.4)];
      default:
        return [AppTheme.sandBeige, AppTheme.warmCream];
    }
  }
}

class RainPainter extends CustomPainter {
  final double animationValue;
  final Random _random = Random(42); // Fixed seed for consistent drops

  RainPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 80; i++) { // 80 raindrops
      final x = _random.nextDouble() * size.width;
      final startY = _random.nextDouble() * size.height;
      final speed = 10 + _random.nextDouble() * 20;
      
      // Move rain down
      double y = (startY + (animationValue * size.height * 2) * (speed / 20)) % size.height;
      
      canvas.drawLine(Offset(x, y), Offset(x, y + 10), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FireflyPainter extends CustomPainter {
  final double animationValue;
  final Random _random = Random(123);

  FireflyPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 30; i++) {
      final baseX = _random.nextDouble() * size.width;
      final baseY = _random.nextDouble() * size.height;
      
      // Gentle floating movement
      final x = baseX + sin(animationValue * 2 * pi + i) * 20;
      final y = baseY + cos(animationValue * 2 * pi + i) * 20;
      
      // Pulsing opacity
      final opacity = 0.3 + 0.4 * sin(animationValue * 4 * pi + i);
      
      final paint = Paint()
        ..color = Colors.amber.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 2.0, paint);
      
      // Glow
      final glowPaint = Paint()
        ..color = Colors.amber.withOpacity(opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        
      canvas.drawCircle(Offset(x, y), 6.0, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
