package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.common.security.*;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.*;
import org.springframework.core.annotation.Order;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.csrf.*;

@Configuration
@RequiredArgsConstructor
public class StaffSecurityConfig {
    private final JwtAuthenticationFilter jwt;
    private final AuthRateLimitFilter rate;
    private final ObjectMapper json;
    @Bean @Order(1)
    SecurityFilterChain staffSecurity(HttpSecurity http) throws Exception {
        return http.securityMatcher("/api/staff/**","/api/staff-auth/**")
            .sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .csrf(c->c.csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
                    .csrfTokenRequestHandler(new CsrfTokenRequestAttributeHandler()))
            .authorizeHttpRequests(a->a.requestMatchers("/api/staff-auth/mfa/setup","/api/staff-auth/csrf","/api/staff-auth/login","/api/staff-auth/refresh").permitAll()
                    .anyRequest().hasAnyRole("STAFF","ADMIN"))
            .exceptionHandling(e->e.authenticationEntryPoint((r,s,x)->{s.setStatus(401);s.setContentType("application/json");json.writeValue(s.getWriter(),ApiResponse.error("Staff authentication required"));})
                .accessDeniedHandler((r,s,x)->{s.setStatus(403);s.setContentType("application/json");json.writeValue(s.getWriter(),ApiResponse.error("Access denied"));}))
            .headers(h->h.contentSecurityPolicy(c->c.policyDirectives("default-src 'none'; frame-ancestors 'none'")))
            .addFilterBefore(rate,UsernamePasswordAuthenticationFilter.class)
            .addFilterBefore(jwt,UsernamePasswordAuthenticationFilter.class).build();
    }
}
