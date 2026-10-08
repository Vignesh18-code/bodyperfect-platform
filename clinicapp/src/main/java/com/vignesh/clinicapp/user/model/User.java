package com.vignesh.clinicapp.user.model;

import com.vignesh.clinicapp.user.enums.Role;
import com.vignesh.clinicapp.user.enums.UserStatus;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@ToString(exclude = {"password", "otp"})
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // ─── Personal Info ─────────────────────────────
    @Column(nullable = false, length = 100)
    private String fullName;

    @Column(nullable = false, unique = true, length = 15)
    private String phone;

    @Column(nullable = false, unique = true, length = 150)
    private String email;

    @Column(name = "otp_attempts")
    private int otpAttempts;

    @Column(name = "otp_locked_until")
    private LocalDateTime otpLockedUntil;

    @Column(length = 100)
    private String preferredTreatment;

    @Column(length = 500)
    private String profileImageUrl;

    private LocalDateTime giftVoucherClaimedAt;

    // ─── Security ──────────────────────────────────
    @Column(nullable = false, length = 255)
    private String password;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private UserStatus status;

    // ─── OTP ───────────────────────────────────────
    @Column(length = 100)
    private String otp;

    @Column(length = 30)
    private String otpPurpose;

    @Column(nullable = false)
    @Builder.Default
    private long tokenVersion = 0;

    @Version
    @Column(nullable = false)
    private long profileVersion;

    private LocalDateTime otpExpiry;

    // ─── Points ────────────────────────────────────
    @Column(nullable = false)
    @Builder.Default
    private Integer totalPoints = 0;

    // ─── Referral Code ─────────────────────────────
    @Column(name = "referral_code", nullable = false, unique = true, length = 10)
    private String referralCode;

    // ─── Login Security ────────────────────────────
    @Column(nullable = false)
    @Builder.Default
    private Integer failedLoginAttempts = 0;

    private LocalDateTime lockedUntil;

    private LocalDateTime lastLoginAt;

    // ─── Soft Delete ───────────────────────────────
    @Column(nullable = false)
    @Builder.Default
    private Boolean isDeleted = false;

    // ─── Timestamps ────────────────────────────────
    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;

    @Column(nullable = false)
    private boolean setupRequired;

    // ─── Lifecycle ─────────────────────────────────
    @PrePersist
    protected void onCreate() {
        createdAt           = LocalDateTime.now();
        status              = UserStatus.PENDING;
        role                = (role != null) ? role : Role.PATIENT;
        failedLoginAttempts = 0;
        totalPoints         = 0;
        isDeleted           = false;

        if (referralCode == null || referralCode.isBlank()) {
            referralCode = generateReferralCode();
        }
    }

    private String generateReferralCode() {
        // BP + 6 uppercase alphanumeric. Service may regenerate on collision.
        String chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no confusing chars (0/O, 1/I)
        StringBuilder sb = new StringBuilder("BP");
        java.security.SecureRandom rnd = new java.security.SecureRandom();
        for (int i = 0; i < 6; i++) {
            sb.append(chars.charAt(rnd.nextInt(chars.length())));
        }
        return sb.toString();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    // ─── Helper Methods ────────────────────────────
    public boolean isLocked() {
        return lockedUntil != null &&
                lockedUntil.isAfter(LocalDateTime.now());
    }

    public boolean isOtpExpired() {
        return otpExpiry == null ||
                otpExpiry.isBefore(LocalDateTime.now());
    }

    public boolean isActive() {
        return UserStatus.ACTIVE.equals(this.status) && !Boolean.TRUE.equals(isDeleted);
    }
    public void incrementFailedAttempts() {
        this.failedLoginAttempts = this.failedLoginAttempts + 1;
    }

    public void resetLoginAttempts() {
        this.failedLoginAttempts = 0;
        this.lockedUntil = null;
    }
}
