import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AppRouteMotion { root, standard, drillIn, modal }

class AppMotion {
  AppMotion._();

  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 260);
  static const emphasized = Duration(milliseconds: 340);

  static const Curve exit = Curves.easeInCubic;
  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve emphasizedCurve = Cubic(0.16, 1, 0.3, 1);
  static const Curve springLike = Cubic(0.2, 1.18, 0.28, 1);

  static Page<T> page<T>(
    BuildContext context,
    GoRouterState state,
    Widget child, {
    AppRouteMotion motion = AppRouteMotion.standard,
  }) {
    if (_reduceMotion(context) || motion == AppRouteMotion.root) {
      return NoTransitionPage<T>(key: state.pageKey, child: child);
    }

    final isCompact = MediaQuery.sizeOf(context).width < 700;
    final duration = switch (motion) {
      AppRouteMotion.modal => emphasized,
      AppRouteMotion.drillIn => standard,
      AppRouteMotion.standard => standard,
      AppRouteMotion.root => Duration.zero,
    };

    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: Duration(
        milliseconds: math.max(140, duration.inMilliseconds - 60),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _transitionFor(
          context: context,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
          motion: motion,
          isCompact: isCompact,
        );
      },
    );
  }

  static Widget shellSwitcher({
    required BuildContext context,
    required int index,
    required Widget child,
  }) {
    if (_reduceMotion(context)) return child;

    return AnimatedSwitcher(
      duration: standard,
      switchInCurve: emphasizedCurve,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(parent: animation, curve: standardCurve);
        final slide = Tween<Offset>(
          begin: const Offset(0.012, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: emphasizedCurve));
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(index), child: child),
    );
  }

  static Widget pressed({required Widget child, Duration duration = fast}) {
    return _PressedScale(duration: duration, child: child);
  }

  static bool _reduceMotion(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    return mq?.disableAnimations == true;
  }

  static Widget _transitionFor({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    required AppRouteMotion motion,
    required bool isCompact,
  }) {
    final curved = CurvedAnimation(parent: animation, curve: emphasizedCurve);
    final fade = CurvedAnimation(parent: animation, curve: standardCurve);

    if (motion == AppRouteMotion.modal) {
      final slide = Tween<Offset>(
        begin: Offset(0, isCompact ? 0.065 : 0.035),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: springLike));
      final scale = Tween<double>(
        begin: isCompact ? 0.992 : 0.985,
        end: 1,
      ).animate(CurvedAnimation(parent: animation, curve: springLike));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    }

    final begin = motion == AppRouteMotion.drillIn
        ? Offset(isCompact ? 0.055 : 0.022, 0)
        : Offset(isCompact ? 0.032 : 0.012, 0);
    final slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(curved);
    final outgoing = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(isCompact ? -0.018 : -0.006, 0),
    ).animate(CurvedAnimation(parent: secondaryAnimation, curve: exit));

    return SlideTransition(
      position: outgoing,
      child: FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      ),
    );
  }
}

class _PressedScale extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const _PressedScale({required this.child, required this.duration});

  @override
  State<_PressedScale> createState() => _PressedScaleState();
}

class _PressedScaleState extends State<_PressedScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return widget.child;
    }

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: widget.duration,
        curve: AppMotion.springLike,
        child: widget.child,
      ),
    );
  }
}
