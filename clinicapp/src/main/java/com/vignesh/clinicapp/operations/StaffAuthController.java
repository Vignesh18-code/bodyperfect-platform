package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.auth.service.*;
import com.vignesh.clinicapp.auth.dto.*;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import jakarta.servlet.http.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.bind.annotation.*;
import java.security.Principal;
import java.util.Map;

@RestController
@RequestMapping("/api/staff-auth")
@RequiredArgsConstructor
public class StaffAuthController {
    private final AuthService auth;
    private final AuthSessionService sessions;
    @Value("${app.staff.cookie-secure:true}") private boolean secure;
    @GetMapping("/csrf") public Map<String,String> csrf(CsrfToken token) {return Map.of("token",token.getToken(),"headerName",token.getHeaderName());}
    @PostMapping("/login") public ResponseEntity<ApiResponse<Void>> login(@Valid @RequestBody LoginRequest request,HttpServletResponse response) {
        var result=auth.login(request);
        if(!result.isSuccess())return ResponseEntity.status(401).body(ApiResponse.error("Invalid staff credentials"));
        if("PATIENT".equals(result.getData().getRole())) {
            sessions.logout(result.getData().getEmail(),result.getData().getAccessToken(),false);
            return ResponseEntity.status(403).body(ApiResponse.error("Staff access required"));
        }
        cookies(response,result.getData());return ResponseEntity.ok(ApiResponse.success("Signed in"));
    }
    @PostMapping("/refresh") public ResponseEntity<ApiResponse<Void>> refresh(@CookieValue(value="bp_staff_refresh",defaultValue="") String token,HttpServletResponse response) {
        var result=auth.refreshToken(token);
        if(!result.isSuccess()) {clear(response);return ResponseEntity.status(401).body(ApiResponse.error("Session expired"));}
        if("PATIENT".equals(result.getData().getRole())) {
            sessions.logout(result.getData().getEmail(),result.getData().getAccessToken(),false);clear(response);
            return ResponseEntity.status(403).body(ApiResponse.error("Staff access required"));
        }
        cookies(response,result.getData());return ResponseEntity.ok(ApiResponse.success("Session refreshed"));
    }
    @PostMapping("/logout") public ApiResponse<Void> logout(Principal p,@CookieValue("bp_staff_access") String access,HttpServletResponse response) {
        sessions.logout(p.getName(),access,false);clear(response);return ApiResponse.success("Signed out");
    }
    private void cookies(HttpServletResponse response,LoginResponse data) {
        cookie(response,"bp_staff_access",data.getAccessToken(),"/api",-1);
        cookie(response,"bp_staff_refresh",data.getRefreshToken(),"/api/staff-auth",-1);
    }
    private void clear(HttpServletResponse response) {cookie(response,"bp_staff_access","","/api",0);cookie(response,"bp_staff_refresh","","/api/staff-auth",0);}
    private void cookie(HttpServletResponse response,String name,String value,String path,long age) {
        var b=ResponseCookie.from(name,value).httpOnly(true).secure(secure).sameSite("Strict").path(path);
        if(age>=0)b.maxAge(age);
        response.addHeader(HttpHeaders.SET_COOKIE,b.build().toString());
    }
}
