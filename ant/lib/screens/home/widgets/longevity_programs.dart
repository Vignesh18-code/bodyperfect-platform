import 'longevity_program.dart';
import 'program_detail_sheet.dart';
import '../../../core/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart'; // Ensure this matches your project structure

class LongevityPrograms extends StatefulWidget {
  final Future<void> Function(String programName) onBookAppointment;
  const LongevityPrograms({super.key, required this.onBookAppointment});

  @override
  State<LongevityPrograms> createState() => _LongevityProgramsState();
}

class _LongevityProgramsState extends State<LongevityPrograms> {
  final _scroll = ScrollController();
  bool _detailsOpen = false;
  bool _allOpen = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openProgram(
    BuildContext context,
    LongevityProgram program,
  ) async {
    if (_detailsOpen) return;
    _detailsOpen = true;
    try {
      final action = await showProgramDetailSheet(context, program);
      if (action != ProgramDetailAction.appointment || !context.mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) {
        await Future<void>.delayed(const Duration(milliseconds: 240));
      }
      if (context.mounted) await widget.onBookAppointment(program.title);
    } finally {
      _detailsOpen = false;
    }
  }

  Future<void> _viewAll(BuildContext context) async {
    if (_allOpen) return;
    _allOpen = true;
    try {
      final selected = await showModalBottomSheet<LongevityProgram>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface,
        constraints: const BoxConstraints(maxWidth: 480),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .72,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Longevity Programs',
                          style: TextStyle(
                            fontFamily: AppTypography.family,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close programs',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                      mainAxisExtent:
                          230.h +
                          (MediaQuery.textScalerOf(context).scale(60) - 60),
                    ),
                    itemCount: LongevityProgram.catalog.length,
                    itemBuilder: (context, index) => _LongevityProgramCard(
                      program: LongevityProgram.catalog[index],
                      onTap: () => Navigator.pop(
                        context,
                        LongevityProgram.catalog[index],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected != null && context.mounted) {
        await _openProgram(context, selected);
      }
    } finally {
      _allOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const programs = LongevityProgram.catalog;

    return Padding(
      padding: EdgeInsets.only(left: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          SizedBox(height: 14.h),
          SizedBox(
            height: 238.h + (MediaQuery.textScalerOf(context).scale(60) - 60),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              controller: _scroll,
              physics: _ServiceCardScrollPhysics(
                itemExtent: 182.w,
                parent: const BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.only(right: 16.w, bottom: 20.h),
              itemCount: programs.length,
              separatorBuilder: (context, index) => SizedBox(width: 12.w),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _scroll,
                  child: _LongevityProgramCard(
                    program: programs[index],
                    onTap: () => _openProgram(context, programs[index]),
                  ),
                  builder: (context, child) {
                    final distance = _scroll.hasClients
                        ? (_scroll.offset / 182.w - index).abs().clamp(0.0, 1.0)
                        : (index == 0 ? 0.0 : 1.0);
                    return Transform.scale(
                      scale: MediaQuery.disableAnimationsOf(context)
                          ? 1
                          : 1 - distance * .015,
                      alignment: Alignment.centerLeft,
                      child: child,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 16.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Longevity Programs',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Explore our 12 clinic services',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          TextButton(
            onPressed: () => _viewAll(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandBlue,
              backgroundColor: const Color(0xFFEBEDFF),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View All',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.arrow_forward_rounded, size: 15),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LongevityProgramCard extends StatefulWidget {
  final LongevityProgram program;
  final VoidCallback onTap;

  const _LongevityProgramCard({required this.program, required this.onTap});

  @override
  State<_LongevityProgramCard> createState() => _LongevityProgramCardState();
}

class _LongevityProgramCardState extends State<_LongevityProgramCard> {
  bool _isPressed = false;
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Semantics(
      button: true,
      label: widget.program.title,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _isPressed && !reduceMotion ? .975 : 1,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: Container(
          width: 170.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF182247).withValues(alpha: .13),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -7,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.r),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedScale(
                  scale: _isHovered && !reduceMotion ? 1.035 : 1,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: Image.asset(
                    widget.program.imagePath,
                    cacheWidth: 600,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, error, stack) =>
                        ColoredBox(color: widget.program.color),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x18131C35),
                        Color(0x33131C35),
                        Color(0xDA131C35),
                        Color(0xFF131C35),
                      ],
                      stops: [0, .28, .62, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(14.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(),
                      Text(
                        widget.program.cardTitle ?? widget.program.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.13,
                          letterSpacing: -.45,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        widget.program.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFDAE0EF),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: .18),
                      ),
                      SizedBox(height: 9.h),
                      Row(
                        children: [
                          Text(
                            'Explore',
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 25.r,
                            height: 25.r,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.north_east_rounded,
                              color: Colors.white,
                              size: 14.r,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      onTapDown: (_) => setState(() => _isPressed = true),
                      onTapUp: (_) => setState(() => _isPressed = false),
                      onTapCancel: () => setState(() => _isPressed = false),
                      onHover: (value) => setState(() => _isHovered = value),
                      onFocusChange: (value) =>
                          setState(() => _isFocused = value),
                      borderRadius: BorderRadius.circular(24.r),
                      splashColor: Colors.white.withValues(alpha: .12),
                      highlightColor: Colors.white.withValues(alpha: .04),
                      child: AnimatedContainer(
                        duration: duration,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: _isFocused
                                ? Colors.white
                                : Colors.white.withValues(
                                    alpha: _isHovered ? .5 : .15,
                                  ),
                            width: _isFocused ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Settle on a card after a drag without changing the existing card dimensions.
class _ServiceCardScrollPhysics extends ScrollPhysics {
  final double itemExtent;
  const _ServiceCardScrollPhysics({required this.itemExtent, super.parent});

  @override
  _ServiceCardScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _ServiceCardScrollPhysics(
        itemExtent: itemExtent,
        parent: buildParent(ancestor),
      );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange ||
        (position.pixels <= position.minScrollExtent && velocity <= 0) ||
        (position.pixels >= position.maxScrollExtent && velocity >= 0)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var page = position.pixels / itemExtent;
    if (velocity.abs() > tolerance.velocity) page += velocity.sign * .5;
    final target = (page.round() * itemExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
