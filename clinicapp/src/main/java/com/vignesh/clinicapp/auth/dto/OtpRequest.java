package com.vignesh.clinicapp.auth.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class OtpRequest {

    @NotBlank(message = "Email is required")
    @Email(message = "Please enter a valid email")
    private String email;

    @NotBlank(message = "OTP is required")
    @Pattern(
            regexp = "^[0-9]{6}$",
            message = "OTP must be exactly 6 digits"
    )
    private String otp;
}