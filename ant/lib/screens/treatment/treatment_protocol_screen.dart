import 'package:flutter/material.dart';
import '../../config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/treatment_service.dart';
import '../home/widgets/next_treatment_session.dart';
import 'widgets/protocol_header.dart';
import 'widgets/protocol_instructions_card.dart';
import 'widgets/protocol_summary_card.dart';
import 'widgets/protocol_timeline_card.dart';

class TreatmentProtocolScreen extends StatefulWidget {
  final VoidCallback? onOpenAppointments, onContactClinic;
  const TreatmentProtocolScreen({
    super.key,
    this.onOpenAppointments,
    this.onContactClinic,
  });
  @override
  State<TreatmentProtocolScreen> createState() =>
      _TreatmentProtocolScreenState();
}

class _TreatmentProtocolScreenState extends State<TreatmentProtocolScreen> {
  ProtocolData? _protocol;
  bool _loading = true;
  String? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProtocol();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadProtocol() async {
    try {
      final result = await ApiService.secureGet(ApiConfig.treatmentActive);
      if (!mounted) return;
      if (result['success'] != true) {
        setState(() {
          _protocol = null;
          _error = result['httpStatus'] == 401
              ? 'Your session has expired. Please sign in again.'
              : 'We couldn’t load your treatment plan. Please try again.';
          _loading = false;
        });
        return;
      }
      final data = result['data'];
      setState(() {
        _protocol = data == null ? null : ProtocolData.fromJson(data);
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _protocol = null;
          _error = 'We couldn’t load your treatment plan. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _protocol;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadProtocol,
        color: AppColors.brandBlue,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brandBlue),
              )
            : ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  if (_error != null)
                    _empty(error: true)
                  else if (p == null)
                    _empty()
                  else ...[
                    ProtocolHeader(
                      protocolName: p.protocolName,
                      status: p.status,
                    ),
                    const SizedBox(height: 14),
                    ProtocolSummaryCard(
                      protocolName: p.protocolName,
                      weightKg: p.weightKg,
                      heightCm: p.heightCm,
                      bmi: p.bmi,
                      goalWeightKg: p.goalWeightKg,
                    ),
                    const SizedBox(height: 18),
                    NextTreatmentSession(
                      heading: 'Next treatment session',
                      subtitle: 'Your upcoming visit in this plan',
                      horizontalPadding: 0,
                      showViewButton: false,
                      protocolName: p.protocolName,
                      treatmentType: p.treatmentType,
                      status: p.status,
                      totalSessions: p.totalSessions,
                      completedSessions: p.completedSessions,
                      nextSession: p.nextSession,
                    ),
                    if (widget.onOpenAppointments != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: widget.onOpenAppointments,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brandBlue,
                          ),
                          child: const Text(
                            'View appointments →',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ProtocolTimelineCard(
                      sessions: p.sessions
                          .where(
                            (s) => DateTime.tryParse(s.sessionDate) != null,
                          )
                          .map(
                            (s) => ProtocolSession(
                              number: s.sessionNumber,
                              title: s.sessionName,
                              status: s.status == 'COMPLETED'
                                  ? SessionStatus.completed
                                  : s.status == 'IN_PROGRESS'
                                  ? SessionStatus.current
                                  : SessionStatus.upcoming,
                              statusLabel: s.status.toLowerCase().replaceAll(
                                '_',
                                ' ',
                              ),
                              date: s.date,
                              time: s.formattedTime,
                              durationMinutes: s.durationMinutes,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    ProtocolInstructionsCard(instructions: p.instructions),
                    const SizedBox(height: 10),
                    _support(),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _support() => widget.onContactClinic == null
      ? const SizedBox.shrink()
      : Row(
          children: [
            const Expanded(
              child: Text(
                'Questions about your plan?',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            TextButton(
              onPressed: widget.onContactClinic,
              style: TextButton.styleFrom(foregroundColor: AppColors.brandBlue),
              child: const Text(
                'Contact clinic',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );

  Widget _empty({bool error = false}) => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: AppColors.tint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            error ? Icons.cloud_off_outlined : Icons.assignment_outlined,
            size: 32,
            color: AppColors.brandBlue,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          error ? 'Plan unavailable' : 'Your care journey starts here',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          error
              ? _error!
              : 'Once your clinic assigns a treatment plan, you’ll find your sessions, progress and care instructions here.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 20),
        if (error)
          FilledButton(
            onPressed: () async {
              setState(() => _loading = true);
              await _loadProtocol();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.brandBlue),
            child: const Text('Try again'),
          ),
        _support(),
      ],
    ),
  );
}
