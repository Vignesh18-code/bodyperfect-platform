package com.vignesh.clinicapp.privacy;
import com.vignesh.clinicapp.user.repository.UserRepository;
import com.vignesh.clinicapp.support.SupportService;
import com.vignesh.clinicapp.operations.OperationsService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import lombok.RequiredArgsConstructor;
import jakarta.validation.constraints.*;
import java.util.*;
@Service @RequiredArgsConstructor @Transactional(readOnly=true)
public class PrivacyService {
 private final JdbcTemplate db;
 private final SupportService support;
 private final UserRepository users;
 private final PasswordEncoder passwords;
 private final OperationsService operations;
 public record Deletion(@NotBlank @Size(max=72) String password) {}
 public record Report(@NotBlank @Pattern(regexp="UNSAFE|INCORRECT|OFFENSIVE|PRIVACY|OTHER") String reason) {}
 public record Review(@NotBlank @Size(max=1000) String resolution) {}
 public List<Map<String,Object>> requests(String email){return db.queryForList("select id,state,created_at,updated_at,resolution from privacy_requests where patient_id=? order by id desc limit 20",support.patient(email).getId());}
 @Transactional public Map<String,Object> request(String email,Deletion input){
  var user=users.findByEmailForUpdate(email).orElseThrow();support.patient(email);
  if(!passwords.matches(input.password(),user.getPassword()))throw new ResponseStatusException(HttpStatus.FORBIDDEN,"Password does not match");
  if(db.queryForObject("select count(*) from privacy_requests where patient_id=? and created_at>current_timestamp-interval '1 day'",Long.class,user.getId())>=3)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"Please contact the clinic about your existing request");
  db.update("insert into privacy_requests(patient_id) values (?) on conflict do nothing",user.getId());
  return requests(email).getFirst();
 }
 @Transactional public void report(String email,long id,Report input){
  var patient=support.patient(email);
  users.findByEmailForUpdate(email).orElseThrow();
  if(db.queryForObject("select count(*) from assistant_exchanges where id=? and patient_id=? and state='COMPLETED'",Long.class,id,patient.getId())!=1)throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Reply not found");
  if(db.queryForObject("select count(*) from assistant_reports where patient_id=? and created_at>current_timestamp-interval '1 day'",Long.class,patient.getId())>=20)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"Please contact the clinic for further reports");
  db.update("insert into assistant_reports(patient_id,exchange_id,reason) values (?,?,?) on conflict do nothing",patient.getId(),id,input.reason());
 }
 private long admin(String email){var u=operations.staffUser(email);if(u.getRole()!=com.vignesh.clinicapp.user.enums.Role.ADMIN)throw new AccessDeniedException("Administrator required");return u.getId();}
 public List<Map<String,Object>> queue(String email,String kind,int page){admin(email);if(kind.equals("deletion"))return db.queryForList("select r.*,u.full_name,u.email from privacy_requests r join users u on u.id=r.patient_id order by r.id desc limit 50 offset ?",page*50);return db.queryForList("select r.*,u.full_name,e.question,e.answer from assistant_reports r join users u on u.id=r.patient_id left join assistant_exchanges e on e.id=r.exchange_id order by r.id desc limit 50 offset ?",page*50);}
 @Transactional public void reviewReport(String email,long id,Review input){long actor=admin(email);if(db.update("update assistant_reports set state='REVIEWED',resolution=?,reviewed_by=?,reviewed_at=current_timestamp where id=? and state='OPEN'",input.resolution(),actor,id)!=1)throw new ResponseStatusException(HttpStatus.CONFLICT,"Report missing or already reviewed");}
 @Transactional public void beginDeletionReview(String email,long id){long actor=admin(email);if(db.update("update privacy_requests set state='IN_REVIEW',reviewed_by=?,updated_at=current_timestamp where id=? and state='OPEN'",actor,id)!=1)throw new ResponseStatusException(HttpStatus.CONFLICT,"Request missing or already under review");}
}
