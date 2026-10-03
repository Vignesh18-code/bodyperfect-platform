package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.appointment.service.AppointmentService;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.validation.annotation.Validated;
import java.security.Principal;
import java.time.*;
import java.util.*;
import static com.vignesh.clinicapp.operations.SchedulingRepository.*;

@RestController
@RequestMapping("/api/staff")
@RequiredArgsConstructor
@Validated
public class SchedulingController {
    private final OperationsService operations;
    private final OperationsRepository audit;
    private final SchedulingRepository scheduling;
    private final AppointmentService appointments;
    @GetMapping("/catalog") public ApiResponse<Map<String,Object>> catalog(Principal p,@RequestParam Branch branch){operations.require(p.getName(),branch,false,false);return ApiResponse.success("Catalog",Map.of("services",scheduling.services(),"resources",scheduling.resources(branch)));}
    @PostMapping("/services") @Transactional public ApiResponse<Long> service(Principal p,@RequestParam Branch branch,@Valid @RequestBody ServiceInput input,HttpServletRequest r){var actor=operations.require(p.getName(),branch,false,true);long id=scheduling.createService(input);audit.audit(actor.getId(),branch,"SERVICE_CREATED","SERVICE",id,r.getAttribute("requestId").toString());return ApiResponse.success("Service created",id);}
    @PostMapping("/resources") @Transactional public ApiResponse<Long> resource(Principal p,@Valid @RequestBody ResourceInput input,HttpServletRequest r){var actor=operations.require(p.getName(),input.branch(),false,true);long id=scheduling.createResource(input);audit.audit(actor.getId(),input.branch(),"RESOURCE_CREATED","RESOURCE",id,r.getAttribute("requestId").toString());return ApiResponse.success("Resource created",id);}
    @GetMapping("/resources/{id}/hours") public ApiResponse<List<Hours>> hours(Principal p,@PathVariable long id){var resource=scheduling.resource(id,false);operations.require(p.getName(),resource.branch(),false,false);return ApiResponse.success("Hours",scheduling.hours(id));}
    @PutMapping("/resources/{id}/hours") @Transactional public ApiResponse<Void> hours(Principal p,@PathVariable long id,@Valid @RequestBody HoursInput input,HttpServletRequest r){var resource=scheduling.resource(id,true);var actor=operations.require(p.getName(),resource.branch(),false,true);scheduling.hours(id,input);audit.audit(actor.getId(),resource.branch(),"RESOURCE_HOURS_UPDATED","RESOURCE",id,r.getAttribute("requestId").toString());return ApiResponse.success("Hours saved");}
    @PostMapping("/resources/{id}/blocks") @Transactional public ApiResponse<Void> block(Principal p,@PathVariable long id,@Valid @RequestBody BlockInput input,HttpServletRequest r){var resource=scheduling.resource(id,true);var actor=operations.require(p.getName(),resource.branch(),false,true);if(!scheduling.free(id,input.startsAt(),input.endsAt(),null))throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.CONFLICT,"Blocked interval overlaps a reservation or block");scheduling.block(id,input);audit.audit(actor.getId(),resource.branch(),"RESOURCE_BLOCKED","RESOURCE",id,r.getAttribute("requestId").toString());return ApiResponse.success("Time blocked");}
    @GetMapping("/availability") public ApiResponse<List<Instant>> slots(Principal p,@RequestParam long resourceId,@RequestParam long serviceId,@RequestParam LocalDate day){var resource=scheduling.resource(resourceId,false);operations.require(p.getName(),resource.branch(),false,false);if(day.isBefore(LocalDate.now(ZoneId.of(resource.timezone())))||day.isAfter(LocalDate.now(ZoneId.of(resource.timezone())).plusDays(365)))throw new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.BAD_REQUEST,"Choose a date within the next year");return ApiResponse.success("Available slots",scheduling.slots(resourceId,serviceId,day));}
    @PostMapping("/appointments") public ApiResponse<AppointmentService.ReservedResponse> create(Principal p,@RequestParam Branch branch,@Valid @RequestBody AppointmentService.ReservedRequest input,@RequestHeader("Idempotency-Key") @Size(min=8,max=100) String key,HttpServletRequest r){return ApiResponse.success("Appointment confirmed",appointments.reserve(p.getName(),branch,input,key,r.getAttribute("requestId").toString()));}
    @PatchMapping("/appointments/{id}/reschedule") public ApiResponse<AppointmentService.ReservedResponse> move(Principal p,@RequestParam Branch branch,@PathVariable long id,@Valid @RequestBody AppointmentService.RescheduleRequest input,@RequestHeader("Idempotency-Key") @Size(min=8,max=100) String key,HttpServletRequest r){return ApiResponse.success("Appointment rescheduled",appointments.rescheduleReserved(p.getName(),branch,id,input,key,r.getAttribute("requestId").toString()));}
    @PatchMapping("/appointments/{id}/status") public ApiResponse<Void> transition(Principal p,@RequestParam Branch branch,@PathVariable long id,@Valid @RequestBody AppointmentService.TransitionRequest input,HttpServletRequest r){appointments.transition(p.getName(),branch,id,input,r.getAttribute("requestId").toString());return ApiResponse.success("Appointment updated");}
}
