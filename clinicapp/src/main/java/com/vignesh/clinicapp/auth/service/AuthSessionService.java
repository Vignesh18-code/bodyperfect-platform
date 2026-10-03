package com.vignesh.clinicapp.auth.service;

import com.vignesh.clinicapp.auth.dto.LoginResponse;
import com.vignesh.clinicapp.auth.model.RefreshSession;
import com.vignesh.clinicapp.auth.repository.RefreshSessionRepository;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.common.security.JwtService;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthSessionService {
    private final RefreshSessionRepository sessions;
    private final UserRepository users;
    private final JwtService jwt;

    @Transactional
    public LoginResponse issue(User user) {
        if (!user.isActive()) throw new IllegalArgumentException("Account is not active");
        return issue(user, UUID.randomUUID(), jwt.refreshExpiry());
    }

    private LoginResponse issue(User user, UUID family, Instant expires) {
        String refresh = jwt.generate(user.getEmail(), user.getRole().name(), user.getTokenVersion(), family, "REFRESH", expires);
        sessions.save(RefreshSession.builder().id(UUID.randomUUID()).user(user).familyId(family)
                .tokenHash(hash(refresh)).expiresAt(expires).build());
        return LoginResponse.builder()
                .accessToken(jwt.generate(user.getEmail(), user.getRole().name(), user.getTokenVersion(), family, "ACCESS", jwt.accessExpiry()))
                .refreshToken(refresh).fullName(user.getFullName()).email(user.getEmail())
                .role(user.getRole().name()).totalPoints(user.getTotalPoints()).build();
    }

    @Transactional
    public ApiResponse<LoginResponse> refresh(String token) {
        Claims claims;
        try {
            claims = jwt.claims(token);
            if (!"REFRESH".equals(claims.get("type"))) return invalid();
        } catch (JwtException | IllegalArgumentException ex) {
            return invalid();
        }
        // All session mutations take the same user lock, including reset and logout.
        User user = users.findByEmailForUpdate(claims.getSubject()).orElse(null);
        if (user == null || !user.isActive() || user.isLocked() || !versionMatches(claims, user)) return invalid();
        RefreshSession previous = sessions.findByTokenHash(hash(token)).orElse(null);
        if (previous == null || !previous.getUser().getId().equals(user.getId())) return invalid();
        if (previous.isConsumed() || previous.isRevoked()) {
            // A consumed token replay compromises this device family, not every device.
            sessions.revokeFamily(previous.getFamilyId());
            return invalid();
        }
        if (!previous.getExpiresAt().isAfter(Instant.now())) return invalid();
        previous.setConsumed(true);
        sessions.saveAndFlush(previous);
        // Preserve absolute family expiry instead of extending a stolen session indefinitely.
        return ApiResponse.success("Token refreshed!", issue(user, previous.getFamilyId(), previous.getExpiresAt()));
    }

    public boolean isAccessValid(Claims claims, User user) {
        if (!user.isActive() || !versionMatches(claims, user)) return false;
        try {
            return sessions.existsByFamilyIdAndUserIdAndConsumedFalseAndRevokedFalseAndExpiresAtAfter(
                    UUID.fromString(claims.get("sid", String.class)), user.getId(), Instant.now());
        } catch (IllegalArgumentException | NullPointerException ex) { return false; }
    }

    @Transactional
    public void revokeAll(User user) {
        user.setTokenVersion(user.getTokenVersion() + 1);
        users.save(user);
        sessions.revokeUser(user.getId());
    }

    @Transactional
    public void logout(String email, String token, boolean allDevices) {
        User user = users.findByEmailForUpdate(email).orElseThrow();
        if (allDevices) revokeAll(user);
        else sessions.revokeFamily(UUID.fromString(jwt.claims(token).get("sid", String.class)));
    }

    private boolean versionMatches(Claims claims, User user) {
        Object value = claims.get("ver");
        return value instanceof Number number && number.longValue() == user.getTokenVersion();
    }
    private ApiResponse<LoginResponse> invalid() {
        return ApiResponse.error("Invalid or expired refresh token. Please login again");
    }
    private String hash(String token) {
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8))); }
        catch (NoSuchAlgorithmException ex) { throw new IllegalStateException(ex); }
    }
}
