import '../config/api_config.dart';
import 'api_service.dart';

class NotificationData {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String createdAt;
  final String? readAt;
  final String? actionType;
  final int? actionId;
  final String priority;

  NotificationData({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.actionType,
    this.actionId,
    required this.priority,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'GENERAL',
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] ?? '',
      readAt: json['readAt'],
      actionType: json['actionType'],
      actionId: json['actionId'],
      priority: json['priority'] ?? 'NORMAL',
    );
  }

  DateTime get createdDate =>
      DateTime.tryParse(createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

  NotificationData copyWith({
    bool? isRead,
    String? readAt,
  }) {
    return NotificationData(
      id: id,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      actionType: actionType,
      actionId: actionId,
      priority: priority,
    );
  }
}

class NotificationService {
  static Future<List<NotificationData>> fetchNotifications({
    int page = 0,
    int size = 20,
  }) async {
    final response = await ApiService.secureGet(
      ApiConfig.notifications(page: page, size: size),
    );

    if (response['success'] == true && response['data'] != null) {
      final list = response['data'] as List;
      return _sortNotifications(
        list.map((e) => NotificationData.fromJson(e)).toList(),
      );
    }

    return [];
  }

  static Future<List<NotificationData>> getNotifications() {
    return fetchNotifications();
  }

  static Future<int> fetchUnreadCount() async {
    final response = await ApiService.secureGet(ApiConfig.notificationsUnread);

    if (response['success'] == true && response['data'] != null) {
      return response['data']['unreadCount'] ?? 0;
    }

    return 0;
  }

  static Future<int> getUnreadCount() {
    return fetchUnreadCount();
  }

  static Future<bool> markAsRead(int id) async {
    final response = await ApiService.securePatch(ApiConfig.notificationRead(id));
    return response['success'] == true;
  }

  static Future<bool> markAllAsRead() async {
    final response = await ApiService.securePatch(ApiConfig.notificationsReadAll);
    return response['success'] == true;
  }

  static Future<bool> deleteNotification(int id) async {
    final response = await ApiService.secureDelete(ApiConfig.notificationDelete(id));
    return response['success'] == true;
  }

  static List<NotificationData> _sortNotifications(
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
