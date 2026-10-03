package com.vignesh.clinicapp.support;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.server.ResponseStatusException;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
@SpringBootTest @ActiveProfiles("test")
@EnabledIfSystemProperty(named="spring.flyway.enabled",matches="true")
class AssistantRagTests {
 @Autowired AssistantService assistant; @Autowired UserRepository users; @Autowired JdbcTemplate db; @Autowired ClinicKnowledge knowledge; @Autowired ObjectMapper json;
 @MockitoBean OpenAiGateway ai;
 User patient(){String id=UUID.randomUUID().toString().substring(0,10);var p=users.saveAndFlush(User.builder().email(id+"@example.invalid").phone(id).fullName("Synthetic RAG client").password("SECRET_HASH_NOT_FOR_AI").role(Role.PATIENT).build());p.setStatus(UserStatus.ACTIVE);return users.saveAndFlush(p);}
 @BeforeEach void setup()throws Exception{when(ai.available()).thenReturn(true);when(ai.model()).thenReturn("mock-model");when(ai.answer(anyString(),any())).thenReturn("{\"answer\":\"Source-backed answer\",\"sourceIds\":[\"S1\",\"FORGED\"]}");}
 void exchange(User p,String q,String a){db.update("insert into assistant_exchanges(patient_id,client_id,question,answer,state,consent_version) values (?,?,?,?,'COMPLETED','test')",p.getId(),UUID.randomUUID(),q,a);}
 @Test void knowledgeHasSourcesAndRelevantRetrieval(){assertTrue(knowledge.pages()>=12);assertTrue(knowledge.search("What services does BodyPerfect offer?").getFirst().text().contains("12 service categories"));for(String q:List.of("IV Therapy","Hydra facial","Burjuman clinic address","personal training gym")){var sources=knowledge.search(q);assertFalse(sources.isEmpty());assertTrue(sources.stream().allMatch(s->s.url().startsWith("https://www.bodyperfect.ae/")&&!s.text().isBlank()));}assertTrue(knowledge.search("IV Therapy").stream().anyMatch(s->s.url().contains("iv-therapy")));}
 @Test void memoryIsScopedAndRecentHistoryIsSentInOrder()throws Exception{
  var own=patient();var other=patient();exchange(own,"Please use brief English answers","I will keep it brief.");exchange(other,"OTHER_CLIENT_SECRET","PRIVATE_OTHER_HISTORY");
  assistant.savePreferences(own.getEmail(),new AssistantService.Preferences(true,"Use simple English"));
  when(ai.answer(anyString(),any())).thenAnswer(call->{var c=call.getArgument(1).toString();assertTrue(c.contains("brief English"));assertTrue(c.contains("simple English"));assertFalse(c.contains("OTHER_CLIENT_SECRET"));assertFalse(c.contains("SECRET_HASH"));return "Remembered your preference.";});
  assistant.ask(own.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"What did I ask you to remember?",true));
 }
 @Test void memoryOffExcludesHistoryAndSavedNotes()throws Exception{
  var p=patient();exchange(p,"OLD_MEMORY_MARKER","OLD_RESPONSE_MARKER");assistant.savePreferences(p.getEmail(),new AssistantService.Preferences(false,"NOTE_MARKER"));
  when(ai.answer(anyString(),any())).thenAnswer(call->{String c=call.getArgument(1).toString();assertFalse(c.contains("OLD_MEMORY_MARKER"));assertFalse(c.contains("NOTE_MARKER"));return "No prior memory used.";});
  assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"Hello",true));
 }
 @Test void recallFindsRelevantOlderConversation(){var p=patient();exchange(p,"Hydra facial consultation","Earlier discussion about hydra facial");for(int i=0;i<17;i++)exchange(p,"Unrelated message "+i,"Unrelated reply");try{when(ai.answer(anyString(),any())).thenAnswer(call->{String c=call.getArgument(1).toString();assertTrue(c.contains("relevantEarlierConversation"));assertTrue(c.contains("Earlier discussion"));return "Earlier context recalled.";});}catch(Exception e){throw new RuntimeException(e);}assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"Hydra facial consultation",true));}
 @Test void citationsAreAllowlistedAndActionsDoNotMutateBookings(){var p=patient();long before=db.queryForObject("select count(*) from appointments where user_id=?",Long.class,p.getId());var r=assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"Book an IV Therapy consultation",true));assertFalse(r.sources().isEmpty());assertTrue(r.sources().stream().noneMatch(s->s.id().equals("FORGED")));assertTrue(r.actions().contains("BOOK_APPOINTMENT"));assertEquals(before,db.queryForObject("select count(*) from appointments where user_id=?",Long.class,p.getId()));}
 @Test void clearingHistoryIsPrivateAndCannotResetDailyUsage(){var own=patient();var other=patient();exchange(other,"Keep this","Saved");assistant.savePreferences(own.getEmail(),new AssistantService.Preferences(true,"Remember me"));assistant.ask(own.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"IV therapy",true));assistant.clearHistory(own.getEmail());assertTrue(assistant.history(own.getEmail()).isEmpty());assertEquals("",assistant.preferences(own.getEmail()).note());assertEquals(1,assistant.history(other.getEmail()).size());assertEquals(1,db.queryForObject("select count(*) from assistant_usage where patient_id=?",Integer.class,own.getId()));for(int i=0;i<29;i++)db.update("insert into assistant_usage(patient_id,client_id) values (?,?)",own.getId(),UUID.randomUUID());assertEquals(429,assertThrows(ResponseStatusException.class,()->assistant.ask(own.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"Hello",true))).getStatusCode().value());}
 @Test void aiHistoryPaginationAndRetentionAreBounded(){var p=patient();for(int i=0;i<35;i++)exchange(p,"Question "+i,"Answer");var first=assistant.history(p.getEmail());assertEquals(30,first.size());assertEquals(5,assistant.history(p.getEmail(),first.getLast().id()).size());db.update("update assistant_exchanges set created_at=CURRENT_TIMESTAMP-INTERVAL '91 days' where patient_id=?",p.getId());assistant.expireHistory();assertTrue(assistant.history(p.getEmail()).isEmpty());}
 @Test void privateCredentialsAreRejectedBeforeProvider()throws Exception{var p=patient();assertThrows(ResponseStatusException.class,()->assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"password=hidden-credential",true)));assertThrows(ResponseStatusException.class,()->assistant.savePreferences(p.getEmail(),new AssistantService.Preferences(true,"api_key=example")));verify(ai,never()).answer(anyString(),any());}
 @Test void longPlansIncludeNearestUpcomingSessionInsteadOfOnlyTheLastSessions(){
  var p=patient();long plan=db.queryForObject("insert into treatment_protocols(user_id,protocol_name,status,total_sessions,approved_at) values (?,'Synthetic long plan','ACTIVE',25,CURRENT_TIMESTAMP) returning id",Long.class,p.getId());
  for(int i=1;i<=25;i++)db.update("insert into treatment_sessions(protocol_id,user_id,session_number,session_name,session_date,session_time) values (?,?,?,'Synthetic session',CURRENT_DATE+cast(? as integer),TIME '10:00')",plan,p.getId(),i,i);
  var rows=(List<?>)assistant.context(p.getId()).get("sessions");assertEquals(20,rows.size());assertEquals(1,((Map<?,?>)rows.getFirst()).get("session_number"));
 }
 @Test void profileNameIsAvailableWithoutCredentialsAndSixMinutePauseKeepsHistory()throws Exception {
  var p=patient();exchange(p,"I am interested in a diet consultation","We can discuss arranging a consultation.");
  db.update("update assistant_exchanges set created_at=CURRENT_TIMESTAMP-INTERVAL '6 minutes' where patient_id=?",p.getId());
  when(ai.answer(anyString(),any())).thenAnswer(call->{String c=call.getArgument(1).toString();assertTrue(c.contains(p.getFullName()));assertTrue(c.contains("diet consultation"));assertFalse(c.contains(p.getEmail()));assertFalse(c.contains("SECRET_HASH"));return "Your previous discussion was about a diet consultation.";});
  var result=assistant.ask(p.getEmail(),new AssistantService.Ask(UUID.randomUUID(),"Can we continue my diet discussion?",true));
  assertTrue(result.followUps().contains("Will I need blood tests?"));assertTrue(result.actions().contains("BOOK_APPOINTMENT"));
 }
}
