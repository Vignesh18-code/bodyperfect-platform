import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ReportData {
  final String title;
  final DateTime date;
  final double sizeMB;
  final String? fileUrl;

  const ReportData({
    required this.title,
    required this.date,
    required this.sizeMB,
    this.fileUrl,
  });
}

class ReportsCard extends StatefulWidget {
  final List<ReportData>? reports;

  const ReportsCard({super.key, this.reports});

  @override
  State<ReportsCard> createState() => _ReportsCardState();
}

class _ReportsCardState extends State<ReportsCard>
    with SingleTickerProviderStateMixin {
  // ── Premium Color Palette ─────────────────────────────
  static const _navy = Color(0xFF0F1729);
  static const _navyLight = Color(0xFF1E2A4A);
  static const _gold = Color(0xFFD4A574);
  static const _accent = Color(0xFF4361EE);
  static const _success = Color(0xFF06B78A);
  static const _pdfRed = Color(0xFFE74C3C);
  static const _textPrimary = Color(0xFF0F1729);
  static const _textSecondary = Color(0xFF6B7280);
  static const _borderSoft = Color(0xFFEEF1F8);
  static const _surfaceSoft = Color(0xFFF8FAFD);

  late final List<ReportData> _reports;
  final Set<int> _downloadingSet = {};
  final Set<int> _downloadedSet = {};

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  // Sort: Newest, Oldest, Largest, Smallest
  int _sortIndex = 0;
  static const _sortLabels = ['Newest', 'Oldest', 'Largest', 'Smallest'];

  @override
  void initState() {
    super.initState();
    _reports = widget.reports ?? const [];

    _animController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<ReportData> get _sorted {
    final list = List<ReportData>.from(_reports);
    switch (_sortIndex) {
      case 0:
        list.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 1:
        list.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 2:
        list.sort((a, b) => b.sizeMB.compareTo(a.sizeMB));
        break;
      case 3:
        list.sort((a, b) => a.sizeMB.compareTo(b.sizeMB));
        break;
    }
    return list;
  }

  void _onDownload(int globalIndex) {
    if (_downloadedSet.contains(globalIndex) ||
        _downloadingSet.contains(globalIndex)) {
      return;
    }

    setState(() => _downloadingSet.add(globalIndex));

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _downloadingSet.remove(globalIndex);
        _downloadedSet.add(globalIndex);
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _downloadedSet.remove(globalIndex));
      });
    });
  }

  void _onView(ReportData report) {
    // Preview action — backend integration later
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: _navy.withValues(alpha: 0.06),
              blurRadius: 32.r,
              offset: Offset(0, 10.h),
            ),
            BoxShadow(
              color: _accent.withValues(alpha: 0.03),
              blurRadius: 48.r,
              offset: Offset(0, 20.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.r),
          child: Column(
            children: [
              _buildHeader(),
              if (sorted.isEmpty)
                _buildEmptyState()
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                  child: Column(
                    children: List.generate(sorted.length, (i) {
                      final report = sorted[i];
                      final globalIndex = _reports.indexOf(report);
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: i < sorted.length - 1 ? 10.h : 0,
                        ),
                        child: _buildReportItem(report, globalIndex),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
      decoration: BoxDecoration(
        color: _surfaceSoft,
        border: Border(
          bottom: BorderSide(color: _borderSoft, width: 1.r),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_navy, _navyLight],
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: _navy.withValues(alpha: 0.18),
                      blurRadius: 10.r,
                      offset: Offset(0, 4.h),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.folder_special_rounded,
                  size: 20.r,
                  color: _gold,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Medical Reports',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${_reports.length} ${_reports.length == 1 ? "document" : "documents"} available',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildSortButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<int>(
      initialValue: _sortIndex,
      onSelected: (val) => setState(() => _sortIndex = val),
      offset: Offset(0, 38.h),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.r),
        side: BorderSide(color: _borderSoft, width: 1.r),
      ),
      itemBuilder: (ctx) => List.generate(
        _sortLabels.length,
        (i) => PopupMenuItem<int>(
          value: i,
          height: 40.h,
          child: Row(
            children: [
              Icon(
                _sortIndex == i
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 16.r,
                color: _sortIndex == i ? _accent : _textSecondary,
              ),
              SizedBox(width: 10.w),
              Text(
                _sortLabels[i],
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: _sortIndex == i ? FontWeight.w700 : FontWeight.w500,
                  color: _sortIndex == i ? _textPrimary : _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: _borderSoft, width: 1.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 14.r, color: _textPrimary),
            SizedBox(width: 5.w),
            Text(
              _sortLabels[_sortIndex],
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 36.h, horizontal: 24.w),
      child: Column(
        children: [
          Container(
            width: 64.r,
            height: 64.r,
            decoration: BoxDecoration(
              color: _borderSoft,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Icon(
              Icons.description_outlined,
              size: 30.r,
              color: _textSecondary,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            'No reports yet',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Your medical documents will appear here\nonce uploaded by your clinic.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Report Item ────────────────────────────────────
  Widget _buildReportItem(ReportData report, int globalIndex) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final isDownloading = _downloadingSet.contains(globalIndex);
    final isDownloaded = _downloadedSet.contains(globalIndex);
    final dateStr = '${months[report.date.month - 1]} ${report.date.day}, ${report.date.year}';

    return GestureDetector(
      onTap: () => _onView(report),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: _borderSoft,
            width: 1.r,
          ),
        ),
        child: Row(
          children: [
            // ── PDF Icon (premium, document-style) ───────
            _buildPdfIcon(),

            SizedBox(width: 12.w),

            // ── Title + Meta ─────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    report.title,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 5.h),
                  Row(
                    children: [
                      Icon(
                        Icons.event_outlined,
                        size: 11.r,
                        color: _textSecondary,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w500,
                          color: _textSecondary,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: 3.r,
                        height: 3.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _textSecondary.withValues(alpha: 0.4),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${report.sizeMB.toStringAsFixed(1)} MB',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(width: 8.w),

            // ── Action buttons (View / Download) ──────────
            _buildActionButtons(globalIndex, isDownloading, isDownloaded),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfIcon() {
    return Container(
      width: 44.r,
      height: 52.r,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _pdfRed.withValues(alpha: 0.95),
            _pdfRed.withValues(alpha: 0.75),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _pdfRed.withValues(alpha: 0.25),
            blurRadius: 8.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Folded corner
          Positioned(
            top: 0,
            right: 0,
            child: ClipPath(
              clipper: _CornerClipper(),
              child: Container(
                width: 12.r,
                height: 12.r,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ),
          // PDF Label
          Positioned(
            bottom: 6.h,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'PDF',
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(int globalIndex, bool isDownloading, bool isDownloaded) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View button (icon only)
        GestureDetector(
          onTap: () => _onView(_reports[globalIndex]),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: _surfaceSoft,
              borderRadius: BorderRadius.circular(11.r),
              border: Border.all(color: _borderSoft, width: 1.r),
            ),
            child: Icon(
              Icons.visibility_outlined,
              size: 16.r,
              color: _textPrimary,
            ),
          ),
        ),
        SizedBox(width: 6.w),
        // Download button
        GestureDetector(
          onTap: () => _onDownload(globalIndex),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              gradient: isDownloaded
                  ? LinearGradient(
                      colors: [_success, _success.withValues(alpha: 0.85)],
                    )
                  : const LinearGradient(
                      colors: [_navy, _navyLight],
                    ),
              borderRadius: BorderRadius.circular(11.r),
              boxShadow: [
                BoxShadow(
                  color: (isDownloaded ? _success : _navy).withValues(alpha: 0.22),
                  blurRadius: 8.r,
                  offset: Offset(0, 3.h),
                ),
              ],
            ),
            child: Center(
              child: isDownloading
                  ? SizedBox(
                      width: 14.r,
                      height: 14.r,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _gold,
                      ),
                    )
                  : Icon(
                      isDownloaded
                          ? Icons.check_rounded
                          : Icons.file_download_outlined,
                      size: 17.r,
                      color: isDownloaded ? Colors.white : _gold,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
