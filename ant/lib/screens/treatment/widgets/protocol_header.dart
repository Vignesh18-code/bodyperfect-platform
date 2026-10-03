import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';

class ProtocolHeader extends StatelessWidget {
  final String protocolName;
  final String status;

  const ProtocolHeader({
    super.key,
    required this.protocolName,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.5.r,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3FF),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Icon(
                  Icons.medical_services_rounded,
                  size: 24.r,
                  color: const Color(0xFF4361EE),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Treatment Protocol',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.4.sp,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      protocolName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                        letterSpacing: -0.1.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildStatusPill(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill() {
    final isActive = status == 'ACTIVE';
    final color = isActive ? const Color(0xFF00C48C) : Colors.orange;
    final bgColor = isActive
        ? const Color(0xFFE8FBF4).withValues(alpha: 0.8)
        : Colors.orange.withValues(alpha: 0.1);
    final borderColor = isActive
        ? const Color(0xFFD1F4E6)
        : Colors.orange.withValues(alpha: 0.3);
    final textColor = isActive
        ? const Color(0xFF00966D)
        : Colors.orange.shade800;
    final label = status.isEmpty
        ? 'Not specified'
        : status[0] + status.substring(1).toLowerCase();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: borderColor, width: 1.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.r,
            height: 6.r,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: Offset.zero,
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.2.sp,
            ),
          ),
        ],
      ),
    );
  }
}
