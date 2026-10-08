import 'package:flutter/material.dart';

/// Supporting information for a real appointment, never a simulated status.
class VisitGuide extends StatelessWidget {
  final String status;
  final bool voucherBooking;
  final VoidCallback? onContactClinic;
  const VisitGuide({
    super.key,
    required this.status,
    required this.voucherBooking,
    this.onContactClinic,
  });

  static const blue = Color(0xFF4361EE);
  static const ink = Color(0xFF1A1D2E);
  static const muted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final stage = switch (status) {
      'PENDING' => 0,
      'CONFIRMED' => 1,
      'CHECKED_IN' || 'IN_CONSULTATION' || 'IN_PROGRESS' => 2,
      _ => -1,
    };
    final explanation = switch (status) {
      'PENDING' =>
        'Your request is with the clinic. Your visit is confirmed once the team approves it.',
      'CONFIRMED' =>
        'Your visit is confirmed. We look forward to welcoming you.',
      'CHECKED_IN' =>
        'You’re checked in. The clinic team will guide you from here.',
      'IN_CONSULTATION' || 'IN_PROGRESS' => 'Your consultation is underway.',
      _ => 'Contact the clinic to confirm the latest appointment status.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 6, 4, 12),
          child: Text(
            'Your visit guide',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What happens next',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              if (stage >= 0)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Expanded(
                        child: Semantics(
                          label:
                              '${['Request received', 'Clinic confirmation', 'Your visit'][i]}: ${i < stage
                                  ? 'complete'
                                  : i == stage
                                  ? 'current'
                                  : 'upcoming'}',
                          excludeSemantics: true,
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 2,
                                      color: i == 0
                                          ? Colors.transparent
                                          : i <= stage
                                          ? blue
                                          : const Color(0xFFE9ECF5),
                                    ),
                                  ),
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: i <= stage
                                          ? blue
                                          : const Color(0xFFF0F2FA),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      i < stage
                                          ? Icons.check_rounded
                                          : [
                                              Icons.check_rounded,
                                              Icons.event_available_outlined,
                                              Icons.favorite_border_rounded,
                                            ][i],
                                      size: 16,
                                      color: i <= stage ? Colors.white : muted,
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 2,
                                      color: i == 2
                                          ? Colors.transparent
                                          : i < stage
                                          ? blue
                                          : const Color(0xFFE9ECF5),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  [
                                    'Request\nreceived',
                                    'Clinic\nconfirmation',
                                    'Your\nvisit',
                                  ][i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    fontWeight: i == stage
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: i == stage ? ink : muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              Text(
                explanation,
                style: const TextStyle(fontSize: 13, height: 1.5, color: muted),
              ),
            ],
          ),
        ),
        if (voucherBooking) ...[
          const SizedBox(height: 12),
          _panel(
            color: const Color(0xFFFFFAEF),
            border: const Color(0xFFF0DFBB),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF936C22),
                  size: 23,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your AED 1,000 voucher is claimed',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF77551B),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Your consultant will explain eligible treatments and help you choose a plan. Terms apply.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFF806E4D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _panel(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prepare for your visit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              SizedBox(height: 14),
              _PreparationRow(
                icon: Icons.folder_outlined,
                text: 'Bring any previous reports you would like to discuss.',
              ),
              SizedBox(height: 12),
              _PreparationRow(
                icon: Icons.checklist_rounded,
                text: 'Keep a list of your medications and questions ready.',
              ),
              SizedBox(height: 12),
              _PreparationRow(
                icon: Icons.chat_bubble_outline_rounded,
                text:
                    'Follow any preparation instructions shared by your clinic.',
              ),
            ],
          ),
        ),
        if (onContactClinic != null) ...[
          const SizedBox(height: 12),
          _panel(
            color: const Color(0xFFF0F2FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A little help before your visit?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Our clinic team can help with your appointment or preparation.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: muted),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onContactClinic,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Chat with our team'),
                  style: TextButton.styleFrom(
                    foregroundColor: blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 0,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _panel({
    required Widget child,
    Color color = Colors.white,
    Color border = const Color(0xFFE9ECF5),
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: child,
  );
}

class _PreparationRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PreparationRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 19, color: VisitGuide.blue),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: VisitGuide.muted,
          ),
        ),
      ),
    ],
  );
}
