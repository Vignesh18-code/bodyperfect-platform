import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

/// Uses the home header's exact brand gradient, inset and bottom curve.
class AppointmentHeader extends StatelessWidget {
  const AppointmentHeader({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(
      20.w,
      MediaQuery.paddingOf(context).top + 16.h,
      20.w,
      24.h,
    ),
    decoration: BoxDecoration(
      gradient: AppColors.brandGradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR CARE, PLANNED',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.6,
                  color: Colors.white.withValues(alpha: .75),
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                'Appointments',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 25.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.65,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Your next step to feeling your best.',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 12.sp,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: .85),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 14.w),
        ExcludeSemantics(
          child: Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: Colors.white.withValues(alpha: .2)),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: Colors.white,
              size: 23.r,
            ),
          ),
        ),
      ],
    ),
  );
}
