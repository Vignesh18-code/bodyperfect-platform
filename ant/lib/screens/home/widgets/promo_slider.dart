import '../../../core/constants/app_typography.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PromoSlider extends StatefulWidget {
  final bool active;
  final ValueChanged<int>? onOpenService;
  const PromoSlider({super.key, this.active = true, this.onOpenService});

  @override
  State<PromoSlider> createState() => _PromoSliderState();
}

class _PromoSliderState extends State<PromoSlider>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentSlide = 0;
  Timer? _slideTimer;
  Timer? _resumeTimer;
  bool _foreground = true;

  late AnimationController _slideAnimController;
  late Animation<double> _slideScale;
  late Animation<double> _slideOpacity;
  late Animation<Offset> _slideOffset;

  final List<_PromoSlide> _slides = const [
    _PromoSlide(
      imagePath: 'assets/images/slide1.png',
      badge: 'IV THERAPY & PEPTIDES',
      title: 'Restore Energy\n& Wellness',
      buttonText: 'Explore',
      accentColor: Color(0xFF3A86FF),
      shadowColor: Color(0xFF3A86FF),
    ),
    _PromoSlide(
      imagePath: 'assets/images/slide2.png',
      badge: 'HYDRA FACIAL',
      title: 'Glow With\nAdvanced Skin Care',
      buttonText: 'Book Now',
      accentColor: Color(0xFFF72585),
      shadowColor: Color(0xFFF72585),
    ),
    _PromoSlide(
      imagePath: 'assets/images/slide3.png',
      badge: 'SLIMMING PROGRAM',
      title: 'Shape Your\nBody Goals',
      buttonText: 'Start Now',
      accentColor: Color(0xFF06D6A0),
      shadowColor: Color(0xFF06D6A0),
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _slideAnimController = AnimationController(
      duration: const Duration(milliseconds: 720),
      vsync: this,
    );

    final curvedAnimation = CurvedAnimation(
      parent: _slideAnimController,
      curve: Curves.easeOutCubic,
    );

    _slideScale = Tween<double>(
      begin: 0.985,
      end: 1.0,
    ).animate(curvedAnimation);

    _slideOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(curvedAnimation);

    _slideOffset = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    _slideAnimController.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAutoSlide();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _slideTimer?.cancel();
    _resumeTimer?.cancel();
    _slideAnimController.dispose();
    super.dispose();
  }

  bool get _canAutoPlay =>
      mounted &&
      widget.active &&
      _foreground &&
      TickerMode.of(context) &&
      !MediaQuery.disableAnimationsOf(context) &&
      !MediaQuery.accessibleNavigationOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startAutoSlide();
  }

  @override
  void didUpdateWidget(covariant PromoSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _startAutoSlide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _slideTimer?.cancel();
    if (!_canAutoPlay || (_resumeTimer?.isActive ?? false)) return;
    _slideTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_canAutoPlay) _goToSlide((_currentSlide + 1) % _slides.length);
    });
  }

  void _pauseAutoSlide() {
    _slideTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) _startAutoSlide();
    });
  }

  void _goToSlide(int index) {
    if (index == _currentSlide) return;

    setState(() => _currentSlide = index);
    if (MediaQuery.disableAnimationsOf(context)) {
      _slideAnimController.value = 1;
    } else {
      _slideAnimController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentSlide];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: '${slide.badge}. ${slide.buttonText}',
            child: GestureDetector(
              onTap: () {
                _pauseAutoSlide();
                widget.onOpenService?.call(const [6, 1, 0][_currentSlide]);
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 50) return;
                _pauseAutoSlide();
                _goToSlide(
                  (_currentSlide + (velocity < 0 ? 1 : -1) + _slides.length) %
                      _slides.length,
                );
              },
              child: AnimatedBuilder(
                animation: _slideAnimController,
                child: _buildPromoCard(slide),
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _slideOpacity,
                    child: SlideTransition(
                      position: _slideOffset,
                      child: Transform.scale(
                        scale: _slideScale.value,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 2.h),
          _buildIndicators(),
        ],
      ),
    );
  }

  Widget _buildPromoCard(_PromoSlide slide) {
    return Container(
      height: 148.h + (MediaQuery.textScalerOf(context).scale(64) - 64),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: slide.shadowColor.withValues(alpha: 0.14),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            slide.imagePath,
            cacheWidth: 1200,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Promo image error: $error');

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [slide.accentColor, const Color(0xFF3A0CA3)],
                  ),
                ),
              );
            },
          ),

          // Main readability overlay.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.60),
                  Colors.black.withValues(alpha: 0.28),
                  Colors.black.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),

          // Premium bottom depth.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.16),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(15.w, 13.h, 15.w, 13.h),
            child: _PromoTextContent(slide: slide),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (i) {
        final isActive = i == _currentSlide;

        return GestureDetector(
          onTap: () {
            _pauseAutoSlide();
            _goToSlide(i);
          },
          child: Semantics(
            button: true,
            label: 'Show promotion ${i + 1} of ${_slides.length}',
            selected: isActive,
            child: SizedBox(
              width: 44,
              height: 32,
              child: Center(
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  width: isActive ? 19.w : 7.w,
                  height: 7.h,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _slides[i].accentColor
                        : Colors.grey.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _PromoTextContent extends StatelessWidget {
  final _PromoSlide slide;

  const _PromoTextContent({required this.slide});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 214.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGlassBadge(slide.badge),
          _buildTitle(),
          _buildGlassButton(),
        ],
      ),
    );
  }

  Widget _buildGlassBadge(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 9.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      slide.title,
      style: TextStyle(
        fontFamily: AppTypography.family,
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.03,
        letterSpacing: -0.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildGlassButton() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slide.buttonText,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 5.w),
          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 13.r),
        ],
      ),
    );
  }
}

class _PromoSlide {
  final String imagePath;
  final String badge;
  final String title;
  final String buttonText;
  final Color accentColor;
  final Color shadowColor;

  const _PromoSlide({
    required this.imagePath,
    required this.badge,
    required this.title,
    required this.buttonText,
    required this.accentColor,
    required this.shadowColor,
  });
}
