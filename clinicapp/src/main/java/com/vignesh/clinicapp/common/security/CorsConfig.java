package com.vignesh.clinicapp.common.security;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

@Configuration
public class CorsConfig {

    @Value("${app.cors.allowed-origins}")
    private String allowedOrigins;

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {

        CorsConfiguration config = new CorsConfiguration();

        List<String> origins = Arrays.stream(allowedOrigins.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isBlank())
                .toList();

        config.setAllowedOrigins(origins);

        // ── Step 2: Allowed Methods (WHAT actions allowed) ───
        config.setAllowedMethods(List.of(
                "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"
        ));
        /*
         * GET     → fetch data (appointments, profile)
         * POST    → create data (register, login, book)
         * PUT     → update full data (update profile)
         * PATCH   → update partial data (change name only)
         * DELETE  → remove data (cancel appointment)
         * OPTIONS → preflight check (browser sends this first)
         */

        // ── Step 3: Allowed Headers (WHAT headers allowed) ───
        config.setAllowedHeaders(List.of(
                "Authorization",
                "Content-Type",
                "Accept",
                "Origin",
                "X-Requested-With"
        ));
        /*
         * Authorization  → Bearer token (JWT)
         * Content-Type   → application/json
         * Accept         → what response format client wants
         * Origin         → where request comes from
         * X-Requested-With → AJAX identifier
         */

        // ── Step 4: Exposed Headers (WHAT client can read) ───
        config.setExposedHeaders(List.of(
                "Authorization"
        ));
        /*
         * By default browser hides response headers
         * We expose Authorization so Flutter can read new tokens
         */

        // ── Step 5: Allow Credentials ────────────────────────
        config.setAllowCredentials(true);
        /*
         * Allows cookies and Authorization headers
         * Required for JWT authentication
         */

        // ── Step 6: Cache preflight for 1 hour ──────────────
        config.setMaxAge(3600L);
        // ── Step 7: Apply to ALL endpoints ──────────────────
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);

        return source;
    }
}
