package com.vignesh.clinicapp.support;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.constraints.*;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.*;
import java.util.*;

@Service
public class AssistantService {
 private static final String CONSENT="care-profile-memory-v3";
 private final JdbcTemplate db;
 private final SupportService support;
 private final OpenAiGateway ai;
 private final ClinicKnowledge knowledge;
 private final ObjectMapper json;
 private final TransactionTemplate tx;
 public AssistantService(JdbcTemplate db,SupportService support,OpenAiGateway ai,ClinicKnowledge knowledge,ObjectMapper json,PlatformTransactionManager manager){this.db=db;this.support=support;this.ai=ai;this.knowledge=knowledge;this.json=json;tx=new TransactionTemplate(manager);}
 public record Ask(@NotNull UUID clientId,@NotBlank @Size(max=2000) String question,@AssertTrue boolean consent){}
 public record Citation(String id,String title,String url,String retrievedAt){}
 public record Exchange(long id,UUID clientId,String question,String answer,String state,String createdAt,List<Citation> sources,List<String> actions,List<String> followUps){}
 public record Preferences(boolean memoryEnabled,@NotNull @Size(max=1000) String note){}
 public Map<String,Object> status(){return Map.of("available",ai.available(),"consentVersion",CONSENT,"provider","OpenAI","knowledgePages",knowledge.pages(),"knowledgeUpdatedAt",knowledge.updated(),"retentionDays",90);}
 public Map<String,Object> status(String email){var result=new LinkedHashMap<String,Object>(status());result.put("displayName",support.patient(email).getFullName());return result;}
 public List<Exchange> history(String email){return history(email,null);}
 public List<Exchange> history(String email,Long before){long id=support.patient(email).getId();return db.query("select * from assistant_exchanges where patient_id=? and created_at>CURRENT_TIMESTAMP-INTERVAL '90 days' and (cast(? as bigint) is null or id<?) order by id desc limit 30",this::exchange,id,before,before);}
 private Exchange exchange(ResultSet r,int row)throws SQLException{
  try{return new Exchange(r.getLong("id"),r.getObject("client_id",UUID.class),r.getString("question"),r.getString("answer"),r.getString("state"),r.getTimestamp("created_at").toInstant().toString(),json.readValue(r.getString("sources"),new TypeReference<>(){}),json.readValue(r.getString("actions"),new TypeReference<>(){}),followUps(r.getString("question")));}
  catch(Exception e){throw new SQLException("Invalid assistant metadata",e);}
 }
 public Preferences preferences(String email){return preferences(support.patient(email).getId());}
 private Preferences preferences(long patient){return db.query("select memory_enabled,note from assistant_preferences where patient_id=?",(r,n)->new Preferences(r.getBoolean(1),r.getString(2)),patient).stream().findFirst().orElse(new Preferences(true,""));}
 public Preferences savePreferences(String email,Preferences input){
  rejectCredentials(input.note());long patient=support.patient(email).getId();
  tx.executeWithoutResult(s->{lock(patient);requireIdle(patient);db.update("insert into assistant_preferences(patient_id,memory_enabled,note) values (?,?,?) on conflict(patient_id) do update set memory_enabled=excluded.memory_enabled,note=excluded.note,updated_at=CURRENT_TIMESTAMP",patient,input.memoryEnabled(),input.note().trim());});return preferences(patient);
 }
 public void clearHistory(String email){long patient=support.patient(email).getId();tx.executeWithoutResult(s->{lock(patient);requireIdle(patient);db.update("delete from assistant_exchanges where patient_id=?",patient);db.update("update assistant_preferences set note='',updated_at=CURRENT_TIMESTAMP where patient_id=?",patient);});}
 private void lock(long patient){db.queryForObject("select id from users where id=? for update",Long.class,patient);}
 private void requireIdle(long patient){if(db.queryForObject("select count(*) from assistant_exchanges where patient_id=? and state='PENDING' and created_at>CURRENT_TIMESTAMP-INTERVAL '2 minutes'",Long.class,patient)>0)throw new ResponseStatusException(HttpStatus.CONFLICT,"Wait for your current reply before changing memory.");}
 private void rejectCredentials(String text){if(text.matches("(?s).*(sk-(?:proj-)?[A-Za-z0-9_-]{16,}|(?i:password|otp|api[_ ]?key)\\s*[:=]\\s*\\S+).*"))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Please remove passwords, verification codes and API keys from your message.");}
 // Allowlisted, authenticated patient projection. Never serialize a User/entity or private staff notes.
 Map<String,Object> context(long patient){
  var data=new LinkedHashMap<String,Object>();
  data.put("profile",db.queryForMap("select full_name,preferred_treatment from users where id=?",patient));
  data.put("clinicTime",ZonedDateTime.now(ZoneId.of("Asia/Dubai")).toString());
  data.put("plans",db.queryForList("select protocol_name,treatment_type,status,left(instructions,4000) as instructions,total_sessions,start_date,end_date,branch from treatment_protocols where user_id=? and is_deleted=false and approved_at is not null and status='ACTIVE' order by id desc limit 3",patient));
  data.put("appointments",db.queryForList("select branch,appointment_date,appointment_time,status from appointments where user_id=? and is_deleted=false and status not in ('CANCELLED','COMPLETED','NO_SHOW') and appointment_date>=cast(CURRENT_TIMESTAMP at time zone 'Asia/Dubai' as date) order by appointment_date,appointment_time limit 10",patient));
  data.put("sessions",db.queryForList("select p.protocol_name,s.session_number,s.session_name,s.session_date,s.session_time,s.duration_minutes,s.status from treatment_sessions s join treatment_protocols p on p.id=s.protocol_id where s.user_id=? and p.user_id=? and not s.is_deleted and not p.is_deleted and p.approved_at is not null and p.status='ACTIVE' order by case when s.status in ('SCHEDULED','IN_PROGRESS') and s.session_date+s.session_time>=CURRENT_TIMESTAMP at time zone 'Asia/Dubai' then s.session_date+s.session_time end asc nulls last,s.session_date desc,s.session_time desc limit 20",patient,patient));
  data.put("rewards",db.queryForMap("select total_points from users where id=?",patient));
  data.put("linkedBranches",db.queryForList("select branch from patient_branches where patient_id=? order by branch",patient));
  return data;
 }
 private Map<String,Object> memory(long patient,String question){
  var prefs=preferences(patient);if(!prefs.memoryEnabled())return Map.of("enabled",false);
  var recent=db.queryForList("select id,created_at::text as sent_at,question,left(answer,2200) as answer from assistant_exchanges where patient_id=? and state='COMPLETED' and created_at>CURRENT_TIMESTAMP-INTERVAL '90 days' order by id desc limit 16",patient);
  long before=recent.isEmpty()?Long.MAX_VALUE:((Number)recent.getLast().get("id")).longValue();
  String recallQuery=ClinicKnowledge.tokens(question).stream().filter(t->t.length()>2).distinct().limit(12).map(t->"\""+t+"\"").collect(java.util.stream.Collectors.joining(" OR "));
  var recalled=db.queryForList("select question,left(answer,1500) as answer from assistant_exchanges where patient_id=? and id<? and state='COMPLETED' and created_at>CURRENT_TIMESTAMP-INTERVAL '90 days' and to_tsvector('english',question || ' ' || coalesce(answer,'')) @@ websearch_to_tsquery('english',?) order by ts_rank_cd(to_tsvector('english',question || ' ' || coalesce(answer,'')),websearch_to_tsquery('english',?)) desc,id desc limit 3",patient,before,recallQuery,recallQuery);
  Collections.reverse(recent);
  return Map.of("enabled",true,"clientPreferences",prefs.note(),"recentConversation",recent,"relevantEarlierConversation",recalled);
 }
 public Exchange ask(String email,Ask request){
  if(!request.consent())throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Consent is required to share your question and permitted care context with OpenAI");
  rejectCredentials(request.question());long patient=support.patient(email).getId();
  if(!ai.available())throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"The assistant is temporarily unavailable. Your clinic team can help.");
  tx.executeWithoutResult(s->db.update("update assistant_exchanges set state='FAILED',finished_at=CURRENT_TIMESTAMP where patient_id=? and state='PENDING' and created_at<CURRENT_TIMESTAMP-INTERVAL '2 minutes'",patient));
  var claim=tx.execute(s->{
   lock(patient);
   var old=db.queryForList("select question,state from assistant_exchanges where patient_id=? and client_id=?",patient,request.clientId());
   if(!old.isEmpty()){
    if(!old.getFirst().get("question").equals(request.question().trim()))throw new ResponseStatusException(HttpStatus.CONFLICT,"Request key already used with different text");
    if(old.getFirst().get("state").equals("COMPLETED"))return false;
    throw new ResponseStatusException(HttpStatus.CONFLICT,old.getFirst().get("state").equals("PENDING")?"Your question is still processing. Refresh shortly.":"The previous attempt failed. Send a new question to retry.");
   }
   if(db.queryForObject("select count(*) from assistant_exchanges where patient_id=? and state='PENDING'",Long.class,patient)>0)
    throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"Please wait for the current reply before sending another question.");
   long daily=db.queryForObject("select greatest((select count(*) from assistant_usage where patient_id=? and created_at>CURRENT_TIMESTAMP-INTERVAL '24 hours'),(select count(*) from assistant_exchanges where patient_id=? and created_at>CURRENT_TIMESTAMP-INTERVAL '24 hours'))",Long.class,patient,patient);
   if(daily>=30)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"The assistant allows 30 questions per day. Your clinic team can still help.");
   if(db.queryForObject("select count(*) from assistant_usage where patient_id=? and client_id=?",Long.class,patient,request.clientId())>0)throw new ResponseStatusException(HttpStatus.CONFLICT,"This request was cleared. Start a new question.");
   db.update("insert into assistant_exchanges(patient_id,client_id,question,model,consent_version) values (?,?,?,?,?)",patient,request.clientId(),request.question().trim(),ai.model(),CONSENT);
   db.update("insert into assistant_usage(patient_id,client_id) values (?,?)",patient,request.clientId());return true;
  });
  if(Boolean.TRUE.equals(claim))try {
   var recall=memory(patient,request.question());
   String retrievalQuery=request.question();
   // Resolve short follow-ups against the last user turn without treating it as authority.
   if(ClinicKnowledge.tokens(retrievalQuery).size()<5 && Boolean.TRUE.equals(recall.get("enabled"))){
    var recent=(List<?>)recall.get("recentConversation");if(!recent.isEmpty())retrievalQuery+=" "+((Map<?,?>)recent.getLast()).get("question");
   }
   var sources=knowledge.search(retrievalQuery);
   var ctx=context(patient);ctx.put("conversationMemory",recall);ctx.put("websiteKnowledge",sources);
   String raw=ai.answer(request.question(),ctx);
   String answer=raw;List<Citation> citations=new ArrayList<>();
   if(raw.stripLeading().startsWith("{")){
    var response=json.readTree(raw);answer=response.path("answer").asText();
    Set<String> ids=new HashSet<>();response.path("sourceIds").forEach(n->ids.add(n.asText()));
    Set<String> urls=new HashSet<>();for(var source:sources)if(ids.contains(source.id())&&urls.add(source.url()))citations.add(new Citation(source.id(),source.title(),source.url(),source.retrievedAt()));
   }
   if(answer==null||answer.isBlank()||answer.length()>16000)throw new IllegalStateException("Invalid answer");
   List<String> actions=actions(request.question()+" "+answer);
   String finalAnswer=answer,sourceJson=json.writeValueAsString(citations),actionJson=json.writeValueAsString(actions);
   tx.executeWithoutResult(s->db.update("update assistant_exchanges set state='COMPLETED',answer=?,sources=cast(? as jsonb),actions=cast(? as jsonb),finished_at=CURRENT_TIMESTAMP where patient_id=? and client_id=? and state='PENDING'",finalAnswer,sourceJson,actionJson,patient,request.clientId()));
  }catch(Exception ex){
   if(ex instanceof InterruptedException)Thread.currentThread().interrupt();
   tx.executeWithoutResult(s->db.update("update assistant_exchanges set state='FAILED',finished_at=CURRENT_TIMESTAMP where patient_id=? and client_id=? and state='PENDING'",patient,request.clientId()));
   throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"The assistant could not finish this reply. Please retry or message your clinic.");
  }
  return db.query("select * from assistant_exchanges where patient_id=? and client_id=?",this::exchange,patient,request.clientId()).getFirst();
 }
 private List<String> actions(String question){String q=question.toLowerCase(Locale.ROOT);var actions=new ArrayList<String>();if(q.matches("(?s).*\\b(book|appointment|schedule|visit|consultation|gym|diet|deit|nutrition|blood)\\b.*"))actions.add("BOOK_APPOINTMENT");if(q.matches("(?s).*\\b(plan|treatment|protocol|session|progress)\\b.*"))actions.add("VIEW_TREATMENT");actions.add("CLINIC_TEAM");return actions;}
 private List<String> followUps(String question){
  String q=question.toLowerCase(Locale.ROOT);
  if(q.matches("(?s).*\\b(name|who am i)\\b.*"))return List.of("When is my next appointment?","Explain my approved treatment plan");
  if(q.matches("(?s).*\\b(diet|deit|nutrition|weight|blood)\\b.*"))return List.of("What happens at the consultation?","Will I need blood tests?","How can I book a consultation?");
  if(q.matches("(?s).*\\b(appointment|visit|booking)\\b.*"))return List.of("How should I prepare for my visit?","How can I change my appointment?");
  return List.of("Explain that more simply","What should I do next?");
 }
 @Scheduled(fixedDelayString="3600000",initialDelayString="300000")
 public void expireHistory(){db.update("delete from assistant_exchanges where created_at<CURRENT_TIMESTAMP-INTERVAL '90 days'");db.update("delete from assistant_usage where created_at<CURRENT_TIMESTAMP-INTERVAL '48 hours'");}
}
