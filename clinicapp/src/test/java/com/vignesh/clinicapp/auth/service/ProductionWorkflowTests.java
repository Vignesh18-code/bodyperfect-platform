package com.vignesh.clinicapp.auth.service;
import com.vignesh.clinicapp.auth.dto.LoginRequest;
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
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.MailSendException;
import org.springframework.transaction.support.TransactionTemplate;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@SpringBootTest(properties={"app.staff.mfa-required=true","app.mail.poll-ms=3600000"})
@ActiveProfiles("test") @AutoConfigureMockMvc
class ProductionWorkflowTests {
 @Autowired AuthService auth; @Autowired AuthSessionService sessions; @Autowired StaffMfaService mfa;
 @Autowired UserRepository users; @Autowired PasswordEncoder encoder; @Autowired JdbcTemplate db;
 @Autowired PrivacyService privacy; @Autowired EmailService email; @Autowired TransactionTemplate tx;
 @Autowired MockMvc mvc; @MockitoBean JavaMailSender sender;
 User user(Role role){String id=UUID.randomUUID().toString();var u=User.builder().email(id+"@example.test").phone(id.substring(0,12)).fullName("Synthetic").password(encoder.encode("Test@12345")).role(role).build();u=users.saveAndFlush(u);u.setStatus(UserStatus.ACTIVE);return users.saveAndFlush(u);}
 LoginRequest login(User u){var r=new LoginRequest();r.setEmail(u.getEmail());r.setPassword("Test@12345");return r;}
 @Test void staffMustEnrollAndCannotReplayCodeOrBypassThroughGeneralLogin(){
  var u=user(Role.ADMIN);var r=login(u);
  assertEquals("MFA_SETUP_REQUIRED",auth.login(r).getMessage());
  String secret=(String)((java.util.Map<?,?>)auth.setupStaffMfa(r).getData()).get("secret");
  assertEquals("MFA_REQUIRED",auth.login(r).getMessage());
  r.setOtp(StaffMfaService.totp(secret,java.time.Instant.now().getEpochSecond()/30));
  assertTrue(auth.login(r).isSuccess());assertFalse(auth.login(r).isSuccess());
  for(int i=0;i<5;i++){r.setOtp("999999");auth.login(r);}
  assertNotNull(db.queryForObject("select locked_until from staff_totp where user_id=?",java.sql.Timestamp.class,u.getId()));
  assertTrue(auth.login(login(user(Role.PATIENT))).isSuccess());
 }
 @Test void privacyRequiresPasswordOwnershipAndAdministrator(){
  var owner=user(Role.PATIENT);var other=user(Role.PATIENT);var admin=user(Role.ADMIN);
  assertThrows(org.springframework.web.server.ResponseStatusException.class,()->privacy.request(owner.getEmail(),new PrivacyService.Deletion("wrong")));
  privacy.request(owner.getEmail(),new PrivacyService.Deletion("Test@12345"));privacy.request(owner.getEmail(),new PrivacyService.Deletion("Test@12345"));
  assertEquals(1,privacy.requests(owner.getEmail()).size());assertTrue(privacy.requests(other.getEmail()).isEmpty());
  assertThrows(org.springframework.security.access.AccessDeniedException.class,()->privacy.queue(other.getEmail(),"deletion",0));
  Long id=db.queryForObject("insert into assistant_exchanges(patient_id,client_id,question,answer,state,consent_version) values (?,?,'test','test','COMPLETED','test') returning id",Long.class,owner.getId(),UUID.randomUUID());
  assertThrows(org.springframework.web.server.ResponseStatusException.class,()->privacy.report(other.getEmail(),id,new PrivacyService.Report("UNSAFE")));
  privacy.report(owner.getEmail(),id,new PrivacyService.Report("UNSAFE"));privacy.report(owner.getEmail(),id,new PrivacyService.Report("UNSAFE"));
  assertEquals(1L,db.queryForObject("select count(*) from assistant_reports where exchange_id=?",Long.class,id));
  assertFalse(privacy.queue(admin.getEmail(),"reports",0).isEmpty());
 }
 @Test void oldPhotoPathsAndAnonymousOwnerEndpointAreBlocked() throws Exception {
  mvc.perform(get("/uploads/profiles/test.jpg")).andExpect(status().isUnauthorized());
  mvc.perform(get("/api/user/profile/image")).andExpect(status().isUnauthorized());
  var token=sessions.issue(user(Role.PATIENT)).getAccessToken();
  mvc.perform(get("/uploads/profiles/test.jpg").header("Authorization","Bearer "+token)).andExpect(status().isForbidden());
 }
 @Test void uploadedPhotoIsReadableOnlyByItsOwner() throws Exception {
  var owner=user(Role.PATIENT);var other=user(Role.PATIENT);
  String a=sessions.issue(owner).getAccessToken(),b=sessions.issue(other).getAccessToken();
  var image=new java.awt.image.BufferedImage(2,2,java.awt.image.BufferedImage.TYPE_INT_RGB);
  var out=new java.io.ByteArrayOutputStream();javax.imageio.ImageIO.write(image,"png",out);
  var file=new org.springframework.mock.web.MockMultipartFile("file","avatar.png","image/png",out.toByteArray());
  mvc.perform(multipart("/api/user/profile/image").file(file).header("Authorization","Bearer "+a)).andExpect(status().isOk());
  mvc.perform(get("/api/user/profile/image").header("Authorization","Bearer "+a)).andExpect(status().isOk()).andExpect(header().string("Cache-Control",org.hamcrest.Matchers.containsString("no-store")));
  mvc.perform(get("/api/user/profile/image").header("Authorization","Bearer "+b)).andExpect(status().isNotFound());
 }
 @Test void mailQueueRollsBackRetriesAndClearsSecretsAfterDelivery(){
  String address=UUID.randomUUID()+"@example.test";
  tx.executeWithoutResult(s->{email.sendOtpEmail(address,"test","123456");s.setRollbackOnly();});
  assertEquals(0L,db.queryForObject("select count(*) from mail_outbox where recipient=?",Long.class,address));
  email.sendOtpEmail(address,"test","123456");
  assertFalse(db.queryForObject("select payload from mail_outbox where recipient=?",String.class,address).contains("123456"));
  doThrow(new MailSendException("temporary")).when(sender).send(any(SimpleMailMessage.class));email.deliverPending();
  assertEquals(1,db.queryForObject("select attempts from mail_outbox where recipient=?",Integer.class,address));
  reset(sender);db.update("update mail_outbox set next_attempt=current_timestamp where recipient=?",address);email.deliverPending();
  assertEquals(0L,db.queryForObject("select count(*) from mail_outbox where recipient=?",Long.class,address));
 }
}
