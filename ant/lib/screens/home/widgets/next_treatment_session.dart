import '../../../core/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/treatment_service.dart';

class NextTreatmentSession extends StatelessWidget {
  final String heading;
  final String subtitle;
  final bool showViewButton;
  final double horizontalPadding;

  final String? protocolName;
  final String? treatmentType;
  final String? status;
  final int? totalSessions;
  final int? completedSessions;
  final SessionData? nextSession;
  final VoidCallback? onViewPlan;

  const NextTreatmentSession({
    super.key,
    this.heading = 'Next Treatment Session',
    this.subtitle = 'Your upcoming scheduled treatment',
    this.showViewButton = true,
    this.horizontalPadding = 12,
    this.protocolName,
    this.treatmentType,
    this.status,
    this.totalSessions,
    this.completedSessions,
    this.nextSession,
    this.onViewPlan,
  });

  static const _purple = Color(0xFF4361EE);
  static const _purpleLight = Color(0xFF7B61FF);
  static const _purpleBg = Color(0xFFEEEDFE);
  static const _borderColor = Color(0xFFE8EAF3);
  static const _divider = Color(0xFFE9EBF3);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding.w),
      child: Column(
        children: [
          _buildTopHeader(),
          SizedBox(height: 10.h),
          _buildSessionCard(),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Container(
          width: 48.r,
          height: 48.r,
          decoration: BoxDecoration(
            color: _purpleBg,
            borderRadius: BorderRadius.circular(13.r),
          ),
          child: Icon(Icons.calendar_month_rounded, color: _purple, size: 24.r),
        ),
        SizedBox(width: 11.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 15.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  letterSpacing: -0.3.sp,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (showViewButton && onViewPlan != null) ...[
          SizedBox(width: 8.w),
          _buildViewPlanButton(),
        ],
      ],
    );
  }

  Widget _buildViewPlanButton() {
    return GestureDetector(
      onTap: onViewPlan,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _purpleBg,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View Plan',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: _purple,
              ),
            ),
            SizedBox(width: 3.w),
            Icon(Icons.arrow_forward_rounded, size: 13.r, color: _purple),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard() {
    final ns = nextSession;
    if (protocolName == null || protocolName!.trim().isEmpty) {
      return _buildEmptyProtocolCard();
    }

    final pName = protocolName!;
    final tType = treatmentType ?? '';
    final pStatus = status ?? 'PENDING';
    final total = totalSessions ?? 0;
    final completed = completedSessions ?? 0;

    final date = ns == null ? null : DateTime.tryParse(ns.sessionDate);
    const days = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY',
    ];
    const months = [
      '',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final dayName = date == null ? 'NEXT VISIT' : days[date.weekday - 1];
    final dayNum = date == null ? '—' : '${date.day}';
    final monthName = date == null ? 'PENDING' : months[date.month];
    final time = ns == null || ns.sessionTime.isEmpty
        ? 'Not set'
        : ns.formattedTime;
    final duration = ns?.durationMinutes;
    final sessionNum = ns?.sessionNumber;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(13.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFFBFCFF)],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: const Color(0xFFE5E8F6), width: 1.r),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.06),
            blurRadius: 24.r,
            offset: Offset(0, 8.h),
            spreadRadius: -6.r,
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDateCard(dayName, dayNum, monthName),
            SizedBox(width: 12.w),
            Container(width: 1.w, color: _divider),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildTreatmentDetails(
                pName,
                tType,
                pStatus,
                time,
                duration,
                sessionNum,
                total,
                completed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyProtocolCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: _borderColor, width: 1.r),
      ),
      child: Row(
        children: [
          Container(
            width: 48.r,
            height: 48.r,
            decoration: BoxDecoration(
              color: _purpleBg,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(Icons.assignment_outlined, color: _purple, size: 24.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No active treatment protocol',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Your plan will appear after the clinic assigns it.',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.sp,
                    height: 1.35,
                    color: Colors.grey.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(String dayName, String dayNum, String monthName) {
    return Container(
      width: 82.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF0F2FF)],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE0E5FC), width: 1.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8.h),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_purpleLight, _purple],
                ),
              ),
              child: Text(
                dayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.4.sp,
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (dayNum == '—')
                    Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Icon(
                        Icons.event_available_outlined,
                        size: 33.r,
                        color: _purple.withValues(alpha: .65),
                      ),
                    )
                  else
                    Text(
                      dayNum,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 52.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1,
                        letterSpacing: -2.sp,
                      ),
                    ),
                  SizedBox(height: 3.h),
                  Text(
                    monthName,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: _purple,
                      letterSpacing: 1.2.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentDetails(
    String pName,
    String tType,
    String pStatus,
    String time,
    int? duration,
    int? sessionNum,
    int total,
    int completed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                pName,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  letterSpacing: -0.3.sp,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 6.w),
            _buildActivePill(pStatus),
          ],
        ),
        SizedBox(height: 3.h),
        Text(
          tType,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 9.h),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 6.h,
          children: [
            _buildInfoChip(Icons.access_time_rounded, time),
            SizedBox(width: 6.w),
            Container(width: 1.w, height: 14.h, color: _divider),
            SizedBox(width: 6.w),
            _buildInfoChip(
              Icons.timer_rounded,
              duration == null ? '— min' : '$duration min',
            ),
          ],
        ),
        SizedBox(height: 9.h),
        Row(
          children: [
            _buildIconBox(Icons.event_note_rounded),
            SizedBox(width: 6.w),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Session ',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  TextSpan(
                    text: sessionNum == null
                        ? '—'
                        : sessionNum.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: _purple,
                    ),
                  ),
                  TextSpan(
                    text: ' / $total',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        _buildBarProgress(total: total, completed: completed),
        SizedBox(height: 5.h),
        Text(
          '$completed of $total completed',
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 9.sp,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBarProgress({required int total, required int completed}) {
    const int bars = 38;
    final int filledBars = total > 0
        ? (completed / total * bars).round().clamp(0, bars)
        : 0;

    final List<double> heights = [
      14.h,
      19.h,
      13.h,
      21.h,
      17.h,
      11.h,
      19.h,
      15.h,
      23.h,
      17.h,
      13.h,
      21.h,
      15.h,
      19.h,
      11.h,
      17.h,
      23.h,
      13.h,
      19.h,
      15.h,
      21.h,
      17.h,
      11.h,
      19.h,
      15.h,
      23.h,
      13.h,
      17.h,
      21.h,
      15.h,
      19.h,
      13.h,
      21.h,
      17.h,
      11.h,
      19.h,
      15.h,
      23.h,
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(bars, (i) {
        final bool filled = i < filledBars;

        return Expanded(
          child: Container(
            height: heights[i % heights.length],
            margin: EdgeInsets.symmetric(horizontal: 1.1.w),
            decoration: BoxDecoration(
              color: filled ? _purple : const Color(0xFFE3E5EF),
              borderRadius: BorderRadius.circular(3.r),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActivePill(String pStatus) {
    final isActive = pStatus == 'ACTIVE';
    final color = isActive ? const Color(0xFF06D6A0) : Colors.orange;
    final textColor = isActive
        ? const Color(0xFF00A676)
        : Colors.orange.shade800;
    final label = isActive
        ? 'Active'
        : pStatus.isEmpty
        ? 'Pending'
        : pStatus[0] + pStatus.substring(1).toLowerCase();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 5.5.r, color: color),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconBox(icon),
        SizedBox(width: 5.w),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 23.r,
      height: 23.r,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FF),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFFE7EBFF)),
      ),
      child: Icon(icon, size: 13.r, color: _purple),
    );
  }
}
