import '../core/constants/app_typography.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// A consistent name avatar across the home header, profile and navigation.
class ClientAvatar extends StatelessWidget {
  final String initials;
  final double size;
  const ClientAvatar({super.key, required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    final name = initials.trim();
    final letter = name.isEmpty ? 'U' : name.characters.first.toUpperCase();
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF2FF), Color(0xFFECE8FF)],
          ),
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: size * .38,
              fontWeight: FontWeight.w500,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
              color: AppColors.navy,
            ),
            textAlign: TextAlign.center,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
          ),
        ),
      ),
    );
  }
}
