package com.vignesh.clinicapp.treatment.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class SessionResponse {

    private Long id;
    private Long protocolId;
    private String protocolName;

    private int sessionNumber;
    private String sessionName;

    private LocalDate sessionDate;
    private LocalTime sessionTime;
    private int durationMinutes;

    private String status;
}
