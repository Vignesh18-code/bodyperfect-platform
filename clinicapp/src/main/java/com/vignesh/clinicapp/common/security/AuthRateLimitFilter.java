package com.vignesh.clinicapp.common.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

@Component
public class AuthRateLimitFilter extends OncePerRequestFilter {

    private static final String[] LIMITED_PATHS = {
            "/api/staff-auth/login",
            "/api/staff-auth/refresh",
            "/api/auth/register",
            "/api/auth/login",
            "/api/auth/verify-otp",
            "/api/auth/resend-otp",
            "/api/auth/forgot-password",
            "/api/auth/reset-password"
    };

    private final ObjectMapper objectMapper;
    private final int maxAttempts;
    private final long windowSeconds;
    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();
    private final AtomicLong lastCleanupEpochSecond = new AtomicLong(0);

    public AuthRateLimitFilter(
            ObjectMapper objectMapper,
            @Value("${app.rate-limit.auth.max-attempts:20}") int maxAttempts,
            @Value("${app.rate-limit.auth.window-seconds:60}") long windowSeconds) {
        this.objectMapper = objectMapper;
        this.maxAttempts = maxAttempts;
        this.windowSeconds = windowSeconds;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        if (!isLimited(request)) {
            filterChain.doFilter(request, response);
            return;
        }

        String key = request.getRequestURI() + ":" + clientIp(request);
        long now = Instant.now().getEpochSecond();
        cleanupExpiredBuckets(now);
        Bucket bucket = buckets.compute(key, (ignored, existing) -> {
            if (existing == null || now >= existing.resetAtEpochSecond) {
                return new Bucket(now + windowSeconds);
            }
            existing.count.incrementAndGet();
            return existing;
        });

        if (bucket.count.get() > maxAttempts) {
            response.setStatus(429);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            objectMapper.writeValue(response.getWriter(),
                    ApiResponse.error("Too many attempts. Please try again later"));
            return;
        }

        filterChain.doFilter(request, response);
    }

    private boolean isLimited(HttpServletRequest request) {
        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            return false;
        }
        String path = request.getRequestURI();
        for (String limitedPath : LIMITED_PATHS) {
            if (limitedPath.equals(path)) {
                return true;
            }
        }
        return false;
    }

    private String clientIp(HttpServletRequest request) {
        // Only the container/edge may resolve a configured trusted proxy chain.
        // Never accept arbitrary client-supplied forwarding headers here.
        return request.getRemoteAddr();
    }

    private void cleanupExpiredBuckets(long now) {
        long previousCleanup = lastCleanupEpochSecond.get();
        if (now - previousCleanup < windowSeconds) {
            return;
        }
        if (lastCleanupEpochSecond.compareAndSet(previousCleanup, now)) {
            buckets.entrySet().removeIf(entry -> now >= entry.getValue().resetAtEpochSecond);
        }
    }

    private static final class Bucket {
        private final long resetAtEpochSecond;
        private final AtomicInteger count = new AtomicInteger(1);

        private Bucket(long resetAtEpochSecond) {
            this.resetAtEpochSecond = resetAtEpochSecond;
        }
    }
}
