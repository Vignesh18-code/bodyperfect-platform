package com.vignesh.clinicapp.security;

import com.vignesh.clinicapp.operations.*;
import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.treatment.enums.ProtocolStatus;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.server.ResponseStatusException;
import java.time.LocalDate;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static com.vignesh.clinicapp.operations.ClinicalService.*;
import static com.vignesh.clinicapp.operations.OperationsContracts.*;

@SpringBootTest
@ActiveProfiles("test")
@EnabledIfSystemProperty(named="spring.flyway.enabled",matches="true")
class ClinicalAuthoringTests {
 @Autowired ClinicalService clinical;
 @Autowired OperationsRepository ops;
 @Autowired UserRepository users;
 @Autowired JdbcTemplate db;
 User user(Role role){String id=UUID.randomUUID().toString().substring(0,8);var u=users.saveAndFlush(User.builder().email(id+"@example.test").phone(id).fullName("Synthetic clinician test").password("unused").role(role).build());u.setStatus(UserStatus.ACTIVE);return users.saveAndFlush(u);}
 User clinician(){var u=user(Role.STAFF);ops.member(u.getId(),new MemberInput(Branch.MARINA,StaffRole.CLINICIAN,true));return u;}
 long draft(User c,Long previous,String instructions){return clinical.createTemplate(c.getEmail(),Branch.MARINA,new TemplateInput(previous,"Synthetic template","Test content",instructions,2),"test");}
 @Test void onlyBranchClinicianCanAuthorAndReadClinicalContent(){var c=clinician();var admin=user(Role.ADMIN);var reception=user(Role.STAFF);ops.member(reception.getId(),new MemberInput(Branch.MARINA,StaffRole.RECEPTION,true));assertThrows(AccessDeniedException.class,()->draft(admin,null,"Test"));assertThrows(AccessDeniedException.class,()->clinical.templates(reception.getEmail(),Branch.MARINA));assertThrows(AccessDeniedException.class,()->clinical.templates(c.getEmail(),Branch.BURJUMAN));}
 @Test void draftCannotBeAssignedAndPublishedRevisionDoesNotChangeExistingPlan(){var c=clinician();var p=user(Role.PATIENT);ops.associate(p.getId(),Branch.MARINA);long v1=draft(c,null,"Approved version one");var input=new PlanInput(v1,LocalDate.now(),"Synthetic suitability review");assertThrows(ResponseStatusException.class,()->clinical.assign(c.getEmail(),Branch.MARINA,p.getId(),input,"test"));clinical.publish(c.getEmail(),Branch.MARINA,v1,"test");long plan=clinical.assign(c.getEmail(),Branch.MARINA,p.getId(),input,"test");long v2=draft(c,v1,"Approved version two");clinical.publish(c.getEmail(),Branch.MARINA,v2,"test");assertEquals("Approved version one",db.queryForObject("select instructions from treatment_protocols where id=?",String.class,plan));assertEquals(2,db.queryForObject("select revision from clinical_templates where id=?",Integer.class,v2));assertThrows(ResponseStatusException.class,()->clinical.publish(c.getEmail(),Branch.MARINA,v1,"test"));assertThrows(ResponseStatusException.class,()->clinical.assign(c.getEmail(),Branch.MARINA,p.getId(),input,"test"));}
 @Test void patientScopeVersionAndCompletionRulesAreEnforced(){var c=clinician();var p=user(Role.PATIENT);ops.associate(p.getId(),Branch.MARINA);long template=draft(c,null,"Synthetic instructions");clinical.publish(c.getEmail(),Branch.MARINA,template,"test");long plan=clinical.assign(c.getEmail(),Branch.MARINA,p.getId(),new PlanInput(template,LocalDate.now(),"Reviewed"),"test");assertThrows(ResponseStatusException.class,()->clinical.change(c.getEmail(),Branch.MARINA,p.getId(),plan,new PlanChange(ProtocolStatus.COMPLETED,0,"Close too soon"),"test"));clinical.change(c.getEmail(),Branch.MARINA,p.getId(),plan,new PlanChange(ProtocolStatus.PAUSED,0,"Clinician paused"),"test");assertThrows(ResponseStatusException.class,()->clinical.change(c.getEmail(),Branch.MARINA,p.getId(),plan,new PlanChange(ProtocolStatus.ACTIVE,0,"Stale update"),"test"));var outsider=user(Role.PATIENT);assertThrows(ResponseStatusException.class,()->clinical.plans(c.getEmail(),Branch.MARINA,outsider.getId()));assertEquals(1,db.queryForObject("select count(*) from clinical_plan_events where protocol_id=?",Integer.class,plan));}
}
