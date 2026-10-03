import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/clinic_contact_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import 'longevity_program.dart';

enum ProgramDetailAction { appointment }

Future<ProgramDetailAction?> showProgramDetailSheet(
  BuildContext context,
  LongevityProgram program, {
  String clinicPhone = ClinicContactConfig.phone,
}) {
  final reducedMotion = MediaQuery.disableAnimationsOf(context);
  return showModalBottomSheet<ProgramDetailAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.navy.withValues(alpha: .46),
    constraints: const BoxConstraints(maxWidth: 480),
    sheetAnimationStyle: reducedMotion
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 380),
            reverseDuration: Duration(milliseconds: 240),
          ),
    builder: (context) =>
        _ProgramDetailSheet(program: program, clinicPhone: clinicPhone),
  );
}

class _ProgramDetailSheet extends StatefulWidget {
  final LongevityProgram program;
  final String clinicPhone;
  const _ProgramDetailSheet({required this.program, required this.clinicPhone});

  @override
  State<_ProgramDetailSheet> createState() => _ProgramDetailSheetState();
}

class _ProgramDetailSheetState extends State<_ProgramDetailSheet> {
  final _feedbackKey = GlobalKey();
  bool _calling = false;
  String? _callMessage;
  String get _number => widget.clinicPhone.replaceAll(RegExp(r'[\s()\-]'), '');
  bool get _hasNumber => RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(_number);

  Future<void> _callClinic() async {
    if (!_hasNumber) {
      setState(
        () => _callMessage =
            'The clinic phone number is not available yet. You can contact the team in Clinic Chat.',
      );
      return;
    }
    setState(() {
      _calling = true;
      _callMessage = null;
    });
    try {
      final opened = await launchUrl(Uri(scheme: 'tel', path: _number));
      if (!opened && mounted) {
        setState(
          () => _callMessage =
              'This device cannot open the phone app. You can copy the clinic number below.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _callMessage =
              'Unable to open the phone app. You can copy the clinic number below.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _calling = false);
        if (_callMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final feedback = _feedbackKey.currentContext;
            if (feedback != null && mounted) {
              Scrollable.ensureVisible(
                feedback,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 19;
    final height = math.min(
      math.max(screen.height * (largeText ? .78 : .56), 440.0),
      screen.height * .92,
    );
    final textStyle = const TextStyle(
      fontFamily: AppTypography.family,
      color: AppColors.navy,
    );
    return SizedBox(
      height: height,
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: Center(
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close program details',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.navy,
                  fixedSize: const Size.square(44),
                  elevation: 2,
                  shadowColor: Colors.black26,
                ),
                icon: const Icon(Icons.close_rounded, size: 21),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                widget.program.imagePath,
                                cacheWidth: 1200,
                                width: double.infinity,
                                height: (height * .29).clamp(105.0, 160.0),
                                fit: BoxFit.cover,
                                semanticLabel: widget.program.title,
                                errorBuilder: (_, _, _) => Container(
                                  height: 110,
                                  color: AppColors.tint,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.spa_outlined,
                                    color: AppColors.brandBlue,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.program.title,
                              style: textStyle.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -.55,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.program.description,
                              style: textStyle.copyWith(
                                fontSize: 13,
                                height: 1.55,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Your clinician will discuss suitability during your consultation.',
                              style: textStyle.copyWith(
                                fontSize: 11,
                                height: 1.4,
                                color: AppColors.muted,
                              ),
                            ),
                            if (_callMessage != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                key: _feedbackKey,
                                liveRegion: true,
                                child: Text(
                                  _callMessage!,
                                  style: textStyle.copyWith(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppColors.brandBlue,
                                  ),
                                ),
                              ),
                              if (_hasNumber)
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: _number),
                                    );
                                    if (mounted) {
                                      setState(
                                        () => _callMessage =
                                            'Clinic number copied.',
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 15,
                                  ),
                                  label: Text(
                                    _number,
                                    style: textStyle.copyWith(fontSize: 13),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final book = FilledButton.icon(
                            onPressed: () => Navigator.pop(
                              context,
                              ProgramDetailAction.appointment,
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              backgroundColor: AppColors.brandBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              textStyle: textStyle.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            icon: const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                            ),
                            label: const Text('Book appointment'),
                          );
                          final call = OutlinedButton.icon(
                            onPressed: _calling ? null : _callClinic,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 14,
                              ),
                              side: const BorderSide(color: AppColors.border),
                              foregroundColor: AppColors.navy,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              textStyle: textStyle.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            icon: const Icon(Icons.call_outlined, size: 18),
                            label: Text(_calling ? 'Opening…' : 'Call clinic'),
                          );
                          if (largeText || constraints.maxWidth < 290) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [book, const SizedBox(height: 8), call],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(flex: 3, child: book),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: call),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
