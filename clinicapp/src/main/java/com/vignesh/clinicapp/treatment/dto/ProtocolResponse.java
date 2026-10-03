package com.vignesh.clinicapp.treatment.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ProtocolResponse {

    private Long id;
    private String protocolName;
    private String treatmentType;
    private String status;

    private BigDecimal weightKg;
    private BigDecimal heightCm;
    private BigDecimal bmi;
    private BigDecimal goalWeightKg;

    private int totalSessions;
    private long completedSessions;
    private int progressPercent;

    private String instructions;
    private LocalDate startDate;
    private LocalDate endDate;

    private SessionResponse nextSession;
    private List<SessionResponse> sessions;
}
