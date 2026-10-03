import '../../../core/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/client_avatar.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String initials;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    this.initials = 'U',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
      _NavItem(
        Icons.calendar_month_rounded,
        Icons.calendar_month_outlined,
        'Appointments',
      ),
      _NavItem(
        Icons.medical_services_rounded,
        Icons.medical_services_outlined,
        'Treatment',
      ),
      _NavItem(Icons.chat_rounded, Icons.chat_outlined, 'Chat'),
      _NavItem(Icons.person_rounded, Icons.person_outlined, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = currentIndex == index;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isActive,
                  label: item.label,
                  excludeSemantics: true,
                  child: Tooltip(
                    message: item.label,
                    child: GestureDetector(
                      onTap: () => onTap(index),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 250),
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.navy.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (index == 4)
                              Container(
                                padding: EdgeInsets.all(1.r),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isActive
                                        ? AppColors.navy
                                        : const Color(0xFFDDE2F0),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClientAvatar(
                                  initials: initials,
                                  size: 23.r,
                                ),
                              )
                            else
                              Icon(
                                isActive ? item.activeIcon : item.icon,
                                size: 24.r,
                                color: isActive
                                    ? AppColors.navy
                                    : AppColors.muted,
                              ),
                            SizedBox(height: 4.h),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 10.5.sp,
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isActive
                                      ? AppColors.navy
                                      : AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;

  const _NavItem(this.activeIcon, this.icon, this.label);
}
