package com.vignesh.clinicapp.notification.service;

import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.notification.dto.NotificationResponse;
import com.vignesh.clinicapp.notification.enums.NotificationPriority;
import com.vignesh.clinicapp.notification.enums.NotificationType;
import com.vignesh.clinicapp.notification.model.Notification;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.notification.repository.NotificationRepository;
import com.vignesh.clinicapp.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationService {

    private static final int DEFAULT_PAGE_SIZE = 20;
    private static final int MAX_PAGE_SIZE = 50;

    private final NotificationRepository notificationRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public ApiResponse<List<NotificationResponse>> getNotifications(String email) {
        return getNotifications(email, 0, DEFAULT_PAGE_SIZE);
    }

    @Transactional(readOnly = true)
    public ApiResponse<List<NotificationResponse>> getNotifications(String email, int page, int size) {
        User user = findUserOrThrow(email);
        int safePage = Math.max(page, 0);
        int safeSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);

        List<NotificationResponse> notifications = notificationRepository
                .findByUserIdAndIsDeletedFalseOrderByIsReadAscCreatedAtDesc(
                        user.getId(), PageRequest.of(safePage, safeSize))
                .stream()
                .map(this::toResponse)
                .toList();

        log.info("Notifications fetched for user: [{}] → count: [{}]", email, notifications.size());
        return ApiResponse.success("Notifications loaded", notifications);
    }

    @Transactional(readOnly = true)
    public ApiResponse<Map<String, Long>> getUnreadCount(String email) {
        User user = findUserOrThrow(email);

        long count = notificationRepository
                .countByUserIdAndIsReadFalseAndIsDeletedFalse(user.getId());

        log.info("Unread count for user: [{}] → [{}]", email, count);
        return ApiResponse.success("Unread count loaded", Map.of("unreadCount", count));
    }

    @Transactional
    public ApiResponse<Void> markAsRead(String email, Long notificationId) {
        User user = findUserOrThrow(email);

        Notification notification = notificationRepository
                .findByIdAndUserIdAndIsDeletedFalse(notificationId, user.getId())
                .orElse(null);

        if (notification == null) {
            return ApiResponse.error("Notification not found");
        }

        notification.setIsRead(true);
        notification.setReadAt(java.time.LocalDateTime.now());
        notificationRepository.save(notification);

        log.info("Notification [{}] marked as read for user: [{}]", notificationId, email);
        return ApiResponse.success("Notification marked as read", null);
    }

    @Transactional
    public ApiResponse<Void> markAllAsRead(String email) {
        User user = findUserOrThrow(email);

        int updated = notificationRepository.markAllAsRead(user.getId());

        log.info("Marked [{}] notifications as read for user: [{}]", updated, email);
        return ApiResponse.success("All notifications marked as read", null);
    }

    @Transactional
    public ApiResponse<Void> deleteNotification(String email, Long notificationId) {
        User user = findUserOrThrow(email);

        Notification notification = notificationRepository
                .findByIdAndUserIdAndIsDeletedFalse(notificationId, user.getId())
                .orElse(null);

        if (notification == null) {
            return ApiResponse.error("Notification not found");
        }

        notification.setIsDeleted(true);
        notificationRepository.save(notification);

        log.info("Notification [{}] soft-deleted for user: [{}]", notificationId, email);
        return ApiResponse.success("Notification deleted", null);
    }

    @Transactional
    public void createNotification(
            User user,
            String title,
            String message,
            NotificationType type,
            String actionType,
            Long actionId,
            NotificationPriority priority) {

        if (user == null || user.getId() == null) {
            return;
        }

        if (actionType != null && actionId != null
                && notificationRepository.existsByUserIdAndTypeAndActionTypeAndActionIdAndIsDeletedFalse(
                user.getId(), type, actionType, actionId)) {
            log.debug("Notification skipped as duplicate user=[{}] type=[{}] action=[{}:{}]",
                    user.getId(), type, actionType, actionId);
            return;
        }

        Notification notification = Notification.builder()
                .user(user)
                .title(title)
                .message(message)
                .type(type)
                .actionType(actionType)
                .actionId(actionId)
                .priority(priority == null ? NotificationPriority.NORMAL : priority)
                .isRead(false)
                .isDeleted(false)
                .build();

        notificationRepository.save(notification);
    }

    private User findUserOrThrow(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> {
                    log.error("User not found: [{}]", email);
                    return new RuntimeException("User not found");
                });
    }

    private NotificationResponse toResponse(Notification n) {
        return NotificationResponse.builder()
                .id(n.getId())
                .title(n.getTitle())
                .message(n.getMessage())
                .type(n.getType().name())
                .isRead(n.getIsRead())
                .createdAt(n.getCreatedAt())
                .readAt(n.getReadAt())
                .actionType(n.getActionType())
                .actionId(n.getActionId())
                .priority(n.getPriority().name())
                .build();
    }
}
