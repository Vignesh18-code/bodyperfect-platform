package com.vignesh.clinicapp.operations;
import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.validation.annotation.Validated;
import java.security.Principal;
import java.util.List;
import static com.vignesh.clinicapp.operations.FollowUpService.*;
@RestController
@RequestMapping("/api/staff/follow-ups")
@RequiredArgsConstructor
@Validated
public class FollowUpController {
 private final FollowUpService service;
 @GetMapping("/assignees") public ApiResponse<List<Assignee>> assignees(Principal p,@RequestParam Branch branch){return ApiResponse.success("Assignees",service.assignees(p.getName(),branch));}
 @GetMapping public ApiResponse<OperationsContracts.Page<Task>> list(Principal p,@RequestParam Branch branch,@RequestParam(defaultValue="OPEN") State state,@RequestParam(defaultValue="0") @Min(0) @Max(10000) int page){return ApiResponse.success("Follow-ups",service.list(p.getName(),branch,state,page));}
 @PostMapping public ApiResponse<Long> create(Principal p,@RequestParam Branch branch,@Valid @RequestBody Input input,HttpServletRequest r){return ApiResponse.success("Follow-up created",service.create(p.getName(),branch,input,r.getAttribute("requestId").toString()));}
 @PatchMapping("/{id}") public ApiResponse<Void> resolve(Principal p,@RequestParam Branch branch,@PathVariable long id,@Valid @RequestBody Resolve input,HttpServletRequest r){service.resolve(p.getName(),branch,id,input,r.getAttribute("requestId").toString());return ApiResponse.success("Follow-up resolved");}
}
