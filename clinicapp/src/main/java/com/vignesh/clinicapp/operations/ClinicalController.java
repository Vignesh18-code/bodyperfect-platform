package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import java.security.Principal;
import java.util.List;
import static com.vignesh.clinicapp.operations.ClinicalService.*;

@RestController
@RequestMapping("/api/staff")
@RequiredArgsConstructor
public class ClinicalController {
    private final ClinicalService clinical;
    @GetMapping("/templates") public ApiResponse<List<Template>> templates(Principal p,@RequestParam Branch branch){return ApiResponse.success("Templates",clinical.templates(p.getName(),branch));}
    @PostMapping("/templates") public ApiResponse<Long> create(Principal p,@RequestParam Branch branch,@Valid @RequestBody TemplateInput input,HttpServletRequest r){return ApiResponse.success("Draft created",clinical.createTemplate(p.getName(),branch,input,requestId(r)));}
    @PostMapping("/templates/{id}/publish") public ApiResponse<Void> publish(Principal p,@RequestParam Branch branch,@PathVariable long id,HttpServletRequest r){clinical.publish(p.getName(),branch,id,requestId(r));return ApiResponse.success("Template published");}
    @GetMapping("/patients/{patient}/plans") public ApiResponse<List<Plan>> plans(Principal p,@RequestParam Branch branch,@PathVariable long patient){return ApiResponse.success("Treatment plans",clinical.plans(p.getName(),branch,patient));}
    @PostMapping("/patients/{patient}/plans") public ApiResponse<Long> assign(Principal p,@RequestParam Branch branch,@PathVariable long patient,@Valid @RequestBody PlanInput input,HttpServletRequest r){return ApiResponse.success("Plan approved",clinical.assign(p.getName(),branch,patient,input,requestId(r)));}
    @PatchMapping("/patients/{patient}/plans/{id}") public ApiResponse<Void> change(Principal p,@RequestParam Branch branch,@PathVariable long patient,@PathVariable long id,@Valid @RequestBody PlanChange input,HttpServletRequest r){clinical.change(p.getName(),branch,patient,id,input,requestId(r));return ApiResponse.success("Plan updated");}
    @GetMapping("/patients/{patient}/plans/{id}/sessions") public ApiResponse<List<Session>> sessions(Principal p,@RequestParam Branch branch,@PathVariable long patient,@PathVariable long id){return ApiResponse.success("Sessions",clinical.sessions(p.getName(),branch,patient,id));}
    @PostMapping("/patients/{patient}/plans/{id}/sessions") public ApiResponse<Long> session(Principal p,@RequestParam Branch branch,@PathVariable long patient,@PathVariable long id,@Valid @RequestBody SessionInput input,HttpServletRequest r){return ApiResponse.success("Session scheduled",clinical.linkSession(p.getName(),branch,patient,id,input,requestId(r)));}
    private String requestId(HttpServletRequest r){return r.getAttribute("requestId").toString();}
}
