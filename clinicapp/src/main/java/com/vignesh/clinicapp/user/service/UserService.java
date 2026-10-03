package com.vignesh.clinicapp.user.service;

import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.notification.enums.NotificationPriority;
import com.vignesh.clinicapp.notification.enums.NotificationType;
import com.vignesh.clinicapp.notification.repository.NotificationRepository;
import com.vignesh.clinicapp.notification.service.NotificationService;
import com.vignesh.clinicapp.user.dto.UpdateProfileRequest;
import com.vignesh.clinicapp.user.dto.UserProfileResponse;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Set;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class UserService {

    private final UserRepository userRepository;
    private final NotificationRepository notificationRepository;
    private final NotificationService notificationService;

    private static final long MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 MB
    private static final Set<String> ALLOWED_IMAGE_TYPES = Set.of(
            "image/jpeg", "image/jpg", "image/png", "image/webp");

    @Value("${app.upload.dir:uploads}")
    private String uploadDir;

    // ── Read ────────────────────────────────────────────
    @Transactional(readOnly = true)
    public ApiResponse<UserProfileResponse> getProfile(String email) {
        User user = findUserOrThrow(email);
        long unreadCount = notificationRepository
                .countByUserIdAndIsReadFalseAndIsDeletedFalse(user.getId());

        log.info("Profile fetched for user: [{}]", email);
        return ApiResponse.success("Profile loaded", toResponse(user, unreadCount));
    }

    // ── Update name / preferred treatment ───────────────
    @Transactional
    public ApiResponse<UserProfileResponse> updateProfile(
            String email, UpdateProfileRequest request) {

        User user = findUserOrThrow(email);

        boolean changed = false;

        if (request.getFullName() != null && !request.getFullName().isBlank()) {
            String trimmed = request.getFullName().trim();
            if (!trimmed.equals(user.getFullName())) {
                user.setFullName(trimmed);
                changed = true;
            }
        }

        if (request.getPreferredTreatment() != null) {
            String pt = request.getPreferredTreatment().trim();
            if (!pt.equals(user.getPreferredTreatment())) {
                user.setPreferredTreatment(pt.isEmpty() ? null : pt);
                changed = true;
            }
        }

        if (changed) {
            userRepository.save(user);
            notificationService.createNotification(
                    user,
                    "Profile Updated",
                    "Your profile information was updated.",
                    NotificationType.PROFILE_UPDATED,
                    null,
                    null,
                    NotificationPriority.NORMAL);
            log.info("Profile updated for user: [{}]", email);
        }

        long unreadCount = notificationRepository
                .countByUserIdAndIsReadFalseAndIsDeletedFalse(user.getId());

        return ApiResponse.success(
                changed ? "Profile updated successfully" : "No changes detected",
                toResponse(user, unreadCount));
    }

    // ── Upload profile image ────────────────────────────
    @Transactional
    public ApiResponse<UserProfileResponse> uploadProfileImage(
            String email, MultipartFile file) {

        if (file == null || file.isEmpty()) {
            return ApiResponse.error("No file provided");
        }

        if (file.getSize() > MAX_IMAGE_BYTES) {
            return ApiResponse.error("Image too large. Maximum is 5 MB");
        }

        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_IMAGE_TYPES.contains(contentType.toLowerCase())) {
            return ApiResponse.error("Only JPG, PNG, or WEBP images are allowed");
        }

        User user = findUserOrThrow(email);

        try {
            byte[] bytes = file.getBytes();
            if (!hasAllowedImageSignature(bytes, contentType)) {
                return ApiResponse.error("Invalid image file");
            }

            // Ensure upload directory exists
            Path uploadPath = Paths.get(uploadDir, "profiles");
            if (!Files.exists(uploadPath)) {
                Files.createDirectories(uploadPath);
            }

            // Save with unique filename: user-{id}-{uuid}.{ext}
            String ext = extensionFor(contentType);
            String filename = "user-" + user.getId() + "-" + UUID.randomUUID() + "." + ext;
            Path target = uploadPath.resolve(filename);

            Files.write(target, bytes);

            // Delete previous image if it was uploaded by us (lives under /uploads/)
            String previous = user.getProfileImageUrl();
            if (previous != null && previous.contains("/uploads/profiles/")) {
                try {
                    String prevName = previous.substring(previous.lastIndexOf('/') + 1);
                    Files.deleteIfExists(uploadPath.resolve(prevName));
                } catch (Exception e) {
                    log.warn("Could not delete previous image: {}", e.getMessage());
                }
            }

            // Save URL (relative — Flutter will prepend base URL)
            String publicUrl = "/uploads/profiles/" + filename;
            user.setProfileImageUrl(publicUrl);
            userRepository.save(user);

            log.info("Profile image uploaded for user: [{}] → [{}]", email, publicUrl);

            long unreadCount = notificationRepository
                    .countByUserIdAndIsReadFalseAndIsDeletedFalse(user.getId());

            return ApiResponse.success(
                    "Profile image updated", toResponse(user, unreadCount));

        } catch (IOException e) {
            log.error("Image upload failed for user [{}]: {}", email, e.getMessage());
            return ApiResponse.error("Failed to save image. Please try again");
        }
    }

    // ── Helpers ─────────────────────────────────────────
    private User findUserOrThrow(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> {
                    log.error("User not found: [{}]", email);
                    return new RuntimeException("User not found");
                });
    }

    private UserProfileResponse toResponse(User user, long unreadCount) {
        return UserProfileResponse.builder()
                .id(user.getId())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole().name())
                .totalPoints(user.getTotalPoints())
                .unreadNotifications(unreadCount)
                .referralCode(user.getReferralCode())
                .profileImageUrl(user.getProfileImageUrl())
                .preferredTreatment(user.getPreferredTreatment())
                .build();
    }

    private String extensionFor(String contentType) {
        return switch (contentType.toLowerCase()) {
            case "image/png" -> "png";
            case "image/webp" -> "webp";
            default -> "jpg";
        };
    }

    private boolean hasAllowedImageSignature(byte[] bytes, String contentType) {
        String normalized = contentType.toLowerCase();
        if (("image/jpeg".equals(normalized) || "image/jpg".equals(normalized))
                && bytes.length >= 3) {
            return (bytes[0] & 0xFF) == 0xFF
                    && (bytes[1] & 0xFF) == 0xD8
                    && (bytes[2] & 0xFF) == 0xFF;
        }
        if ("image/png".equals(normalized) && bytes.length >= 8) {
            return (bytes[0] & 0xFF) == 0x89
                    && bytes[1] == 0x50
                    && bytes[2] == 0x4E
                    && bytes[3] == 0x47
                    && bytes[4] == 0x0D
                    && bytes[5] == 0x0A
                    && bytes[6] == 0x1A
                    && bytes[7] == 0x0A;
        }
        if ("image/webp".equals(normalized) && bytes.length >= 12) {
            return bytes[0] == 0x52
                    && bytes[1] == 0x49
                    && bytes[2] == 0x46
                    && bytes[3] == 0x46
                    && bytes[8] == 0x57
                    && bytes[9] == 0x45
                    && bytes[10] == 0x42
                    && bytes[11] == 0x50;
        }
        return false;
    }
}
