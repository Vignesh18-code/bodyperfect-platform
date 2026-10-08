import '../../services/report_service.dart';
import 'widgets/reports_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../services/appointment_service.dart';
import '../../config/clinic_contact_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'widgets/visit_guide.dart';
import '../../services/external_link_service.dart';
import '../../widgets/top_notification_toast.dart';
import 'widgets/appointment_card.dart';
import 'widgets/book_appointment_sheet.dart';

class AppointmentsScreen extends StatefulWidget {
  final VoidCallback? onContactClinic;
  final bool active;
  final Future<List<PatientReport>> Function()? fetchReports;
  final Future<List<AppointmentData>> Function()? fetch;
  const AppointmentsScreen({
    super.key,
    this.onContactClinic,
    this.active = true,
    this.fetch,
    this.fetchReports,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  // ── Theme ─────────────────────────────────────────
  static const _primaryBlue = Color(0xFF4361EE);
  static const _primaryPurple = Color(0xFF3A0CA3);
  static const _textPrimary = Color(0xFF1A1D2E);
  static const _textSecondary = Color(0xFF6B7280);
  static const _borderSoft = Color(0xFFEEF1F8);
  static const _surfaceSoft = Color(0xFFF8FAFD);

  AppointmentCardData? _activeAppointment;
  AppointmentData? _activeAppointmentData;
  bool _loading = true;
  bool _calling = false;
  String? _loadError;
  List<AppointmentData> _history = [];
  List<PatientReport> _reports = [];
  bool _reportError = false;
  int _reportRequest = 0;

  Future<void> _refresh() async {
    await Future.wait([_loadAppointment(), _loadReports()]);
  }

  Future<void> _loadReports() async {
    final request = ++_reportRequest;
    try {
      final reports = await (widget.fetchReports ?? ReportService.list)();
      if (mounted && request == _reportRequest) {
        setState(() {
          _reports = reports;
          _reportError = false;
        });
      }
    } catch (_) {
      if (mounted && request == _reportRequest) {
        setState(() {
          _reports = [];
          _reportError = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant AppointmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _refresh();
  }

  Future<List<AppointmentData>> _fetch() =>
      (widget.fetch ?? AppointmentService.getMyAppointments)();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _loadAppointment() async {
    setState(() => _loading = true);

    List<AppointmentData> list;
    try {
      list = await _fetch();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError =
              'Your appointments could not be loaded. Please try again.';
        });
      }
      return;
    }
    if (!mounted) return;

    // Find the first active (future) appointment
    final now = DateTime.now();
    final active = list.where((a) {
      final dt = _parseDateTime(a.appointmentDate, a.appointmentTime);
      return !['CANCELLED', 'NO_SHOW', 'COMPLETED'].contains(a.status) &&
          (['CHECKED_IN', 'IN_CONSULTATION'].contains(a.status) ||
              (dt != null && dt.isAfter(now)));
    }).toList();

    setState(() {
      _loading = false;
      _loadError = null;
      _history = list
          .where((a) => !active.any((current) => current.id == a.id))
          .toList();
      _activeAppointmentData = active.isEmpty ? null : active.first;
      _activeAppointment = active.isEmpty ? null : _toCardData(active.first);
    });
  }

  Future<void> _openBookingSheet() async {
    AppointmentData? activeAppointment;
    try {
      activeAppointment = await _getActiveAppointment();
    } catch (_) {
      if (mounted) {
        showTopNotificationToast(
          context,
          title: 'Please try again',
          message: 'We could not check your appointments.',
          tone: TopNotificationTone.warning,
        );
      }
      return;
    }
    if (!mounted) return;

    if (activeAppointment != null) {
      showTopNotificationToast(
        context,
        title: 'Appointment Already Exists',
        message: _activeAppointmentMessage(activeAppointment),
        tone: TopNotificationTone.warning,
      );
      return;
    }

    final result = await showBookAppointmentSheet(context);
    if (result == null || !mounted) return;

    if (result.status == AppointmentSheetStatus.booked) {
      _loadAppointment();
      showTopNotificationToast(
        context,
        title: 'Appointment Requested',
        message: 'We\'ve received your request. Check notifications.',
      );
    } else if (result.status == AppointmentSheetStatus.alreadyExists) {
      showTopNotificationToast(
        context,
        title: 'Appointment Already Exists',
        message: result.message,
        tone: TopNotificationTone.warning,
      );
    }
  }

  Future<void> _openRescheduleSheet() async {
    final appointment = _activeAppointmentData;
    if (appointment == null) return;
    if (appointment.resourceId != null) {
      showTopNotificationToast(
        context,
        title: 'Contact the Clinic',
        message:
            'Please contact your branch to change a confirmed resource booking.',
      );
      return;
    }

    final result = await showBookAppointmentSheet(
      context,
      rescheduleAppointment: appointment,
    );
    if (result == null || !mounted) return;

    if (result.status == AppointmentSheetStatus.rescheduled ||
        result.status == AppointmentSheetStatus.booked) {
      _loadAppointment();
      showTopNotificationToast(
        context,
        title: 'Appointment Rescheduled',
        message: result.message,
      );
    } else if (result.status == AppointmentSheetStatus.alreadyExists) {
      showTopNotificationToast(
        context,
        title: 'Appointment Already Exists',
        message: result.message,
        tone: TopNotificationTone.warning,
      );
    }
  }

  Future<void> _openDirections() async {
    final appointment = _activeAppointmentData;
    if (appointment == null) return;

    final url = _directionsUrl(appointment.branch);
    if (url == null) {
      showTopNotificationToast(
        context,
        title: 'Directions Unavailable',
        message: 'We could not find directions for this branch.',
        tone: TopNotificationTone.warning,
      );
      return;
    }

    final opened = await ExternalLinkService.openDirections(
      branch: appointment.branch,
      fallbackUrl: url,
    );
    if (!mounted || opened) return;

    await ExternalLinkService.copyUrl(url);
    if (!mounted) return;

    showTopNotificationToast(
      context,
      title: 'Directions Link Copied',
      message:
          'Could not open maps automatically. Paste the copied link in your browser.',
      tone: TopNotificationTone.warning,
    );
  }

  Future<AppointmentData?> _getActiveAppointment() async {
    final appointments = await _fetch();
    final now = DateTime.now();
    for (final appointment in appointments) {
      final dateTime = _parseDateTime(
        appointment.appointmentDate,
        appointment.appointmentTime,
      );
      if (!['CANCELLED', 'NO_SHOW', 'COMPLETED'].contains(appointment.status) &&
          dateTime != null &&
          dateTime.isAfter(now)) {
        return appointment;
      }
    }
    return null;
  }

  String _activeAppointmentMessage(AppointmentData appointment) {
    final dateTime = _parseDateTime(
      appointment.appointmentDate,
      appointment.appointmentTime,
    );
    if (dateTime == null) {
      return 'You already have an active appointment. You can book a new one once it is completed.';
    }

    return 'You already have an active appointment on '
        '${_formatAppointmentDate(dateTime)} at ${_formatAppointmentTime(dateTime)}.';
  }

  String _formatAppointmentDate(DateTime dateTime) {
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
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }

  String _formatAppointmentTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  AppointmentCardData _toCardData(AppointmentData a) {
    final dt =
        _parseDateTime(a.appointmentDate, a.appointmentTime) ?? DateTime.now();

    return AppointmentCardData(
      id: a.id,
      dateTime: dt,
      status: _parseStatus(a.status),
      note: (a.note != null && a.note!.isNotEmpty) ? a.note : null,
      location: _branchLabel(a.branch),
      branchCode: a.branch,
    );
  }

  DateTime? _parseDateTime(String date, String time) {
    try {
      final dateParts = date.split('-');
      final timeParts = time.split(':');
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    } catch (_) {
      return null;
    }
  }

  AppointmentStatus _parseStatus(String s) {
    switch (s.toUpperCase()) {
      case 'CONFIRMED':
        return AppointmentStatus.confirmed;
      case 'PENDING':
        return AppointmentStatus.waiting;
      case 'CHECKED_IN':
        return AppointmentStatus.checkedIn;
      case 'IN_CONSULTATION':
      case 'IN_PROGRESS':
        return AppointmentStatus.inProgress;
      case 'COMPLETED':
        return AppointmentStatus.completed;
      case 'CANCELLED':
        return AppointmentStatus.cancelled;
      case 'NO_SHOW':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.unknown;
    }
  }

  String _branchLabel(String code) {
    switch (code.toUpperCase()) {
      case 'BURJUMAN':
        return 'BurJuman';
      case 'MARINA':
        return 'Marina';
      default:
        return code;
    }
  }

  String? _directionsUrl(String branch) {
    final normalized = branch
        .toUpperCase()
        .replaceAll(' ', '')
        .replaceAll('-', '');
    switch (normalized) {
      case 'MARINA':
      case 'DUBAIMARINA':
        return 'https://maps.app.goo.gl/mmD7EyHPQRt5YoFH6';
      case 'BURJUMAN':
      case 'KARAMA':
      case 'BURDUBAI':
        return 'https://maps.app.goo.gl/eDCguXqshUBfZ5HY6';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: _primaryBlue,
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                _buildLoading()
              else if (_loadError != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _loadAppointment,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (_activeAppointment != null)
                AppointmentCard(
                  appointment: _activeAppointment,
                  onReschedule: _openRescheduleSheet,
                  onGetDirections: _openDirections,
                  onCallClinic: _callClinic,
                )
              else
                _buildEmptyState(),

              ReportsCard(reports: _reports),
              if (_reportError)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Unable to check for reports.',
                          style: TextStyle(fontSize: 12, color: _textSecondary),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadReports,
                        child: const Text('Retry reports'),
                      ),
                    ],
                  ),
                ),
              if (!_loading && _loadError == null) ...[
                SizedBox(height: 14.h),
                if (_activeAppointmentData != null)
                  VisitGuide(
                    status: _activeAppointmentData!.status,
                    voucherBooking: _activeAppointmentData!.giftVoucherBooking,
                    onContactClinic: widget.onContactClinic,
                  )
                else if (widget.onContactClinic != null)
                  Center(
                    child: TextButton.icon(
                      onPressed: widget.onContactClinic,
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('Need help? Chat with our team'),
                    ),
                  ),
                if (_history.isNotEmpty) _buildHistory(),
              ],
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callClinic() async {
    if (_calling) return;
    _calling = true;
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri(scheme: 'tel', path: ClinicContactConfig.phone),
      );
    } catch (_) {
      opened = false;
    } finally {
      _calling = false;
    }
    if (!mounted || opened) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Call clinic'),
        content: const Text(
          'This device cannot open the phone app. You can call us on ${ClinicContactConfig.phone}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await ExternalLinkService.copyUrl(ClinicContactConfig.phone);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Copy number'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent appointments',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final appointment in _history.take(5))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderSoft),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_note_outlined,
                  color: _primaryBlue,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _branchLabel(appointment.branch),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${appointment.appointmentDate} · ${appointment.appointmentTime.length >= 5 ? appointment.appointmentTime.substring(0, 5) : appointment.appointmentTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                      Text(
                        appointment.status.replaceAll('_', ' ').toLowerCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _buildLoading() {
    return Container(
      height: 220.h,
      decoration: BoxDecoration(
        color: _surfaceSoft,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Center(
        child: SizedBox(
          width: 28.r,
          height: 28.r,
          child: const CircularProgressIndicator(
            strokeWidth: 2.5,
            color: _primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22.w, 28.h, 22.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _borderSoft, width: 1.r),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.05),
            blurRadius: 20.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        children: [
          // Decorative icon
          Container(
            width: 78.r,
            height: 78.r,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _primaryBlue.withValues(alpha: 0.1),
                  _primaryPurple.withValues(alpha: 0.06),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available_rounded,
              size: 36.r,
              color: _primaryBlue,
            ),
          ),
          SizedBox(height: 18.h),

          Text(
            'Plan your next visit',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Book your next visit at BurJuman or Marina\nto see it appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
              height: 1.4,
            ),
          ),
          SizedBox(height: 22.h),

          // Book button
          GestureDetector(
            onTap: _openBookingSheet,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 14.h),
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
                    blurRadius: 14.r,
                    offset: Offset(0, 5.h),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 18.r,
                    color: Colors.white,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Book Appointment',
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
