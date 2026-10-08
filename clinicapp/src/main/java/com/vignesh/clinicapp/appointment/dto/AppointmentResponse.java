package com.vignesh.clinicapp.appointment.dto;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Data
@Builder
public class AppointmentResponse {
    private boolean giftVoucherBooking;
    private Long id;
    private Long resourceId;
    private LocalDate appointmentDate;
    private LocalTime appointmentTime;
    private String branch;
    private String status;
    private String note;
    private LocalDateTime createdAt;
}
