package com.vignesh.clinicapp.auth.service;
import com.vignesh.clinicapp.privacy.*;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import java.util.*;
import java.nio.file.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={"app.mail.worker-enabled=false","app.privacy.fulfillment-enabled=true"}) @ActiveProfiles("test") @AutoConfigureMockMvc
class AccountClosureTests {
 @Autowired AccountClosureService closures; @Autowired PrivacyService privacy;
 @Autowired PrivacyFileCleanup cleanup; @Autowired UserRepository users;
 @Autowired PasswordEncoder encoder; @Autowired JdbcTemplate db;
 @Autowired AuthSessionService sessions; @Autowired MockMvc mvc; @Autowired SecretCipher cipher;
 User user(Role role){String id=UUID.randomUUID().toString();var u=users.saveAndFlush(User.builder().email(id+"@example.test").phone(id.substring(0,12)).fullName("Synthetic test").password(encoder.encode("Test@12345")).role(role).build());u.setStatus(UserStatus.ACTIVE);return users.saveAndFlush(u);}
 long request(User u,User admin){long id=((Number)privacy.request(u.getEmail(),new PrivacyService.Deletion("Test@12345")).get("id")).longValue();privacy.beginDeletionReview(admin.getEmail(),id);return id;}
 AccountClosureService.Fulfillment input(String reason,List<Long> ids,long last){return new AccountClosureService.Fulfillment(true,true,true,"Identity verified; outcome explained to patient",reason,ids,last);}
 @Test void productionGateBlocksDeletionWithoutChangingTheAccount(){
  var u=user(Role.PATIENT);var admin=user(Role.ADMIN);long id=request(u,admin);
  Object target=org.springframework.test.util.AopTestUtils.getUltimateTargetObject(closures);
  org.springframework.test.util.ReflectionTestUtils.setField(target,"fulfillmentEnabled",false);
  try{assertThrows(org.springframework.web.server.ResponseStatusException.class,()->closures.fulfill(admin.getEmail(),id,input(null,List.of(),0)));assertTrue(users.findById(u.getId()).orElseThrow().isActive());assertEquals(0L,db.queryForObject("select count(*) from account_closures where patient_id=?",Long.class,u.getId()));}
  finally{org.springframework.test.util.ReflectionTestUtils.setField(target,"fulfillmentEnabled",true);}
 }
 @Test void deletesNonClinicalDataRevokesBothTokensAndCleansOnlyOwnerFiles() throws Exception {
  var u=user(Role.PATIENT);var admin=user(Role.ADMIN);var other=user(Role.PATIENT);var token=sessions.issue(u);long id=request(u,admin);
  db.update("insert into assistant_preferences(patient_id,note) values (?,'synthetic preference')",u.getId());
  db.update("insert into notifications(user_id,title,message) values (?,'test','synthetic')",u.getId());
  Path dir=Path.of(System.getProperty("java.io.tmpdir"),"clinicapp-test-uploads","profiles");Files.createDirectories(dir);
  Path own=dir.resolve("user-"+u.getId()+"-test.png"),unrelated=dir.resolve("user-"+other.getId()+"-test.png");Files.writeString(own,"test");Files.writeString(unrelated,"other");
  closures.fulfill(admin.getEmail(),id,input(null,List.of(),0));
  assertFalse(sessions.refresh(token.getRefreshToken()).isSuccess());
  mvc.perform(get("/api/user/profile").header("Authorization","Bearer "+token.getAccessToken())).andExpect(status().isUnauthorized());
  assertTrue(users.findByEmail(u.getEmail()).isEmpty());
  assertEquals(0L,db.queryForObject("select count(*) from notifications where user_id=?",Long.class,u.getId()));
  assertEquals(0L,db.queryForObject("select count(*) from assistant_preferences where patient_id=?",Long.class,u.getId()));
  assertNull(db.queryForObject("select retained_identity from account_closures where patient_id=?",String.class,u.getId()));
  assertEquals("IN_REVIEW",db.queryForObject("select state from privacy_requests where id=?",String.class,id));
  cleanup.run();assertFalse(Files.exists(own));assertTrue(Files.exists(unrelated));Files.delete(unrelated);
  assertEquals("COMPLETED",db.queryForObject("select state from privacy_requests where id=?",String.class,id));
  assertThrows(org.springframework.web.server.ResponseStatusException.class,()->closures.fulfill(admin.getEmail(),id,input(null,List.of(),0)));
 }
 @Test void preservesClinicalRecordsRequiresReasonAndRejectsOtherPatientMessages(){
  var u=user(Role.PATIENT);var admin=user(Role.ADMIN);long id=request(u,admin);
  db.update("insert into appointments(user_id,appointment_date,appointment_time,branch) values (?,current_date,'09:00','BURJUMAN')",u.getId());
  assertThrows(org.springframework.security.access.AccessDeniedException.class,()->closures.fulfill(u.getEmail(),id,input("test",List.of(),0)));
  assertThrows(org.springframework.web.server.ResponseStatusException.class,()->closures.fulfill(admin.getEmail(),id,input(null,List.of(),0)));
  assertThrows(org.springframework.web.server.ResponseStatusException.class,()->closures.fulfill(admin.getEmail(),id,input("DHA retention",List.of(999999L),0)));
  assertTrue(users.findById(u.getId()).orElseThrow().isActive());
  closures.fulfill(admin.getEmail(),id,input("DHA clinical record, minimum 25 years from last encounter; no automatic purge",List.of(),0));
  assertEquals(1L,db.queryForObject("select count(*) from appointments where user_id=?",Long.class,u.getId()));
  String retained=db.queryForObject("select retained_identity from account_closures where patient_id=?",String.class,u.getId());
  assertFalse(retained.contains(u.getEmail()));assertTrue(cipher.decrypt(retained).contains(u.getEmail()));
 }
 @Test void refusesStaleMessageReviewAndDeletesOnlyExplicitAdministrativeSelection(){
  var u=user(Role.PATIENT);var admin=user(Role.ADMIN);long id=request(u,admin);
  long thread=db.queryForObject("insert into support_threads(patient_id,branch) values (?,'BURJUMAN') returning id",Long.class,u.getId());
  long message=db.queryForObject("insert into support_messages(thread_id,sender_id,sender_role,client_id,body) values (?,?,'PATIENT',?,'synthetic appointment enquiry') returning id",Long.class,thread,u.getId(),UUID.randomUUID());
  assertThrows(org.springframework.web.server.ResponseStatusException.class,()->closures.fulfill(admin.getEmail(),id,input(null,List.of(message),0)));
  closures.fulfill(admin.getEmail(),id,input(null,List.of(message),message));
  assertEquals(0L,db.queryForObject("select count(*) from support_messages where thread_id=?",Long.class,thread));
  assertNull(db.queryForObject("select retained_identity from account_closures where patient_id=?",String.class,u.getId()));
 }
}
