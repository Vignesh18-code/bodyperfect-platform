package com.vignesh.clinicapp.security;

import com.vignesh.clinicapp.auth.dto.*;
import com.vignesh.clinicapp.auth.service.*;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import com.vignesh.clinicapp.treatment.model.*;
import com.vignesh.clinicapp.treatment.repository.*;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthLifecycleTests {
    @Autowired AuthService auth;
    @Autowired AuthSessionService sessions;
    @Autowired UserRepository users;
    @Autowired PasswordEncoder encoder;
    @Autowired MockMvc mvc;
    @Autowired TreatmentProtocolRepository protocols;
    @Autowired TreatmentSessionRepository treatmentSessions;
    @MockitoBean EmailService mail;

    User user(UserStatus status) {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        User u = users.saveAndFlush(User.builder().email(suffix+"@example.test").phone(suffix)
                .fullName("Synthetic User").password(encoder.encode("Test@12345")).role(Role.PATIENT).build());
        u.setStatus(status); u.setTotalPoints(777);
        return users.saveAndFlush(u);
    }
    OtpRequest otp(User u, String code) {
        OtpRequest r = new OtpRequest(); r.setEmail(u.getEmail()); r.setOtp(code); return r;
    }
    String code(User u, boolean reset) {
        ArgumentCaptor<String> c = ArgumentCaptor.forClass(String.class);
        if (reset) verify(mail, atLeastOnce()).sendPasswordResetEmail(eq(u.getEmail()), anyString(), c.capture());
        else verify(mail, atLeastOnce()).sendOtpEmail(eq(u.getEmail()), anyString(), c.capture());
        return c.getValue();
    }
    @Test void recoveryCodeCannotVerifyAccountOrAlterPoints() {
        User u = user(UserStatus.ACTIVE); auth.forgotPassword(u.getEmail()); String code = code(u,true);
        assertNotEquals(code, users.findById(u.getId()).orElseThrow().getOtp());
        assertFalse(auth.verifyOtp(otp(u,code)).isSuccess());
        assertEquals(777,users.findById(u.getId()).orElseThrow().getTotalPoints());
        assertTrue(auth.resetPassword(u.getEmail(),code,"Changed@123").isSuccess());
        assertFalse(auth.resetPassword(u.getEmail(),code,"Changed@456").isSuccess());
    }
    @Test void blockedAndDeletedUsersCannotBeReactivatedOrUseTokens() throws Exception {
        for (boolean deleted: List.of(false,true)) {
            User u = user(UserStatus.ACTIVE); LoginResponse tokens = sessions.issue(u);
            if(deleted) u.setIsDeleted(true); else u.setStatus(UserStatus.BLOCKED);
            users.saveAndFlush(u);
            assertFalse(auth.resendOtp(u.getEmail()).isSuccess());
            assertFalse(auth.verifyOtp(otp(u,"123456")).isSuccess());
            assertFalse(auth.refreshToken(tokens.getRefreshToken()).isSuccess());
            mvc.perform(get("/api/user/profile").header("Authorization","Bearer "+tokens.getAccessToken()))
                    .andExpect(status().isUnauthorized());
            assertEquals(777,users.findById(u.getId()).orElseThrow().getTotalPoints());
        }
    }
    @Test void resetRevokesAccessAndRefreshAcrossDevices() throws Exception {
        User u = user(UserStatus.ACTIVE); LoginResponse a=sessions.issue(u), b=sessions.issue(u);
        auth.forgotPassword(u.getEmail());
        assertTrue(auth.resetPassword(u.getEmail(),code(u,true),"Changed@123").isSuccess());
        for(LoginResponse t: List.of(a,b)) {
            assertFalse(auth.refreshToken(t.getRefreshToken()).isSuccess());
            mvc.perform(get("/api/user/profile").header("Authorization","Bearer "+t.getAccessToken()))
                    .andExpect(status().isUnauthorized());
        }
    }
    @Test void refreshRotatesAndReplayRevokesOnlyThatFamily() throws Exception {
        User u=user(UserStatus.ACTIVE); LoginResponse a=sessions.issue(u), other=sessions.issue(u);
        var rotated=auth.refreshToken(a.getRefreshToken()); assertTrue(rotated.isSuccess());
        assertNotEquals(a.getRefreshToken(),rotated.getData().getRefreshToken());
        assertFalse(auth.refreshToken(a.getRefreshToken()).isSuccess());
        assertFalse(auth.refreshToken(rotated.getData().getRefreshToken()).isSuccess());
        mvc.perform(get("/api/user/profile").header("Authorization","Bearer "+rotated.getData().getAccessToken()))
                .andExpect(status().isUnauthorized());
        assertTrue(auth.refreshToken(other.getRefreshToken()).isSuccess());
    }
    @Test void concurrentVerificationAwardsPointsExactlyOnce() throws Exception {
        User u=user(UserStatus.PENDING); auth.resendOtp(u.getEmail()); String code=code(u,false);
        CountDownLatch start=new CountDownLatch(1);
        try(var pool=Executors.newFixedThreadPool(4)) {
            List<Future<Boolean>> outcomes=new ArrayList<>();
            for(int n=0;n<4;n++) outcomes.add(pool.submit(()->{start.await();return auth.verifyOtp(otp(u,code)).isSuccess();}));
            start.countDown(); int successes=0;
            for(var result:outcomes) if(result.get(15,TimeUnit.SECONDS)) successes++;
            assertEquals(1,successes);
        }
        assertEquals(877,users.findById(u.getId()).orElseThrow().getTotalPoints());
    }
    @Test void resendAndReregistrationCannotResetAttemptBudgetOrCredentials() {
        User u=user(UserStatus.PENDING); auth.resendOtp(u.getEmail()); String original=code(u,false);
        for(int n=0;n<4;n++) assertFalse(auth.verifyOtp(otp(u,"000000")).isSuccess());
        auth.resendOtp(u.getEmail());
        assertFalse(auth.verifyOtp(otp(u,"000000")).isSuccess());
        assertFalse(auth.resendOtp(u.getEmail()).isSuccess());
        RegisterRequest request=new RegisterRequest();request.setEmail(u.getEmail());request.setPhone(u.getPhone());
        request.setFullName("Attacker");request.setPassword("Attacker@123");request.setPreferredTreatment("x");
        assertFalse(auth.register(request).isSuccess());
        User saved=users.findById(u.getId()).orElseThrow();
        assertTrue(encoder.matches("Test@12345",saved.getPassword()));
        assertNotNull(saved.getOtpLockedUntil());
        assertFalse(auth.verifyOtp(otp(u,original)).isSuccess());
    }
    @Test void expiredCodesAndWrongPurposeDoNotConsumeValidRegistration() {
        User u=user(UserStatus.PENDING);auth.resendOtp(u.getEmail());String code=code(u,false);
        assertFalse(auth.resetPassword(u.getEmail(),code,"Changed@123").isSuccess());
        u=users.findById(u.getId()).orElseThrow();u.setOtpExpiry(LocalDateTime.now().minusSeconds(1));users.saveAndFlush(u);
        assertFalse(auth.verifyOtp(otp(u,code)).isSuccess());
    }
    @Test void logoutRevokesDeviceAndLogoutAllRevokesRemainingDevices() throws Exception {
        User u=user(UserStatus.ACTIVE);LoginResponse a=sessions.issue(u),b=sessions.issue(u);
        mvc.perform(post("/api/auth/logout").header("Authorization","Bearer "+a.getAccessToken())).andExpect(status().isOk());
        assertFalse(auth.refreshToken(a.getRefreshToken()).isSuccess());
        mvc.perform(post("/api/auth/logout-all").header("Authorization","Bearer "+b.getAccessToken())).andExpect(status().isOk());
        assertFalse(auth.refreshToken(b.getRefreshToken()).isSuccess());
    }
    @Test void malformedRefreshDoesNotDiscloseParserDetails() throws Exception {
        mvc.perform(post("/api/auth/refresh").contentType("application/json").content("{\"refreshToken\":\"invalid.jwt.token\"}"))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.message").value("Invalid or expired refresh token. Please login again"));
    }
    @Test void pendingLoginRequiresCorrectPasswordBeforeSendingEmail() {
        User u=user(UserStatus.PENDING);LoginRequest r=new LoginRequest();r.setEmail(u.getEmail());r.setPassword("wrong");
        assertFalse(auth.login(r).isSuccess());verifyNoInteractions(mail);
        r.setPassword("Test@12345");assertEquals("PENDING_VERIFICATION",auth.login(r).getMessage());
        assertNotNull(code(u,false));
    }
    @Test void concurrentRefreshHasOneWinnerAndReplayInvalidatesTheFamily() throws Exception {
        User u=user(UserStatus.ACTIVE);LoginResponse initial=sessions.issue(u);
        var gate=new CountDownLatch(1);
        try(var pool=Executors.newFixedThreadPool(2)) {
            var a=pool.submit(()->{gate.await();return auth.refreshToken(initial.getRefreshToken());});
            var b=pool.submit(()->{gate.await();return auth.refreshToken(initial.getRefreshToken());});
            gate.countDown();var first=a.get(10,TimeUnit.SECONDS);var second=b.get(10,TimeUnit.SECONDS);
            assertNotEquals(first.isSuccess(),second.isSuccess());
            var winner=first.isSuccess()?first:second;
            assertFalse(auth.refreshToken(winner.getData().getRefreshToken()).isSuccess());
        }
    }
    @Test void registrationAndLoginIssueUsableSessions() throws Exception {
        RegisterRequest r=new RegisterRequest();String id=UUID.randomUUID().toString().substring(0,8);
        r.setFullName("Synthetic New User");r.setEmail(id+"@example.test");r.setPhone(id);
        r.setPreferredTreatment("Synthetic");r.setPassword("Test@12345");
        assertTrue(auth.register(r).isSuccess());User u=users.findByEmail(r.getEmail()).orElseThrow();
        var verified=auth.verifyOtp(otp(u,code(u,false)));assertTrue(verified.isSuccess());
        assertEquals(100,verified.getData().getTotalPoints());
        mvc.perform(get("/api/user/profile").header("Authorization","Bearer "+verified.getData().getAccessToken()))
                .andExpect(status().isOk());
        LoginRequest login=new LoginRequest();login.setEmail(u.getEmail());login.setPassword(r.getPassword());
        assertTrue(auth.login(login).isSuccess());
    }
    @Test void treatmentInsertsInitializeBothRequiredTimestamps() {
        User u=user(UserStatus.ACTIVE);
        TreatmentProtocol p=protocols.saveAndFlush(TreatmentProtocol.builder().user(u).protocolName("Synthetic plan").totalSessions(1).build());
        TreatmentSession s=treatmentSessions.saveAndFlush(TreatmentSession.builder().user(u).protocol(p).sessionNumber(1)
                .sessionName("Synthetic session").sessionDate(LocalDate.now().plusDays(1)).sessionTime(LocalTime.NOON).build());
        assertNotNull(p.getUpdatedAt());assertNotNull(s.getUpdatedAt());
    }
    @Test void invitedAccountRequiresSetupPurposeAndChosenPasswordBeforeActivation() {
        User u=user(UserStatus.PENDING);u.setSetupRequired(true);users.saveAndFlush(u);
        assertFalse(auth.resendOtp(u.getEmail()).isSuccess());
        auth.forgotPassword(u.getEmail());String code=code(u,true);
        assertFalse(auth.verifyOtp(otp(u,code)).isSuccess());
        assertEquals(UserStatus.PENDING,users.findById(u.getId()).orElseThrow().getStatus());
        assertTrue(auth.resetPassword(u.getEmail(),code,"Chosen@12345").isSuccess());
        var saved=users.findById(u.getId()).orElseThrow();
        assertTrue(saved.isActive());assertFalse(saved.isSetupRequired());assertEquals(777,saved.getTotalPoints());
        assertTrue(encoder.matches("Chosen@12345",saved.getPassword()));
        assertFalse(auth.resetPassword(u.getEmail(),code,"Replay@12345").isSuccess());
    }
    @Test void blockedInvitationCannotBeActivatedBySetupCode() {
        User u=user(UserStatus.PENDING);u.setSetupRequired(true);users.saveAndFlush(u);
        auth.forgotPassword(u.getEmail());String code=code(u,true);
        u=users.findById(u.getId()).orElseThrow();u.setStatus(UserStatus.BLOCKED);users.saveAndFlush(u);
        assertFalse(auth.resetPassword(u.getEmail(),code,"Chosen@12345").isSuccess());
    }
}
