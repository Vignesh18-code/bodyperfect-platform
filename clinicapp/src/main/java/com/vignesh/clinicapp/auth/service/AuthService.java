package com.vignesh.clinicapp.auth.service;

import com.vignesh.clinicapp.auth.dto.*;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.notification.enums.NotificationPriority;
import com.vignesh.clinicapp.notification.enums.NotificationType;
import com.vignesh.clinicapp.notification.service.NotificationService;
import com.vignesh.clinicapp.user.enums.Role;
import com.vignesh.clinicapp.user.enums.UserStatus;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.security.SecureRandom;
import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {
    private static final String VERIFY = "VERIFY_EMAIL";
    private static final String SETUP = "ACCOUNT_SETUP";
    private static final String RESET = "RESET_PASSWORD";
    private static final String RECOVERY_MESSAGE = "If this email exists, a reset code has been sent";
    private static final SecureRandom RANDOM = new SecureRandom();
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;
    private final SanitizationService sanitizationService;
    private final NotificationService notificationService;
    private final AuthSessionService sessions;

    @Transactional
    public ApiResponse<Void> register(RegisterRequest request) {
        String email = sanitizationService.sanitizeEmail(request.getEmail());
        String phone = sanitizationService.sanitizePhone(request.getPhone());
        if (userRepository.findByEmailForUpdate(email).isPresent()) {
            // Never replace pending credentials/profile through unauthenticated re-registration.
            return ApiResponse.error("This email is already registered. Please login or request a new verification code.");
        }
        if (userRepository.existsByPhone(phone)) return ApiResponse.error("This phone number is already registered");
        User user = User.builder().email(email).phone(phone)
                .fullName(sanitizationService.sanitize(request.getFullName()))
                .preferredTreatment(sanitizationService.sanitize(request.getPreferredTreatment()))
                .password(passwordEncoder.encode(request.getPassword())).role(Role.PATIENT).build();
        userRepository.saveAndFlush(user);
        issueCode(user, VERIFY);
        return ApiResponse.success("Registration successful! Please check your email for OTP.");
    }

    @Transactional
    public ApiResponse<LoginResponse> verifyOtp(OtpRequest request) {
        User user = lockedUser(request.getEmail());
        if (!pending(user) || user.isSetupRequired() || !consumeCode(user, request.getOtp(), VERIFY)) {
            return ApiResponse.error("Invalid or expired verification code");
        }
        user.setStatus(UserStatus.ACTIVE);
        user.setTotalPoints(user.getTotalPoints() + 100);
        user.setLastLoginAt(LocalDateTime.now());
        return ApiResponse.success("Welcome! Account verified", sessions.issue(user));
    }

    @Transactional
    public ApiResponse<Void> resendOtp(String email) {
        User user = lockedUser(email);
        if (!pending(user) || user.isSetupRequired() || otpLocked(user)) return ApiResponse.error("Verification code cannot be sent");
        issueCode(user, VERIFY);
        return ApiResponse.success("New OTP sent! Check your email");
    }

    @Transactional
    public ApiResponse<LoginResponse> login(LoginRequest request) {
        User user = lockedUser(request.getEmail());
        if (user == null || Boolean.TRUE.equals(user.getIsDeleted()) || user.isLocked()) {
            return ApiResponse.error("Invalid email or password");
        }
        // Password proof precedes pending-account side effects.
        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            user.incrementFailedAttempts();
            if (user.getFailedLoginAttempts() >= 5) user.setLockedUntil(LocalDateTime.now().plusMinutes(30));
            return ApiResponse.error("Invalid email or password");
        }
        if (pending(user)) {
            if (user.isSetupRequired()) return ApiResponse.error("Use Forgot password to complete your account setup");
            if (!otpLocked(user)) issueCode(user, VERIFY);
            return ApiResponse.error("PENDING_VERIFICATION");
        }
        if (!user.isActive()) return ApiResponse.error("Invalid email or password");
        user.resetLoginAttempts();
        user.setLastLoginAt(LocalDateTime.now());
        return ApiResponse.success("Login successful!", sessions.issue(user));
    }

    public ApiResponse<LoginResponse> refreshToken(String token) { return sessions.refresh(token); }

    @Transactional
    public ApiResponse<Void> forgotPassword(String email) {
        User user = lockedUser(email);
        if (user != null && !otpLocked(user)) {
            if (pending(user) && user.isSetupRequired()) issueCode(user, SETUP);
            else if (user.isActive()) issueCode(user, RESET);
        }
        // Identical public response for missing, blocked, deleted and throttled accounts.
        return ApiResponse.success(RECOVERY_MESSAGE);
    }

    @Transactional
    public ApiResponse<Void> resetPassword(String email, String otp, String password) {
        User user = lockedUser(email);
        boolean setup = pending(user) && user.isSetupRequired();
        if (user == null || (!user.isActive() && !setup) || !consumeCode(user, otp, setup ? SETUP : RESET)) {
            return ApiResponse.error("Invalid or expired reset code");
        }
        user.setPassword(passwordEncoder.encode(password));
        if (setup) { user.setStatus(UserStatus.ACTIVE); user.setSetupRequired(false); }
        user.resetLoginAttempts();
        sessions.revokeAll(user);
        notificationService.createNotification(user, "Password Changed", "Your password was changed successfully.",
                NotificationType.PASSWORD_CHANGED, null, null, NotificationPriority.HIGH);
        return ApiResponse.success("Password reset successful! Please login with your new password");
    }

    private User lockedUser(String email) {
        return userRepository.findByEmailForUpdate(sanitizationService.sanitizeEmail(email)).orElse(null);
    }
    private boolean pending(User user) {
        return user != null && user.getStatus() == UserStatus.PENDING && !Boolean.TRUE.equals(user.getIsDeleted());
    }
    private boolean otpLocked(User user) {
        return user.getOtpLockedUntil() != null && user.getOtpLockedUntil().isAfter(LocalDateTime.now());
    }
    private void issueCode(User user, String purpose) {
        String code = String.valueOf(100000 + RANDOM.nextInt(900000));
        user.setOtp(passwordEncoder.encode(code));
        user.setOtpPurpose(purpose);
        user.setOtpExpiry(LocalDateTime.now().plusMinutes(5));
        // Resending must not reset the wrong-attempt budget while its window is active.
        if (user.getOtpLockedUntil() != null && !otpLocked(user)) {
            user.setOtpAttempts(0);
            user.setOtpLockedUntil(null);
        }
        userRepository.save(user);
        try {
            if (RESET.equals(purpose) || SETUP.equals(purpose)) emailService.sendPasswordResetEmail(user.getEmail(), user.getFullName(), code);
            else emailService.sendOtpEmail(user.getEmail(), user.getFullName(), code);
        } catch (Exception ex) {
            log.warn("Authentication email could not be queued");
        }
    }
    private boolean consumeCode(User user, String code, String purpose) {
        if (otpLocked(user) || !purpose.equals(user.getOtpPurpose()) || user.getOtp() == null
                || user.getOtpExpiry() == null || !user.getOtpExpiry().isAfter(LocalDateTime.now())) return false;
        if (!passwordEncoder.matches(code.trim(), user.getOtp())) {
            user.setOtpAttempts(user.getOtpAttempts() + 1);
            if (user.getOtpAttempts() >= 5) {
                user.setOtpLockedUntil(LocalDateTime.now().plusMinutes(15));
                user.setOtp(null);
                user.setOtpExpiry(null);
            }
            return false;
        }
        user.setOtp(null);
        user.setOtpPurpose(null);
        user.setOtpExpiry(null);
        user.setOtpAttempts(0);
        user.setOtpLockedUntil(null);
        return true;
    }
}
