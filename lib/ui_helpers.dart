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

/// A buttery smooth spinning loading indicator wheel
class SmoothSpinner extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const SmoothSpinner({super.key, this.size = 36.0, this.color, this.strokeWidth = 3.5});

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
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.rotate(
            angle: _controller.value * 2.0 * 3.141592653589793,
            child: CircularProgressIndicator(
              strokeWidth: widget.strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(widget.color ?? Theme.of(context).colorScheme.primary),
            ),
          );
        },
      ),
    );
  }
}
