package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.auth.service.AuthService;
import com.vignesh.clinicapp.auth.service.AuthSessionService;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.util.*;
import java.time.LocalDate;
import static com.vignesh.clinicapp.operations.OperationsContracts.*;

@Service
@RequiredArgsConstructor
@Transactional(readOnly=true)
public class OperationsService {
    private final OperationsRepository repository;
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final AuthService auth;
    private final AuthSessionService sessions;

    public User staffUser(String email) {
        return users.findByEmail(email).filter(User::isActive).filter(u->u.getRole()!=Role.PATIENT)
            .orElseThrow(()->new AccessDeniedException("Staff access required"));
    }
    public User require(String email,Branch branch,boolean clinical,boolean manage) {
        User actor=staffUser(email);
        if(actor.getRole()==Role.ADMIN && !clinical)return actor;
        Membership member=repository.memberships(actor.getId()).stream().filter(m->m.branch()==branch).findFirst()
            .orElseThrow(()->new AccessDeniedException("Branch access required"));
        if(clinical && member.role()!=StaffRole.CLINICIAN)throw new AccessDeniedException("Clinical permission required");
        if(manage && member.role()!=StaffRole.BRANCH_MANAGER)throw new AccessDeniedException("Manager permission required");
        return actor;
    }
    public Me me(String email) {
        User u=staffUser(email);
        List<Membership> memberships=u.getRole()==Role.ADMIN?Arrays.stream(Branch.values()).map(b->new Membership(b,StaffRole.BRANCH_MANAGER)).toList():repository.memberships(u.getId());
        return new Me(u.getId(),u.getFullName(),u.getRole().name(),memberships);
    }
    public Page<Patient> patients(String email,Branch branch,String query,int page,int size) {
        require(email,branch,false,false);return page(repository.patients(branch,query,page,size),page,size);
    }
    public Patient patient(String email,Branch branch,long id) {
        require(email,branch,false,false);checkPatient(id,branch);return repository.patient(id);
    }
    public void checkPatient(long id,Branch branch) {
        if(!repository.containsPatient(id,branch))throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Patient not found");
    }
    @Transactional
    public Patient createPatient(String email,Branch branch,PatientInput input,String requestId) {
        User actor=require(email,branch,false,false);
        // An existing account is not silently linked to another branch or overwritten.
        User patient=users.saveAndFlush(User.builder().fullName(input.fullName().trim()).email(input.email().trim().toLowerCase(Locale.ROOT))
            .phone(input.phone()).password(encoder.encode(UUID.randomUUID()+"!Aa1")).role(Role.PATIENT).setupRequired(true).build());
        repository.associate(patient.getId(),branch);
        repository.audit(actor.getId(),branch,"PATIENT_CREATED","PATIENT",patient.getId(),requestId);
        // Email ownership and a patient-chosen password are both required before activation.
        auth.forgotPassword(patient.getEmail());
        return repository.patient(patient.getId());
    }
    @Transactional
    public Patient editPatient(String email,Branch branch,long id,PatientEdit input,String requestId) {
        User actor=require(email,branch,false,false);checkPatient(id,branch);
        if(!repository.edit(id,input))throw new ResponseStatusException(HttpStatus.CONFLICT,"Patient changed. Refresh and try again");
        repository.audit(actor.getId(),branch,"PATIENT_UPDATED","PATIENT",id,requestId);return repository.patient(id);
    }
    public List<Staff> staff(String email,Branch branch) {require(email,branch,false,true);return repository.staff(branch);}
    @Transactional
    public void invite(String email,StaffInput input,String requestId) {
        User actor=staffUser(email);if(actor.getRole()!=Role.ADMIN)throw new AccessDeniedException("Administrator required");
        User staff=users.saveAndFlush(User.builder().fullName(input.fullName().trim()).email(input.email().trim().toLowerCase(Locale.ROOT))
            .phone(input.phone()).password(encoder.encode(UUID.randomUUID()+"!Aa1")).role(Role.STAFF).setupRequired(true).build());
        repository.member(staff.getId(),new MemberInput(input.branch(),input.staffRole(),true));
        repository.audit(actor.getId(),input.branch(),"STAFF_INVITED","USER",staff.getId(),requestId);
        auth.forgotPassword(staff.getEmail());
    }
    @Transactional
    public void member(String email,long id,MemberInput input,String requestId) {
        User actor=staffUser(email);if(actor.getRole()!=Role.ADMIN)throw new AccessDeniedException("Administrator required");
        User target=users.findById(id).filter(u->u.getRole()==Role.STAFF).orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Staff not found"));
        // Serialize with login/refresh/password reset before changing security state.
        target=users.findByEmailForUpdate(target.getEmail()).orElseThrow();
        repository.member(id,input);sessions.revokeAll(target);
        repository.audit(actor.getId(),input.branch(),"STAFF_MEMBERSHIP_CHANGED","USER",id,requestId);
    }
    public Page<Audit> audit(String email,Branch branch,int page,int size) {
        require(email,branch,false,true);return page(repository.audit(branch,page,size),page,size);
    }
    public Page<AppointmentItem> appointments(String email,Branch branch,LocalDate from,LocalDate to,int page,int size,Long patient) {
        require(email,branch,false,false);
        if(from.isAfter(to)||from.plusDays(93).isBefore(to))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Date range must be at most 93 days");
        if(patient!=null)checkPatient(patient,branch);
        return page(repository.appointments(branch,from,to,page,size,patient),page,size);
    }
    public Overview overview(String email,Branch branch,LocalDate day) {require(email,branch,false,false);return repository.overview(branch,day);}
    private <T> Page<T> page(List<T> values,int page,int size) {return new Page<>(values.stream().limit(size).toList(),page,size,values.size()>size);}
}
