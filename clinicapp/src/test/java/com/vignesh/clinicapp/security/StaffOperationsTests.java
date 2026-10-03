package com.vignesh.clinicapp.security;

import com.vignesh.clinicapp.operations.*;
import static com.vignesh.clinicapp.operations.OperationsContracts.*;
import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.auth.service.*;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@EnabledIfSystemProperty(named="spring.flyway.enabled",matches="true")
class StaffOperationsTests {
    @Autowired UserRepository users;
    @Autowired OperationsRepository repo;
    @Autowired OperationsService service;
    @Autowired AuthSessionService sessions;
    @Autowired PasswordEncoder encoder;
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate db;
    @MockitoBean EmailService mail;

    User user(Role role) {
        String key=UUID.randomUUID().toString().substring(0,8);
        User u=users.saveAndFlush(User.builder().fullName("Synthetic Staff").email(key+"@example.test").phone(key)
                .role(role).password(encoder.encode("Test@12345")).build());
        u.setStatus(UserStatus.ACTIVE);return users.saveAndFlush(u);
    }
    String token(User u){return sessions.issue(u).getAccessToken();}
    User receptionist(){User u=user(Role.STAFF);repo.member(u.getId(),new MemberInput(Branch.BURJUMAN,StaffRole.RECEPTION,true));return u;}
    @Test void patientAndWrongBranchCannotReadDirectoryOrPatient() throws Exception {
        User reception=receptionist(),patient=user(Role.PATIENT);repo.associate(patient.getId(),Branch.MARINA);
        mvc.perform(get("/api/staff/patients?branch=BURJUMAN").header("Authorization","Bearer "+token(patient))).andExpect(status().isForbidden());
        String access=token(reception);
        mvc.perform(get("/api/staff/patients?branch=MARINA").header("Authorization","Bearer "+access)).andExpect(status().isForbidden());
        mvc.perform(get("/api/staff/patients/"+patient.getId()+"?branch=BURJUMAN").header("Authorization","Bearer "+access)).andExpect(status().isNotFound());
        assertTrue(service.patients(reception.getEmail(),Branch.BURJUMAN,patient.getEmail(),0,25).items().isEmpty());
    }
    @Test void patientEditIsScopedVersionedAndAudited() {
        User reception=receptionist(),patient=user(Role.PATIENT);repo.associate(patient.getId(),Branch.BURJUMAN);
        Patient before=service.patient(reception.getEmail(),Branch.BURJUMAN,patient.getId());
        var edited=service.editPatient(reception.getEmail(),Branch.BURJUMAN,patient.getId(),new PatientEdit("Changed name","500123456",before.version()),"test-request");
        assertEquals(before.version()+1,edited.version());
        assertThrows(org.springframework.web.server.ResponseStatusException.class,()->service.editPatient(reception.getEmail(),Branch.BURJUMAN,patient.getId(),new PatientEdit("Stale","500123456",before.version()),"test-request"));
        assertEquals(1,db.queryForObject("select count(*) from audit_events where entity_id=? and action='PATIENT_UPDATED'",Integer.class,patient.getId()));
    }
    @Test void managerPermissionsAndRevocationAreImmediate() throws Exception {
        User admin=user(Role.ADMIN),reception=receptionist();String access=token(reception);
        assertThrows(org.springframework.security.access.AccessDeniedException.class,()->service.staff(reception.getEmail(),Branch.BURJUMAN));
        assertThrows(org.springframework.security.access.AccessDeniedException.class,()->service.require(admin.getEmail(),Branch.BURJUMAN,true,false));
        service.member(admin.getEmail(),reception.getId(),new MemberInput(Branch.BURJUMAN,StaffRole.RECEPTION,false),"test");
        mvc.perform(get("/api/staff/me").header("Authorization","Bearer "+access)).andExpect(status().isUnauthorized());
        assertThrows(org.springframework.security.access.AccessDeniedException.class,()->service.patients(reception.getEmail(),Branch.BURJUMAN,"",0,25));
    }
    @Test void browserLoginRequiresCsrfAndSetsHttpOnlySecureCookies() throws Exception {
        User reception=receptionist();String body=json.writeValueAsString(Map.of("email",reception.getEmail(),"password","Test@12345"));
        mvc.perform(post("/api/staff-auth/login").contentType("application/json").content(body)).andExpect(status().isForbidden());
        var csrf=mvc.perform(get("/api/staff-auth/csrf")).andExpect(status().isOk()).andReturn().getResponse();
        String csrfValue=json.readTree(csrf.getContentAsString()).get("token").asText();
        var login=mvc.perform(post("/api/staff-auth/login").cookie(csrf.getCookies()).header("X-XSRF-TOKEN",csrfValue)
                .contentType("application/json").content(body)).andExpect(status().isOk()).andExpect(jsonPath("$.data").doesNotExist()).andReturn().getResponse();
        assertTrue(login.getHeaders("Set-Cookie").stream().allMatch(v->v.contains("HttpOnly")&&v.contains("Secure")&&v.contains("SameSite=Strict")));
        String access=login.getHeaders("Set-Cookie").stream().filter(v->v.startsWith("bp_staff_access=")).findFirst().orElseThrow().split(";",2)[0].substring("bp_staff_access=".length());
        mvc.perform(get("/api/staff/me").cookie(new Cookie("bp_staff_access",access))).andExpect(status().isOk());
    }
    @Test void searchEscapesWildcardsAndRejectsUnboundedRequests() throws Exception {
        User reception=receptionist();
        assertTrue(service.patients(reception.getEmail(),Branch.BURJUMAN,"%_",0,25).items().isEmpty());
        mvc.perform(get("/api/staff/patients?branch=BURJUMAN&size=999").header("Authorization","Bearer "+token(reception))).andExpect(status().isBadRequest());
    }
    @Test void appointmentListAndOverviewOnlyUseRequestedBranch() {
        User reception=receptionist();
        assertNotNull(service.overview(reception.getEmail(),Branch.BURJUMAN,java.time.LocalDate.now()));
        assertNotNull(service.appointments(reception.getEmail(),Branch.BURJUMAN,java.time.LocalDate.now(),java.time.LocalDate.now(),0,25,null));
    }
}
