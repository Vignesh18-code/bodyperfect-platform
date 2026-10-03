package com.vignesh.clinicapp.common.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;

@Service
public class JwtService {
    @Value("${jwt.secret}") private String secret;
    @Value("${jwt.access-token-expiration}") private long accessTokenExpiration;
    @Value("${jwt.refresh-token-expiration}") private long refreshTokenExpiration;

    @PostConstruct
    void validateConfiguration() {
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32
                || accessTokenExpiration <= 0 || refreshTokenExpiration <= 0) {
            throw new IllegalStateException("Valid JWT key and positive token lifetimes are required");
        }
    }

    private SecretKey key() { return Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8)); }

    public String generate(String email, String role, long version, UUID family, String type, Instant expires) {
        return Jwts.builder().id(UUID.randomUUID().toString()).subject(email)
                .claim("role", role).claim("type", type).claim("ver", version)
                .claim("sid", family.toString()).issuedAt(new Date()).expiration(Date.from(expires))
                .signWith(key()).compact();
    }

    public Instant accessExpiry() { return Instant.now().plusMillis(accessTokenExpiration); }
    public Instant refreshExpiry() { return Instant.now().plusMillis(refreshTokenExpiration); }
    public Claims claims(String token) {
        return Jwts.parser().verifyWith(key()).build().parseSignedClaims(token).getPayload();
    }
}
