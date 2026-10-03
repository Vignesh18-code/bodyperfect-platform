import '../config/api_config.dart';
import 'api_service.dart';

class ProtocolData {
  final int id;
  final String protocolName;
  final String treatmentType;
  final String status;
  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final double? goalWeightKg;
  final int totalSessions;
  final int completedSessions;
  final int progressPercent;
  final String? instructions;
  final SessionData? nextSession;
  final List<SessionData> sessions;

  ProtocolData({
    required this.id,
    required this.protocolName,
    required this.treatmentType,
    required this.status,
    this.weightKg,
    this.heightCm,
    this.bmi,
    this.goalWeightKg,
    required this.totalSessions,
    required this.completedSessions,
    required this.progressPercent,
    this.instructions,
    this.nextSession,
    required this.sessions,
  });

  factory ProtocolData.fromJson(Map<String, dynamic> json) {
    final sessionsJson = json['sessions'] as List<dynamic>? ?? [];
    final nextJson = json['nextSession'] as Map<String, dynamic>?;

    return ProtocolData(
      id: json['id'] ?? 0,
      protocolName: json['protocolName'] ?? '',
      treatmentType: json['treatmentType'] ?? '',
      status: json['status'] ?? '',
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      goalWeightKg: (json['goalWeightKg'] as num?)?.toDouble(),
      totalSessions: json['totalSessions'] ?? 0,
      completedSessions: json['completedSessions'] ?? 0,
      progressPercent: json['progressPercent'] ?? 0,
      instructions: json['instructions'],
      nextSession: nextJson != null ? SessionData.fromJson(nextJson) : null,
      sessions: sessionsJson.map((s) => SessionData.fromJson(s)).toList(),
    );
  }
}

class SessionData {
  final int id;
  final int protocolId;
  final String protocolName;
  final int sessionNumber;
  final String sessionName;
  final String sessionDate;
  final String sessionTime;
  final int durationMinutes;
  final String status;

  SessionData({
    required this.id,
    required this.protocolId,
    required this.protocolName,
    required this.sessionNumber,
    required this.sessionName,
    required this.sessionDate,
    required this.sessionTime,
    required this.durationMinutes,
    required this.status,
  });

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      id: json['id'] ?? 0,
      protocolId: json['protocolId'] ?? 0,
      protocolName: json['protocolName'] ?? '',
      sessionNumber: json['sessionNumber'] ?? 0,
      sessionName: json['sessionName'] ?? '',
      sessionDate: json['sessionDate'] ?? '',
      sessionTime: json['sessionTime'] ?? '',
      durationMinutes: json['durationMinutes'] ?? 30,
      status: json['status'] ?? 'SCHEDULED',
    );
  }

  DateTime get date => DateTime.parse(sessionDate);

  String get formattedTime {
    final parts = sessionTime.split(':');
    if (parts.length < 2) return sessionTime;
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${h.toString().padLeft(2, '0')}:$minute $period';
  }
}

class TreatmentService {
  static Future<ProtocolData?> getActiveProtocol() async {
    final result = await ApiService.secureGet(ApiConfig.treatmentActive);

    if (result['success'] == true && result['data'] != null) {
      return ProtocolData.fromJson(result['data']);
    }
    return null;
  }

  static Future<List<ProtocolData>> getAllProtocols() async {
    final result = await ApiService.secureGet(ApiConfig.treatmentProtocols);

    if (result['success'] == true && result['data'] != null) {
      final list = result['data'] as List<dynamic>;
      return list.map((p) => ProtocolData.fromJson(p)).toList();
    }
    return [];
  }

  static Future<SessionData?> getNextSession() async {
    final result = await ApiService.secureGet(ApiConfig.treatmentNextSession);

    if (result['success'] == true && result['data'] != null) {
      return SessionData.fromJson(result['data']);
    }
    return null;
  }
}
