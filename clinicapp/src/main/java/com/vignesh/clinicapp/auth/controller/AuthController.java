package com.vignesh.clinicapp.auth.controller;

import com.vignesh.clinicapp.auth.dto.*;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.auth.service.AuthService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletResponse;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Slf4j
@Validated
public class AuthController {

    private final AuthService authService;
    private final com.vignesh.clinicapp.auth.service.AuthSessionService sessions;

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<Void>> register(
            @Valid @RequestBody RegisterRequest request) {

        log.info("POST /api/auth/register");
        ApiResponse<Void> response = authService.register(request);

        return response.isSuccess()
                ? ResponseEntity.ok(response)
                : ResponseEntity.badRequest().body(response);
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<ApiResponse<LoginResponse>> verifyOtp(
            @Valid @RequestBody OtpRequest request) {

        log.info("POST /api/auth/verify-otp");
        ApiResponse<LoginResponse> response = authService.verifyOtp(request);

        return response.isSuccess()
                ? ResponseEntity.ok(response)
                : ResponseEntity.badRequest().body(response);
    }

    @PostMapping("/resend-otp")
    public ResponseEntity<ApiResponse<Void>> resendOtp(
            @RequestParam @NotBlank(message = "Email is required")
            @Email(message = "Please enter a valid email") String email) {

        log.info("POST /api/auth/resend-otp");
        ApiResponse<Void> response = authService.resendOtp(email);

        return response.isSuccess()
                ? ResponseEntity.ok(response)
                : ResponseEntity.badRequest().body(response);
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponse>> login(
            @Valid @RequestBody LoginRequest request) {

        log.info("POST /api/auth/login");
        ApiResponse<LoginResponse> response = authService.login(request);

        return response.isSuccess()
                ? ResponseEntity.ok(response)
                : ResponseEntity.badRequest().body(response);
    }
    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<LoginResponse>> refreshToken(
            @Valid @RequestBody RefreshRequest request) {

        log.info("POST /api/auth/refresh");
        ApiResponse<LoginResponse> response = authService.refreshToken(request.getRefreshToken());

        return response.isSuccess()
                ? ResponseEntity.ok(response)
                : ResponseEntity.status(HttpServletResponse.SC_UNAUTHORIZED).body(response);
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<ApiResponse<Void>> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request) {

        log.info("POST /api/auth/forgot-password");
        ApiResponse<Void> response = authService.forgotPassword(request.getEmail());

        return response.isSuccess()
                ? ResponseEntity.ok(response)
                : ResponseEntity.badRequest().body(response);
    }

    @PostMapping("/reset-password")
    public ResponseEntity<ApiResponse<Void>> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request) {

        log.info("POST /api/auth/reset-password");
        ApiResponse<Void> response = authService.resetPassword(
                request.getEmail(),
                request.getOtp(),
                request.getNewPassword()
        );

        return response.isSuccess()
                ? ResponseEntity.ok(response)
                : ResponseEntity.badRequest().body(response);
    }
    @PostMapping("/logout")
    public ApiResponse<Void> logout(java.security.Principal principal,
            @RequestHeader("Authorization") String authorization) {
        sessions.logout(principal.getName(), authorization.substring(7), false);
        return ApiResponse.success("Logged out");
    }

    @PostMapping("/logout-all")
    public ApiResponse<Void> logoutAll(java.security.Principal principal,
            @RequestHeader("Authorization") String authorization) {
        sessions.logout(principal.getName(), authorization.substring(7), true);
        return ApiResponse.success("Logged out on all devices");
    }
}
