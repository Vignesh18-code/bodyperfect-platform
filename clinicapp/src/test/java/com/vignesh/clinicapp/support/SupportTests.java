package com.vignesh.clinicapp.support;
import com.vignesh.clinicapp.operations.*;
import static com.vignesh.clinicapp.operations.OperationsContracts.*;
import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.auth.service.AuthSessionService;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.server.ResponseStatusException;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
@EnabledIfSystemProperty(named="spring.flyway.enabled",matches="true")
class SupportTests {
 @Autowired SupportService support; @Autowired AssistantService assistant; @Autowired UserRepository users; @Autowired OperationsRepository ops; @Autowired JdbcTemplate db; @Autowired MockMvc mvc; @Autowired AuthSessionService sessions;
 @MockitoBean OpenAiGateway ai;
 User user(Role role){String key=UUID.randomUUID().toString().substring(0,8);var u=users.saveAndFlush(User.builder().email(key+"@example.test").phone(key).fullName("Synthetic Support").password("SECRET_PASSWORD_MUST_NOT_LEAK").role(role).build());u.setStatus(UserStatus.ACTIVE);return users.saveAndFlush(u);}
 User patient(){var u=user(Role.PATIENT);ops.associate(u.getId(),Branch.MARINA);return u;}
 User staff(){var u=user(Role.STAFF);ops.member(u.getId(),new MemberInput(Branch.MARINA,StaffRole.RECEPTION,true));return u;}
 @BeforeEach void setup(){when(ai.available()).thenReturn(true);when(ai.model()).thenReturn("mock-model");}
 @Test void messagesAreScopedDeduplicatedAndRepliesNotify() {
  var p=patient();var stranger=patient();var s=staff();var t=support.open(p.getEmail(),Branch.MARINA);var send=new SupportService.Send(UUID.randomUUID(),"When is reception available?");
  var m=support.send(p.getEmail(),t.id(),false,send,null);assertEquals(m.id(),support.send(p.getEmail(),t.id(),false,send,null).id());
  assertThrows(ResponseStatusException.class,()->support.send(p.getEmail(),t.id(),false,new SupportService.Send(send.clientId(),"Changed"),null));
  assertThrows(ResponseStatusException.class,()->support.messages(stranger.getEmail(),t.id(),false,null));
  support.send(s.getEmail(),t.id(),true,new SupportService.Send(UUID.randomUUID(),"A synthetic staff reply"),"test");
  assertEquals(2,support.messages(p.getEmail(),t.id(),false,null).items().size());
  assertEquals(1,db.queryForObject("select count(*) from notifications where user_id=? and title='Clinic support replied'",Integer.class,p.getId()));
  assertEquals(1,db.queryForObject("select count(*) from audit_events where entity_type='SUPPORT_THREAD' and entity_id=? and action='SUPPORT_REPLIED'",Integer.class,t.id()));
  ops.member(s.getId(),new MemberInput(Branch.MARINA,StaffRole.RECEPTION,false));
  assertThrows(AccessDeniedException.class,()->support.messages(s.getEmail(),t.id(),true,null));
 }
 @Test void wrongBranchAndStaleUpdatesAreRejected(){var p=patient();var s=staff();var t=support.open(p.getEmail(),Branch.MARINA);assertThrows(AccessDeniedException.class,()->support.inbox(s.getEmail(),Branch.BURJUMAN,0));assertThrows(ResponseStatusException.class,()->support.open(p.getEmail(),Branch.BURJUMAN));support.update(s.getEmail(),t.id(),new SupportService.Update("CLAIM",0),"test");assertThrows(ResponseStatusException.class,()->support.update(s.getEmail(),t.id(),new SupportService.Update("RESOLVE",0),"test"));}
 @Test void paginationAndRateLimitAreBounded(){var p=patient();var t=support.open(p.getEmail(),Branch.MARINA);for(int i=0;i<52;i++)db.update("insert into support_messages(thread_id,sender_id,sender_role,client_id,body,created_at) values (?,?,'PATIENT',?,? ,CURRENT_TIMESTAMP-INTERVAL '2 minutes')",t.id(),p.getId(),UUID.randomUUID(),"Message "+i);var page=support.messages(p.getEmail(),t.id(),false,null);assertEquals(50,page.items().size());assertTrue(page.hasEarlier());assertEquals(2,support.messages(p.getEmail(),t.id(),false,page.items().getFirst().id()).items().size());for(int i=0;i<20;i++)support.send(p.getEmail(),t.id(),false,new SupportService.Send(UUID.randomUUID(),"Recent "+i),null);assertEquals(429,assertThrows(ResponseStatusException.class,()->support.send(p.getEmail(),t.id(),false,new SupportService.Send(UUID.randomUUID(),"Too many"),null)).getStatusCode().value());}
 @Test void assistantRequiresConsentConfigurationAndPatientAccount()throws Exception{var p=patient();assertThrows(ResponseStatusException.class,()->assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"Help",false)));when(ai.available()).thenReturn(false);assertEquals(503,assertThrows(ResponseStatusException.class,()->assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"Help",true))).getStatusCode().value());assertThrows(AccessDeniedException.class,()->assistant.history(staff().getEmail()));verify(ai,never()).answer(anyString(),any());}
 @Test void assistantProjectionExcludesOtherPatientsSecretsAndNotesAndIsIdempotent()throws Exception {
  var p=patient();var other=patient();
  for(var u:List.of(p,other))db.update("insert into treatment_protocols(user_id,protocol_name,status,instructions,total_sessions,is_deleted,created_at,updated_at,approved_at,notes) values (?,?,'ACTIVE',?,2,false,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,'PRIVATE_INTERNAL_NOTE')",u.getId(),"Approved plan",u.getId().equals(p.getId())?"MY_APPROVED_INSTRUCTIONS":"OTHER_PATIENT_INSTRUCTIONS");
  db.update("insert into treatment_protocols(user_id,protocol_name,status,instructions,total_sessions,is_deleted,created_at,updated_at) values (?,'Draft','ACTIVE','UNAPPROVED_INSTRUCTIONS',2,false,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",p.getId());
  when(ai.answer(anyString(),any())).thenAnswer(call->{String context=call.getArgument(1).toString();assertTrue(context.contains("MY_APPROVED_INSTRUCTIONS"));for(var forbidden:List.of("SECRET_PASSWORD","PRIVATE_INTERNAL_NOTE","OTHER_PATIENT_INSTRUCTIONS","UNAPPROVED_INSTRUCTIONS",p.getEmail()))assertFalse(context.contains(forbidden));return "Your approved plan summary.";});
  var ask=new AssistantService.Ask(UUID.randomUUID(),"Summarize my plan",true);var first=assistant.ask(p.getEmail(),ask);assertEquals("COMPLETED",first.state());assertEquals(first.id(),assistant.ask(p.getEmail(),ask).id());verify(ai,times(1)).answer(anyString(),any());assertTrue(assistant.history(other.getEmail()).isEmpty());assertThrows(ResponseStatusException.class,()->assistant.ask(p.getEmail(),new AssistantService.Ask(ask.clientId(),"Changed",true)));
 }
 @Test void providerFailureIsTruthfulAndNotRetriedImplicitly()throws Exception {var p=patient();when(ai.answer(anyString(),any())).thenThrow(new java.net.http.HttpTimeoutException("secret provider details"));var ask=new AssistantService.Ask(UUID.randomUUID(),"Help",true);var failure=assertThrows(ResponseStatusException.class,()->assistant.ask(p.getEmail(),ask));assertEquals(503,failure.getStatusCode().value());assertFalse(failure.getReason().contains("secret"));assertEquals("FAILED",assistant.history(p.getEmail()).getFirst().state());assertThrows(ResponseStatusException.class,()->assistant.ask(p.getEmail(),ask));verify(ai,times(1)).answer(anyString(),any());}
 @Test void assistantDailyBudgetAndConcurrentPendingAreEnforced()throws Exception {
  var p=patient();var key=UUID.randomUUID();
  db.update("insert into assistant_exchanges(patient_id,client_id,question,consent_version) values (?,?,'Pending question','treatment-context-v1')",p.getId(),key);
  assertEquals(429,assertThrows(ResponseStatusException.class,()->assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"New",true))).getStatusCode().value());
  db.update("update assistant_exchanges set state='FAILED' where patient_id=?",p.getId());
  for(int i=0;i<29;i++)db.update("insert into assistant_exchanges(patient_id,client_id,question,state,consent_version) values (?,?,'Question','FAILED','treatment-context-v1')",p.getId(),UUID.randomUUID());
  assertEquals(429,assertThrows(ResponseStatusException.class,()->assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"Over daily limit",true))).getStatusCode().value());
  verify(ai,never()).answer(anyString(),any());
 }
 @Test void completedRequestsRemainIdempotentBeyondRecentHistory()throws Exception{
  var p=patient();var key=UUID.randomUUID();
  db.update("insert into assistant_exchanges(patient_id,client_id,question,answer,state,consent_version,created_at) values (?,?,'Original','Saved answer','COMPLETED','treatment-context-v1',CURRENT_TIMESTAMP-INTERVAL '2 days')",p.getId(),key);
  for(int i=0;i<31;i++)db.update("insert into assistant_exchanges(patient_id,client_id,question,state,consent_version,created_at) values (?,?,'Later','FAILED','treatment-context-v1',CURRENT_TIMESTAMP-INTERVAL '1 day')",p.getId(),UUID.randomUUID());
  assertEquals("Saved answer",assistant.ask(p.getEmail(),new AssistantService.Ask(key,"Original",true)).answer());
  verify(ai,never()).answer(anyString(),any());
 }
 @Test void abandonedRequestsRecoverEvenWhenRetryingTheSameKey()throws Exception{
  var p=patient();var key=UUID.randomUUID();
  db.update("insert into assistant_exchanges(patient_id,client_id,question,consent_version,created_at) values (?,?,'Help','treatment-context-v1',CURRENT_TIMESTAMP-INTERVAL '3 minutes')",p.getId(),key);
  assertEquals(409,assertThrows(ResponseStatusException.class,()->assistant.ask(p.getEmail(),new AssistantService.Ask(key,"Help",true))).getStatusCode().value());
  assertEquals("FAILED",assistant.history(p.getEmail()).getFirst().state());
  when(ai.answer(anyString(),any())).thenReturn("Recovered");
  assertEquals("Recovered",assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"Help",true)).answer());
 }
 @Test void httpEndpointsRequireAuthValidateAndProtectStaffMutations()throws Exception{mvc.perform(get("/api/support/assistant/history")).andExpect(status().isUnauthorized());var p=patient();String token=sessions.issue(p).getAccessToken();mvc.perform(post("/api/support/assistant").header("Authorization","Bearer "+token).contentType("application/json").content("{\"clientId\":\""+UUID.randomUUID()+"\",\"question\":\"Hi\",\"consent\":false}")).andExpect(status().isBadRequest());mvc.perform(get("/api/staff/support?branch=MARINA").header("Authorization","Bearer "+token)).andExpect(status().isForbidden());mvc.perform(post("/api/staff/support/1/messages").contentType("application/json").content("{}")).andExpect(status().isForbidden());}
}
