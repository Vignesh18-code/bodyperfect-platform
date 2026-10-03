package com.vignesh.clinicapp.user.dto;

import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class UpdateProfileRequest {

    @Size(min = 2, max = 100, message = "Name must be 2-100 characters")
    private String fullName;

    @Size(max = 100, message = "Preferred treatment too long")
    private String preferredTreatment;
}
