package com.vignesh.clinicapp.treatment.controller;

import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.treatment.dto.ProtocolResponse;
import com.vignesh.clinicapp.treatment.dto.SessionResponse;
import com.vignesh.clinicapp.treatment.service.TreatmentService;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Positive;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/api/treatment")
@RequiredArgsConstructor
@Slf4j
@Validated
public class TreatmentController {

    private final TreatmentService treatmentService;

    @GetMapping("/active")
    public ResponseEntity<ApiResponse<ProtocolResponse>> getActiveProtocol(
            Authentication authentication) {

        String email = authentication.getName();
        log.info("GET /api/treatment/active → user: [{}]", email);

        ApiResponse<ProtocolResponse> response = treatmentService.getActiveProtocol(email);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/protocols")
    public ResponseEntity<ApiResponse<List<ProtocolResponse>>> getAllProtocols(
            Authentication authentication) {

        String email = authentication.getName();
        log.info("GET /api/treatment/protocols → user: [{}]", email);

        ApiResponse<List<ProtocolResponse>> response = treatmentService.getAllProtocols(email);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/protocols/{protocolId}")
    public ResponseEntity<ApiResponse<ProtocolResponse>> getProtocolById(
            Authentication authentication,
            @PathVariable @Positive(message = "Protocol id must be positive") Long protocolId) {

        String email = authentication.getName();
        log.info("GET /api/treatment/protocols/{} → user: [{}]", protocolId, email);

        ApiResponse<ProtocolResponse> response = treatmentService.getProtocolById(email, protocolId);

        return response.isSuccess()
                ? ResponseEntity.ok(response)
                : ResponseEntity.badRequest().body(response);
    }

    @GetMapping("/protocols/{protocolId}/sessions")
    public ResponseEntity<ApiResponse<List<SessionResponse>>> getSessionsByMonth(
            Authentication authentication,
            @PathVariable @Positive(message = "Protocol id must be positive") Long protocolId,
            @RequestParam @Min(value = 2020, message = "Invalid year or month")
            @Max(value = 2030, message = "Invalid year or month") int year,
            @RequestParam @Min(value = 1, message = "Invalid year or month")
            @Max(value = 12, message = "Invalid year or month") int month) {

        String email = authentication.getName();
        log.info("GET /api/treatment/protocols/{}/sessions → year: [{}], month: [{}], user: [{}]",
                protocolId, year, month, email);

        ApiResponse<List<SessionResponse>> response =
                treatmentService.getSessionsByMonth(email, protocolId, year, month);

        return response.isSuccess()
                ? ResponseEntity.ok(response)
                : ResponseEntity.badRequest().body(response);
    }

    @GetMapping("/sessions/date")
    public ResponseEntity<ApiResponse<List<SessionResponse>>> getSessionsByDate(
            Authentication authentication,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {

        String email = authentication.getName();
        log.info("GET /api/treatment/sessions/date → date: [{}], user: [{}]", date, email);

        ApiResponse<List<SessionResponse>> response =
                treatmentService.getSessionsByDate(email, date);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/sessions/next")
    public ResponseEntity<ApiResponse<SessionResponse>> getNextSession(
            Authentication authentication) {

        String email = authentication.getName();
        log.info("GET /api/treatment/sessions/next → user: [{}]", email);

        ApiResponse<SessionResponse> response = treatmentService.getNextSession(email);
        return ResponseEntity.ok(response);
    }
}
