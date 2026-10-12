package com.vignesh.clinicapp.auth.dto;
import jakarta.validation.constraints.*;
public record MfaRotationRequest(
 @NotBlank @Size(max=72) String password,
 @NotBlank @Pattern(regexp="[0-9]{6}") String otp) {
 @Override public String toString(){return "MfaRotationRequest[redacted]";}
}
