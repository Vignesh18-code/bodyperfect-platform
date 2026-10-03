package com.vignesh.clinicapp.support;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vignesh.clinicapp.auth.service.AuthSessionService;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.context.*;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import java.nio.file.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/** Opt-in authenticated HTTP -> PostgreSQL -> actual provider -> persisted history smoke test. */
@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
@EnabledIfSystemProperty(named="bp.ai.live",matches="true")
class AssistantLiveFlowTests {
 @Autowired MockMvc mvc; @Autowired UserRepository users; @Autowired AuthSessionService sessions;
 @Autowired JdbcTemplate db; @Autowired ObjectMapper json;
 @DynamicPropertySource static void config(DynamicPropertyRegistry r)throws Exception {
  String database=System.getProperty("spring.datasource.url", "");
  if(!database.contains("bp_chat_audit_"))throw new IllegalStateException("Live chat tests require the isolated audit database");
  var p=new Properties();try(var in=Files.newInputStream(Path.of("../.local/ai.properties"))){p.load(in);}
  r.add("app.ai.enabled",()->true);r.add("OPENAI_API_KEY",()->p.getProperty("OPENAI_API_KEY"));r.add("OPENAI_MODEL",()->p.getProperty("OPENAI_MODEL"));
 }
 @Test void authenticatedQuestionsUseSyntheticCarePersistMemoryAndCiteServiceDirectory()throws Exception {
  String id=UUID.randomUUID().toString().substring(0,10);
  var u=users.saveAndFlush(User.builder().email(id+"@example.invalid").phone(id).fullName("Synthetic live chat audit").password("unused-synthetic-hash").role(Role.PATIENT).build());
  u.setStatus(UserStatus.ACTIVE);u=users.saveAndFlush(u);
  db.update("insert into treatment_protocols(user_id,protocol_name,status,instructions,total_sessions,is_deleted,created_at,updated_at,approved_at) values (?,'Synthetic Orchard Plan','ACTIVE','Discuss your questions with reception at the next visit. Synthetic test instructions only.',2,false,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",u.getId());
  String token=sessions.issue(u).getAccessToken();
  mvc.perform(put("/api/support/assistant/preferences").header("Authorization","Bearer "+token).contentType("application/json").content("{\"memoryEnabled\":true,\"note\":\"Use simple English and call me Test Guest.\"}")).andExpect(status().isOk());
  var evidence=new ArrayList<Object>();
  for(String question:List.of("What is the name of my approved care plan?", "What name did I ask you to call me?", "List the 12 BodyPerfect service category names only, without describing medical benefits.")) {
   String body=json.writeValueAsString(Map.of("clientId",UUID.randomUUID(),"consent",true,"question",question));
   String response=mvc.perform(post("/api/support/assistant").header("Authorization","Bearer "+token).contentType("application/json").content(body)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
   var result=json.readTree(response).path("data");assertEquals("COMPLETED",result.path("state").asText());
   String answer=result.path("answer").asText();
   if(question.contains("approved"))assertTrue(answer.contains("Orchard"));
   if(question.contains("call me"))assertTrue(answer.contains("Test Guest"));
   if(question.contains("category")){assertTrue(answer.contains("Personal Training"));assertTrue(answer.contains("Ayurveda"));assertTrue(result.path("sources").size()>0);}
   evidence.add(result);
  }
  String history=mvc.perform(get("/api/support/assistant/history").header("Authorization","Bearer "+token)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
  assertEquals(3,json.readTree(history).path("data").size());
  Files.writeString(Path.of("target/chat-live-flow-evidence.json"),json.writerWithDefaultPrettyPrinter().writeValueAsString(evidence));
 }
 @Test void realNameDietGuidanceAndReturningAfterSixMinutes()throws Exception {
  String id=UUID.randomUUID().toString().substring(0,10);
  var u=users.saveAndFlush(User.builder().email(id+"@example.invalid").phone(id).fullName("Elena Testclient").password("unused-synthetic-hash").role(Role.PATIENT).build());u.setStatus(UserStatus.ACTIVE);u=users.saveAndFlush(u);
  String token=sessions.issue(u).getAccessToken();var evidence=new ArrayList<Object>();
  for(String question:List.of("What's my name?","I want a personalized deit plan. What should I do first?","I'm back. Which plan were we discussing before I left?")) {
   var body=json.writeValueAsString(Map.of("clientId",UUID.randomUUID(),"consent",true,"question",question));
   var response=mvc.perform(post("/api/support/assistant").header("Authorization","Bearer "+token).contentType("application/json").content(body)).andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
   var result=json.readTree(response).path("data");var answer=result.path("answer").asText().toLowerCase(Locale.ROOT);evidence.add(result);
   Files.writeString(Path.of("target/chat-continuity-evidence.json"),json.writerWithDefaultPrettyPrinter().writeValueAsString(evidence));
   if(question.contains("name"))assertTrue(answer.contains("elena"));
   if(question.contains("deit")){assertTrue(answer.contains("consult"));assertTrue(answer.contains("blood"));assertTrue(answer.matches("(?s).*(may|if|might|whether|depending).*"));db.update("update assistant_exchanges set created_at=CURRENT_TIMESTAMP-INTERVAL '6 minutes' where patient_id=?",u.getId());}
   if(question.contains("back"))assertTrue(answer.contains("diet"));
  }
 }
}
