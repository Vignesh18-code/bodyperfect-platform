package com.vignesh.clinicapp.security;

import com.vignesh.clinicapp.operations.*;
import static com.vignesh.clinicapp.operations.OperationsContracts.*;
import static com.vignesh.clinicapp.operations.SchedulingRepository.*;
import com.vignesh.clinicapp.appointment.enums.*;
import com.vignesh.clinicapp.appointment.service.AppointmentService;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.jdbc.core.JdbcTemplate;
import java.time.*;
import java.util.*;
import java.util.concurrent.*;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
@EnabledIfSystemProperty(named="spring.flyway.enabled",matches="true")
class ResourceBookingTests {
 @Autowired UserRepository users;
 @Autowired OperationsRepository ops;
 @Autowired SchedulingRepository scheduling;
 @Autowired AppointmentService appointments;
 @Autowired JdbcTemplate db;
 @Autowired ClinicalService clinical;
 @Autowired FollowUpService followups;
 User user(Role role){String id=UUID.randomUUID().toString().substring(0,8);var u=users.saveAndFlush(User.builder().email(id+"@example.test").phone(id).fullName("Synthetic reservation").password("unused").role(role).build());u.setStatus(UserStatus.ACTIVE);return users.saveAndFlush(u);}
 record Fixture(long resource,long service,Instant start,User actor,User patient){}
 Fixture fixture(){User actor=user(Role.STAFF),patient=user(Role.PATIENT);ops.member(actor.getId(),new MemberInput(Branch.MARINA,StaffRole.RECEPTION,true));ops.associate(patient.getId(),Branch.MARINA);long resource=scheduling.createResource(new ResourceInput(Branch.MARINA,"Synthetic resource","Asia/Dubai")),service=scheduling.createService(new ServiceInput("Synthetic service",30));LocalDate day=LocalDate.now(ZoneId.of("Asia/Dubai")).plusDays(3);scheduling.hours(resource,new HoursInput(day.getDayOfWeek().getValue(),LocalTime.of(9,0),LocalTime.of(17,0)));return new Fixture(resource,service,day.atTime(10,0).atZone(ZoneId.of("Asia/Dubai")).toInstant(),actor,patient);}
 AppointmentService.ReservedRequest request(Fixture f,long patient){return new AppointmentService.ReservedRequest(patient,f.resource,f.service,f.start,"Synthetic");}
 @Test void oneHundredConflictingRequestsCommitExactlyOneBooking()throws Exception{
  Fixture f=fixture();List<User> actors=new ArrayList<>(),patients=new ArrayList<>();
  for(int i=0;i<10;i++){User a=user(Role.STAFF);ops.member(a.getId(),new MemberInput(Branch.MARINA,StaffRole.RECEPTION,true));actors.add(a);}
  for(int i=0;i<100;i++){User p=user(Role.PATIENT);ops.associate(p.getId(),Branch.MARINA);patients.add(p);}
  CountDownLatch start=new CountDownLatch(1);int wins=0;
  try(var pool=Executors.newFixedThreadPool(20)){
   List<Future<Boolean>> futures=new ArrayList<>();
   for(int i=0;i<100;i++){int n=i;futures.add(pool.submit(()->{start.await();try{appointments.reserve(actors.get(n%10).getEmail(),Branch.MARINA,request(f,patients.get(n).getId()),"concurrency-"+n,"test");return true;}catch(org.springframework.web.server.ResponseStatusException e){assertEquals(409,e.getStatusCode().value());return false;}}));}
   start.countDown();for(var future:futures)if(future.get(60,TimeUnit.SECONDS))wins++;
  }
  assertEquals(1,wins);assertEquals(1,db.queryForObject("select count(*) from appointments where resource_id=?",Integer.class,f.resource));
 }
 @Test void databaseConstraintRejectsOverlapEvenOutsideBookingService(){Fixture f=fixture();appointments.reserve(f.actor.getEmail(),Branch.MARINA,request(f,f.patient.getId()),"constraint-first","test");
  assertThrows(org.springframework.dao.DataIntegrityViolationException.class,()->db.update("insert into appointments(user_id,appointment_date,appointment_time,branch,status,resource_id,service_id,starts_at,ends_at) values (?,CURRENT_DATE,'10:00','MARINA','CONFIRMED',?,?,?,?)",f.patient.getId(),f.resource,f.service,java.sql.Timestamp.from(f.start.plusSeconds(60)),java.sql.Timestamp.from(f.start.plusSeconds(1800))));
 }
 @Test void idempotencyReplaysExactResultAndRejectsChangedPayload(){Fixture f=fixture();var input=request(f,f.patient.getId());var first=appointments.reserve(f.actor.getEmail(),Branch.MARINA,input,"stable-create","test");assertEquals(first,appointments.reserve(f.actor.getEmail(),Branch.MARINA,input,"stable-create","test"));assertThrows(org.springframework.web.server.ResponseStatusException.class,()->appointments.reserve(f.actor.getEmail(),Branch.MARINA,new AppointmentService.ReservedRequest(f.patient.getId(),f.resource,f.service,f.start.plusSeconds(1800),"Synthetic"),"stable-create","test"));}
 @Test void rescheduleIsVersionedAndCancellationReleasesSlot(){Fixture f=fixture();var first=appointments.reserve(f.actor.getEmail(),Branch.MARINA,request(f,f.patient.getId()),"reschedule-create","test");var move=new AppointmentService.RescheduleRequest(f.start.plusSeconds(1800),first.version(),"Patient requested");var changed=appointments.rescheduleReserved(f.actor.getEmail(),Branch.MARINA,first.id(),move,"reschedule-key","test");assertEquals(changed,appointments.rescheduleReserved(f.actor.getEmail(),Branch.MARINA,first.id(),move,"reschedule-key","test"));assertTrue(changed.version()>first.version());appointments.transition(f.actor.getEmail(),Branch.MARINA,first.id(),new AppointmentService.TransitionRequest(AppointmentStatus.CANCELLED,changed.version(),"Patient requested"),"test");assertTrue(scheduling.free(f.resource,changed.startsAt(),changed.endsAt(),null));}
 @Test void clinicalTransitionsRequireClinicianAndInvalidJumpsAreRejected(){Fixture f=fixture();var first=appointments.reserve(f.actor.getEmail(),Branch.MARINA,request(f,f.patient.getId()),"transition-create","test");assertThrows(org.springframework.security.access.AccessDeniedException.class,()->appointments.transition(f.actor.getEmail(),Branch.MARINA,first.id(),new AppointmentService.TransitionRequest(AppointmentStatus.COMPLETED,0,null),"test"));assertThrows(org.springframework.web.server.ResponseStatusException.class,()->appointments.transition(f.actor.getEmail(),Branch.MARINA,first.id(),new AppointmentService.TransitionRequest(AppointmentStatus.NO_SHOW,0,"Too early"),"test"));appointments.transition(f.actor.getEmail(),Branch.MARINA,first.id(),new AppointmentService.TransitionRequest(AppointmentStatus.CHECKED_IN,0,null),"test");User clinician=user(Role.STAFF);ops.member(clinician.getId(),new MemberInput(Branch.MARINA,StaffRole.CLINICIAN,true));appointments.transition(clinician.getEmail(),Branch.MARINA,first.id(),new AppointmentService.TransitionRequest(AppointmentStatus.IN_CONSULTATION,1,null),"test");appointments.transition(clinician.getEmail(),Branch.MARINA,first.id(),new AppointmentService.TransitionRequest(AppointmentStatus.COMPLETED,2,null),"test");assertEquals("COMPLETED",db.queryForObject("select status from appointments where id=?",String.class,first.id()));}
 @Test void mobileRequestIsConfirmedInPlaceAndCannotBypassResourceRules(){
  Fixture f=fixture();var input=new com.vignesh.clinicapp.appointment.dto.CreateAppointmentRequest();
  var local=f.start.atZone(ZoneId.of("Asia/Dubai"));input.setAppointmentDate(local.toLocalDate());input.setAppointmentTime(local.toLocalTime());input.setBranch("MARINA");
  var response=appointments.createAppointment(f.patient.getEmail(),input);assertTrue(response.isSuccess());
  long id=db.queryForObject("select id from appointments where user_id=?",Long.class,f.patient.getId());
  assertEquals("PENDING",db.queryForObject("select status from appointments where id=?",String.class,id));
  var confirmed=appointments.reserve(f.actor.getEmail(),Branch.MARINA,new AppointmentService.ReservedRequest(f.patient.getId(),f.resource,f.service,f.start,"Requested by patient",id,0),"confirm-request","test");
  assertEquals(id,confirmed.id());assertEquals("CONFIRMED",confirmed.status());
  assertEquals(1,db.queryForObject("select count(*) from appointments where user_id=?",Integer.class,f.patient.getId()));
 }
 @Test void linkedSessionTracksReservationAndRequiresClinicalCompletion(){
  Fixture f=fixture();User c=user(Role.STAFF);ops.member(c.getId(),new MemberInput(Branch.MARINA,StaffRole.CLINICIAN,true));
  long template=clinical.createTemplate(c.getEmail(),Branch.MARINA,new ClinicalService.TemplateInput(null,"Synthetic plan","Test","Test only",1),"test");
  clinical.publish(c.getEmail(),Branch.MARINA,template,"test");
  long plan=clinical.assign(c.getEmail(),Branch.MARINA,f.patient.getId(),new ClinicalService.PlanInput(template,LocalDate.now(),"Test review"),"test");
  var booked=appointments.reserve(f.actor.getEmail(),Branch.MARINA,request(f,f.patient.getId()),"session-book","test");
  var input=new ClinicalService.SessionInput(booked.id(),"Synthetic session");
  assertThrows(org.springframework.security.access.AccessDeniedException.class,()->clinical.linkSession(f.actor.getEmail(),Branch.MARINA,f.patient.getId(),plan,input,"test"));
  long session=clinical.linkSession(c.getEmail(),Branch.MARINA,f.patient.getId(),plan,input,"test");
  assertEquals(session,clinical.linkSession(c.getEmail(),Branch.MARINA,f.patient.getId(),plan,input,"test"));
  var moved=appointments.rescheduleReserved(f.actor.getEmail(),Branch.MARINA,booked.id(),new AppointmentService.RescheduleRequest(f.start.plusSeconds(1800),0,"Requested"),"session-move","test");
  assertEquals(moved.startsAt().atZone(ZoneId.of("Asia/Dubai")).toLocalTime(),db.queryForObject("select session_time from treatment_sessions where id=?",java.sql.Time.class,session).toLocalTime());
  assertThrows(org.springframework.web.server.ResponseStatusException.class,()->clinical.change(c.getEmail(),Branch.MARINA,f.patient.getId(),plan,new ClinicalService.PlanChange(com.vignesh.clinicapp.treatment.enums.ProtocolStatus.PAUSED,0,"Pause"),"test"));
  appointments.transition(f.actor.getEmail(),Branch.MARINA,booked.id(),new AppointmentService.TransitionRequest(AppointmentStatus.CHECKED_IN,moved.version(),null),"test");
  appointments.transition(c.getEmail(),Branch.MARINA,booked.id(),new AppointmentService.TransitionRequest(AppointmentStatus.IN_CONSULTATION,moved.version()+1,null),"test");
  assertEquals("IN_PROGRESS",db.queryForObject("select status from treatment_sessions where id=?",String.class,session));
  appointments.transition(c.getEmail(),Branch.MARINA,booked.id(),new AppointmentService.TransitionRequest(AppointmentStatus.COMPLETED,moved.version()+2,null),"test");
  clinical.change(c.getEmail(),Branch.MARINA,f.patient.getId(),plan,new ClinicalService.PlanChange(com.vignesh.clinicapp.treatment.enums.ProtocolStatus.COMPLETED,0,"Completed reviewed sessions"),"test");
  assertEquals("COMPLETED",db.queryForObject("select status from treatment_protocols where id=?",String.class,plan));
 }
 @Test void followUpsRequireBranchPatientAndAssigneeAndRejectStaleResolution(){
  Fixture f=fixture();var input=new FollowUpService.Input(f.patient.getId(),f.actor.getId(),"Synthetic call reminder",LocalDate.now().plusDays(1));
  long id=followups.create(f.actor.getEmail(),Branch.MARINA,input,"test");
  assertTrue(followups.list(f.actor.getEmail(),Branch.MARINA,FollowUpService.State.OPEN,0).items().stream().anyMatch(t->t.id()==id));
  assertThrows(org.springframework.security.access.AccessDeniedException.class,()->followups.list(f.actor.getEmail(),Branch.BURJUMAN,FollowUpService.State.OPEN,0));
  assertThrows(org.springframework.web.server.ResponseStatusException.class,()->followups.create(f.actor.getEmail(),Branch.MARINA,new FollowUpService.Input(f.patient.getId(),f.patient.getId(),"Test",LocalDate.now()),"test"));
  followups.resolve(f.actor.getEmail(),Branch.MARINA,id,new FollowUpService.Resolve(FollowUpService.State.DONE,"Called",0),"test");
  assertThrows(org.springframework.web.server.ResponseStatusException.class,()->followups.resolve(f.actor.getEmail(),Branch.MARINA,id,new FollowUpService.Resolve(FollowUpService.State.CANCELLED,"Stale",0),"test"));
 }
}
