import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_colors.dart';
import 'home_data_controller.dart';
import 'widgets/longevity_program.dart';
import 'widgets/program_detail_sheet.dart';
import '../auth/login_screen.dart';
import '../../services/treatment_service.dart';
import '../../widgets/top_notification_toast.dart';
import '../appointments/appointments_screen.dart';
import '../appointments/widgets/book_appointment_sheet.dart';
import '../chat/chat_screen.dart';
import '../search/app_search_screen.dart';
import '../profile/profile_screen.dart';
import '../treatment/treatment_protocol_screen.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/home_header.dart';
import 'widgets/home_scroll_layout.dart';
import 'widgets/longevity_programs.dart';
import 'widgets/notification_panel.dart';
import 'widgets/next_treatment_session.dart';
import 'widgets/promo_slider.dart';
import 'widgets/quick_actions.dart';
import 'widgets/gift_voucher_card.dart';

class HomeScreen extends StatefulWidget {
  final HomeFetch? fetch;
  final bool showWelcomeBonus;
  final int welcomePoints;
  final String welcomeName;

  const HomeScreen({
    super.key,
    this.fetch,
    this.showWelcomeBonus = false,
    this.welcomePoints = 0,
    this.welcomeName = '',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _homeSearch = TextEditingController();
  String _homeQuery = '';
  late final _homeData = HomeDataController(fetch: widget.fetch);
  final _homeScroll = ScrollController();
  final Set<int> _visitedTabs = {0};
  bool _bookingOpen = false;
  bool _programOpen = false;
  bool _notificationsOpen = false;
  bool _promoVisible = true;
  String get _fullName =>
      _homeData.profile?.fullName ??
      (_homeData.loading ? 'Loading…' : 'Welcome');
  int get _totalPoints => _homeData.profile?.totalPoints ?? 0;
  int get _unreadNotifications => _homeData.profile?.unreadNotifications ?? 0;
  ProtocolData? get _activeProtocol => _homeData.protocol;
  int _currentNavIndex = 0;
  int _clinicContactRequest = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeScroll.addListener(_onHomeScroll);
    _homeData.addListener(_onHomeChanged);
    _homeData.refresh();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showWelcomeBonus && mounted) {
        _showWelcomeBonus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _homeData.removeListener(_onHomeChanged);
    _homeData.dispose();
    _homeScroll.dispose();
    _homeSearch.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onHomeScroll() {
    final visible = _homeScroll.offset < 220;
    if (visible != _promoVisible) setState(() => _promoVisible = visible);
  }

  void _onHomeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadUserData() => _homeData.refresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentNavIndex == 0) {
      _homeData.refresh();
    }
  }

  void _navigateTo(int index) {
    FocusScope.of(context).unfocus();
    final returningHome = index == 0 && _currentNavIndex != 0;
    setState(() {
      _visitedTabs.add(index);
      _currentNavIndex = index;
    });
    if (returningHome) _homeData.refresh();
  }

  Future<void> _handleBookAppointment({
    String? programName,
    String? bookingNote,
  }) async {
    if (_bookingOpen || _homeData.sessionExpired) return;
    _bookingOpen = true;
    try {
      // Booking eligibility is enforced by the backend when submitted.
      final result = await showBookAppointmentSheet(
        context,
        initialNote:
            bookingNote ??
            (programName == null
                ? null
                : 'Interested in $programName consultation.'),
      );
      if (result == null || !mounted) return;
      if (result.status == AppointmentSheetStatus.booked) {
        _homeData.refresh();
        showTopNotificationToast(
          context,
          title: 'Appointment Requested',
          message: "We've received your request. Check notifications.",
        );
      } else if (result.status == AppointmentSheetStatus.alreadyExists) {
        showTopNotificationToast(
          context,
          title: 'Appointment Already Exists',
          message: result.message,
          tone: TopNotificationTone.warning,
        );
        _navigateTo(1);
      }
    } finally {
      _bookingOpen = false;
    }
  }

  Future<void> _openService(LongevityProgram program) async {
    if (_programOpen) return;
    _programOpen = true;
    try {
      final result = await showProgramDetailSheet(context, program);
      if (result != ProgramDetailAction.appointment || !mounted) return;
      if (!MediaQuery.disableAnimationsOf(context)) {
        await Future<void>.delayed(const Duration(milliseconds: 240));
      }
      if (mounted) await _handleBookAppointment(programName: program.title);
    } finally {
      _programOpen = false;
    }
  }

  Future<void> _openNotifications() async {
    if (_notificationsOpen || _homeData.sessionExpired) return;
    _notificationsOpen = true;
    try {
      await showNotificationPanel(context, onChanged: _loadUserData);
      if (mounted) await _homeData.refresh();
    } finally {
      _notificationsOpen = false;
    }
  }

  String _getUserInitials() {
    final name = _fullName.trim();
    return name.isEmpty ? 'U' : name.characters.first.toUpperCase();
  }

  void _showWelcomeBonus() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 32.w),
            padding: EdgeInsets.all(32.r),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 30.r,
                  offset: Offset(0, 10.h),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90.r,
                  height: 90.r,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                        blurRadius: 20.r,
                        spreadRadius: 5.r,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.star_rounded,
                    color: const Color(0xFFFF9800),
                    size: 50.r,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Welcome Aboard! 🎉',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                    letterSpacing: -0.5.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                if (widget.welcomeName.isNotEmpty)
                  Text(
                    'Hi ${widget.welcomeName}!',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                SizedBox(height: 8.h),
                Text(
                  'You\'ve earned ${widget.welcomePoints} bonus points\nas a welcome gift! 🎁',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '⭐ ${widget.welcomePoints} Points',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Start My Journey 🚀',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: FadeTransition(
        opacity: MediaQuery.disableAnimationsOf(context)
            ? const AlwaysStoppedAnimation(1)
            : _fadeAnim,
        child: IndexedStack(
          index: _currentNavIndex,
          children: [
            _buildHomeTab(),
            _visitedTabs.contains(1)
                ? const AppointmentsScreen()
                : const SizedBox.shrink(),
            _visitedTabs.contains(2)
                ? TreatmentProtocolScreen(
                    onOpenAppointments: () => _navigateTo(1),
                    onContactClinic: () {
                      _clinicContactRequest++;
                      _navigateTo(3);
                    },
                  )
                : const SizedBox.shrink(),
            _visitedTabs.contains(3)
                ? ChatScreen(
                    onBookAppointment: _handleBookAppointment,
                    onOpenTreatment: () => _navigateTo(2),
                    active: _currentNavIndex == 3,
                    clinicContactRequest: _clinicContactRequest,
                  )
                : const SizedBox.shrink(),
            _visitedTabs.contains(4)
                ? ProfileScreen(
                    onProfileChanged: _loadUserData,
                    fullName: _fullName,
                    totalPoints: _totalPoints,
                    initials: _getUserInitials(),
                  )
                : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentNavIndex,
        initials: _getUserInitials(),
        onTap: _navigateTo,
      ),
    );
  }

  void _openSearchResult(int destination) {
    FocusScope.of(context).unfocus();
    _homeSearch.clear();
    setState(() => _homeQuery = '');
    if (destination >= 100 &&
        destination < 100 + LongevityProgram.catalog.length) {
      _openService(LongevityProgram.catalog[destination - 100]);
    } else if (destination == 5) {
      _openNotifications();
    } else if (destination == 6) {
      _handleBookAppointment();
    } else {
      _navigateTo(destination);
    }
  }

  Widget _buildHomeTab() {
    return HomeScrollLayout(
      cornerOverlap: _homeQuery.trim().isEmpty ? 28.r : 0,
      headerBuilder: (searchVisible) => HomeHeader(
        searchVisible: searchVisible,
        fullName: _fullName,
        accountLoaded: _homeData.profile != null,
        totalPoints: _totalPoints,
        initials: _getUserInitials(),
        unreadNotifications: _unreadNotifications,
        onNotificationsTap: _openNotifications,
        searchController: _homeSearch,
        onSearchChanged: (value) => setState(() => _homeQuery = value),
      ),
      child: _homeQuery.trim().isNotEmpty
          ? HomeSearchResults(query: _homeQuery, onNavigate: _openSearchResult)
          : RefreshIndicator(
              onRefresh: _homeData.refresh,
              child: SingleChildScrollView(
                key: const PageStorageKey('home-scroll'),
                controller: _homeScroll,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.only(top: 28.r, bottom: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 5.h),
                    if (_homeData.profileError != null ||
                        _homeData.treatmentError != null)
                      _buildHomeStatus(),
                    PromoSlider(
                      active: _currentNavIndex == 0 && _promoVisible,
                      onOpenService: (index) =>
                          _openService(LongevityProgram.catalog[index]),
                    ),
                    SizedBox(height: 12.h),
                    if (!_homeData.treatmentLoaded)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          height: 100,
                          child: Center(
                            child: Text(
                              _homeData.loading
                                  ? 'Loading your treatment…'
                                  : 'Treatment information is unavailable. Please retry.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else
                      NextTreatmentSession(
                        onViewPlan: () => _navigateTo(2),
                        protocolName: _activeProtocol?.protocolName,
                        treatmentType: _activeProtocol?.treatmentType,
                        status: _activeProtocol?.status,
                        totalSessions: _activeProtocol?.totalSessions,
                        completedSessions: _activeProtocol?.completedSessions,
                        nextSession: _activeProtocol?.nextSession,
                      ),
                    SizedBox(height: 14.h),
                    QuickActions(
                      onBookAppointment: _handleBookAppointment,
                      onGymMembership: () =>
                          _handleBookAppointment(programName: 'GYM Membership'),
                      onOpenTreatment: () => _navigateTo(2),
                    ),
                    SizedBox(height: 14.h),
                    LongevityPrograms(
                      onBookAppointment: (programName) =>
                          _handleBookAppointment(programName: programName),
                    ),
                    SizedBox(height: 4.h),
                    GiftVoucherCard(
                      onCollect: () => _handleBookAppointment(
                        bookingNote:
                            'I would like to collect the AED 1,000 gift voucher.',
                      ),
                    ),
                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHomeStatus() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _homeData.sessionExpired
                  ? 'Your session has expired. Please sign in again.'
                  : 'Some details could not be refreshed. ${_homeData.profile != null || _homeData.protocol != null ? "Showing the last loaded information." : "Check your connection and retry."}',
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: _homeData.loading
                ? null
                : () {
                    if (_homeData.sessionExpired) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    } else {
                      _homeData.refresh();
                    }
                  },
            child: Text(_homeData.sessionExpired ? 'Sign in' : 'Retry'),
          ),
        ],
      ),
    ),
  );
}
