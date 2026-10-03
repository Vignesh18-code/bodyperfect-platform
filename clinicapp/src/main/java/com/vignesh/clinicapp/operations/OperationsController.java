package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.validation.annotation.Validated;
import java.security.Principal;
import java.time.LocalDate;
import java.util.List;
import static com.vignesh.clinicapp.operations.OperationsContracts.*;

@RestController
@RequestMapping("/api/staff")
@Validated
@RequiredArgsConstructor
public class OperationsController {
    private final OperationsService service;
    @GetMapping("/me") public ApiResponse<Me> me(Principal p) {return ApiResponse.success("Staff session",service.me(p.getName()));}
    @GetMapping("/patients") public ApiResponse<Page<Patient>> patients(Principal p,@RequestParam Branch branch,
            @RequestParam(defaultValue="") @Size(max=100) String query,@RequestParam(defaultValue="0") @Min(0) @Max(100000) int page,
            @RequestParam(defaultValue="25") @Min(1) @Max(100) int size) {
        return ApiResponse.success("Patients",service.patients(p.getName(),branch,query,page,size));
    }
    @GetMapping("/patients/{id}") public ApiResponse<Patient> patient(Principal p,@RequestParam Branch branch,@PathVariable long id) {
        return ApiResponse.success("Patient",service.patient(p.getName(),branch,id));
    }
    @PostMapping("/patients") public ApiResponse<Patient> create(Principal p,@RequestParam Branch branch,@Valid @RequestBody PatientInput input,HttpServletRequest r) {
        return ApiResponse.success("Patient created",service.createPatient(p.getName(),branch,input,r.getAttribute("requestId").toString()));
    }
    @PutMapping("/patients/{id}") public ApiResponse<Patient> edit(Principal p,@RequestParam Branch branch,@PathVariable long id,@Valid @RequestBody PatientEdit input,HttpServletRequest r) {
        return ApiResponse.success("Patient updated",service.editPatient(p.getName(),branch,id,input,r.getAttribute("requestId").toString()));
    }
    @GetMapping("/members") public ApiResponse<List<Staff>> staff(Principal p,@RequestParam Branch branch) {return ApiResponse.success("Staff",service.staff(p.getName(),branch));}
    @PostMapping("/members") public ApiResponse<Void> invite(Principal p,@Valid @RequestBody StaffInput input,HttpServletRequest r) {
        service.invite(p.getName(),input,r.getAttribute("requestId").toString());return ApiResponse.success("Staff created; password setup requested");
    }
    @PutMapping("/members/{id}") public ApiResponse<Void> member(Principal p,@PathVariable long id,@Valid @RequestBody MemberInput input,HttpServletRequest r) {
        service.member(p.getName(),id,input,r.getAttribute("requestId").toString());return ApiResponse.success("Membership updated; sessions revoked");
    }
    @GetMapping("/audit") public ApiResponse<Page<Audit>> audit(Principal p,@RequestParam Branch branch,
            @RequestParam(defaultValue="0") @Min(0) @Max(100000) int page,@RequestParam(defaultValue="25") @Min(1) @Max(100) int size) {
        return ApiResponse.success("Audit events",service.audit(p.getName(),branch,page,size));
    }
    @GetMapping("/appointments") public ApiResponse<Page<AppointmentItem>> appointments(Principal p,@RequestParam Branch branch,
            @RequestParam LocalDate from,@RequestParam LocalDate to,@RequestParam(required=false) Long patientId,
            @RequestParam(defaultValue="0") @Min(0) @Max(100000) int page,@RequestParam(defaultValue="25") @Min(1) @Max(100) int size) {
        return ApiResponse.success("Appointments",service.appointments(p.getName(),branch,from,to,page,size,patientId));
    }
    @GetMapping("/overview") public ApiResponse<Overview> overview(Principal p,@RequestParam Branch branch,@RequestParam LocalDate day) {
        return ApiResponse.success("Overview",service.overview(p.getName(),branch,day));
    }
}
