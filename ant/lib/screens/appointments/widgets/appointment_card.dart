import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum AppointmentStatus { confirmed, waiting, checkedIn, inProgress, completed, cancelled, noShow, unknown }

/// View-model for the AppointmentCard. Kept independent of backend DTOs
/// so the widget stays reusable.
class AppointmentCardData {
  final int? id;
  final DateTime dateTime;
  final AppointmentStatus status;
  final String? note;
  final String? location;
  final String? branchCode;

  const AppointmentCardData({
    this.id,
    required this.dateTime,
    this.status = AppointmentStatus.confirmed,
    this.note,
    this.location,
    this.branchCode,
  });
}

class AppointmentCard extends StatefulWidget {
  final AppointmentCardData? appointment;
  final VoidCallback? onReschedule;
  final VoidCallback? onGetDirections;

  const AppointmentCard({
    super.key,
    this.appointment,
    this.onReschedule,
    this.onGetDirections,
  });

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard>
    with SingleTickerProviderStateMixin {
  // ── Theme Colors (match home header) ──────────────────
  static const _primaryBlue = Color(0xFF4361EE);
  static const _primaryPurple = Color(0xFF3A0CA3);
  static const _accentLight = Color(0xFFB8C4FF);
  static const _success = Color(0xFF06B78A);
  static const _warning = Color(0xFFFF9F1C);
  static const _purpleSoft = Color(0xFF7B61FF);
  static const _textPrimary = Color(0xFF1A1D2E);
  static const _textSecondary = Color(0xFF6B7280);
  static const _borderSoft = Color(0xFFEEF1F8);

  AppointmentCardData get _data => widget.appointment ?? AppointmentCardData(dateTime: DateTime.now(), status: AppointmentStatus.unknown);
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(_fadeAnim);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _statusLabel {
    switch (_data.status) {
      case AppointmentStatus.confirmed:
        return 'Confirmed';
      case AppointmentStatus.waiting:
        return 'Pending';
      case AppointmentStatus.inProgress:
        return 'In Session';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.checkedIn:
        return 'Checked In';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.noShow:
        return 'Not Attended';
      case AppointmentStatus.unknown:
        return 'Status Unavailable';
    }
  }

  Color get _statusColor {
    switch (_data.status) {
      case AppointmentStatus.confirmed:
        return _success;
      case AppointmentStatus.waiting:
        return _warning;
      case AppointmentStatus.inProgress:
        return _purpleSoft;
      case AppointmentStatus.checkedIn:
        return _purpleSoft;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.noShow:
      case AppointmentStatus.unknown:
      case AppointmentStatus.completed:
        return _textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _buildCard(),
      ),
    );
  }

  Widget _buildCard() {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    final dayName = days[_data.dateTime.weekday - 1];
    final dayNum = _data.dateTime.day.toString();
    final monthName = months[_data.dateTime.month - 1];
    final year = _data.dateTime.year.toString();

    final hour = _data.dateTime.hour == 0
        ? 12
        : _data.dateTime.hour > 12
            ? _data.dateTime.hour - 12
            : _data.dateTime.hour;
    final amPm = _data.dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = _data.dateTime.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.18),
            blurRadius: 32.r,
            offset: Offset(0, 12.h),
          ),
          BoxShadow(
            color: _primaryPurple.withValues(alpha: 0.1),
            blurRadius: 48.r,
            offset: Offset(0, 24.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.r),
        child: Column(
          children: [
            _buildHeroSection(dayName, dayNum, monthName, year, timeStr, amPm),
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(String dayName, String dayNum, String monthName,
      String year, String timeStr, String amPm) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryBlue, _primaryPurple],
        ),
      ),
      child: Stack(
        children: [
          // Ambient white orbs (matches home header style)
          Positioned(
            top: -50.h,
            right: -40.w,
            child: Container(
              width: 180.r,
              height: 180.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -70.h,
            left: -40.w,
            child: Container(
              width: 200.r,
              height: 200.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _purpleSoft.withValues(alpha: 0.2),
                    _purpleSoft.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 26.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top label row
                Row(
                  children: [
                    Container(
                      width: 32.r,
                      height: 32.r,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        Icons.event_available_rounded,
                        size: 16.r,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      'UPCOMING APPOINTMENT',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                        letterSpacing: 1.4,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(),
                  ],
                ),

                SizedBox(height: 22.h),

                // Date + Time hero block
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      dayNum,
                      style: TextStyle(
                        fontSize: 64.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 0.95,
                        letterSpacing: -2.5,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$monthName · $year',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: _accentLight,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '$dayName · $timeStr $amPm',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(22.w, 18.h, 22.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location row (full width)
          if (_data.location != null) ...[
            _buildLocationTile(_data.location!),
            SizedBox(height: 12.h),
          ],

          // Note section
          if (_data.note != null) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 11.h,
              ),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: _primaryBlue.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15.r,
                    color: _primaryBlue,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      _data.note!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: _textPrimary.withValues(alpha: 0.7),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildSecondaryButton(
                  icon: Icons.calendar_today_outlined,
                  label: 'Reschedule',
                  onTap: widget.onReschedule ?? () {},
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                flex: 2,
                child: _buildPrimaryButton(
                  icon: Icons.directions_outlined,
                  label: 'Get Directions',
                  onTap: widget.onGetDirections ?? () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(String location) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: _borderSoft,
          width: 1.r,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryBlue, _purpleSoft],
              ),
              borderRadius: BorderRadius.circular(11.r),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.25),
                  blurRadius: 8.r,
                  offset: Offset(0, 3.h),
                ),
              ],
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 18.r,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LOCATION',
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  location,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    letterSpacing: -0.2,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13.r,
            color: _textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryBlue, _primaryPurple],
          ),
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withValues(alpha: 0.32),
              blurRadius: 12.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16.r, color: Colors.white),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: _borderSoft,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15.r, color: _textPrimary),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final color = _statusColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeInOut,
            builder: (context, pulseVal, _) {
              return Container(
                width: 6.r,
                height: 6.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6 * pulseVal),
                      blurRadius: 5 * pulseVal,
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(width: 6.w),
          Text(
            _statusLabel,
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
