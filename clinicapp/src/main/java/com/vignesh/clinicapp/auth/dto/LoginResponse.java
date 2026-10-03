package com.vignesh.clinicapp.auth.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class LoginResponse {

    private String accessToken;
    private String refreshToken;
    private String fullName;
    private String email;
    private String role;
    private Integer totalPoints;
}