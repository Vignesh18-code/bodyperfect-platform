import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import '../constants/app_colors.dart';

class AppBackground extends StatefulWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with TickerProviderStateMixin {
  late AnimationController _c1, _c2, _c3;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(duration: const Duration(seconds: 8), vsync: this)..repeat(reverse: true);
    _c2 = AnimationController(duration: const Duration(seconds: 10), vsync: this)..repeat(reverse: true);
    _c3 = AnimationController(duration: const Duration(seconds: 12), vsync: this)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.skyBlueGradient),
      child: Stack(
        children: [
          _circle(_c1, 200.r, top: 100.h, left: -50.w),
          _circle(_c2, 300.r, top: 400.h, right: -100.w),
          _circle(_c3, 150.r, bottom: 150.h, left: 50.w),
          widget.child,
        ],
      ),
    );
  }

  Widget _circle(AnimationController c, double size, {double? top, double? bottom, double? left, double? right}) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        final v = c.value;
        final y = math.sin(v * 2 * math.pi) * 30;
        final x = math.cos(v * 2 * math.pi) * 20;
        final s = 1.0 + (math.sin(v * 2 * math.pi) * 0.1);
        return Positioned(
          top: top != null ? top + y : null,
          bottom: bottom != null ? bottom - y : null,
          left: left != null ? left + x : null,
          right: right != null ? right - x : null,
          child: Transform.scale(
            scale: s,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}