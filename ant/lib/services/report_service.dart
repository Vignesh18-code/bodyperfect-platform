import 'dart:typed_data';
import '../config/api_config.dart';
import 'api_service.dart';

class PatientReport {
  final int id;
  final String title;
  final DateTime date;
  final int sizeBytes;
  final String branch;
  const PatientReport({
    required this.id,
    required this.title,
    required this.date,
    required this.sizeBytes,
    required this.branch,
  });
  factory PatientReport.fromJson(Map<String, dynamic> json) => PatientReport(
    id: json['id'] as int,
    title: json['title'] as String,
    date: DateTime.parse(json['reportDate'] as String),
    sizeBytes: json['sizeBytes'] as int,
    branch: json['branch'] as String,
  );
}

class ReportService {
  static Future<List<PatientReport>> list() async {
    final response = await ApiService.secureGet(
      '${ApiConfig.baseUrl}/api/reports',
    );
    if (response['success'] != true || response['data'] is! List) {
      throw StateError('Reports could not be loaded.');
    }
    return (response['data'] as List)
        .map((r) => PatientReport.fromJson(r))
        .toList();
  }

  static Future<Uint8List> download(PatientReport report) =>
      ApiService.securePdf(
        '${ApiConfig.baseUrl}/api/reports/${report.id}/download',
      );
}
