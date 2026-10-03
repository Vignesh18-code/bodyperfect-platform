import '../../core/validation/auth_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/auth_service.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/constants/app_colors.dart';
import 'login_screen.dart';
import 'otp_screen.dart';

class TreatmentItem {
  final IconData icon;
  final String name;
  final Color color;
  final Color bg;

  const TreatmentItem({
    required this.icon,
    required this.name,
    required this.color,
    required this.bg,
  });
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String? _selectedTreatment;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final List<TreatmentItem> _treatments = const [
    TreatmentItem(
      icon: Icons.fitness_center_rounded,
      name: 'Weight Management',
      color: Color(0xFFFF6B6B),
      bg: Color(0xFFFFEEEE),
    ),
    TreatmentItem(
      icon: Icons.spa_rounded,
      name: 'Body Contouring',
      color: Color(0xFFAB7AE0),
      bg: Color(0xFFF3EEFF),
    ),
    TreatmentItem(
      icon: Icons.health_and_safety_rounded,
      name: 'Wellness Consultation',
      color: Color(0xFF4A9FD8),
      bg: Color(0xFFE8F5FF),
    ),
    TreatmentItem(
      icon: Icons.restaurant_rounded,
      name: 'Nutrition Planning',
      color: Color(0xFFFF9F43),
      bg: Color(0xFFFFF4E8),
    ),
    TreatmentItem(
      icon: Icons.sports_gymnastics_rounded,
      name: 'Fitness Training',
      color: Color(0xFF26D07C),
      bg: Color(0xFFE8FFF4),
    ),
    TreatmentItem(
      icon: Icons.face_retouching_natural_rounded,
      name: 'Aesthetic Treatments',
      color: Color(0xFFFF6BAE),
      bg: Color(0xFFFFEEF6),
    ),
  ];

  @override
  void initState() {
    super.initState();
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
      if (mounted) _controller?.forward();
    });

    for (final node in [_nameFocus, _phoneFocus, _emailFocus, _passwordFocus]) {
      node.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ─── Bottom Sheet ─────────────────────────────────────────────────────────────
  void _showTreatmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
              ),
              padding: EdgeInsets.only(
                left: 24.w,
                right: 24.w,
                top: 16.h,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    'Select Treatment',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Choose your preferred wellness program',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey.withValues(alpha: 0.6),
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Treatment list
                  for (final TreatmentItem t in _treatments) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedTreatment = t.name);
                        setSheetState(() {});
                        Navigator.pop(ctx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 16.h,
                        ),
                        decoration: BoxDecoration(
                          color: _selectedTreatment == t.name
                              ? const Color(0xFFEEF3FF)
                              : const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: _selectedTreatment == t.name
                                ? AppColors.primary.withValues(alpha: 0.4)
                                : const Color(0xFFEEEFF3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                t.name,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: _selectedTreatment == t.name
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _selectedTreatment == t.name
                                      ? AppColors.primary
                                      : AppColors.textDark,
                                ),
                              ),
                            ),
                            if (_selectedTreatment == t.name)
                              Icon(
                                Icons.check_rounded,
                                color: AppColors.primary,
                                size: 20.r,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_fadeAnimation == null) {
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
                          SizedBox(height: 36.h),
                          _buildHeader(),
                          SizedBox(height: 36.h),
                          _buildForm(),
                          const Spacer(),
                          _buildFooter(),
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

  // ─── Top Bar ──────────────────────────────────────────────────────────────────
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
        // Step dots
        Row(
          children: List.generate(2, (i) {
            return Container(
              margin: EdgeInsets.only(left: 6.w),
              width: i == 0 ? 24.w : 8.w,
              height: 8.h,
              decoration: BoxDecoration(
                color: i == 0
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

  // ─── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Account',
          style: TextStyle(
            fontSize: 42.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.1,
            letterSpacing: -1.5,
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          'Begin your transformation journey today ✨',
          style: TextStyle(
            fontSize: 15.sp,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ─── Form ─────────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildGlassField(
            controller: _nameController,
            focusNode: _nameFocus,
            hint: 'Full Name',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: 16.h),
          _buildGlassPhoneField(),
          SizedBox(height: 16.h),
          _buildGlassField(
            controller: _emailController,
            focusNode: _emailFocus,
            hint: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: 16.h),
          _buildGlassPasswordField(),
          SizedBox(height: 16.h),
          _buildGlassTreatmentField(),
        ],
      ),
    );
  }

  // ─── Glass Input Field ────────────────────────────────────────────────────────
  Widget _buildGlassField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization? textCapitalization,
  }) {
    final isFocused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 58.h,
      decoration: BoxDecoration(
        color: isFocused
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isFocused ? Colors.white : Colors.white.withValues(alpha: 0.4),
          width: isFocused ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isFocused ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization ?? TextCapitalization.none,
        style: TextStyle(
          fontSize: 16.sp,
          color: isFocused ? AppColors.textDark : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 16.sp,
            color: isFocused
                ? Colors.grey.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            icon,
            size: 22.r,
            color: isFocused
                ? AppColors.primary.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 18.h,
          ),
        ),
        onTap: () => setState(() {}),
        onFieldSubmitted: (_) {
          focusNode.unfocus();
          setState(() {});
        },
      ),
    );
  }

  // ─── Glass Phone Field ────────────────────────────────────────────────────────
  Widget _buildGlassPhoneField() {
    final isFocused = _phoneFocus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 58.h,
      decoration: BoxDecoration(
        color: isFocused
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isFocused ? Colors.white : Colors.white.withValues(alpha: 0.4),
          width: isFocused ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isFocused ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Country Code
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                Text('🇦🇪', style: TextStyle(fontSize: 18.sp)),
                SizedBox(width: 6.w),
                Text(
                  '+971',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: isFocused
                        ? AppColors.textDark
                        : Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                SizedBox(width: 4.w),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16.r,
                  color: isFocused
                      ? Colors.grey.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 24.h,
            color: isFocused
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.3),
          ),
          // Phone Input
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              style: TextStyle(
                fontSize: 16.sp,
                color: isFocused ? AppColors.textDark : Colors.white,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Phone Number',
                hintStyle: TextStyle(
                  fontSize: 16.sp,
                  color: isFocused
                      ? Colors.grey.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 18.h,
                ),
              ),
              onTap: () => setState(() {}),
              onFieldSubmitted: (_) {
                _phoneFocus.unfocus();
                setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Glass Password Field ─────────────────────────────────────────────────────
  Widget _buildGlassPasswordField() {
    final isFocused = _passwordFocus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 58.h,
      decoration: BoxDecoration(
        color: isFocused
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isFocused ? Colors.white : Colors.white.withValues(alpha: 0.4),
          width: isFocused ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isFocused ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        obscureText: _obscurePassword,
        style: TextStyle(
          fontSize: 16.sp,
          color: isFocused ? AppColors.textDark : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: TextStyle(
            fontSize: 16.sp,
            color: isFocused
                ? Colors.grey.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            size: 22.r,
            color: isFocused
                ? AppColors.primary.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
          ),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20.r,
              color: isFocused
                  ? Colors.grey.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 18.h,
          ),
        ),
        onTap: () => setState(() {}),
        onFieldSubmitted: (_) {
          _passwordFocus.unfocus();
          setState(() {});
        },
      ),
    );
  }

  // ─── Glass Treatment Field ────────────────────────────────────────────────────
  Widget _buildGlassTreatmentField() {
    final hasSelected = _selectedTreatment != null;
    return GestureDetector(
      onTap: _showTreatmentPicker,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 58.h,
        decoration: BoxDecoration(
          color: hasSelected
              ? Colors.white.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: hasSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            width: hasSelected ? 2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: hasSelected
                  ? Colors.white.withValues(alpha: 0.4)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: hasSelected ? 20 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              Icon(
                Icons.medical_services_outlined,
                size: 22.r,
                color: hasSelected
                    ? AppColors.primary.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.8),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  _selectedTreatment ?? 'Preferred Treatment',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: hasSelected
                        ? AppColors.textDark
                        : Colors.white.withValues(alpha: 0.7),
                    fontWeight: hasSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: hasSelected
                    ? AppColors.primary.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.7),
                size: 22.r,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Footer ───────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        AppButton(
          text: 'Create Account',
          isLoading: _isLoading,
          onPressed: () async {
            FocusScope.of(context).unfocus();

            // ── Validate fields before API call ──────────
            final validationError =
                AuthValidation.name(_nameController.text) ??
                AuthValidation.phone(_phoneController.text) ??
                AuthValidation.email(_emailController.text) ??
                AuthValidation.newPassword(_passwordController.text);
            if (validationError != null) {
              _showError(validationError);
              return;
            }
            if (_selectedTreatment == null) {
              _showError('Please select a preferred treatment');
              return;
            }

            // ── All valid → call API ─────────────────────
            if (_formKey.currentState!.validate()) {
              setState(() => _isLoading = true);

              final email = _emailController.text.trim();
              final fullName = _nameController.text.trim();

              final result = await AuthService.register(
                fullName: fullName,
                phone: _phoneController.text.trim(),
                email: email,
                password: _passwordController.text,
                preferredTreatment: _selectedTreatment ?? '',
              );

              if (!mounted) return;
              setState(() => _isLoading = false);

              if (result.success) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OtpScreen(email: email, fullName: fullName),
                  ),
                );
              } else {
                _showError(result.message);
              }
            }
          },
        ),
        SizedBox(height: 20.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account?  ',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Error SnackBar ───────────────────────────────────────────────────────────
  void _showError(String message) {
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
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
