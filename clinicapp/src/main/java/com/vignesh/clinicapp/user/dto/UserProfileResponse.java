package com.vignesh.clinicapp.user.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class UserProfileResponse {
    private boolean giftVoucherClaimed;
    private Long id;
    private String fullName;
    private String email;
    private String phone;
    private String role;
    private Integer totalPoints;
    private long unreadNotifications;
    private String referralCode;
    private String profileImageUrl;
    private String preferredTreatment;
}
