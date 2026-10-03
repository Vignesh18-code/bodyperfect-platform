package com.vignesh.clinicapp.notification.controller;

import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.notification.dto.NotificationResponse;
import com.vignesh.clinicapp.notification.service.NotificationService;
import jakarta.validation.constraints.Positive;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/notifications")
@RequiredArgsConstructor
@Validated
public class NotificationController {

    private final NotificationService notificationService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<NotificationResponse>>> getNotifications(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(notificationService.getNotifications(email, page, size));
    }

    @GetMapping("/unread-count")
    public ResponseEntity<ApiResponse<Map<String, Long>>> getUnreadCount(
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(notificationService.getUnreadCount(email));
    }

    @PutMapping("/{id}/read")
    public ResponseEntity<ApiResponse<Void>> markAsRead(
            @PathVariable @Positive(message = "Notification id must be positive") Long id,
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(notificationService.markAsRead(email, id));
    }

    @PatchMapping("/{id}/read")
    public ResponseEntity<ApiResponse<Void>> patchMarkAsRead(
            @PathVariable @Positive(message = "Notification id must be positive") Long id,
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(notificationService.markAsRead(email, id));
    }

    @PutMapping("/read-all")
    public ResponseEntity<ApiResponse<Void>> markAllAsRead(
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(notificationService.markAllAsRead(email));
    }

    @PatchMapping("/read-all")
    public ResponseEntity<ApiResponse<Void>> patchMarkAllAsRead(
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(notificationService.markAllAsRead(email));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteNotification(
            @PathVariable @Positive(message = "Notification id must be positive") Long id,
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(notificationService.deleteNotification(email, id));
    }
}
