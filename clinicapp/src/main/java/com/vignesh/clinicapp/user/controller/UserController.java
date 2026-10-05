package com.vignesh.clinicapp.user.controller;

import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.user.dto.UpdateProfileRequest;
import com.vignesh.clinicapp.user.dto.UserProfileResponse;
import com.vignesh.clinicapp.user.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    @GetMapping("/profile")
    public ResponseEntity<ApiResponse<UserProfileResponse>> getProfile(
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(userService.getProfile(email));
    }

    @GetMapping("/profile/image")
    public ResponseEntity<org.springframework.core.io.Resource> photo(Authentication auth) throws java.io.IOException {
        var resource = userService.readOwnPhoto(auth.getName());
        var name = resource.getFilename();
        String type = name.endsWith(".png") ? "image/png" : name.endsWith(".webp") ? "image/webp" : "image/jpeg";
        return ResponseEntity.ok().header("Cache-Control", "no-store, private")
                .header("X-Content-Type-Options", "nosniff")
                .contentType(org.springframework.http.MediaType.parseMediaType(type)).body(resource);
    }

    @PutMapping("/profile")
    public ResponseEntity<ApiResponse<UserProfileResponse>> updateProfile(
            @Valid @RequestBody UpdateProfileRequest request,
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(userService.updateProfile(email, request));
    }

    @PostMapping(value = "/profile/image", consumes = "multipart/form-data")
    public ResponseEntity<ApiResponse<UserProfileResponse>> uploadProfileImage(
            @RequestParam("file") MultipartFile file,
            Authentication authentication) {
        String email = authentication.getName();
        return ResponseEntity.ok(userService.uploadProfileImage(email, file));
    }
}
