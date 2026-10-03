package com.vignesh.clinicapp.appointment.service;

import com.vignesh.clinicapp.appointment.repository.AppointmentRepository;
import com.vignesh.clinicapp.appointment.enums.AppointmentStatus;
import com.vignesh.clinicapp.notification.enums.NotificationPriority;
import com.vignesh.clinicapp.notification.enums.NotificationType;
import com.vignesh.clinicapp.notification.service.NotificationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

/** Reminder generation only. Elapsed time is not evidence of completed care. */
@Component
@RequiredArgsConstructor
@Slf4j
public class AppointmentCleanupScheduler {

    private final AppointmentRepository appointmentRepository;
    private final NotificationService notificationService;

    @Scheduled(fixedRateString = "3600000", initialDelayString = "120000")
    @Transactional
    public void createUpcomingAppointmentNotifications() {
        LocalDate today = LocalDate.now();
        LocalDate tomorrow = today.plusDays(1);
        LocalTime now = LocalTime.now();

        appointmentRepository.findUpcomingReminderCandidates(today, tomorrow, AppointmentStatus.CONFIRMED).stream()
                .filter(appointment -> appointment.getAppointmentDate().isAfter(today)
                        || appointment.getAppointmentTime().isAfter(now))
                .forEach(appointment -> notificationService.createNotification(
                        appointment.getUser(),
                        "Upcoming Appointment",
                        "You have an upcoming appointment on "
                                + appointment.getAppointmentDate().format(DateTimeFormatter.ofPattern("MMM d, yyyy"))
                                + " at " + formatTime(appointment.getAppointmentTime()) + ".",
                        NotificationType.APPOINTMENT_UPCOMING,
                        "APPOINTMENT_UPCOMING",
                        appointment.getId(),
                        NotificationPriority.NORMAL));
    }

    private String formatTime(LocalTime time) {
        int hour = time.getHour();
        int minute = time.getMinute();
        String amPm = hour >= 12 ? "PM" : "AM";
        int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return String.format("%d:%02d %s", displayHour, minute, amPm);
    }
}
