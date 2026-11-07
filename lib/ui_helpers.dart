import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
}
