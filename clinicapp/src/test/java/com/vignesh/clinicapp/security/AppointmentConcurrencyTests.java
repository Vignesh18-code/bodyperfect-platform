package com.vignesh.clinicapp.security;

import com.vignesh.clinicapp.appointment.dto.CreateAppointmentRequest;
import com.vignesh.clinicapp.appointment.enums.*;
import com.vignesh.clinicapp.appointment.model.Appointment;
import com.vignesh.clinicapp.appointment.repository.AppointmentRepository;
import com.vignesh.clinicapp.appointment.service.AppointmentService;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.data.domain.PageRequest;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
class AppointmentConcurrencyTests {
    @Autowired AppointmentService service;
    @Autowired AppointmentRepository appointments;
    @Autowired UserRepository users;

    User user() {
        String id=UUID.randomUUID().toString().substring(0,8);
        User u=users.saveAndFlush(User.builder().email(id+"@example.test").phone(id).fullName("Synthetic")
                .password("unused").role(Role.PATIENT).build());
        u.setStatus(UserStatus.ACTIVE);return users.saveAndFlush(u);
    }
    CreateAppointmentRequest request() {
        var r=new CreateAppointmentRequest();r.setAppointmentDate(LocalDate.now().plusDays(3));
        r.setAppointmentTime(LocalTime.NOON);r.setBranch("BURJUMAN");return r;
    }
    @Test void simultaneousBookingsForOnePatientHaveOneWinner() throws Exception {
        User u=user();var start=new CountDownLatch(1);
        try(var pool=Executors.newFixedThreadPool(8)) {
            List<Future<Boolean>> futures=new ArrayList<>();
            for(int n=0;n<8;n++) futures.add(pool.submit(()->{start.await();return service.createAppointment(u.getEmail(),request()).isSuccess();}));
            start.countDown();int winners=0;
            for(var f:futures)if(f.get(20,TimeUnit.SECONDS))winners++;
            assertEquals(1,winners);
        }
        assertEquals(1,appointments.findActiveByUserId(u.getId(),LocalDate.now(),LocalTime.now()).size());
    }
    @Test void terminalRecordsCannotBeRescheduledAndDoNotPreventNewBooking() {
        User u=user();
        Appointment cancelled=appointments.saveAndFlush(Appointment.builder().user(u).appointmentDate(LocalDate.now().plusDays(2))
                .appointmentTime(LocalTime.NOON).branch(Branch.BURJUMAN).status(AppointmentStatus.CANCELLED).build());
        assertFalse(service.rescheduleAppointment(u.getEmail(),cancelled.getId(),request()).isSuccess());
        assertTrue(service.createAppointment(u.getEmail(),request()).isSuccess());
        assertEquals(2,appointments.findByUserIdAndIsDeletedFalseOrderByAppointmentDateDescAppointmentTimeDesc(u.getId(),PageRequest.of(0,10)).size());
    }
    @Test void pastAppointmentIsPreservedAndPastBookingIsRejectedAtServiceBoundary() {
        User u=user();
        appointments.saveAndFlush(Appointment.builder().user(u).appointmentDate(LocalDate.now().minusDays(1))
                .appointmentTime(LocalTime.NOON).branch(Branch.BURJUMAN).status(AppointmentStatus.CONFIRMED).build());
        var r=request();r.setAppointmentDate(LocalDate.now().minusDays(1));
        assertFalse(service.createAppointment(u.getEmail(),r).isSuccess());
        var history=service.getMyAppointments(u.getEmail()).getData();
        assertEquals(1,history.size());assertEquals("CONFIRMED",history.getFirst().getStatus());
    }
}
