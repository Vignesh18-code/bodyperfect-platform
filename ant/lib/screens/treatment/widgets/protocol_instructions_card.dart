import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ProtocolInstructionsCard extends StatelessWidget {
  final String? instructions;
  const ProtocolInstructionsCard({super.key, this.instructions});
  @override
  Widget build(BuildContext context) {
    final hasInstructions = instructions?.trim().isNotEmpty == true;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.description_outlined,
            color: AppColors.brandBlue,
            size: 24,
          ),
          const SizedBox(height: 12),
          const Text(
            'Care instructions',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Shared by your clinic for this plan',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: AppColors.border),
          ),
          SelectableText(
            hasInstructions
                ? instructions!.trim()
                : 'Your clinic has not added care instructions yet. Contact the team if you need help preparing for your treatment.',
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
