import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_colors.dart';

enum SessionStatus { completed, current, upcoming }

class ProtocolSession {
  final int number;
  final String title;
  final SessionStatus status;
  final String? statusLabel;
  final DateTime date;
  final String time;
  final int durationMinutes;

  const ProtocolSession({
    required this.number,
    required this.title,
    required this.status,
    this.statusLabel,
    required this.date,
    required this.time,
    this.durationMinutes = 30,
  });
}

class ProtocolTimelineCard extends StatefulWidget {
  final List<ProtocolSession>? sessions;
  const ProtocolTimelineCard({super.key, this.sessions});

  @override
  State<ProtocolTimelineCard> createState() => _ProtocolTimelineCardState();
}

class _ProtocolTimelineCardState extends State<ProtocolTimelineCard> {
  static const _green = Color(0xFF06B78A);
  static const _blue = Color(0xFF4361EE);
  static const _purple = Color(0xFF4361EE);
  static const _pink = Color(0xFF4361EE);
  static const _grey = Color(0xFF646C80);
  static const _border = Color(0xFFE8EAF3);
  static const _weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _monthShort = [
    '',
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
  static const _dayNames = [
    '',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  List<ProtocolSession> get _sessions => widget.sessions ?? [];
  late DateTime _month = DateTime(_today.year, _today.month);
  final DateTime _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  DateTime? _selectedDate;

  int get _doneCount =>
      _sessions.where((s) => s.status == SessionStatus.completed).length;
  int get _total => _sessions.length;

  @override
  void initState() {
    super.initState();
    if (_sessionsOn(_today).isNotEmpty) {
      _selectedDate = _today;
    } else {
      final next = _sessions
          .where(
            (s) =>
                s.status == SessionStatus.current ||
                s.status == SessionStatus.upcoming,
          )
          .toList();
      if (next.isNotEmpty) {
        final d = next.first.date;
        _selectedDate = DateTime(d.year, d.month, d.day);
        _month = DateTime(d.year, d.month);
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<ProtocolSession> _sessionsOn(DateTime d) =>
      _sessions.where((s) => _sameDay(s.date, d)).toList();

  int _monthSessionCount() => _sessions
      .where((s) => s.date.year == _month.year && s.date.month == _month.month)
      .length;

  Set<DateTime> get _sessionDatesInMonth => _sessions
      .where((s) => s.date.year == _month.year && s.date.month == _month.month)
      .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
      .toSet();

  List<DateTime?> _calendarGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final List<DateTime?> days = [];
    for (int i = 0; i < leading; i++) {
      days.add(null);
    }
    for (int i = 1; i <= daysInMonth; i++) {
      days.add(DateTime(_month.year, _month.month, i));
    }
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  Color _color(SessionStatus s) {
    switch (s) {
      case SessionStatus.completed:
        return _green;
      case SessionStatus.current:
        return _blue;
      case SessionStatus.upcoming:
        return _grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDate != null
        ? _sessionsOn(_selectedDate!)
        : <ProtocolSession>[];
    final monthCount = _monthSessionCount();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.08),
            blurRadius: 40,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: _purple.withValues(alpha: 0.05),
            blurRadius: 60,
            offset: const Offset(0, 20),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.r),
        child: Stack(
          children: [
            // Glass gradient blobs
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 140.w,
                height: 140.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_blue.withValues(alpha: 0.07), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 100,
              left: -40,
              child: Container(
                width: 120.w,
                height: 120.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_pink.withValues(alpha: 0.04), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              right: 40,
              child: Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _green.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Frosted glass overlay
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(),
                    _monthNav(monthCount),
                    _calendar(),
                    if (selected.isNotEmpty)
                      _selectedDaySessions(selected)
                    else
                      _emptyState(),
                    SizedBox(height: 14.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────

  Widget _header() {
    return Container(
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _blue.withValues(alpha: 0.04),
            _purple.withValues(alpha: 0.02),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),
      ),
      child: Row(
        children: [
          // Glass icon
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _blue.withValues(alpha: 0.12),
                  _purple.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: _blue.withValues(alpha: 0.08)),
            ),
            child: Icon(Icons.calendar_month_rounded, size: 22.r, color: _blue),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Protocol Timeline',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3.h),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                    children: [
                      TextSpan(
                        text: '$_doneCount',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                      const TextSpan(text: ' of '),
                      TextSpan(
                        text: '$_total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _blue,
                        ),
                      ),
                      const TextSpan(text: ' sessions completed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Glass progress ring
          Container(
            width: 48.w,
            height: 48.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.6),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: _green.withValues(alpha: 0.1),
                  blurRadius: 12,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(48.w, 48.h),
                  painter: _RingPainter(
                    progress: _total > 0 ? _doneCount / _total : 0.0,
                    track: _border.withValues(alpha: 0.5),
                    fill: _green,
                  ),
                ),
                Text(
                  '${_total > 0 ? (_doneCount / _total * 100).round() : 0}%',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Month Navigation ────────────────────────────────────

  Widget _monthNav(int count) {
    final isCurrentMonth =
        _month.year == _today.year && _month.month == _today.month;

    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 6.h, 18.w, 0),
      child: Row(
        children: [
          _navBtn(Icons.chevron_left_rounded, () {
            setState(() {
              _month = DateTime(_month.year, _month.month - 1);
              _selectedDate = null;
            });
          }),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.2,
                  ),
                ),
                if (count > 0) ...[
                  SizedBox(height: 2.h),
                  Text(
                    '$count session${count > 1 ? 's' : ''} this month',
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isCurrentMonth) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _month = DateTime(_today.year, _today.month);
                  _selectedDate = _sessionsOn(_today).isNotEmpty
                      ? _today
                      : null;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _blue.withValues(alpha: 0.10),
                      _purple.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: _blue.withValues(alpha: 0.08)),
                ),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
          ],
          _navBtn(Icons.chevron_right_rounded, () {
            setState(() {
              _month = DateTime(_month.year, _month.month + 1);
              _selectedDate = null;
            });
          }),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34.w,
        height: 34.h,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(11.r),
          border: Border.all(color: _border.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20.r, color: AppColors.textDark),
      ),
    );
  }

  // ─── Calendar Grid ───────────────────────────────────────

  Widget _calendar() {
    final grid = _calendarGrid();
    final dates = _sessionDatesInMonth;

    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 10.h),
      child: Column(
        children: [
          // Weekday headers
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Row(
              children: _weekDays
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          SizedBox(height: 8.h),
          // Days grid
          ...List.generate((grid.length / 7).ceil(), (week) {
            return Padding(
              padding: EdgeInsets.only(bottom: 2.h),
              child: Row(
                children: List.generate(7, (day) {
                  final idx = week * 7 + day;
                  if (idx >= grid.length || grid[idx] == null) {
                    return const Expanded(child: SizedBox());
                  }

                  final date = grid[idx]!;
                  final isToday = _sameDay(date, _today);
                  final isSelected =
                      _selectedDate != null && _sameDay(date, _selectedDate!);
                  final hasSessions = dates.contains(date);
                  final onDate = hasSessions
                      ? _sessionsOn(date)
                      : <ProtocolSession>[];

                  Color? dotColor;
                  if (hasSessions) {
                    if (onDate.any((s) => s.status == SessionStatus.current)) {
                      dotColor = _blue;
                    } else if (onDate.every(
                      (s) => s.status == SessionStatus.completed,
                    )) {
                      dotColor = _green;
                    } else {
                      dotColor = _grey;
                    }
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: hasSessions
                          ? () => setState(() => _selectedDate = date)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 44.h,
                        margin: EdgeInsets.all(1.5.r),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _blue,
                                    _purple.withValues(alpha: 0.9),
                                  ],
                                )
                              : null,
                          color: !isSelected && isToday
                              ? _blue.withValues(alpha: 0.05)
                              : null,
                          borderRadius: BorderRadius.circular(12.r),
                          border: isToday && !isSelected
                              ? Border.all(color: _blue.withValues(alpha: 0.2))
                              : isSelected
                              ? null
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: _blue.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                    spreadRadius: -2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: hasSessions
                                    ? FontWeight.w800
                                    : FontWeight.w400,
                                color: isSelected
                                    ? Colors.white
                                    : hasSessions
                                    ? AppColors.textDark
                                    : AppColors.muted,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            if (hasSessions)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  onDate.length.clamp(0, 3),
                                  (_) => Container(
                                    width: 4.w,
                                    height: 4.h,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 0.5.w,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.white.withValues(alpha: 0.8)
                                          : dotColor,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SizedBox(height: 4.h),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Selected Day Sessions ───────────────────────────────

  Widget _selectedDaySessions(List<ProtocolSession> sessions) {
    final isToday = _sameDay(_selectedDate!, _today);

    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Glass divider
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _border.withValues(alpha: 0.5),
                  _border.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Text(
                isToday
                    ? 'Today'
                    : '${_dayNames[_selectedDate!.weekday]}, ${_monthShort[_selectedDate!.month]} ${_selectedDate!.day}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _blue.withValues(alpha: 0.10),
                      _purple.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${sessions.length} session${sessions.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _blue,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...sessions.map((s) => _sessionCard(s)),
        ],
      ),
    );
  }

  Widget _sessionCard(ProtocolSession s) {
    final color = _color(s.status);
    final isCurrent = s.status == SessionStatus.current;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrent
              ? [_blue.withValues(alpha: 0.04), _purple.withValues(alpha: 0.02)]
              : [
                  Colors.white.withValues(alpha: 0.8),
                  Colors.white.withValues(alpha: 0.5),
                ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isCurrent
              ? _blue.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent
                ? _blue.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Session number
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: color.withValues(alpha: 0.08)),
            ),
            child: Center(
              child: s.status == SessionStatus.completed
                  ? Icon(Icons.check_rounded, size: 18.r, color: color)
                  : Text(
                      '${s.number}'.padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 5.h),
                Row(
                  children: [
                    _infoChip(Icons.access_time_rounded, s.time),
                    SizedBox(width: 8.w),
                    _infoChip(
                      Icons.hourglass_bottom_rounded,
                      '${s.durationMinutes} min',
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Glass status chip
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.12),
                  color.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Text(
              s.statusLabel ??
                  (s.status == SessionStatus.completed
                      ? 'Done'
                      : s.status == SessionStatus.current
                      ? 'Now'
                      : 'Upcoming'),
              style: TextStyle(
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.r, color: AppColors.muted),
          SizedBox(width: 3.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ─────────────────────────────────────────

  Widget _emptyState() {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 4.h, 18.w, 0),
      child: Column(
        children: [
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _border.withValues(alpha: 0.5),
                  _border.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 22.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.6),
                  Colors.white.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 22.r,
                  color: _grey.withValues(alpha: 0.6),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Tap a highlighted date to view sessions',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color fill;
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 3.5;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
