package com.vignesh.clinicapp.privacy;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.vignesh.clinicapp.operations.OperationsService;
import com.vignesh.clinicapp.user.enums.Role;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import java.util.*;

@Service @RequiredArgsConstructor @Transactional(readOnly=true)
public class AccountClosureService {
 private final JdbcTemplate db;
 private final OperationsService operations;
 private final PasswordEncoder passwords;
 private final SecretCipher cipher;
 private final ObjectMapper json;
 @org.springframework.beans.factory.annotation.Value("${app.privacy.fulfillment-enabled:false}")
 private boolean fulfillmentEnabled;

 public record Fulfillment(@AssertTrue boolean identityVerified,
     @AssertTrue boolean patientNotified, @AssertTrue boolean recordsReviewed,
     @NotBlank @Size(max=1000) String resolution,
     @Size(max=1000) String retentionReason,
     @NotNull @Size(max=1000) List<@Positive Long> administrativeMessageIds,
     @Min(0) long reviewedThroughMessageId) {}

 private long admin(String email) {
  var actor=operations.staffUser(email);
  if(actor.getRole()!=Role.ADMIN)throw new AccessDeniedException("Administrator required");
  return actor.getId();
 }
 private Map<String,Object> request(long id) {
  return db.queryForList("select * from privacy_requests where id=?",id).stream().findFirst()
   .orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Request not found"));
 }
 public Map<String,Object> preview(String email,long id) {
  admin(email);var request=request(id);long patient=((Number)request.get("patient_id")).longValue();
  var messages=db.queryForList("select m.id,m.body,m.created_at,t.branch from support_messages m join support_threads t on t.id=m.thread_id where t.patient_id=? order by m.id limit 1001",patient);
  if(messages.size()>1000)throw new ResponseStatusException(HttpStatus.CONFLICT,"More than 1000 messages require a clinic-assisted data review before fulfillment");
  return Map.of("request",request,"messages",messages,"clinicalRecords",clinicalRecords(patient),"fulfillmentEnabled",fulfillmentEnabled,
   "reviewedThroughMessageId",messages.isEmpty()?0:((Number)messages.getLast().get("id")).longValue());
 }
 private long clinicalRecords(long patient) {
  return db.queryForObject("select (select count(*) from appointments where user_id=?) + (select count(*) from treatment_protocols where user_id=?) + (select count(*) from patient_reports where patient_id=?) + (select count(*) from follow_up_tasks where patient_id=?)",Long.class,patient,patient,patient,patient);
 }
 @Transactional public void fulfill(String email,long id,Fulfillment input) {
  long actor=admin(email);var initial=request(id);long patient=((Number)initial.get("patient_id")).longValue();
  if(!fulfillmentEnabled)throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Account-deletion fulfillment is awaiting the clinic's retention and privacy approval. Request review remains available.");
  // Same user row lock used by login/reset/refresh. Lock threads before classifying messages.
  var user=db.queryForMap("select * from users where id=? for update",patient);
  var r=db.queryForMap("select * from privacy_requests where id=? for update",id);
  if(!"IN_REVIEW".equals(r.get("state"))||Boolean.TRUE.equals(user.get("is_deleted")))
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Request is not awaiting fulfillment");
  if(!"PATIENT".equals(user.get("role")))throw new ResponseStatusException(HttpStatus.CONFLICT,"Only patient accounts can be closed here");
  if(!input.identityVerified()||!input.patientNotified()||!input.recordsReviewed())
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Complete identity, records and patient-notification checks first");
  db.queryForList("select id from support_threads where patient_id=? order by id for update",patient);
  var messageIds=db.queryForList("select m.id from support_messages m join support_threads t on t.id=m.thread_id where t.patient_id=? order by m.id",Long.class,patient);
  long latest=messageIds.isEmpty()?0:messageIds.getLast();
  if(latest!=input.reviewedThroughMessageId())throw new ResponseStatusException(HttpStatus.CONFLICT,"Messages changed. Review the latest conversation before deleting");
  var deleteIds=new HashSet<>(input.administrativeMessageIds());
  if(deleteIds.size()!=input.administrativeMessageIds().size()||!messageIds.containsAll(deleteIds))
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Message selection does not belong to this patient");
  boolean retains=clinicalRecords(patient)>0||messageIds.size()>deleteIds.size();
  if(retains&&(input.retentionReason()==null||input.retentionReason().isBlank()))
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Record the clinical/legal retention basis and applicable period");
  String identity=null;
  if(retains){var fields=new LinkedHashMap<String,Object>();for(String key:List.of("full_name","phone","email","preferred_treatment"))fields.put(key,user.get(key));identity=cipher.encrypt(encode(fields));}
  db.update("insert into account_closures(patient_id,request_id,closed_by,original_created_at,retained_identity,retention_reason,deleted_message_ids) values (?,?,?,?,?,?,cast(? as jsonb))",patient,id,actor,user.get("created_at"),identity,retains?input.retentionReason():null,encode(deleteIds));
  for(long message:deleteIds)db.update("delete from support_messages where id=?",message);
  db.update("delete from assistant_reports where patient_id=?",patient);
  db.update("delete from assistant_exchanges where patient_id=?",patient);
  db.update("delete from assistant_preferences where patient_id=?",patient);
  db.update("delete from assistant_usage where patient_id=?",patient);
  db.update("delete from notifications where user_id=?",patient);
  db.update("delete from refresh_sessions where user_id=?",patient);
  db.update("delete from mail_outbox where recipient=?",user.get("email"));
  db.update("delete from appointment_idempotency where actor_id=?",patient);
  // Random unusable credentials and tombstones free the original email/phone for future registration.
  db.update("update users set full_name='Closed account',email=?,phone=?,password=?,preferred_treatment=null,profile_image_url=null,total_points=0,gift_voucher_claimed_at=null,otp=null,otp_purpose=null,otp_expiry=null,otp_attempts=0,otp_locked_until=null,failed_login_attempts=0,locked_until=null,last_login_at=null,setup_required=false,is_deleted=true,status='BLOCKED',token_version=token_version+1,profile_version=profile_version+1,updated_at=current_timestamp where id=?",
   "closed-"+UUID.randomUUID()+"@deleted.invalid","x"+UUID.randomUUID().toString().replace("-","").substring(0,14),passwords.encode(UUID.randomUUID().toString()),patient);
  db.update("update privacy_requests set resolution=?,reviewed_by=?,updated_at=current_timestamp where id=?",input.resolution(),actor,id);
  db.update("insert into privacy_file_cleanup(patient_id) values (?)",patient);
  db.update("insert into audit_events(actor_id,action,entity_type,entity_id,request_id) values (?,'ACCOUNT_CLOSED','PATIENT',?,?)",actor,patient,UUID.randomUUID().toString());
 }
 private String encode(Object value){try{return json.writeValueAsString(value);}catch(JsonProcessingException e){throw new IllegalStateException("Unable to record deletion decision");}}
}
