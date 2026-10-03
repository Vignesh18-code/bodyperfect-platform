package com.vignesh.clinicapp.appointment.controller;

import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.appointment.dto.AppointmentResponse;
import com.vignesh.clinicapp.appointment.dto.CreateAppointmentRequest;
import com.vignesh.clinicapp.appointment.service.AppointmentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/appointments")
@RequiredArgsConstructor
public class AppointmentController {

    private final AppointmentService appointmentService;

    @PostMapping
    public ResponseEntity<ApiResponse<AppointmentResponse>> create(
            @Valid @RequestBody CreateAppointmentRequest request,
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(appointmentService.createAppointment(email, request));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<AppointmentResponse>>> list(
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(appointmentService.getMyAppointments(email));
    }

    @PatchMapping("/{id}/reschedule")
    public ResponseEntity<ApiResponse<AppointmentResponse>> reschedule(
            @PathVariable Long id,
            @Valid @RequestBody CreateAppointmentRequest request,
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(appointmentService.rescheduleAppointment(email, id, request));
    }
}
