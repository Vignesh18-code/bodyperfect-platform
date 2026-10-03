package com.vignesh.clinicapp.common.security;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.stereotype.Component;
import org.springframework.core.annotation.Order;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.util.UUID;

@Component
@Order(-200)
public class RequestIdFilter extends OncePerRequestFilter {
    @Override protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain) throws ServletException,IOException {
        // Server-generated to avoid attacker-controlled audit/log values.
        String id=UUID.randomUUID().toString();request.setAttribute("requestId",id);response.setHeader("X-Request-Id",id);
        response.setHeader("Cache-Control","no-store");
        chain.doFilter(request,response);
    }
}
