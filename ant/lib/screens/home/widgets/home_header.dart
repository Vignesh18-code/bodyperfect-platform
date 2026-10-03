import '../../../core/constants/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/client_avatar.dart';

class HomeHeader extends StatefulWidget {
  final bool searchVisible;
  final bool accountLoaded;
  final String fullName;
  final int totalPoints;
  final String initials;
  final int unreadNotifications;
  final VoidCallback? onNotificationsTap;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const HomeHeader({
    super.key,
    this.searchVisible = true,
    this.accountLoaded = true,
    required this.fullName,
    required this.totalPoints,
    required this.initials,
    this.unreadNotifications = 0,
    this.onNotificationsTap,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader>
    with SingleTickerProviderStateMixin {
  final _searchFocus = FocusNode();
  late AnimationController _headerFadeController;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChanged);

    _headerFadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerFade = CurvedAnimation(
      parent: _headerFadeController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _headerFadeController.value = 1;
      } else {
        _headerFadeController.forward();
      }
    });
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _searchFocus.removeListener(_onFocusChanged);
    _searchFocus.dispose();
    _headerFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return FadeTransition(
      opacity: _headerFade,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: topPad + 16.h,
          left: 20.w,
          right: 20.w,
          bottom: 16.h,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.brandBlue, AppColors.brandIndigo],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28.r),
            bottomRight: Radius.circular(28.r),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildProfileAvatar(),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hello, Welcome 🎉',
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 12.sp,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        widget.fullName,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 21.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.55,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildPointsPill(),
                SizedBox(width: 10.w),
                _buildBellIcon(),
              ],
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.searchController,
              builder: (context, value, child) {
                // Preserve the field while typing or reviewing search results.
                final visible =
                    widget.searchVisible ||
                    _searchFocus.hasFocus ||
                    value.text.isNotEmpty;
                return TweenAnimationBuilder<double>(
                  tween: Tween(end: visible ? 1 : 0),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  child: child,
                  builder: (context, progress, child) => ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: progress,
                      child: IgnorePointer(
                        ignoring: !visible,
                        child: ExcludeFocus(
                          excluding: !visible,
                          child: ExcludeSemantics(
                            excluding: !visible,
                            child: Opacity(opacity: progress, child: child),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.only(top: 16.h),
                child: _buildSearchBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      padding: EdgeInsets.all(1.5.r),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(48.r),
        child: ClientAvatar(initials: widget.initials, size: 44.r),
      ),
    );
  }

  Widget _buildPointsPill() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.monetization_on_rounded,
            color: AppColors.gold,
            size: 16.r,
          ),
          SizedBox(width: 5.w),
          Text(
            widget.accountLoaded ? '${widget.totalPoints}' : '—',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBellIcon() {
    final count = widget.unreadNotifications;

    return GestureDetector(
      onTap: widget.onNotificationsTap,
      child: SizedBox(
        width: 40.r,
        height: 40.r,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 26.r,
              color: Colors.white,
            ),
            if (count > 0)
              Positioned(
                top: 6.h,
                right: 6.w,
                child: Container(
                  width: 16.r,
                  height: 16.r,
                  decoration: const BoxDecoration(
                    color: AppColors.rose,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: widget.searchController,
      focusNode: _searchFocus,
      onChanged: widget.onSearchChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(
        fontFamily: AppTypography.family,
        fontSize: 14,
        height: 1.3,
        color: Colors.white,
      ),
      cursorColor: Colors.white,
      maxLength: 100,
      decoration: InputDecoration(
        hintText: 'Search treatments, appointments…',
        hintStyle: const TextStyle(
          fontFamily: AppTypography.family,
          fontSize: 13,
          color: Colors.white70,
        ),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withValues(alpha: .16),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 21,
          color: Colors.white,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 46,
          minHeight: 48,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.searchController,
          builder: (context, value, child) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    widget.searchController.clear();
                    widget.onSearchChanged('');
                    FocusScope.of(context).unfocus();
                  },
                ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white70, width: 1.2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
