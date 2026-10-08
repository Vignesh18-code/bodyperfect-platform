import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../services/report_service.dart';

/// No placeholder records: empty data takes no space in the appointment page.
class ReportsCard extends StatefulWidget {
  final List<PatientReport> reports;
  final Future<void> Function(PatientReport, Rect)? onDownload;
  const ReportsCard({super.key, required this.reports, this.onDownload});
  @override
  State<ReportsCard> createState() => _ReportsCardState();
}

class _ReportsCardState extends State<ReportsCard> {
  final Set<int> _busy = {};
  final Set<int> _errors = {};
  bool _expanded = false;
  static const blue = Color(0xFF4361EE);
  static const ink = Color(0xFF1A1D2E);
  static const muted = Color(0xFF6B7280);

  Future<void> _download(
    PatientReport report,
    BuildContext buttonContext,
  ) async {
    if (_busy.contains(report.id)) return;
    final box = buttonContext.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      _busy.add(report.id);
      _errors.remove(report.id);
    });
    try {
      if (widget.onDownload != null) {
        await widget.onDownload!(report, origin);
      } else {
        final bytes = await ReportService.download(report);
        if (!mounted) return;
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: ['bodyperfect-report-${report.id}.pdf'],
          sharePositionOrigin: origin,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _errors.add(report.id));
    } finally {
      if (mounted) setState(() => _busy.remove(report.id));
    }
  }

  String _meta(PatientReport r) {
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
    final size = r.sizeBytes >= 1024 * 1024
        ? '${(r.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(r.sizeBytes / 1024).ceil()} KB';
    return '${r.date.day} ${months[r.date.month - 1]} ${r.date.year} · PDF · $size';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reports.isEmpty) return const SizedBox.shrink();
    final reports = [...widget.reports]
      ..sort((a, b) => b.date.compareTo(a.date));
    final visible = _expanded ? reports : reports.take(3);
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E9F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x064361EE),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: blue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Shared by your clinic',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5FA),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${reports.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (final report in visible) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEF0F7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.description_outlined,
                          size: 22,
                          color: blue,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.title,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _meta(report),
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.branch == 'BURJUMAN'
                              ? 'BurJuman clinic'
                              : report.branch == 'MARINA'
                              ? 'Marina clinic'
                              : report.branch,
                          style: const TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Builder(
                          builder: (buttonContext) => TextButton.icon(
                            onPressed: _busy.contains(report.id)
                                ? null
                                : () => _download(report, buttonContext),
                            icon: _busy.contains(report.id)
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.file_download_outlined,
                                    size: 18,
                                  ),
                            label: Text(
                              _busy.contains(report.id)
                                  ? 'Preparing…'
                                  : _errors.contains(report.id)
                                  ? 'Retry'
                                  : 'Download',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: blue,
                              backgroundColor: const Color(0xFFECEFFE),
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_errors.contains(report.id))
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Could not open this report. Please try again.',
                        style: TextStyle(
                          color: Color(0xFFAC3434),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (reports.length > 3)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? 'Show fewer reports'
                    : 'View all ${reports.length} reports',
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Choose where to save or share your PDF.',
              style: TextStyle(fontSize: 11, color: muted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
