import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/appointment_service.dart';

enum AppointmentSheetStatus { booked, rescheduled, alreadyExists }

class AppointmentSheetResult {
  final AppointmentSheetStatus status;
  final String message;

  const AppointmentSheetResult({required this.status, required this.message});
}

/// Opens a premium glassy modal for booking an appointment.
/// Returns a typed result for success or known user-facing conflicts.
Future<AppointmentSheetResult?> showBookAppointmentSheet(
  BuildContext context, {
  AppointmentData? rescheduleAppointment,
  String? initialNote,
}) {
  return showModalBottomSheet<AppointmentSheetResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _BookAppointmentSheet(
      rescheduleAppointment: rescheduleAppointment,
      initialNote: initialNote,
    ),
  );
}

class _BookAppointmentSheet extends StatefulWidget {
  final AppointmentData? rescheduleAppointment;
  final String? initialNote;

  const _BookAppointmentSheet({this.rescheduleAppointment, this.initialNote});

  @override
  State<_BookAppointmentSheet> createState() => _BookAppointmentSheetState();
}

class _BookAppointmentSheetState extends State<_BookAppointmentSheet> {
  // ── Theme (matches home/appointment theme) ────────────
  static const _primaryBlue = Color(0xFF4361EE);
  static const _primaryPurple = Color(0xFF3A0CA3);
  static const _purpleSoft = Color(0xFF7B61FF);
  static const _textPrimary = Color(0xFF1A1D2E);
  static const _textSecondary = Color(0xFF6B7280);
  static const _borderSoft = Color(0xFFE6EAF5);
  static const _surfaceSoft = Color(0xFFF8FAFD);
  static const _error = Color(0xFFE74C3C);

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedBranch; // 'BURJUMAN' or 'MARINA'
  final TextEditingController _noteController = TextEditingController();

  bool _submitting = false;
  String? _errorText;

  bool get _isReschedule => widget.rescheduleAppointment != null;

  @override
  void initState() {
    super.initState();
    final appointment = widget.rescheduleAppointment;
    if (appointment == null) {
      _noteController.text = widget.initialNote ?? '';
      return;
    }

    _selectedDate = DateTime.tryParse(appointment.appointmentDate);
    _selectedTime = _parseTimeOfDay(appointment.appointmentTime);
    _selectedBranch = appointment.branch.toUpperCase();
    if (appointment.note != null) {
      _noteController.text = appointment.note!;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primaryBlue,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (result != null) {
      setState(() => _selectedDate = result);
    }
  }

  Future<void> _pickTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primaryBlue,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: _textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (result != null) {
      setState(() => _selectedTime = result);
    }
  }

  Future<void> _submit() async {
    if (_selectedDate == null) {
      setState(() => _errorText = 'Please select a date');
      return;
    }
    if (_selectedTime == null) {
      setState(() => _errorText = 'Please select a time');
      return;
    }
    if (_selectedBranch == null) {
      setState(() => _errorText = 'Please select a branch');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final dateStr =
        '${_selectedDate!.year.toString().padLeft(4, '0')}-'
        '${_selectedDate!.month.toString().padLeft(2, '0')}-'
        '${_selectedDate!.day.toString().padLeft(2, '0')}';

    final timeStr =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}:00';

    final result = _isReschedule
        ? await AppointmentService.rescheduleAppointment(
            id: widget.rescheduleAppointment!.id,
            date: dateStr,
            time: timeStr,
            branch: _selectedBranch!,
            note: _noteController.text.trim(),
          )
        : await AppointmentService.bookAppointment(
            date: dateStr,
            time: timeStr,
            branch: _selectedBranch!,
            note: _noteController.text.trim(),
          );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (result.success) {
      Navigator.pop(
        context,
        AppointmentSheetResult(
          status: _isReschedule
              ? AppointmentSheetStatus.rescheduled
              : AppointmentSheetStatus.booked,
          message: result.message,
        ),
      );
    } else {
      if (_isActiveAppointmentConflict(result.message)) {
        Navigator.pop(
          context,
          AppointmentSheetResult(
            status: AppointmentSheetStatus.alreadyExists,
            message: result.message,
          ),
        );
        return;
      }
      setState(() => _errorText = result.message);
    }
  }

  bool _isActiveAppointmentConflict(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('already have an active appointment') ||
        normalized.contains('already have appointment') ||
        normalized.contains('active appointment exists');
  }

  TimeOfDay? _parseTimeOfDay(String raw) {
    try {
      final parts = raw.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32.r),
              topRight: Radius.circular(32.r),
            ),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withValues(alpha: 0.18),
                blurRadius: 40.r,
                offset: Offset(0, -8.h),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32.r),
              topRight: Radius.circular(32.r),
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Stack(
                children: [
                  // Ambient orbs
                  Positioned(
                    top: -60.h,
                    right: -40.w,
                    child: Container(
                      width: 200.r,
                      height: 200.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _purpleSoft.withValues(alpha: 0.12),
                            _purpleSoft.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50.h,
                    left: -40.w,
                    child: Container(
                      width: 180.r,
                      height: 180.r,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _primaryBlue.withValues(alpha: 0.1),
                            _primaryBlue.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          margin: EdgeInsets.only(top: 12.h),
                          width: 44.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: _borderSoft,
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 18.h),

                      // Header
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22.w),
                        child: Row(
                          children: [
                            Container(
                              width: 44.r,
                              height: 44.r,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_primaryBlue, _primaryPurple],
                                ),
                                borderRadius: BorderRadius.circular(14.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primaryBlue.withValues(alpha: 0.3),
                                    blurRadius: 10.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white,
                                size: 22.r,
                              ),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isReschedule
                                        ? 'Reschedule Appointment'
                                        : 'Book Appointment',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w800,
                                      color: _textPrimary,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    _isReschedule
                                        ? 'Choose a new date, time and branch'
                                        : 'Pick your preferred date, time and branch',
                                    style: TextStyle(
                                      fontSize: 11.5.sp,
                                      fontWeight: FontWeight.w500,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 32.r,
                                height: 32.r,
                                decoration: BoxDecoration(
                                  color: _surfaceSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18.r,
                                  color: _textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 22.h),

                      // Date + Time picker tiles
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22.w),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildPickerTile(
                                icon: Icons.event_rounded,
                                label: 'Date',
                                value: _selectedDate == null
                                    ? 'Select date'
                                    : _formatDate(_selectedDate!),
                                hasValue: _selectedDate != null,
                                onTap: _pickDate,
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: _buildPickerTile(
                                icon: Icons.access_time_rounded,
                                label: 'Time',
                                value: _selectedTime == null
                                    ? 'Select time'
                                    : _formatTime(_selectedTime!),
                                hasValue: _selectedTime != null,
                                onTap: _pickTime,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 18.h),

                      // Branch selector
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SELECT BRANCH',
                              style: TextStyle(
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w700,
                                color: _textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildBranchCard(
                                    code: 'BURJUMAN',
                                    label: 'BurJuman',
                                    subtitle: 'Downtown Dubai',
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: _buildBranchCard(
                                    code: 'MARINA',
                                    label: 'Marina',
                                    subtitle: 'Dubai Marina',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 18.h),

                      // Optional note
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NOTE (OPTIONAL)',
                              style: TextStyle(
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w700,
                                color: _textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              decoration: BoxDecoration(
                                color: _surfaceSoft,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: _borderSoft,
                                  width: 1.r,
                                ),
                              ),
                              child: TextField(
                                controller: _noteController,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: _textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Anything we should know?',
                                  hintStyle: TextStyle(
                                    fontSize: 13.sp,
                                    color: _textSecondary.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 12.h,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Error
                      if (_errorText != null) ...[
                        SizedBox(height: 12.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 22.w),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: _error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: _error.withValues(alpha: 0.2),
                                width: 1.r,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 16.r,
                                  color: _error,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    _errorText!,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: _error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      SizedBox(height: 22.h),

                      // Submit button
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22.w),
                        child: _buildSubmitButton(),
                      ),

                      SizedBox(height: 28.h),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required String value,
    required bool hasValue,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
        decoration: BoxDecoration(
          color: hasValue ? Colors.white : _surfaceSoft,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: hasValue ? _primaryBlue.withValues(alpha: 0.4) : _borderSoft,
            width: hasValue ? 1.5.r : 1.r,
          ),
          boxShadow: hasValue
              ? [
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.08),
                    blurRadius: 10.r,
                    offset: Offset(0, 3.h),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                gradient: hasValue
                    ? const LinearGradient(colors: [_primaryBlue, _purpleSoft])
                    : null,
                color: hasValue ? null : _borderSoft.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(
                icon,
                size: 18.r,
                color: hasValue ? Colors.white : _textSecondary,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w700,
                      color: _textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: hasValue ? _textPrimary : _textSecondary,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchCard({
    required String code,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _selectedBranch == code;

    return GestureDetector(
      onTap: () => setState(() => _selectedBranch = code),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_primaryBlue, _primaryPurple],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? Colors.transparent : _borderSoft,
            width: 1.r,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.28),
                    blurRadius: 14.r,
                    offset: Offset(0, 5.h),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 32.r,
                  height: 32.r,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.22)
                        : _surfaceSoft,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 17.r,
                    color: isSelected ? Colors.white : _primaryBlue,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 20.r,
                    height: 20.r,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 14.r,
                      color: _primaryBlue,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : _textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : _textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryBlue, _primaryPurple],
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withValues(alpha: 0.35),
              blurRadius: 14.r,
              offset: Offset(0, 5.h),
            ),
          ],
        ),
        child: Center(
          child: _submitting
              ? SizedBox(
                  width: 22.r,
                  height: 22.r,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 18.r,
                      color: Colors.white,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _isReschedule
                          ? 'Confirm Reschedule'
                          : 'Confirm Appointment',
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}, ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final amPm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }
}
