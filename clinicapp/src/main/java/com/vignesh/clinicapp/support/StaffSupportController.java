package com.vignesh.clinicapp.support;
import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.validation.annotation.Validated;
import java.security.Principal;
@RestController @RequestMapping("/api/staff/support") @RequiredArgsConstructor @Validated
public class StaffSupportController {
 private final SupportService service;
 @GetMapping public ApiResponse<?> inbox(Principal p,@RequestParam Branch branch,@RequestParam(defaultValue="0") @Min(0) @Max(10000) int page){return ApiResponse.success("Support inbox",service.inbox(p.getName(),branch,page));}
 @GetMapping("/{id}/messages") public ApiResponse<?> messages(Principal p,@PathVariable @Positive long id,@RequestParam(required=false) @Positive Long before){return ApiResponse.success("Messages",service.messages(p.getName(),id,true,before));}
 @PostMapping("/{id}/messages") public ApiResponse<?> send(Principal p,@PathVariable @Positive long id,@Valid @RequestBody SupportService.Send input,HttpServletRequest r){return ApiResponse.success("Reply saved",service.send(p.getName(),id,true,input,String.valueOf(r.getAttribute("requestId"))));}
 @PatchMapping("/{id}") public ApiResponse<?> update(Principal p,@PathVariable @Positive long id,@Valid @RequestBody SupportService.Update input,HttpServletRequest r){service.update(p.getName(),id,input,String.valueOf(r.getAttribute("requestId")));return ApiResponse.success("Conversation updated");}
}
