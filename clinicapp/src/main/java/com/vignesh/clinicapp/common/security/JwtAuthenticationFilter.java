package com.vignesh.clinicapp.common.security;

import com.vignesh.clinicapp.auth.service.AuthSessionService;
import com.vignesh.clinicapp.user.repository.UserRepository;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.util.List;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtService jwt;
    private final UserRepository users;
    private final AuthSessionService sessions;

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        // Public authentication must still work when a client holds an expired access token.
        return java.util.Set.of("/api/auth/login", "/api/auth/register", "/api/auth/verify-otp",
                "/api/auth/resend-otp", "/api/auth/refresh", "/api/auth/forgot-password",
                "/api/auth/reset-password", "/api/staff-auth/mfa/setup","/api/staff-auth/csrf", "/api/staff-auth/login", "/api/staff-auth/refresh").contains(request.getRequestURI());
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if ((request.getRequestURI().startsWith("/api/staff/") || request.getRequestURI().startsWith("/api/staff-auth/"))
                && header == null && request.getCookies() != null) {
            for (var cookie : request.getCookies()) if ("bp_staff_access".equals(cookie.getName())) header = "Bearer " + cookie.getValue();
        }
        if (header == null || !header.startsWith("Bearer ")) { chain.doFilter(request, response); return; }
        try {
            Claims claims = jwt.claims(header.substring(7));
            if (!"ACCESS".equals(claims.get("type"))) { reject(response, "Invalid token type"); return; }
            var user = users.findByEmail(claims.getSubject()).orElse(null);
            if (user == null || !sessions.isAccessValid(claims, user)) { reject(response, "Invalid token"); return; }
            // Use current server-side role, never a stale role claim.
            SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(
                    user.getEmail(), null, List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole().name()))));
        } catch (ExpiredJwtException ex) {
            reject(response, "Token expired. Please refresh or login again"); return;
        } catch (JwtException | IllegalArgumentException ex) {
            reject(response, "Invalid token"); return;
        }
        chain.doFilter(request, response);
    }

    private void reject(HttpServletResponse response, String message) throws IOException {
        SecurityContextHolder.clearContext();
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType("application/json");
        response.getWriter().write("{\"success\":false,\"message\":\"" + message + "\"}");
    }
}
