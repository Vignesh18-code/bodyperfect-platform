import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../auth/registration_screen.dart';
import '../auth/login_screen.dart';
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  AnimationController? _flightController;
  AnimationController? _flightFloatController;
  AnimationController? _textController;

  Animation<Offset>? _flightAnimation;
  Animation<double>? _flightScaleAnimation;
  Animation<double>? _flightFloatAnimation;
  Animation<double>? _flightTiltAnimation;
  Animation<double>? _titleAnimation;
  Animation<double>? _subtitleAnimation;
  Animation<Offset>? _titleSlideAnimation;
  Animation<Offset>? _subtitleSlideAnimation;

  final List<Map<String, String>> _carouselContent = [
    {
      'title': 'Transform\nYour Body',
      'subtitle': 'Advanced wellness programs tailored to your lifestyle and goals',
    },
    {
      'title': 'Guided By\nExperts',
      'subtitle': 'Professional consultations for safe, effective, and lasting results',
    },
    {
      'title': 'Achieve\nReal Results',
      'subtitle': 'Track your progress and stay consistent on your health journey',
    },
  ];
  int _currentIndex = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _startCarousel();
  }

  void _initializeAnimations() {
    _flightController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _flightFloatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _flightAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _flightController!,
      curve: Curves.easeInOutCubic,
    ));

    _flightScaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flightController!,
      curve: Curves.easeOut,
    ));

    _flightFloatAnimation = Tween<double>(
      begin: -15.0,
      end: 15.0,
    ).animate(CurvedAnimation(
      parent: _flightFloatController!,
      curve: Curves.easeInOut,
    ));

    _flightTiltAnimation = Tween<double>(
      begin: -0.02,
      end: 0.02,
    ).animate(CurvedAnimation(
      parent: _flightFloatController!,
      curve: Curves.easeInOut,
    ));

    _titleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController!,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController!,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _subtitleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController!,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _subtitleSlideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController!,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _flightController?.forward().then((_) {
          _flightFloatController?.repeat(reverse: true);
        });
        _textController?.forward();
      }
    });
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _carouselContent.length;
        });
        _textController?.reset();
        _textController?.forward();
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _flightController?.dispose();
    _flightFloatController?.dispose();
    _textController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (_flightAnimation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    _buildTopBar(),
                    const Spacer(flex: 1),
                    _buildAnimatedImage(size),
                    const Spacer(flex: 1),
                    _buildContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RegistrationScreen(),
                ),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: EdgeInsets.symmetric(
                horizontal: 24.w,
                vertical: 10.h,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            child: Text(
              "Skip",
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedImage(Size size) {
    return SlideTransition(
      position: _flightAnimation!,
      child: ScaleTransition(
        scale: _flightScaleAnimation!,
        child: AnimatedBuilder(
          animation: _flightFloatController ?? _flightController!,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _flightFloatAnimation?.value ?? 0),
              child: Transform.rotate(
                angle: _flightTiltAnimation?.value ?? 0,
                child: Container(
                  height: size.height * 0.32,
                  width: size.width * 0.7,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 50,
                        spreadRadius: 10,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/Flight.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(40.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.flight_takeoff_rounded,
                          size: 120.r,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(),
          SizedBox(height: 14.h),
          _buildSubtitle(),
          SizedBox(height: 32.h),
          _buildPageIndicators(),
          SizedBox(height: 32.h),
          _buildGetStartedButton(),
          SizedBox(height: 16.h),
          _buildLoginLink(),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return SlideTransition(
      position: _titleSlideAnimation!,
      child: FadeTransition(
        opacity: _titleAnimation!,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            _carouselContent[_currentIndex]['title']!,
            key: ValueKey<int>(_currentIndex),
            style: TextStyle(
              fontSize: 40.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -1,
              shadows: const [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return SlideTransition(
      position: _subtitleSlideAnimation!,
      child: FadeTransition(
        opacity: _subtitleAnimation!,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            _carouselContent[_currentIndex]['subtitle']!,
            key: ValueKey<int>(_currentIndex * 2),
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      children: List.generate(
        3,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: EdgeInsets.only(right: 8.w),
          height: 4.h,
          width: index == _currentIndex ? 32.w : 12.w,
          decoration: BoxDecoration(
            color: index == _currentIndex
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return AppButton(
      text: 'Get Started',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RegistrationScreen(),
          ),
        );
      },
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),  // ← Go to Login!
          ),
        );
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: 24.w,
            vertical: 8.h,
          ),
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            children: const [
              TextSpan(text: "Already have an account? "),
              TextSpan(
                text: "Login",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationThickness: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}