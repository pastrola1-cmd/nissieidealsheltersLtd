import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Extension on [BuildContext] to safely pop the current route or navigate
/// to a fallback route if no previous routes exist on the navigator stack.
extension SafeNavigationExtension on BuildContext {
  void popOrGo([String fallbackRoute = '/']) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackRoute);
    }
  }
}

/// A wrapper widget that intercepts system back presses (and swipe-back gestures)
/// on inner/detail pages so the user is never stuck and the app does not unexpectedly exit.
///
/// If [canPop()] is true, it pops the navigator stack.
/// If [canPop()] is false (e.g., opened via deep-link or direct URL), it navigates
/// smoothly to [fallbackRoute] (defaults to '/').
class SafeBackScope extends StatelessWidget {
  final Widget child;
  final String fallbackRoute;
  final VoidCallback? onBack;

  const SafeBackScope({
    super.key,
    required this.child,
    this.fallbackRoute = '/',
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (onBack != null) {
          onBack!();
          return;
        }
        context.popOrGo(fallbackRoute);
      },
      child: child,
    );
  }
}

/// A wrapper widget for root screens or multi-tab shells that requires
/// a double-tap within 2 seconds to exit the application.
///
/// If [onIntercept] returns true (e.g., when switching from a sub-tab back
/// to the home tab), exit is canceled and the tab switch occurs instead.
class DoubleBackExitScope extends StatefulWidget {
  final Widget child;
  final bool Function()? onIntercept;
  final String exitMessage;

  const DoubleBackExitScope({
    super.key,
    required this.child,
    this.onIntercept,
    this.exitMessage = 'Press back again to exit',
  });

  @override
  State<DoubleBackExitScope> createState() => _DoubleBackExitScopeState();
}

class _DoubleBackExitScopeState extends State<DoubleBackExitScope> {
  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If the screen or shell intercepts the back press (e.g. going back to tab 0)
        if (widget.onIntercept != null && widget.onIntercept!()) {
          return;
        }

        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.exitMessage,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          // Double pressed within 2 seconds -> cleanly exit the app
          SystemNavigator.pop();
        }
      },
      child: widget.child,
    );
  }
}
