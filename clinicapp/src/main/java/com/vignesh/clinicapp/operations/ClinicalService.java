package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.treatment.enums.ProtocolStatus;
import com.vignesh.clinicapp.treatment.model.TreatmentProtocol;
import com.vignesh.clinicapp.treatment.repository.TreatmentProtocolRepository;
import com.vignesh.clinicapp.user.repository.UserRepository;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.time.*;
import java.util.*;

@Service
@RequiredArgsConstructor
@Transactional(readOnly=true)
public class ClinicalService {
    private final OperationsService operations;
    private final OperationsRepository audit;
    private final TreatmentProtocolRepository protocols;
    private final UserRepository users;
    private final JdbcTemplate db;
    private final com.vignesh.clinicapp.appointment.repository.AppointmentRepository appointments;
    private final com.vignesh.clinicapp.treatment.repository.TreatmentSessionRepository sessions;

    public record TemplateInput(Long previousVersionId,@NotBlank @Size(max=150) String name,
            @NotBlank @Size(max=200) String treatmentType,@NotBlank @Size(max=10000) String instructions,
            @Min(1) @Max(200) int plannedSessions) {}
    public record Template(long id,String familyId,int revision,String name,String treatmentType,
            String instructions,int plannedSessions,String state) {}
    public record PlanInput(@Positive long templateVersionId,@NotNull LocalDate startDate,
            @NotBlank @Size(max=2000) String approvalReason) {}
    public record Plan(long id,String name,String status,int totalSessions,String instructions,
            LocalDate startDate,long version,Long templateVersionId) {}
    public record PlanChange(@NotNull ProtocolStatus status,@PositiveOrZero long version,
            @NotBlank @Size(max=2000) String reason) {}

    public List<Template> templates(String email,Branch branch) {
        operations.require(email,branch,true,false);
        return db.query("select * from clinical_templates where branch=? order by created_at desc,id desc limit 200",
                (r,n)->template(r),branch.name());
    }
    private Template template(java.sql.ResultSet r)throws java.sql.SQLException {
        return new Template(r.getLong("id"),r.getString("family_id"),r.getInt("revision"),r.getString("name"),
                r.getString("treatment_type"),r.getString("instructions"),r.getInt("planned_sessions"),r.getString("state"));
    }
    private Template template(long id,Branch branch) {
        return db.query("select * from clinical_templates where id=? and branch=? for update",(r,n)->template(r),id,branch.name())
                .stream().findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Template not found"));
    }
    @Transactional
    public long createTemplate(String email,Branch branch,TemplateInput input,String requestId) {
        var actor=operations.require(email,branch,true,false);
        // Serialize versions within a family using the original template row.
        UUID family=UUID.randomUUID();int revision=1;
        if(input.previousVersionId()!=null) {
            var previous=template(input.previousVersionId(),branch);
            family=UUID.fromString(previous.familyId());
            db.queryForList("select id from clinical_templates where family_id=? and revision=1 for update",family);
            revision=db.queryForObject("select max(revision)+1 from clinical_templates where family_id=?",Integer.class,family);
        }
        long id=db.queryForObject("insert into clinical_templates(branch,family_id,revision,name,treatment_type,instructions,planned_sessions,authored_by) values (?,?,?,?,?,?,?,?) returning id",
                Long.class,branch.name(),family,revision,input.name().trim(),input.treatmentType().trim(),input.instructions().trim(),input.plannedSessions(),actor.getId());
        audit.audit(actor.getId(),branch,"TEMPLATE_DRAFT_CREATED","CLINICAL_TEMPLATE",id,requestId);return id;
    }
    @Transactional
    public void publish(String email,Branch branch,long id,String requestId) {
        var actor=operations.require(email,branch,true,false);var value=template(id,branch);
        if(!value.state().equals("DRAFT"))throw conflict("Only a draft can be published");
        db.update("update clinical_templates set state='PUBLISHED',approved_by=?,approved_at=CURRENT_TIMESTAMP where id=?",actor.getId(),id);
        audit.audit(actor.getId(),branch,"TEMPLATE_APPROVED","CLINICAL_TEMPLATE",id,requestId);
    }
    public List<Plan> plans(String email,Branch branch,long patientId) {
        operations.require(email,branch,true,false);operations.checkPatient(patientId,branch);
        return db.query("select id,protocol_name,status,total_sessions,instructions,start_date,version,template_version_id from treatment_protocols where branch=? and user_id=? and is_deleted=false order by created_at desc,id desc limit 100",
                (r,n)->new Plan(r.getLong(1),r.getString(2),r.getString(3),r.getInt(4),r.getString(5),r.getObject(6,LocalDate.class),r.getLong(7),r.getObject(8,Long.class)),branch.name(),patientId);
    }
    @Transactional
    public long assign(String email,Branch branch,long patientId,PlanInput input,String requestId) {
        var actor=operations.require(email,branch,true,false);operations.checkPatient(patientId,branch);
        var patient=users.findById(patientId).orElseThrow();patient=users.findByEmailForUpdate(patient.getEmail()).orElseThrow();
        if(protocols.existsByUserIdAndStatusAndIsDeletedFalse(patientId,ProtocolStatus.ACTIVE))throw conflict("Patient already has an active treatment plan");
        var source=template(input.templateVersionId(),branch);
        if(!source.state().equals("PUBLISHED"))throw conflict("Choose a published template version");
        var plan=TreatmentProtocol.builder().user(patient).protocolName(source.name()).treatmentType(source.treatmentType())
                .instructions(source.instructions()).totalSessions(source.plannedSessions()).startDate(input.startDate())
                .notes(input.approvalReason()).branch(branch).templateVersionId(source.id()).approvedBy(actor.getId())
                .approvedAt(Instant.now()).build();
        plan=protocols.saveAndFlush(plan);
        audit.audit(actor.getId(),branch,"PATIENT_PLAN_APPROVED","TREATMENT_PROTOCOL",plan.getId(),requestId);return plan.getId();
    }
    @Transactional
    public void change(String email,Branch branch,long patientId,long id,PlanChange input,String requestId) {
        var actor=operations.require(email,branch,true,false);operations.checkPatient(patientId,branch);
        var patient=users.findById(patientId).orElseThrow();users.findByEmailForUpdate(patient.getEmail()).orElseThrow();
        var plan=protocols.findByIdAndUserIdAndIsDeletedFalse(id,patientId).filter(p->p.getBranch()==branch)
                .orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Plan not found"));
        if(plan.getVersion()!=input.version())throw conflict("Plan changed. Refresh and try again");
        boolean allowed=switch(plan.getStatus()) {
            case ACTIVE -> input.status()==ProtocolStatus.PAUSED||input.status()==ProtocolStatus.CANCELLED||input.status()==ProtocolStatus.COMPLETED;
            case PAUSED -> input.status()==ProtocolStatus.ACTIVE||input.status()==ProtocolStatus.CANCELLED;
            default -> false;
        };
        if(!allowed)throw conflict("This plan status transition is not allowed");
        if(input.status()==ProtocolStatus.ACTIVE&&protocols.existsByUserIdAndStatusAndIsDeletedFalse(patientId,ProtocolStatus.ACTIVE))throw conflict("Patient already has an active treatment plan");
        if(input.status()==ProtocolStatus.COMPLETED) {
            int completed=db.queryForObject("select count(*) from treatment_sessions where protocol_id=? and is_deleted=false and status='COMPLETED'",Integer.class,id);
            if(completed<plan.getTotalSessions())throw conflict("Complete all planned sessions before closing the plan");
        }
        if(input.status()==ProtocolStatus.PAUSED||input.status()==ProtocolStatus.CANCELLED) {
            int open=db.queryForObject("select count(*) from treatment_sessions where protocol_id=? and is_deleted=false and status in ('SCHEDULED','IN_PROGRESS')",Integer.class,id);
            if(open>0)throw conflict("Resolve scheduled or in-progress sessions before pausing or cancelling this plan");
        }
        plan.setStatus(input.status());if(input.status()==ProtocolStatus.COMPLETED||input.status()==ProtocolStatus.CANCELLED)plan.setEndDate(LocalDate.now());
        protocols.saveAndFlush(plan);
        db.update("insert into clinical_plan_events(protocol_id,actor_id,status,reason) values (?,?,?,?)",id,actor.getId(),input.status().name(),input.reason());
        audit.audit(actor.getId(),branch,"PATIENT_PLAN_STATUS_CHANGED","TREATMENT_PROTOCOL",id,requestId);
    }
    public record SessionInput(@Positive long appointmentId,@NotBlank @Size(max=200) String name) {}
    public record Session(long id,int number,String name,String status,LocalDate date,LocalTime time,Long appointmentId) {}
    public List<Session> sessions(String email,Branch branch,long patientId,long planId) {
        operations.require(email,branch,true,false);operations.checkPatient(patientId,branch);
        scopedPlan(branch,patientId,planId);
        return sessions.findByProtocolIdAndIsDeletedFalseOrderBySessionNumberAsc(planId).stream()
            .map(s->new Session(s.getId(),s.getSessionNumber(),s.getSessionName(),s.getStatus().name(),s.getSessionDate(),s.getSessionTime(),s.getAppointmentId())).toList();
    }
    @Transactional
    public long linkSession(String email,Branch branch,long patientId,long planId,SessionInput input,String requestId) {
        var actor=operations.require(email,branch,true,false);operations.checkPatient(patientId,branch);
        var patient=users.findById(patientId).orElseThrow();users.findByEmailForUpdate(patient.getEmail()).orElseThrow();
        var plan=scopedPlan(branch,patientId,planId);
        if(plan.getStatus()!=ProtocolStatus.ACTIVE)throw conflict("Plan must be active to schedule a session");
        var appointment=appointments.findByIdForUpdate(input.appointmentId())
            .filter(a->a.getUser().getId().equals(patientId)&&a.getBranch()==branch&&!Boolean.TRUE.equals(a.getIsDeleted()))
            .orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Appointment not found"));
        if(appointment.getResourceId()==null||appointment.getStatus()!=com.vignesh.clinicapp.appointment.enums.AppointmentStatus.CONFIRMED)
            throw conflict("Choose a confirmed resource reservation");
        if(appointment.getStartsAt().isBefore(Instant.now())||appointment.getAppointmentDate().isBefore(plan.getStartDate()))
            throw conflict("Session must start in the future and on or after the plan start date");
        var linked=sessions.findByAppointmentId(input.appointmentId());
        if(linked.isPresent()) {
            if(linked.get().getProtocol().getId().equals(planId)&&linked.get().getSessionName().equals(input.name().trim()))return linked.get().getId();
            throw conflict("Appointment is already linked to a treatment session");
        }
        var existing=sessions.findByProtocolIdAndIsDeletedFalseOrderBySessionNumberAsc(planId);
        if(existing.stream().filter(v->v.getStatus()!=com.vignesh.clinicapp.treatment.enums.SessionStatus.CANCELLED).count()>=plan.getTotalSessions())
            throw conflict("All planned sessions are already scheduled");
        var session=com.vignesh.clinicapp.treatment.model.TreatmentSession.builder().protocol(plan).user(patient)
            .appointmentId(appointment.getId()).sessionNumber(existing.stream().mapToInt(v->v.getSessionNumber()).max().orElse(0)+1)
            .sessionName(input.name().trim()).sessionDate(appointment.getAppointmentDate()).sessionTime(appointment.getAppointmentTime())
            .durationMinutes((int)Duration.between(appointment.getStartsAt(),appointment.getEndsAt()).toMinutes()).build();
        session=sessions.saveAndFlush(session);
        audit.audit(actor.getId(),branch,"TREATMENT_SESSION_SCHEDULED","TREATMENT_SESSION",session.getId(),requestId);return session.getId();
    }
    private TreatmentProtocol scopedPlan(Branch branch,long patientId,long planId) {
        return protocols.findByIdAndUserIdAndIsDeletedFalse(planId,patientId).filter(p->p.getBranch()==branch)
            .orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Plan not found"));
    }
    private ResponseStatusException conflict(String message){return new ResponseStatusException(HttpStatus.CONFLICT,message);}
}
