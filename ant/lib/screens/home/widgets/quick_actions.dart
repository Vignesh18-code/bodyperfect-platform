import '../../../core/constants/app_typography.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class QuickActions extends StatefulWidget {
  final VoidCallback? onBookAppointment;
  final VoidCallback? onOpenTreatment;
  final VoidCallback? onGymMembership;

  const QuickActions({
    super.key,
    this.onBookAppointment,
    this.onOpenTreatment,
    this.onGymMembership,
  });

  @override
  State<QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends State<QuickActions> {
  final _controller = PageController(viewportFraction: 0.5);
  int _selected = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final textScale = MediaQuery.textScalerOf(context);
    final cards = [
      _PremiumActionCard(
        title: 'Book Appointment',
        subtitle: 'Schedule next visit',
        icon: Icons.calendar_month_rounded,
        mainColor: const Color(0xFF4361EE),
        gradientColors: const [Color(0xFFF8FAFF), Color(0xFFEFF4FF)],
        borderColor: const Color(0xFFDDE7FF),
        onTap: widget.onBookAppointment,
      ),
      _PremiumActionCard(
        title: 'Treatment Plan',
        subtitle: 'View your care plan',
        icon: Icons.insights_rounded,
        mainColor: const Color(0xFF06B78A),
        gradientColors: const [Color(0xFFF8FFFC), Color(0xFFEFFFF9)],
        borderColor: const Color(0xFFD7F4EA),
        onTap: widget.onOpenTreatment,
      ),
      _PremiumActionCard(
        title: 'GYM Membership',
        subtitle: 'Book a consultation',
        icon: Icons.fitness_center_rounded,
        mainColor: const Color(0xFF7055D8),
        gradientColors: const [Color(0xFFFAF8FF), Color(0xFFF0ECFF)],
        borderColor: const Color(0xFFE5DDFB),
        onTap: widget.onGymMembership ?? widget.onBookAppointment,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Previous quick action',
                onPressed: _selected > 0 ? () => _goTo(_selected - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                color: const Color(0xFF4361EE),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Next quick action',
                onPressed: _selected < 1 ? () => _goTo(_selected + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                color: const Color(0xFF4361EE),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        SizedBox(
          // Keep the original 112 px cards; allow extra room for larger text.
          height: textScale.scale(13) > 14
              ? 90 + textScale.scale(13) * 2.1 + textScale.scale(10.5) * 1.1
              : 120,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              allowImplicitScrolling: true,
              itemCount: cards.length,
              onPageChanged: (page) => setState(() => _selected = page),
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                child: AnimatedBuilder(
                  animation: _controller,
                  child: cards[index],
                  builder: (context, child) {
                    final page =
                        _controller.hasClients &&
                            _controller.position.hasContentDimensions
                        ? _controller.page ?? 0
                        : _selected.toDouble();
                    final distance = (page - index).abs().clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: reducedMotion ? 1 : 1 - distance * 0.035,
                      alignment: Alignment.centerLeft,
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Semantics(
            label: 'Quick action group ${_selected + 1} of 2',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                2,
                (index) => AnimatedContainer(
                  duration: reducedMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _selected == index ? 20 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _selected == index
                        ? const Color(0xFF4361EE)
                        : const Color(0xFFDCE2F3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color mainColor;
  final List<Color> gradientColors;
  final Color borderColor;
  final VoidCallback? onTap;

  const _PremiumActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.mainColor,
    required this.gradientColors,
    required this.borderColor,
    this.onTap,
  });

  @override
  State<_PremiumActionCard> createState() => _PremiumActionCardState();
}

class _PremiumActionCardState extends State<_PremiumActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(24),
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradientColors,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: widget.borderColor, width: 1),
            ),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                _buildBackgroundDecor(),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopRow(),
                      const Spacer(),
                      _buildTitle(),
                      const SizedBox(height: 5),
                      _buildSubtitle(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() => Text(
    widget.title,
    style: const TextStyle(
      fontFamily: AppTypography.family,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textDark,
      height: 1.05,
      letterSpacing: -0.25,
    ),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
  );

  Widget _buildSubtitle() => Text(
    widget.subtitle,
    style: const TextStyle(
      fontFamily: AppTypography.family,
      fontSize: 10.5,
      fontWeight: FontWeight.w500,
      color: AppColors.muted,
      height: 1.1,
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  Widget _buildTopRow() {
    return Row(
      children: [_buildIconBox(), const Spacer(), _buildArrowButton()],
    );
  }

  Widget _buildBackgroundDecor() {
    return Stack(
      children: [
        Positioned(
          right: -30,
          top: -34,
          child: Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.mainColor.withValues(alpha: 0.060),
            ),
          ),
        ),
        Positioned(
          right: -18,
          bottom: -34,
          child: Container(
            width: 110,
            height: 82,
            decoration: BoxDecoration(
              color: widget.mainColor.withValues(alpha: 0.050),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(80),
                bottomLeft: Radius.circular(80),
                topRight: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
          ),
        ),
        Positioned(
          left: -24,
          bottom: -26,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconBox() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1,
        ),
      ),
      child: Icon(widget.icon, color: widget.mainColor, size: 23),
    );
  }

  Widget _buildArrowButton() {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: widget.mainColor,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.arrow_forward_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }
}
