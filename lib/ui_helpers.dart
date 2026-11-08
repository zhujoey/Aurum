import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';

class UIHelpers {
  /// Navigates to a page with a buttery smooth fade and slide transition.
  static Future<T?> smoothPush<T>(BuildContext context, Widget page, {Duration duration = const Duration(milliseconds: 350)}) {
    HapticFeedback.lightImpact();
    return Navigator.push<T>(
      context,
      PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.04);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: SlideTransition(
              position: animation.drive(slideTween),
              child: child,
            ),
          );
        },
        transitionDuration: duration,
        reverseTransitionDuration: duration,
      ),
    );
  }

  /// Navigates and replaces current route with a smooth transition.
  static Future<T?> smoothPushReplacement<T, TO>(BuildContext context, Widget page, {Duration duration = const Duration(milliseconds: 350)}) {
    HapticFeedback.lightImpact();
    return Navigator.pushReplacement<T, TO>(
      context,
      PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.04);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: SlideTransition(
              position: animation.drive(slideTween),
              child: child,
            ),
          );
        },
        transitionDuration: duration,
        reverseTransitionDuration: duration,
      ),
    );
  }

  /// Triggers light haptic feedback on tap / action.
  static void hapticTap() {
    HapticFeedback.lightImpact();
  }

  /// Triggers medium haptic feedback on scoring / confirmation.
  static void hapticScore() {
    HapticFeedback.mediumImpact();
  }

  /// Crisp selection tick (like tab switches)
  static void hapticTick() {
    HapticFeedback.selectionClick();
  }

  /// Double pulse haptic for active session recording / confirmations
  static void hapticDoublePulse() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    HapticFeedback.mediumImpact();
  }

  /// Returns a dedicated custom or Material icon widget for any sport name.
  static Widget getSportIconWidget(String sport, {double size = 24.0, Color? color}) {
    final s = sport.toLowerCase();
    if (s.contains('badminton')) {
      return BadmintonIcon(size: size, color: color ?? Colors.green);
    } else if (s.contains('pickleball')) {
      return PickleballIcon(size: size, color: color ?? Colors.purple);
    } else if (s.contains('tennis')) {
      return Icon(Icons.sports_tennis, size: size, color: color ?? Colors.orange);
    } else if (s.contains('table')) {
      return Icon(Icons.sports_tennis, size: size, color: color ?? Colors.blue);
    }
    return Icon(Icons.sports, size: size, color: color);
  }
}

/// A card with spring physics scale animation (Stiffness: 300, Damping: 24, Mass: 0.8)
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const PressableCard({super.key, required this.child, required this.onTap});

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    )..value = 0.0;
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    const spring = SpringDescription(
      mass: 0.8,
      stiffness: 300.0,
      damping: 24.0,
    );
    final simulation = SpringSimulation(spring, _controller.value, target, 0.0);
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animateTo(1.0),
      onTapUp: (_) {
        _animateTo(0.0);
        widget.onTap();
      },
      onTapCancel: () => _animateTo(0.0),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class MagnifyingGlassSvgPainter extends CustomPainter {
  final Color color;

  const MagnifyingGlassSvgPainter({this.color = const Color(0xFF10B981)});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.scale(scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: const Offset(50, 50), radius: 35);
    canvas.drawArc(rect, 0.4, 5.0, false, paint);
  }

  @override
  bool shouldRepaint(covariant MagnifyingGlassSvgPainter oldDelegate) => oldDelegate.color != color;
}

/// A buttery smooth spinning loader wheel matching the SVG/CSS animation
class SmoothSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  final bool useLogo;

  const SmoothSpinner({super.key, this.size = 64.0, this.color, this.useLogo = false});

  @override
  State<SmoothSpinner> createState() => _SmoothSpinnerState();
}

class _SmoothSpinnerState extends State<SmoothSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spinnerColor = widget.color ?? const Color(0xFF10B981);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget spinnerChild = widget.useLogo
        ? Image.asset(
            isDark ? 'assets/logo_dark.png' : 'assets/logo_light.png',
            width: widget.size,
            height: widget.size,
          )
        : CustomPaint(
            size: Size(widget.size, widget.size),
            painter: MagnifyingGlassSvgPainter(color: spinnerColor),
          );

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns: _controller,
        child: spinnerChild,
      ),
    );
  }
}

/// Custom Badminton Birdie / Shuttlecock Icon matching user SVG
class BadmintonIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const BadmintonIcon({super.key, this.size = 24.0, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: BadmintonBirdiePainter(color: color),
    );
  }
}

class BadmintonBirdiePainter extends CustomPainter {
  final Color? color;

  const BadmintonBirdiePainter({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 32.0;
    canvas.save();
    canvas.scale(scale);

    // Transform: rotate 40 degrees around (16, 16)
    canvas.translate(16, 16);
    canvas.rotate(40 * 3.141592653589793 / 180.0);
    canvas.translate(-16, -16);

    // 1. Feather Skirt
    final skirtPaint = Paint()
      ..color = color ?? const Color(0xFF4ADE80)
      ..style = PaintingStyle.fill;

    final skirtPath = Path()
      ..moveTo(6, 8)
      ..quadraticBezierTo(16, 2, 26, 8)
      ..lineTo(19.5, 20)
      ..lineTo(12.5, 20)
      ..close();

    canvas.drawPath(skirtPath, skirtPaint);

    // Rib lines (veins/cutouts)
    final ribPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(12, 5.5), const Offset(14, 20), ribPaint);
    canvas.drawLine(const Offset(16, 4), const Offset(16, 20), ribPaint);
    canvas.drawLine(const Offset(20, 5.5), const Offset(18, 20), ribPaint);

    // 2. Cork Base
    final corkPaint = Paint()
      ..color = color != null ? color!.withValues(alpha: 0.85) : const Color(0xFFBBF7D0)
      ..style = PaintingStyle.fill;

    final corkPath = Path()
      ..moveTo(12.5, 22)
      ..lineTo(19.5, 22)
      ..lineTo(19.5, 23.5)
      ..arcToPoint(
        const Offset(12.5, 23.5),
        radius: const Radius.circular(3.5),
        clockwise: true,
      )
      ..close();
    canvas.drawPath(corkPath, corkPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BadmintonBirdiePainter oldDelegate) => oldDelegate.color != color;
}

/// Custom Pickleball Paddle & Perforated Ball Icon matching user SVG
class PickleballIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const PickleballIcon({super.key, this.size = 24.0, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: PickleballPainter(color: color),
    );
  }
}

class PickleballPainter extends CustomPainter {
  final Color? color;

  const PickleballPainter({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 32.0;
    canvas.save();
    canvas.scale(scale);

    final holePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // 1. Paddle (rotate 45deg, scale 0.95 around 16,16)
    canvas.save();
    canvas.translate(16, 16);
    canvas.rotate(45 * 3.141592653589793 / 180.0);
    canvas.scale(0.95);
    canvas.translate(-16, -16);

    final paddlePaint = Paint()
      ..color = color ?? const Color(0xFFA855F7)
      ..style = PaintingStyle.fill;

    final handlePaint = Paint()
      ..color = color != null ? color!.withValues(alpha: 0.8) : const Color(0xFFC084FC)
      ..style = PaintingStyle.fill;

    // Paddle Head
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(7, 3, 16, 17), const Radius.circular(7)),
      paddlePaint,
    );

    // Paddle Holes
    canvas.drawCircle(const Offset(12, 8.5), 1.2, holePaint);
    canvas.drawCircle(const Offset(18, 8.5), 1.2, holePaint);
    canvas.drawCircle(const Offset(15, 12), 1.2, holePaint);
    canvas.drawCircle(const Offset(11.5, 14.5), 1.2, holePaint);
    canvas.drawCircle(const Offset(18.5, 14.5), 1.2, holePaint);

    // Paddle Handle
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(13, 20.5, 4, 7), const Radius.circular(2)),
      handlePaint,
    );
    canvas.restore();

    // 2. Perforated Ball
    final ballPaint = Paint()
      ..color = color != null ? color!.withValues(alpha: 0.9) : const Color(0xFFE9D5FF)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(25, 25.5), 4.6, ballPaint);

    // Ball Holes
    canvas.drawCircle(const Offset(23.8, 24.2), 0.9, holePaint);
    canvas.drawCircle(const Offset(26.2, 24.8), 0.9, holePaint);
    canvas.drawCircle(const Offset(24.8, 27), 0.9, holePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PickleballPainter oldDelegate) => oldDelegate.color != color;
}
