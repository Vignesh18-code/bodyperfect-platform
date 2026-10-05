import 'account_privacy_screen.dart';
import '../../widgets/client_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../splash/splash_screen.dart';
import 'widgets/edit_name_sheet.dart';

class ProfileScreen extends StatefulWidget {
  final String fullName;
  final int totalPoints;
  final String initials;
  final VoidCallback? onProfileChanged;

  const ProfileScreen({
    super.key,
    required this.fullName,
    required this.totalPoints,
    required this.initials,
    this.onProfileChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _primaryBlue = Color(0xFF4361EE);
  static const _purpleSoft = Color(0xFF7B61FF);
  static const _gold = Color(0xFFD4A574);
  static const _success = Color(0xFF06B78A);
  static const _danger = Color(0xFFE74C3C);
  static const _textPrimary = Color(0xFF1A1D2E);
  static const _textSecondary = Color(0xFF6B7280);
  static const _borderSoft = Color(0xFFEEF1F8);
  static const _surfaceSoft = Color(0xFFF8FAFD);

  UserProfileData? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await UserService.getProfile();
    if (!mounted) return;

    setState(() {
      _profile = profile;
    });
  }

  String get _displayName => _profile?.fullName.isNotEmpty == true
      ? _profile!.fullName
      : widget.fullName;

  int get _displayPoints => _profile?.totalPoints ?? widget.totalPoints;

  Future<void> _editName() async {
    final newName = await showEditNameSheet(context, currentName: _displayName);

    if (newName == null || newName == _displayName) return;

    final result = await UserService.updateProfile(fullName: newName);
    if (!mounted) return;

    if (result.profile != null) {
      setState(() => _profile = result.profile);
      widget.onProfileChanged?.call();
    }

    _showToast(result.message, isError: !result.success);
  }

  Future<void> _shareReferral() async {
    final code = _profile?.referralCode?.trim();
    if (code == null || code.isEmpty) {
      _showToast('Referral code unavailable', isError: true);
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(0, 0, 1.w, 1.h);

    try {
      await Share.share(
        'Join me on Body Perfect.\nUse my referral code: $code',
        subject: 'Body Perfect Referral Code',
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (!mounted) return;
      _showToast('Could not open share sheet', isError: true);
    }
  }

  void _copyReferral() {
    final code = _profile?.referralCode;
    if (code == null) return;

    Clipboard.setData(ClipboardData(text: code));
    _showToast('Referral code copied');
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17.sp),
        ),
        content: Text(
          'Are you sure you want to log out of Body Perfect?',
          style: TextStyle(fontSize: 13.sp, color: _textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: _textSecondary, fontSize: 13.sp),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.logout();

              if (!mounted) return;
              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
            child: Text(
              'Logout',
              style: TextStyle(
                color: _danger,
                fontWeight: FontWeight.w800,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(fontSize: 13.sp)),
        backgroundColor: isError ? _danger : _success,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.r),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _primaryBlue,
      onRefresh: _loadProfile,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(child: _buildHero()),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 28.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildStatsRow(),
                SizedBox(height: 14.h),
                _buildReferralCard(),
                SizedBox(height: 22.h),
                _buildSectionTitle('Account'),
                SizedBox(height: 10.h),
                _buildSettingsGroup([
                  _buildSettingTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Edit Name',
                    value: _displayName,
                    onTap: _editName,
                  ),
                  _buildSettingTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _profile?.email ?? '',
                    trailing: _readOnlyChip(),
                  ),
                  _buildSettingTile(
                    icon: Icons.phone_iphone_rounded,
                    label: 'Phone',
                    value: _profile?.phone ?? '',
                    trailing: _readOnlyChip(),
                    isLast: true,
                  ),
                ]),
                SizedBox(height: 22.h),
                _buildSectionTitle('App'),
                SizedBox(height: 10.h),
                _buildSettingsGroup([
                  _buildSettingTile(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    value: '${_profile?.unreadNotifications ?? 0} unread',
                    onTap: () {},
                  ),
                  _buildSettingTile(
                    icon: Icons.shield_outlined,
                    label: 'Privacy & account deletion',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccountPrivacyScreen(),
                      ),
                    ),
                  ),
                  _buildSettingTile(
                    icon: Icons.description_outlined,
                    label: 'Terms of Service',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AccountPrivacyScreen(),
                      ),
                    ),
                  ),
                  _buildSettingTile(
                    icon: Icons.info_outline_rounded,
                    label: 'App Version',
                    value: '1.0.0',
                    isLast: true,
                  ),
                ]),
                SizedBox(height: 22.h),
                _buildLogoutButton(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEFF6FF),
            const Color(0xFFF4F1FF),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28.r),
          bottomRight: Radius.circular(28.r),
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.08),
            blurRadius: 22.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: 10.h),
            Row(
              children: [
                Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                    letterSpacing: -0.4.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildAvatar(),
            SizedBox(height: 11.h),
            Text(
              _displayName,
              style: TextStyle(
                fontSize: 21.sp,
                fontWeight: FontWeight.w900,
                color: _textPrimary,
                letterSpacing: -0.45.sp,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: _primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: _primaryBlue.withValues(alpha: 0.12),
                  width: 1.r,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 13.r, color: _gold),
                  SizedBox(width: 5.w),
                  Text(
                    _profile?.role.toLowerCase() == 'patient'
                        ? 'Member'
                        : (_profile?.role ?? 'Member'),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: _primaryBlue,
                      letterSpacing: 0.25.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.r),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: 0.12),
            blurRadius: 18.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: ClientAvatar(initials: _displayName, size: 84.r),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.stars_rounded,
            label: 'Total Points',
            value: '$_displayPoints',
            gradient: [_gold, const Color(0xFFE8C9A0)],
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildStatCard(
            icon: Icons.notifications_active_rounded,
            label: 'Unread',
            value: '${_profile?.unreadNotifications ?? 0}',
            gradient: [_primaryBlue, _purpleSoft],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _borderSoft, width: 1.r),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.12),
            blurRadius: 14.r,
            offset: Offset(0, 5.h),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38.r,
            height: 38.r,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: Colors.white, size: 19.r),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary,
                    letterSpacing: 0.8.sp,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                    letterSpacing: -0.4.sp,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard() {
    final code = _profile?.referralCode ?? '——';

    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 18.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1729), Color(0xFF1E2A4A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F1729).withValues(alpha: 0.18),
            blurRadius: 18.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40.w,
            top: -40.h,
            child: Container(
              width: 140.r,
              height: 140.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _gold.withValues(alpha: 0.22),
                    _gold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30.r,
                    height: 30.r,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _gold.withValues(alpha: 0.22),
                          _gold.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      size: 16.r,
                      color: _gold,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'REFER A FRIEND',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _gold,
                      letterSpacing: 1.4.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Text(
                'Share & earn rewards',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Invite friends with your code and earn bonus points.',
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.35,
                ),
              ),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _copyReferral,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 13.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1.r,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.content_copy_rounded,
                              size: 14.r,
                              color: _gold,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                code,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.5.sp,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  GestureDetector(
                    onTap: _shareReferral,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 13.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_gold, Color(0xFFE8C9A0)],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.ios_share_rounded,
                            size: 15.r,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String label) {
    return Padding(
      padding: EdgeInsets.only(left: 4.w),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 1.2.sp,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _borderSoft, width: 1.r),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String label,
    String? value,
    Widget? trailing,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(color: _borderSoft, width: 1.r),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: _surfaceSoft,
                borderRadius: BorderRadius.circular(11.r),
              ),
              child: Icon(icon, size: 18.r, color: _primaryBlue),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                  if (value != null && value.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13.r,
                color: _textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: _borderSoft,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        'Verified',
        style: TextStyle(
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w700,
          color: _textSecondary,
          letterSpacing: 0.4.sp,
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _handleLogout,
      child: Container(
        width: double.infinity,
        height: 54.h,
        decoration: BoxDecoration(
          color: _danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: _danger.withValues(alpha: 0.2),
            width: 1.2.r,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: _danger, size: 19.r),
            SizedBox(width: 8.w),
            Text(
              'Logout',
              style: TextStyle(
                fontSize: 14.5.sp,
                fontWeight: FontWeight.w800,
                color: _danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
