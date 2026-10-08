package com.vignesh.clinicapp.appointment.service;

import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.appointment.dto.AppointmentResponse;
import com.vignesh.clinicapp.appointment.dto.CreateAppointmentRequest;
import com.vignesh.clinicapp.appointment.enums.AppointmentStatus;
import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.notification.enums.NotificationPriority;
import com.vignesh.clinicapp.notification.enums.NotificationType;
import com.vignesh.clinicapp.appointment.model.Appointment;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.appointment.repository.AppointmentRepository;
import com.vignesh.clinicapp.notification.service.NotificationService;
import com.vignesh.clinicapp.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class AppointmentService {

    private static final int MAX_APPOINTMENTS_RETURNED = 100;

    private final AppointmentRepository appointmentRepository;
    private final NotificationService notificationService;
    private final UserRepository userRepository;
    private final com.vignesh.clinicapp.operations.SchedulingRepository scheduling;
    private final com.vignesh.clinicapp.operations.OperationsService operations;
    private final com.vignesh.clinicapp.operations.OperationsRepository operationData;
    private final com.fasterxml.jackson.databind.ObjectMapper json;

    private final com.vignesh.clinicapp.treatment.repository.TreatmentSessionRepository treatmentSessions;

    public record ReservedRequest(@jakarta.validation.constraints.Positive long patientId,
        @jakarta.validation.constraints.Positive long resourceId,@jakarta.validation.constraints.Positive long serviceId,
        @jakarta.validation.constraints.NotNull java.time.Instant startsAt,
        @jakarta.validation.constraints.Size(max=500) String note, Long requestedAppointmentId, long version) {
        public ReservedRequest(long patientId,long resourceId,long serviceId,java.time.Instant startsAt,String note) {
            this(patientId,resourceId,serviceId,startsAt,note,null,0);
        }
    }
    public record RescheduleRequest(@jakarta.validation.constraints.NotNull java.time.Instant startsAt,
        @jakarta.validation.constraints.Min(0) long version,@jakarta.validation.constraints.NotBlank @jakarta.validation.constraints.Size(max=500) String reason) {}
    public record TransitionRequest(@jakarta.validation.constraints.NotNull AppointmentStatus status,
        @jakarta.validation.constraints.Min(0) long version,@jakarta.validation.constraints.Size(max=500) String reason) {}
    public record ReservedResponse(long id,long patientId,long resourceId,long serviceId,java.time.Instant startsAt,
        java.time.Instant endsAt,String status,long version) {}

    @Transactional
    public ReservedResponse reserve(String actorEmail,Branch branch,ReservedRequest input,String key,String requestId) {
        User actor=operations.require(actorEmail,branch,false,false);
        userRepository.findByEmailForUpdate(actorEmail).orElseThrow();
        operations.checkPatient(input.patientId(),branch);
        String hash=hash(input);String replay=scheduling.replay(actor.getId(),"CREATE",key,hash);
        if(replay!=null)return decode(replay);
        User patient=userRepository.findById(input.patientId()).orElseThrow();
        patient=userRepository.findByEmailForUpdate(patient.getEmail()).orElseThrow();
        var resource=scheduling.resource(input.resourceId(),true);
        if(resource.branch()!=branch)throw new org.springframework.security.access.AccessDeniedException("Resource belongs to another branch");
        scheduling.validate(resource,input.serviceId(),input.startsAt(),null);
        var local=input.startsAt().atZone(java.time.ZoneId.of(resource.timezone()));
        Appointment appointment;
        String previousStatus=null;
        if(input.requestedAppointmentId()!=null) {
            appointment=scopedAppointment(input.requestedAppointmentId(),branch);
            if(!appointment.getUser().getId().equals(patient.getId())||appointment.getResourceId()!=null||appointment.getStatus()!=AppointmentStatus.PENDING||appointment.getVersion()!=input.version())throw conflict("Request changed or is already reserved");
            previousStatus=appointment.getStatus().name();
        } else appointment=Appointment.builder().user(patient).branch(branch).source("DASHBOARD").build();
        appointment.setResourceId(resource.id());appointment.setServiceId(input.serviceId());
        appointment.setStartsAt(input.startsAt());appointment.setEndsAt(input.startsAt().plusSeconds(scheduling.service(input.serviceId()).durationMinutes()*60L));
        appointment.setAppointmentDate(local.toLocalDate());appointment.setAppointmentTime(local.toLocalTime());
        appointment.setStatus(AppointmentStatus.CONFIRMED);if(input.note()!=null)appointment.setNote(input.note());
        appointmentRepository.saveAndFlush(appointment);
        scheduling.event(appointment.getId(),actor.getId(),previousStatus,"CONFIRMED",null,input.startsAt(),null);
        operationData.audit(actor.getId(),branch,"APPOINTMENT_CREATED","APPOINTMENT",appointment.getId(),requestId);
        notificationService.createNotification(patient,"Appointment confirmed","Your appointment schedule has been updated.",NotificationType.APPOINTMENT_BOOKED,"APPOINTMENT",appointment.getId(),NotificationPriority.HIGH);
        ReservedResponse result=reservedResponse(appointment);
        scheduling.remember(actor.getId(),"CREATE",key,hash,appointment.getId(),encode(result));return result;
    }

    @Transactional
    public ReservedResponse rescheduleReserved(String actorEmail,Branch branch,long id,RescheduleRequest input,String key,String requestId) {
        User actor=operations.require(actorEmail,branch,false,false);userRepository.findByEmailForUpdate(actorEmail).orElseThrow();
        Appointment appointment=scopedAppointment(id,branch);String operation="RESCHEDULE:"+id,hash=hash(input);
        String replay=scheduling.replay(actor.getId(),operation,key,hash);if(replay!=null)return decode(replay);
        if(appointment.getVersion()!=input.version())throw conflict("Appointment changed. Refresh and try again");
        if(appointment.getResourceId()==null)throw conflict("Legacy appointment requires a configured resource booking");
        if(appointment.getStatus()!=AppointmentStatus.CONFIRMED&&appointment.getStatus()!=AppointmentStatus.PENDING)throw conflict("This appointment cannot be rescheduled");
        var resource=scheduling.resource(appointment.getResourceId(),true);scheduling.validate(resource,appointment.getServiceId(),input.startsAt(),id);
        var old=appointment.getStartsAt();var local=input.startsAt().atZone(java.time.ZoneId.of(resource.timezone()));
        appointment.setStartsAt(input.startsAt());appointment.setEndsAt(input.startsAt().plusSeconds(scheduling.service(appointment.getServiceId()).durationMinutes()*60L));
        appointment.setAppointmentDate(local.toLocalDate());appointment.setAppointmentTime(local.toLocalTime());appointmentRepository.saveAndFlush(appointment);
        treatmentSessions.findByAppointmentId(id).ifPresent(session -> {
            session.setSessionDate(appointment.getAppointmentDate());
            session.setSessionTime(appointment.getAppointmentTime());
            treatmentSessions.saveAndFlush(session);
        });
        scheduling.event(id,actor.getId(),appointment.getStatus().name(),appointment.getStatus().name(),old,input.startsAt(),input.reason());
        operationData.audit(actor.getId(),branch,"APPOINTMENT_RESCHEDULED","APPOINTMENT",id,requestId);
        var result=reservedResponse(appointment);scheduling.remember(actor.getId(),operation,key,hash,id,encode(result));return result;
    }

    @Transactional
    public void transition(String actorEmail,Branch branch,long id,TransitionRequest input,String requestId) {
        boolean clinical=input.status()==AppointmentStatus.IN_CONSULTATION||input.status()==AppointmentStatus.COMPLETED;
        User actor=operations.require(actorEmail,branch,clinical,false);Appointment appointment=scopedAppointment(id,branch);
        if(appointment.getVersion()!=input.version())throw conflict("Appointment changed. Refresh and try again");
        AppointmentStatus old=appointment.getStatus();boolean allowed=switch(old) {
            case PENDING -> input.status()==AppointmentStatus.CONFIRMED||input.status()==AppointmentStatus.CANCELLED;
            case CONFIRMED -> input.status()==AppointmentStatus.CHECKED_IN||input.status()==AppointmentStatus.CANCELLED||input.status()==AppointmentStatus.NO_SHOW;
            case CHECKED_IN -> input.status()==AppointmentStatus.IN_CONSULTATION;
            case IN_CONSULTATION -> input.status()==AppointmentStatus.COMPLETED;
            default -> false;
        };
        if(!allowed)throw conflict("Invalid appointment transition");
        if(input.status()==AppointmentStatus.CONFIRMED&&appointment.getResourceId()==null)throw conflict("Confirmation requires a resource reservation");
        if((input.status()==AppointmentStatus.CANCELLED||input.status()==AppointmentStatus.NO_SHOW)&&(input.reason()==null||input.reason().isBlank()))throw conflict("A reason is required");
        if(input.status()==AppointmentStatus.NO_SHOW&&(appointment.getEndsAt()==null||appointment.getEndsAt().isAfter(java.time.Instant.now())))throw conflict("No-show cannot be recorded before the reserved interval ends");
        var linked = treatmentSessions.findByAppointmentId(id);
        if (clinical && linked.isPresent() && linked.get().getProtocol().getStatus() != com.vignesh.clinicapp.treatment.enums.ProtocolStatus.ACTIVE)
            throw conflict("Linked treatment plan is not active");
        appointment.setStatus(input.status());appointmentRepository.saveAndFlush(appointment);
        linked.ifPresent(session -> {
            var next = switch(input.status()) {
                case IN_CONSULTATION -> com.vignesh.clinicapp.treatment.enums.SessionStatus.IN_PROGRESS;
                case COMPLETED -> com.vignesh.clinicapp.treatment.enums.SessionStatus.COMPLETED;
                case CANCELLED, NO_SHOW -> com.vignesh.clinicapp.treatment.enums.SessionStatus.CANCELLED;
                default -> session.getStatus();
            };
            session.setStatus(next);treatmentSessions.saveAndFlush(session);
        });
        scheduling.event(id,actor.getId(),old.name(),input.status().name(),appointment.getStartsAt(),appointment.getStartsAt(),input.reason());
        operationData.audit(actor.getId(),branch,"APPOINTMENT_"+input.status(),"APPOINTMENT",id,requestId);
    }
    private Appointment scopedAppointment(long id,Branch branch) {
        return appointmentRepository.findByIdForUpdate(id).filter(a->a.getBranch()==branch&&!Boolean.TRUE.equals(a.getIsDeleted()))
            .orElseThrow(()->new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.NOT_FOUND,"Appointment not found"));
    }
    private org.springframework.web.server.ResponseStatusException conflict(String message){return new org.springframework.web.server.ResponseStatusException(org.springframework.http.HttpStatus.CONFLICT,message);}
    private ReservedResponse reservedResponse(Appointment a){return new ReservedResponse(a.getId(),a.getUser().getId(),a.getResourceId(),a.getServiceId(),a.getStartsAt(),a.getEndsAt(),a.getStatus().name(),a.getVersion());}
    private String hash(Object value){try{return java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(json.writeValueAsBytes(value)));}catch(Exception e){throw new IllegalStateException("Unable to fingerprint request",e);}}
    private String encode(ReservedResponse value){try{return json.writeValueAsString(value);}catch(com.fasterxml.jackson.core.JsonProcessingException e){throw new IllegalStateException(e);}}
    private ReservedResponse decode(String value){try{return json.readValue(value,ReservedResponse.class);}catch(com.fasterxml.jackson.core.JsonProcessingException e){throw new IllegalStateException(e);}}


    @Transactional
    public ApiResponse<AppointmentResponse> createAppointment(
            String email, CreateAppointmentRequest request) {

        User user = findUserForUpdate(email);
        if (request.isClaimGiftVoucher() && user.getGiftVoucherClaimedAt() != null) {
            return ApiResponse.error("You have already claimed this gift voucher");
        }

        if (!request.getAppointmentDate().atTime(request.getAppointmentTime()).isAfter(java.time.LocalDateTime.now())) {
            return ApiResponse.error("Appointment time cannot be in the past");
        }

        // Validate branch
        Branch branch;
        try {
            branch = Branch.valueOf(request.getBranch().toUpperCase());
        } catch (IllegalArgumentException e) {
            log.warn("Invalid branch [{}] from user [{}]", request.getBranch(), email);
            return ApiResponse.error("Invalid branch. Allowed: BURJUMAN, MARINA");
        }

        // One-active-appointment rule: block if any non-expired appointment exists
        List<Appointment> active = appointmentRepository
                .findActiveByUserId(user.getId(), LocalDate.now(), LocalTime.now());

        if (!active.isEmpty()) {
            Appointment a = active.get(0);
            String when = a.getAppointmentDate()
                    .format(DateTimeFormatter.ofPattern("MMM d, yyyy"))
                    + " at " + formatTime(a.getAppointmentTime());
            log.info("Booking blocked for user [{}] → active appointment exists on [{}]",
                    email, when);
            return ApiResponse.error(
                    "You already have an active appointment on " + when
                    + ". You can book a new one once it's completed.");
        }

        // Legacy mobile requests do not reserve a resource and need staff confirmation.
        Appointment appointment = Appointment.builder()
                .user(user)
                .appointmentDate(request.getAppointmentDate())
                .appointmentTime(request.getAppointmentTime())
                .branch(branch)
                .status(AppointmentStatus.PENDING)
                .note(request.getNote())
                .build();

        Appointment saved = appointmentRepository.save(appointment);
        if (request.isClaimGiftVoucher()) {
            user.setGiftVoucherClaimedAt(java.time.LocalDateTime.now());
        }
        operationData.associate(user.getId(), branch);

        String formattedTime = formatTime(request.getAppointmentTime());
        String formattedDate = request.getAppointmentDate()
                .format(DateTimeFormatter.ofPattern("MMM d, yyyy"));
        String branchLabel = branch == Branch.BURJUMAN ? "BurJuman" : "Marina";

        notificationService.createNotification(
                user,
                "Appointment Requested",
                "Your appointment at " + branchLabel + " on "
                        + formattedDate + " at " + formattedTime
                        + " is awaiting clinic confirmation. Our team will contact you to coordinate.",
                NotificationType.APPOINTMENT_BOOKED,
                "APPOINTMENT",
                saved.getId(),
                NotificationPriority.HIGH);

        log.info("Appointment [{}] booked for user [{}] at branch [{}]",
                saved.getId(), email, branchLabel);

        return ApiResponse.success(
                "Appointment requested; awaiting clinic confirmation", toResponse(saved));
    }

    @Transactional(readOnly = true)
    public ApiResponse<List<AppointmentResponse>> getMyAppointments(String email) {
        User user = findUserOrThrow(email);

        List<AppointmentResponse> list = appointmentRepository
                .findByUserIdAndIsDeletedFalseOrderByAppointmentDateDescAppointmentTimeDesc(
                        user.getId(), PageRequest.of(0, MAX_APPOINTMENTS_RETURNED))
                .stream()
                .map(this::toResponse)
                .toList();

        log.info("Appointments fetched for user [{}] → count: [{}]", email, list.size());
        return ApiResponse.success("Appointments loaded", list);
    }

    @Transactional
    public ApiResponse<AppointmentResponse> rescheduleAppointment(
            String email, Long appointmentId, CreateAppointmentRequest request) {

        User user = findUserForUpdate(email);

        Appointment appointment = appointmentRepository.findById(appointmentId)
                .filter(a -> a.getUser().getId().equals(user.getId()))
                .filter(a -> !Boolean.TRUE.equals(a.getIsDeleted()))
                .orElse(null);

        if (appointment == null) {
            return ApiResponse.error("Appointment not found");
        }

        if (appointment.getResourceId() != null) {
            return ApiResponse.error("Please contact the clinic to reschedule this reserved appointment");
        }

        if (appointment.getStatus() != AppointmentStatus.PENDING && appointment.getStatus() != AppointmentStatus.CONFIRMED) {
            return ApiResponse.error("Only pending or confirmed appointments can be rescheduled");
        }

        if (appointment.getAppointmentDate().isBefore(LocalDate.now())
                || (appointment.getAppointmentDate().isEqual(LocalDate.now())
                && !appointment.getAppointmentTime().isAfter(LocalTime.now()))) {
            return ApiResponse.error("Past appointments cannot be rescheduled");
        }

        if (!request.getAppointmentDate().atTime(request.getAppointmentTime()).isAfter(java.time.LocalDateTime.now())) {
            return ApiResponse.error("Appointment time cannot be in the past");
        }

        Branch branch;
        try {
            branch = Branch.valueOf(request.getBranch().toUpperCase());
        } catch (IllegalArgumentException e) {
            log.warn("Invalid reschedule branch [{}] from user [{}]", request.getBranch(), email);
            return ApiResponse.error("Invalid branch. Allowed: BURJUMAN, MARINA");
        }

        List<Appointment> otherActive = appointmentRepository
                .findOtherActiveByUserId(user.getId(), appointmentId, LocalDate.now(), LocalTime.now());

        if (!otherActive.isEmpty()) {
            Appointment a = otherActive.get(0);
            String when = a.getAppointmentDate()
                    .format(DateTimeFormatter.ofPattern("MMM d, yyyy"))
                    + " at " + formatTime(a.getAppointmentTime());
            return ApiResponse.error(
                    "You already have an active appointment on " + when
                    + ". You can book a new one once it's completed.");
        }

        appointment.setAppointmentDate(request.getAppointmentDate());
        appointment.setAppointmentTime(request.getAppointmentTime());
        appointment.setBranch(branch);
        appointment.setNote(request.getNote());

        Appointment saved = appointmentRepository.save(appointment);
        operationData.associate(user.getId(), branch);

        String formattedTime = formatTime(request.getAppointmentTime());
        String formattedDate = request.getAppointmentDate()
                .format(DateTimeFormatter.ofPattern("MMM d, yyyy"));
        String branchLabel = branch == Branch.BURJUMAN ? "BurJuman" : "Marina";

        notificationService.createNotification(
                user,
                "Appointment Rescheduled",
                "Your appointment has been rescheduled to " + branchLabel + " on "
                        + formattedDate + " at " + formattedTime + ".",
                NotificationType.APPOINTMENT_BOOKED,
                "APPOINTMENT_RESCHEDULED",
                saved.getId(),
                NotificationPriority.HIGH);

        log.info("Appointment [{}] rescheduled for user [{}]", saved.getId(), email);
        return ApiResponse.success("Appointment rescheduled successfully", toResponse(saved));
    }

    private User findUserForUpdate(String email) {
        return userRepository.findByEmailForUpdate(email)
                .filter(User::isActive)
                .orElseThrow(() -> new IllegalArgumentException("Active user required"));
    }

    // ── Helpers ──────────────────────────────────────────
    private User findUserOrThrow(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> {
                    log.error("User not found: [{}]", email);
                    return new RuntimeException("User not found");
                });
    }

    private AppointmentResponse toResponse(Appointment a) {
        return AppointmentResponse.builder()
                .id(a.getId())
                .appointmentDate(a.getAppointmentDate())
                .appointmentTime(a.getAppointmentTime())
                .branch(a.getBranch().name())
                .status(a.getStatus().name())
                .note(a.getNote())
                .resourceId(a.getResourceId())
                .createdAt(a.getCreatedAt())
                .build();
    }

    private String formatTime(LocalTime time) {
        int hour = time.getHour();
        int minute = time.getMinute();
        String amPm = hour >= 12 ? "PM" : "AM";
        int displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        return String.format("%d:%02d %s", displayHour, minute, amPm);
    }
}
