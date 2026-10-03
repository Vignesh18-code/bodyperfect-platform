import '../config/api_config.dart';
import 'api_service.dart';

class AppointmentData {
  final int id;
  final int? resourceId;
  final String appointmentDate;
  final String appointmentTime;
  final String branch;
  final String status;
  final String? note;
  final String? createdAt;

  AppointmentData({
    required this.id,
    this.resourceId,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.branch,
    required this.status,
    this.note,
    this.createdAt,
  });

  factory AppointmentData.fromJson(Map<String, dynamic> json) {
    return AppointmentData(
      id: json['id'] ?? 0,
      resourceId: json['resourceId'],
      appointmentDate: json['appointmentDate'] ?? '',
      appointmentTime: json['appointmentTime'] ?? '',
      branch: json['branch'] ?? '',
      status: json['status'] ?? '',
      note: json['note'],
      createdAt: json['createdAt'],
    );
  }
}

class AppointmentBookingResult {
  final bool success;
  final String message;
  final AppointmentData? appointment;

  AppointmentBookingResult({
    required this.success,
    required this.message,
    this.appointment,
  });
}

class AppointmentService {
  /// Book new appointment. `date` must be YYYY-MM-DD, `time` must be HH:mm:ss
  /// `branch` must be one of: BURJUMAN, MARINA
  static Future<AppointmentBookingResult> bookAppointment({
    required String date,
    required String time,
    required String branch,
    String? note,
  }) async {
    final response = await ApiService.securePost(ApiConfig.appointments, {
      'appointmentDate': date,
      'appointmentTime': time,
      'branch': branch,
      if (note != null && note.isNotEmpty) 'note': note,
    });

    if (response['success'] == true && response['data'] != null) {
      return AppointmentBookingResult(
        success: true,
        message: response['message'] ?? 'Appointment booked',
        appointment: AppointmentData.fromJson(response['data']),
      );
    }

    return AppointmentBookingResult(
      success: false,
      message: response['message'] ?? 'Failed to book appointment',
    );
  }

  static Future<AppointmentBookingResult> rescheduleAppointment({
    required int id,
    required String date,
    required String time,
    required String branch,
    String? note,
  }) async {
    final response = await ApiService.securePatch(
      ApiConfig.appointmentReschedule(id),
      body: {
        'appointmentDate': date,
        'appointmentTime': time,
        'branch': branch,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );

    if (response['success'] == true && response['data'] != null) {
      return AppointmentBookingResult(
        success: true,
        message: response['message'] ?? 'Appointment rescheduled',
        appointment: AppointmentData.fromJson(response['data']),
      );
    }

    return AppointmentBookingResult(
      success: false,
      message: response['message'] ?? 'Failed to reschedule appointment',
    );
  }

  static Future<List<AppointmentData>> getMyAppointments() async {
    final response = await ApiService.secureGet(ApiConfig.appointments);

    if (response['success'] == true && response['data'] != null) {
      final list = response['data'] as List;
      return list.map((e) => AppointmentData.fromJson(e)).toList();
    }

    return [];
  }
}
