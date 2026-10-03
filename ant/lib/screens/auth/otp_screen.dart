import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../services/auth_service.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/constants/app_colors.dart';
import '../home/home_screen.dart';
import 'new_password_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String fullName;
  final bool isPasswordReset;

  const OtpScreen({
    super.key,
    required this.email,
    required this.fullName,
    this.isPasswordReset = false,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  final _otpController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String _errorMessage = '';
  bool _disposed = false;

  int _secondsRemaining = 60;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _initAnimation();
    _startCountdown();
  }

  void _initAnimation() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller!,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic),
        );
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !_disposed) _controller?.forward();
    });
  }

  void _startCountdown() {
    _secondsRemaining = 60;
    _canResend = false;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_disposed) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _handleVerify(String otp) async {
    if (otp.length != 6 || _disposed) return;

    FocusScope.of(context).unfocus();

    if (widget.isPasswordReset) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewPasswordScreen(email: widget.email, otp: otp),
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = '';
    });

    final result = await AuthService.verifyOtp(email: widget.email, otp: otp);

    if (!mounted || _disposed) return;
    setState(() => _isVerifying = false);

    if (result.success && result.data != null) {
      await AuthService.handleLoginSuccess(result.data!);
      if (!mounted || _disposed) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            showWelcomeBonus: true,
            welcomePoints: result.data!.totalPoints,
            welcomeName: widget.fullName,
          ),
        ),
        (route) => false,
      );
    } else {
      if (!mounted || _disposed) return;
      setState(() {
        _errorMessage = result.message;
      });
      _otpController.clear();
      _showErrorSnackBar(result.message);
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend || _isResending || _disposed) return;

    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    final result = widget.isPasswordReset
        ? await AuthService.forgotPassword(widget.email)
        : await AuthService.resendOtp(widget.email);

    if (!mounted || _disposed) return;
    setState(() => _isResending = false);

    if (result.success) {
      _startCountdown();
      _showSuccessSnackBar('New OTP sent to ${widget.email}');
    } else {
      _showErrorSnackBar(result.message);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted || _disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20.r),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE74C3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted || _disposed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20.r),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.all(16.r),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fadeAnimation == null || _slideAnimation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AppBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation!,
            child: SlideTransition(
              position: _slideAnimation!,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          _buildTopBar(),
                          SizedBox(height: 40.h),
                          _buildEmailBadge(),
                          SizedBox(height: 28.h),
                          _buildHeader(),
                          SizedBox(height: 40.h),
                          _buildOtpInput(),
                          if (_errorMessage.isNotEmpty) ...[
                            SizedBox(height: 16.h),
                            _buildError(),
                          ],
                          SizedBox(height: 32.h),
                          _buildVerifyButton(),
                          SizedBox(height: 24.h),
                          _buildResendSection(),
                          const Spacer(),
                          _buildHelpText(),
                          SizedBox(height: 28.h),
                        ],
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
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18.r,
            ),
          ),
        ),
        Row(
          children: List.generate(2, (i) {
            return Container(
              margin: EdgeInsets.only(left: 6.w),
              width: i == 1 ? 24.w : 8.w,
              height: 8.h,
              decoration: BoxDecoration(
                color: i == 1
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4.r),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEmailBadge() {
    return Center(
      child: Container(
        width: 80.r,
        height: 80.r,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          Icons.mark_email_read_outlined,
          color: Colors.white.withValues(alpha: 0.95),
          size: 36.r,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          widget.isPasswordReset ? 'Enter Reset Code' : 'Verify Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: 14.h),
        Text(
          'We sent a 6-digit code to',
          style: TextStyle(
            fontSize: 15.sp,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Text(
            widget.email,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: PinCodeTextField(
        appContext: context,
        length: 6,
        controller: _otpController,
        autoFocus: true,
        keyboardType: TextInputType.number,
        animationType: AnimationType.scale,
        animationDuration: const Duration(milliseconds: 200),
        enableActiveFill: true,
        pinTheme: PinTheme(
          shape: PinCodeFieldShape.box,
          borderRadius: BorderRadius.circular(16.r),
          fieldHeight: 58.h,
          fieldWidth: 50.w,
          inactiveColor: Colors.white.withValues(alpha: 0.35),
          inactiveFillColor: Colors.white.withValues(alpha: 0.12),
          selectedColor: Colors.white,
          selectedFillColor: Colors.white.withValues(alpha: 0.95),
          activeColor: Colors.white.withValues(alpha: 0.9),
          activeFillColor: Colors.white.withValues(alpha: 0.95),
          borderWidth: 2,
          selectedBorderWidth: 2.5,
          activeBorderWidth: 2,
        ),
        textStyle: TextStyle(
          fontSize: 24.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        cursorColor: AppColors.primary,
        onCompleted: (otp) {
          _handleVerify(otp);
        },
        onChanged: (value) {
          if (_errorMessage.isNotEmpty) {
            setState(() => _errorMessage = '');
          }
        },
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE74C3C).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFE74C3C).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 20.r,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton() {
    return AppButton(
      text: widget.isPasswordReset ? 'Continue' : 'Verify & Continue',
      isLoading: _isVerifying,
      icon: widget.isPasswordReset
          ? Icons.arrow_forward_rounded
          : Icons.verified_rounded,
      onPressed: () => _handleVerify(_otpController.text),
    );
  }

  Widget _buildResendSection() {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              "Didn't receive the code?",
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            SizedBox(height: 12.h),
            if (_canResend)
              GestureDetector(
                onTap: _isResending ? null : _handleResend,
                child: _isResending
                    ? SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      )
                    : Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28.r,
                    height: 28.r,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _secondsRemaining / 60,
                          strokeWidth: 2.5,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                        Text(
                          '$_secondsRemaining',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'Resend available soon',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpText() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(18.r),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                size: 18.r,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Check your spam folder if you don\'t see the email. OTP expires in 5 minutes.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
