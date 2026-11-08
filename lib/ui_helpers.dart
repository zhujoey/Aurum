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

/// Custom Badminton Birdie / Shuttlecock Icon
class BadmintonIcon extends StatelessWidget {
  final double size;
  final Color color;

  const BadmintonIcon({super.key, this.size = 24.0, this.color = Colors.green});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: BadmintonBirdiePainter(color: color),
    );
  }
}

class BadmintonBirdiePainter extends CustomPainter {
  final Color color;

  const BadmintonBirdiePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width * 0.5;
    final w = size.width;
    final h = size.height;

    // 1. Rounded cork base at bottom
    final corkRect = Rect.fromCircle(center: Offset(cx, h * 0.80), radius: w * 0.12);
    canvas.drawArc(corkRect, 0, 3.14159, false, fillPaint);

    // 2. Flared feather cone outline
    final conePath = Path()
      ..moveTo(cx - w * 0.12, h * 0.80)
      ..lineTo(w * 0.15, h * 0.20)
      ..quadraticBezierTo(cx, h * 0.14, w * 0.85, h * 0.20)
      ..lineTo(cx + w * 0.12, h * 0.80);
    canvas.drawPath(conePath, strokePaint);

    // 3. Vertical feather veins
    canvas.drawLine(Offset(cx - w * 0.04, h * 0.80), Offset(w * 0.38, h * 0.18), strokePaint);
    canvas.drawLine(Offset(cx, h * 0.80), Offset(cx, h * 0.16), strokePaint);
    canvas.drawLine(Offset(cx + w * 0.04, h * 0.80), Offset(w * 0.62, h * 0.18), strokePaint);

    // 4. Horizontal feather band
    final band1 = Path()
      ..moveTo(w * 0.24, h * 0.45)
      ..quadraticBezierTo(cx, h * 0.40, w * 0.76, h * 0.45);
    canvas.drawPath(band1, strokePaint);
  }

  @override
  bool shouldRepaint(covariant BadmintonBirdiePainter oldDelegate) => oldDelegate.color != color;
}

/// Custom Pickleball Paddle & Perforated Ball Icon
class PickleballIcon extends StatelessWidget {
  final double size;
  final Color color;

  const PickleballIcon({super.key, this.size = 24.0, this.color = Colors.purple});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: PickleballPainter(color: color),
    );
  }
}

class PickleballPainter extends CustomPainter {
  final Color color;

  const PickleballPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // 1. Pickleball Paddle Face (rounded rectangle)
    final paddleRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.10, h * 0.15, w * 0.62, h * 0.65),
      Radius.circular(w * 0.16),
    );
    canvas.drawRRect(paddleRect, strokePaint);

    // Paddle Handle
    final handlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.36, h * 0.65), Offset(w * 0.24, h * 0.90), handlePaint);

    // 2. Perforated Pickleball
    final ballCenter = Offset(w * 0.76, h * 0.38);
    final ballRadius = w * 0.20;
    canvas.drawCircle(ballCenter, ballRadius, strokePaint);

    // Holes inside the pickleball
    final holeRadius = w * 0.035;
    canvas.drawCircle(ballCenter, holeRadius, fillPaint);
    canvas.drawCircle(Offset(w * 0.76 - w * 0.09, h * 0.38 - w * 0.07), holeRadius * 0.8, fillPaint);
    canvas.drawCircle(Offset(w * 0.76 + w * 0.09, h * 0.38 - w * 0.07), holeRadius * 0.8, fillPaint);
    canvas.drawCircle(Offset(w * 0.76 - w * 0.09, h * 0.38 + w * 0.07), holeRadius * 0.8, fillPaint);
    canvas.drawCircle(Offset(w * 0.76 + w * 0.09, h * 0.38 + w * 0.07), holeRadius * 0.8, fillPaint);
  }

  @override
  bool shouldRepaint(covariant PickleballPainter oldDelegate) => oldDelegate.color != color;
}
