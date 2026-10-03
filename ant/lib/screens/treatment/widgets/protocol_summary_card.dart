import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';

class ProtocolSummaryCard extends StatelessWidget {
  final String protocolName;
  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final double? goalWeightKg;

  const ProtocolSummaryCard({
    super.key,
    required this.protocolName,
    this.weightKg,
    this.heightCm,
    this.bmi,
    this.goalWeightKg,
  });

  String _formatValue(double? v) {
    if (v == null) return '--';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return _ProtocolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: protocolName,
            subtitle: 'Your measurements and treatment goal',
            icon: Icons.assignment_rounded,
            color: const Color(0xFF4361EE),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _CompactMetricTile(
                  label: 'Weight',
                  value: _formatValue(weightKg),
                  unit: 'kg',
                  color: const Color(0xFF4361EE),
                ),
              ),
              const _MetricGap(),
              Expanded(
                child: _CompactMetricTile(
                  label: 'Height',
                  value: _formatValue(heightCm),
                  unit: 'cm',
                  color: const Color(0xFF4361EE),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _CompactMetricTile(
                  label: 'BMI',
                  value: _formatValue(bmi),
                  unit: '',
                  color: const Color(0xFF4361EE),
                ),
              ),
              const _MetricGap(),
              Expanded(
                child: _CompactMetricTile(
                  label: 'Goal',
                  value: _formatValue(goalWeightKg),
                  unit: 'kg',
                  color: const Color(0xFF4361EE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _CompactMetricTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Adjusted padding to make the inside content fit perfectly without loose empty space
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.08,
        ), // Slightly boosted for better contrast on glass
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1.r),
      ),
      child: Row(
        children: [
          Container(
            width: 28.w,
            height: 28.h,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(_getMetricIcon(label), size: 15.r, color: color),
          ),
          SizedBox(width: 12.w), // Tightened gap inside the box
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment
                  .center, // Centers content vertically to eliminate empty gaps
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.withValues(alpha: 0.9),
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          letterSpacing: -0.3.sp,
                          height: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      SizedBox(width: 2.w),
                      Padding(
                        padding: EdgeInsets.only(bottom: 1.h),
                        child: Text(
                          unit,
                          style: TextStyle(
                            fontSize: 8.5.sp,
                            fontWeight: FontWeight.w900,
                            color: color,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMetricIcon(String label) {
    switch (label) {
      case 'Weight':
        return Icons.monitor_weight_rounded;
      case 'Height':
        return Icons.height_rounded;
      case 'BMI':
        return Icons.analytics_rounded;
      case 'Goal':
        return Icons.flag_rounded;
      default:
        return Icons.favorite_rounded;
    }
  }
}

class _MetricGap extends StatelessWidget {
  const _MetricGap();

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 8.w); // Reduced from 10.w for a tighter, perfect fit
  }
}

class _ProtocolCard extends StatelessWidget {
  final Widget child;

  const _ProtocolCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24.r),
      child: BackdropFilter(
        // 1. Added glassy blur effect
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            // 2. Translucent white for the glass body
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.9,
              ), // Bright white border acts as glass reflection
              width: 1.5.r,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.04,
                ), // Soft shadow for depth
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38.w,
          height: 38.h,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14.r),
          ),
          child: Icon(icon, size: 20.r, color: color),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: -0.3.sp,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.withValues(alpha: 0.78),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
