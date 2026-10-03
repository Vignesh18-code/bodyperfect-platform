import '../../../core/constants/app_typography.dart';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../services/notification_service.dart';
import '../../../services/api_service.dart';
import '../../../config/api_config.dart';

Future<void> showNotificationPanel(
  BuildContext context, {
  VoidCallback? onChanged,
  Future<Map<String, dynamic>> Function(String)? fetch,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close notifications',
    barrierColor: Colors.black.withValues(alpha: 0.38),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _NotificationPanel(onChanged: onChanged, fetch: fetch);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

class _NotificationPanel extends StatefulWidget {
  final VoidCallback? onChanged;

  final Future<Map<String, dynamic>> Function(String)? fetch;
  const _NotificationPanel({this.onChanged, this.fetch});

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  List<NotificationData> _notifications = [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _markingAll = false;
  String? _error;
  int _page = 0;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _generation = 0;
  Future<Map<String, dynamic>> _fetch(String url) =>
      (widget.fetch ?? ApiService.secureGet)(url);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_generation;
    setState(() {
      _loadingMore = false;
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _fetch(ApiConfig.notifications(size: 20)),
        _fetch(ApiConfig.notificationsUnread),
      ]);

      if (!mounted || generation != _generation) return;
      if (results.any((r) => r['success'] != true)) {
        throw const FormatException();
      }
      final list = (results[0]['data'] as List)
          .map((r) => NotificationData.fromJson(r))
          .toList();
      setState(() {
        _notifications = _sortNotifications(list);
        _page = 0;
        _hasMore = list.length == 20;
        _unreadCount = results[1]['data']['unreadCount'] as int;
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Notification load failed: $e');
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Could not load notifications';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final result = await _fetch(
        ApiConfig.notifications(page: _page + 1, size: 20),
      );
      if (result['success'] != true) throw const FormatException();
      final list = (result['data'] as List)
          .map((r) => NotificationData.fromJson(r))
          .toList();
      if (!mounted || generation != _generation) return;
      setState(() {
        final ids = _notifications.map((n) => n.id).toSet();
        _notifications.addAll(list.where((n) => !ids.contains(n.id)));
        _page++;
        _hasMore = list.length == 20;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load more notifications. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _markAsRead(NotificationData notification) async {
    if (notification.isRead) return;

    setState(() {
      _notifications = _sortNotifications(
        _notifications
            .map(
              (item) => item.id == notification.id
                  ? item.copyWith(
                      isRead: true,
                      readAt: DateTime.now().toIso8601String(),
                    )
                  : item,
            )
            .toList(),
      );
      _unreadCount = (_unreadCount - 1).clamp(0, 9999).toInt();
    });

    final success = await NotificationService.markAsRead(notification.id);
    if (!mounted) return;
    if (success) widget.onChanged?.call();
    await _load();
  }

  Future<void> _markAllAsRead() async {
    if (_unreadCount == 0 || _markingAll) return;

    setState(() => _markingAll = true);
    final success = await NotificationService.markAllAsRead();
    if (!mounted) return;

    if (success) {
      setState(() {
        _unreadCount = 0;
        _markingAll = false;
        _notifications = _sortNotifications(
          _notifications
              .map(
                (item) => item.copyWith(
                  isRead: true,
                  readAt: item.readAt ?? DateTime.now().toIso8601String(),
                ),
              )
              .toList(),
        );
      });
      widget.onChanged?.call();
      await _load();
    } else {
      setState(() => _markingAll = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final panelWidth = width < 600 ? width * 0.84 : 420.0;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: panelWidth,
          height: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(30.r),
              bottomRight: Radius.circular(30.r),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2D38A8).withValues(alpha: 0.78),
                      const Color(0xFF111827).withValues(alpha: 0.82),
                    ],
                  ),
                  border: Border(
                    right: BorderSide(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 28.r,
                      offset: Offset(10.w, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 16.w, 12.h),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      _loading
                          ? 'Loading…'
                          : _error != null
                          ? 'Unavailable'
                          : _unreadCount == 0
                          ? 'All caught up'
                          : '$_unreadCount unread',
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 24.r,
                ),
              ),
            ],
          ),
          if (_unreadCount > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _markingAll ? null : _markAllAsRead,
                icon: _markingAll
                    ? SizedBox(
                        width: 14.r,
                        height: 14.r,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.done_all_rounded,
                        color: Colors.white,
                        size: 18.r,
                      ),
                label: Text(
                  'Mark all as read',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.4.r,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 42.r,
              ),
              SizedBox(height: 12.h),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              TextButton(
                onPressed: _load,
                child: Text(
                  'Retry',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFF4361EE),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          children: [
            SizedBox(height: 130.h),
            Icon(
              Icons.notifications_none_rounded,
              color: Colors.white.withValues(alpha: 0.78),
              size: 52.r,
            ),
            SizedBox(height: 14.h),
            Text(
              'No notifications yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.family,
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF4361EE),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 26.h),
        itemBuilder: (context, index) {
          if (index == _notifications.length) {
            return TextButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: Text(
                _loadingMore ? 'Loading…' : 'Load more',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }
          return _NotificationTile(
            notification: _notifications[index],
            onTap: () => _markAsRead(_notifications[index]),
          );
        },
        separatorBuilder: (context, index) => SizedBox(height: 10.h),
        itemCount: _notifications.length + (_hasMore ? 1 : 0),
      ),
    );
  }

  List<NotificationData> _sortNotifications(
    List<NotificationData> notifications,
  ) {
    final sorted = List<NotificationData>.from(notifications);
    sorted.sort((a, b) {
      if (a.isRead != b.isRead) {
        return a.isRead ? 1 : -1;
      }
      return b.createdDate.compareTo(a.createdDate);
    });
    return sorted;
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationData notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final readOpacity = notification.isRead ? 0.66 : 1.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: readOpacity,
        child: Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: notification.isRead ? 0.09 : 0.16,
            ),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: notification.isRead ? 0.10 : 0.24,
              ),
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36.r,
                height: 36.r,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconFor(notification.type),
                  color: Colors.white,
                  size: 19.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontFamily: AppTypography.family,
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8.r,
                            height: 8.r,
                            margin: EdgeInsets.only(left: 8.w, top: 4.h),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6B8A),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5.sp,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'APPOINTMENT_BOOKED':
      case 'APPOINTMENT_UPCOMING':
      case 'APPOINTMENT_CANCELLED':
      case 'APPOINTMENT':
        return Icons.event_available_rounded;
      case 'PASSWORD_CHANGED':
      case 'PASSWORD_RESET_REQUESTED':
        return Icons.lock_reset_rounded;
      case 'PROFILE_UPDATED':
        return Icons.person_rounded;
      case 'TREATMENT':
        return Icons.spa_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(String raw) {
    final created = DateTime.tryParse(raw);
    if (created == null) return '';

    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return '${created.day}/${created.month}/${created.year}';
  }
}
