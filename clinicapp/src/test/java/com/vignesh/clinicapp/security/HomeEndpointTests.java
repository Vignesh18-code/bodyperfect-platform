package com.vignesh.clinicapp.security;

import com.vignesh.clinicapp.auth.service.AuthSessionService;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.repository.UserRepository;
import com.vignesh.clinicapp.treatment.model.*;
import com.vignesh.clinicapp.treatment.enums.*;
import com.vignesh.clinicapp.treatment.repository.*;
import com.vignesh.clinicapp.notification.model.Notification;
import com.vignesh.clinicapp.notification.repository.NotificationRepository;
import com.vignesh.clinicapp.appointment.model.Appointment;
import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.appointment.repository.AppointmentRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.UUID;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.hamcrest.Matchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class HomeEndpointTests {
  @Autowired MockMvc mvc;
  @Autowired UserRepository users;
  @Autowired TreatmentProtocolRepository protocols;
  @Autowired TreatmentSessionRepository treatmentSessions;
  @Autowired NotificationRepository notifications;
  @Autowired AppointmentRepository appointments;
  @Autowired AuthSessionService auth;
  User patient() {
    var id=UUID.randomUUID().toString().replace("-", "");
    var created = users.saveAndFlush(User.builder().fullName("Home audit fixture").email(id+"@example.invalid")
      .phone(id.substring(0,12)).password("unused-test-password").role(Role.PATIENT).status(UserStatus.ACTIVE)
      .referralCode(id.substring(0,10)).totalPoints(42).build());
    created.setStatus(UserStatus.ACTIVE);created.setTotalPoints(42);
    return users.saveAndFlush(created);
  }
  TreatmentProtocol plan(User user) {
    return protocols.saveAndFlush(TreatmentProtocol.builder().user(user).protocolName("Synthetic home plan")
      .treatmentType("Test consultation").totalSessions(3).build());
  }
  TreatmentSession visit(TreatmentProtocol plan, int number, int days, SessionStatus status) {
    return treatmentSessions.saveAndFlush(TreatmentSession.builder().protocol(plan).user(plan.getUser())
      .sessionNumber(number).sessionName("Synthetic visit").sessionDate(LocalDate.now(ZoneId.of("Asia/Dubai")).plusDays(days))
      .sessionTime(LocalTime.of(10,0)).status(status).build());
  }
  String token(User user) { return "Bearer "+auth.issue(user).getAccessToken(); }

  @Test void homeDataIsPatientScopedAndDoesNotExposeSecrets() throws Exception {
    var owner=patient();var outsider=patient();var own=plan(owner);plan(outsider);
    notifications.saveAndFlush(Notification.builder().user(owner).title("Own notice").message("Test").build());
    notifications.saveAndFlush(Notification.builder().user(outsider).title("Other notice").message("Test").build());
    appointments.saveAndFlush(Appointment.builder().user(owner).appointmentDate(LocalDate.now().plusDays(3)).appointmentTime(LocalTime.NOON).branch(Branch.MARINA).build());
    appointments.saveAndFlush(Appointment.builder().user(outsider).appointmentDate(LocalDate.now().plusDays(4)).appointmentTime(LocalTime.NOON).branch(Branch.BURJUMAN).build());
    var bearer=token(owner);
    mvc.perform(get("/api/user/profile").header("Authorization",bearer)).andExpect(status().isOk())
      .andExpect(jsonPath("$.data.id").value(owner.getId())).andExpect(jsonPath("$.data.totalPoints").value(42))
      .andExpect(jsonPath("$.data.unreadNotifications").value(1)).andExpect(jsonPath("$.data.password").doesNotExist()).andExpect(jsonPath("$.data.otp").doesNotExist());
    mvc.perform(get("/api/treatment/active").header("Authorization",bearer)).andExpect(jsonPath("$.data.id").value(own.getId()));
    mvc.perform(get("/api/notifications").header("Authorization",bearer)).andExpect(jsonPath("$.data",hasSize(1))).andExpect(jsonPath("$.data[0].title").value("Own notice"));
    mvc.perform(get("/api/appointments").header("Authorization",bearer)).andExpect(jsonPath("$.data",hasSize(1))).andExpect(jsonPath("$.data[0].branch").value("MARINA"));
  }
  @Test void nextSessionUsesDateAfterReschedulingRatherThanSessionNumber() throws Exception {
    var owner=patient();var plan=plan(owner);
    visit(plan,1,9,SessionStatus.SCHEDULED);
    var nearest=visit(plan,2,2,SessionStatus.SCHEDULED);
    visit(plan,3,1,SessionStatus.CANCELLED);
    mvc.perform(get("/api/treatment/active").header("Authorization",token(owner)))
      .andExpect(jsonPath("$.data.nextSession.id").value(nearest.getId()));
  }
  @Test void inProgressSessionHasPriorityAndPastScheduledSessionIsExcluded() throws Exception {
    var owner=patient();var plan=plan(owner);
    visit(plan,1,1,SessionStatus.SCHEDULED);
    var active=visit(plan,2,-1,SessionStatus.IN_PROGRESS);
    mvc.perform(get("/api/treatment/active").header("Authorization",token(owner)))
      .andExpect(jsonPath("$.data.nextSession.id").value(active.getId()));
    active.setStatus(SessionStatus.COMPLETED);treatmentSessions.saveAndFlush(active);
    var scheduled=treatmentSessions.findByProtocolIdAndIsDeletedFalseOrderBySessionNumberAsc(plan.getId()).get(0);
    scheduled.setSessionDate(LocalDate.now().minusDays(2));treatmentSessions.saveAndFlush(scheduled);
    mvc.perform(get("/api/treatment/active").header("Authorization",token(owner)))
      .andExpect(jsonPath("$.data.nextSession").doesNotExist());
  }
  @Test void emptyHomeStateIsSuccessAndUnauthenticatedRequestsAreDenied() throws Exception {
    var bearer=token(patient());
    mvc.perform(get("/api/treatment/active").header("Authorization",bearer)).andExpect(status().isOk())
      .andExpect(jsonPath("$.success").value(true)).andExpect(jsonPath("$.data").doesNotExist());
    for (var endpoint:new String[]{"/api/user/profile","/api/treatment/active","/api/appointments","/api/notifications"})
      mvc.perform(get(endpoint)).andExpect(status().isUnauthorized());
  }
}
