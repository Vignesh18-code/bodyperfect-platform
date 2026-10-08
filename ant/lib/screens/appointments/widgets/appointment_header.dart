import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import 'appointment_card.dart';

/// Match the expanded home header: 50px profile row, 16px gap and search row,
/// with the same top/bottom inset and curve. Grow for accessibility text sizes.
class AppointmentHeader extends StatelessWidget {
  final AppointmentCardData? appointment;
  const AppointmentHeader({super.key, this.appointment});
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: top + 48.h + 50.r + 50.2),
      padding: EdgeInsets.only(top: top + 16.h, bottom: 16.h),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      ),
      child: appointment != null
          ? AppointmentCard(appointment: appointment, headerOnly: true)
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Appointments',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 21.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.55,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Plan your next clinic visit',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 13.sp,
                      color: Colors.white.withValues(alpha: .85),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
