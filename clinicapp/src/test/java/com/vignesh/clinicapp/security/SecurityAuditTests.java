package com.vignesh.clinicapp.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vignesh.clinicapp.common.security.JwtService;
import com.vignesh.clinicapp.notification.enums.NotificationPriority;
import com.vignesh.clinicapp.notification.enums.NotificationType;
import com.vignesh.clinicapp.notification.model.Notification;
import com.vignesh.clinicapp.notification.repository.NotificationRepository;
import com.vignesh.clinicapp.treatment.model.TreatmentProtocol;
import com.vignesh.clinicapp.treatment.repository.TreatmentProtocolRepository;
import com.vignesh.clinicapp.user.enums.Role;
import com.vignesh.clinicapp.user.enums.UserStatus;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Map;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Date;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.options;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
        "app.rate-limit.auth.max-attempts=3",
        "app.rate-limit.auth.window-seconds=60"
})
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SecurityAuditTests {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private com.vignesh.clinicapp.auth.service.AuthSessionService sessions;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TreatmentProtocolRepository protocolRepository;

    @Autowired
    private NotificationRepository notificationRepository;

    @Value("${jwt.secret}")
    private String jwtSecret;

    @ParameterizedTest
    @ValueSource(strings = {
            "' OR '1'='1",
            "admin'--",
            "'; DROP TABLE users; --",
            "' UNION SELECT NULL--",
            "1 OR 1=1",
            "\" OR \"\"=\"",
            "%' OR '1'='1",
            "test@example.com' OR '1'='1"
    })
    @DisplayName("Login rejects SQL injection payloads without exposing internals")
    void loginRejectsSqlInjectionPayloads(String payload) throws Exception {
        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email", payload,
                                "password", payload))))
                .andExpect(status().is4xxClientError())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(content().string(not(containsString("SQLException"))))
                .andExpect(content().string(not(containsString("syntax error"))));
    }

    @Test
    @DisplayName("Protected APIs require authentication")
    void protectedApiRequiresAuthentication() throws Exception {
        mockMvc.perform(get("/api/user/profile"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Authentication required"));
    }

    @Test
    @DisplayName("Invalid JWT is rejected with JSON ApiResponse")
    void invalidJwtReturnsJsonApiResponse() throws Exception {
        mockMvc.perform(get("/api/user/profile")
                        .header("Authorization", "Bearer invalid.jwt.token"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Invalid token"));
    }

    @Test
    @DisplayName("Expired JWT is rejected with JSON ApiResponse")
    void expiredJwtReturnsJsonApiResponse() throws Exception {
        String expiredToken = Jwts.builder()
                .subject("expired@example.com")
                .claim("role", Role.PATIENT.name())
                .claim("type", "ACCESS")
                .issuedAt(new Date(System.currentTimeMillis() - 120_000))
                .expiration(new Date(System.currentTimeMillis() - 60_000))
                .signWith(Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8)))
                .compact();

        mockMvc.perform(get("/api/user/profile")
                        .header("Authorization", "Bearer " + expiredToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Token expired. Please refresh or login again"));
    }

    @Test
    @DisplayName("A user cannot read another user's treatment protocol")
    void userCannotReadAnotherUsersProtocol() throws Exception {
        User attacker = saveUser("attacker@example.com", "500000001");
        User victim = saveUser("victim@example.com", "500000002");

        TreatmentProtocol victimProtocol = protocolRepository.save(TreatmentProtocol.builder()
                .user(victim)
                .protocolName("Private protocol")
                .treatmentType("Private treatment")
                .totalSessions(3)
                .build());

        String token = sessions.issue(attacker).getAccessToken();

        mockMvc.perform(get("/api/treatment/protocols/{id}", victimProtocol.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Treatment protocol not found"));
    }

    @Test
    @DisplayName("Profile image upload rejects spoofed image content")
    void profileImageUploadRejectsSpoofedContent() throws Exception {
        User user = saveUser("upload@example.com", "500000003");
        String token = sessions.issue(user).getAccessToken();

        MockMultipartFile fakePng = new MockMultipartFile(
                "file",
                "profile.png",
                "image/png",
                "not a real png".getBytes());

        mockMvc.perform(multipart("/api/user/profile/image")
                        .file(fakePng)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Invalid image file"));
    }

    @Test
    @DisplayName("Unsupported upload media type returns JSON 415")
    void unsupportedUploadMediaTypeReturnsJson() throws Exception {
        User user = saveUser("media@example.com", "500000004");
        String token = sessions.issue(user).getAccessToken();

        mockMvc.perform(post("/api/user/profile/image")
                        .contentType(MediaType.APPLICATION_JSON)
                        .header("Authorization", "Bearer " + token)
                        .content("{}"))
                .andExpect(status().isUnsupportedMediaType())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    @DisplayName("Invalid JSON returns stable ApiResponse")
    void invalidJsonReturnsStableApiResponse() throws Exception {
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{bad json"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Invalid request body"));
    }

    @Test
    @DisplayName("Rate-limited auth endpoints return JSON 429")
    void authRateLimitReturnsJson429() throws Exception {
        String body = objectMapper.writeValueAsString(Map.of("email", "rate@example.com"));
        for (int i = 0; i < 3; i++) {
            mockMvc.perform(post("/api/auth/forgot-password")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(body))
                    .andExpect(status().isOk());
        }

        mockMvc.perform(post("/api/auth/forgot-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Too many attempts. Please try again later"));
    }

    @Test
    @DisplayName("CORS allows configured origins")
    void corsAllowsConfiguredOrigins() throws Exception {
        mockMvc.perform(options("/api/auth/login")
                        .header("Origin", "http://localhost:3000")
                        .header("Access-Control-Request-Method", "POST"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin", "http://localhost:3000"));
    }

    @Test
    @DisplayName("Unknown authenticated API returns JSON 404")
    void unknownAuthenticatedApiReturnsJson404() throws Exception {
        User user = saveUser("notfound@example.com", "500000005");
        String token = sessions.issue(user).getAccessToken();

        mockMvc.perform(get("/api/does-not-exist")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    @DisplayName("Health endpoint is available without authentication")
    void healthEndpointIsPublic() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("Authenticated user can fetch own notifications with ApiResponse shape")
    void authenticatedUserCanFetchOwnNotifications() throws Exception {
        User user = saveUser("notify-fetch@example.com", "500000006");
        saveNotification(user, "Welcome", NotificationType.SYSTEM);
        String token = sessions.issue(user).getAccessToken();

        mockMvc.perform(get("/api/notifications?page=0&size=20")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").value("Notifications loaded"))
                .andExpect(jsonPath("$.timestamp").exists())
                .andExpect(jsonPath("$.data[0].title").value("Welcome"))
                .andExpect(jsonPath("$.data[0].isRead").value(false));
    }

    @Test
    @DisplayName("Unauthenticated user cannot fetch notifications")
    void unauthenticatedUserCannotFetchNotifications() throws Exception {
        mockMvc.perform(get("/api/notifications"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    @DisplayName("User cannot mark another user's notification as read")
    void userCannotMarkAnotherUsersNotification() throws Exception {
        User owner = saveUser("notify-owner@example.com", "500000007");
        User attacker = saveUser("notify-attacker@example.com", "500000008");
        Notification notification = saveNotification(owner, "Private", NotificationType.SYSTEM);
        String token = sessions.issue(attacker).getAccessToken();

        mockMvc.perform(patch("/api/notifications/{id}/read", notification.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Notification not found"));
    }

    @Test
    @DisplayName("Unread count, mark one, mark all, and soft delete work")
    void notificationReadAndDeleteLifecycleWorks() throws Exception {
        User user = saveUser("notify-life@example.com", "500000009");
        Notification first = saveNotification(user, "First", NotificationType.SYSTEM);
        Notification second = saveNotification(user, "Second", NotificationType.PROFILE_UPDATED);
        String token = sessions.issue(user).getAccessToken();

        mockMvc.perform(get("/api/notifications/unread-count")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.unreadCount").value(2));

        mockMvc.perform(patch("/api/notifications/{id}/read", first.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        mockMvc.perform(get("/api/notifications/unread-count")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.unreadCount").value(1));

        mockMvc.perform(patch("/api/notifications/read-all")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        mockMvc.perform(delete("/api/notifications/{id}", second.getId())
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));
    }

    @Test
    @DisplayName("Notification list size is capped for large client requests")
    void notificationPaginationCapWorks() throws Exception {
        User user = saveUser("notify-cap@example.com", "500000010");
        for (int i = 0; i < 60; i++) {
            saveNotification(user, "Notice " + i, NotificationType.SYSTEM);
        }
        String token = sessions.issue(user).getAccessToken();

        mockMvc.perform(get("/api/notifications?size=999")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(50));
    }

    @Test
    @DisplayName("Booking an appointment creates a notification")
    void appointmentBookingCreatesNotification() throws Exception {
        User user = saveUser("notify-appointment@example.com", "500000011");
        String token = sessions.issue(user).getAccessToken();

        mockMvc.perform(post("/api/appointments")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "appointmentDate", LocalDate.now().plusDays(5).toString(),
                                "appointmentTime", LocalTime.of(10, 30).toString(),
                                "branch", "BURJUMAN",
                                "note", "Notification test"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        mockMvc.perform(get("/api/notifications")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].type").value(NotificationType.APPOINTMENT_BOOKED.name()))
                .andExpect(jsonPath("$.data[0].actionType").value("APPOINTMENT"));
    }

    @Test
    void spoofedForwardingHeadersDoNotResetRateLimit() throws Exception {
        for (int n=0;n<4;n++) {
            var result = mockMvc.perform(post("/api/auth/resend-otp")
                    .param("email", "missing@example.test")
                    .header("X-Forwarded-For", "192.0.2." + n));
            if (n == 3) result.andExpect(status().isTooManyRequests());
            else result.andExpect(status().isBadRequest());
        }
    }

    private User saveUser(String email, String phone) {
        User user = User.builder()
                .fullName("Security Test User")
                .phone(phone)
                .email(email)
                .password("$2a$10$notARealHashButUnusedInTheseTests")
                .role(Role.PATIENT)
                .status(UserStatus.ACTIVE)
                .build();
        User saved = userRepository.save(user);
        saved.setStatus(UserStatus.ACTIVE);
        return userRepository.save(saved);
    }

    private Notification saveNotification(User user, String title, NotificationType type) {
        return notificationRepository.save(Notification.builder()
                .user(user)
                .title(title)
                .message(title + " message")
                .type(type)
                .priority(NotificationPriority.NORMAL)
                .isRead(false)
                .isDeleted(false)
                .build());
    }
}
