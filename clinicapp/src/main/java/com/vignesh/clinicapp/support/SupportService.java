package com.vignesh.clinicapp.support;

import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.operations.*;
import com.vignesh.clinicapp.user.enums.Role;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import com.vignesh.clinicapp.notification.service.NotificationService;
import com.vignesh.clinicapp.notification.enums.*;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.util.*;

@Service
@RequiredArgsConstructor
@Transactional(readOnly=true)
public class SupportService {
 private final JdbcTemplate db;
 private final UserRepository users;
 private final OperationsService operations;
 private final OperationsRepository audit;
 private final NotificationService notifications;
 public record ThreadItem(long id,long patientId,String patientName,Branch branch,String state,Long assignedTo,long version,String updatedAt) {}
 public record Message(long id,String senderRole,String senderName,String body,String createdAt,UUID clientId) {}
 public record Page(List<Message> items,boolean hasEarlier) {}
 public record Send(@NotNull UUID clientId,@NotBlank @Size(max=4000) String body) {}
 public record Update(@NotBlank @Pattern(regexp="CLAIM|RESOLVE|REOPEN") String action,@Min(0) long version) {}
 public User patient(String email){return users.findByEmail(email).filter(User::isActive).filter(u->u.getRole()==Role.PATIENT).orElseThrow(()->new org.springframework.security.access.AccessDeniedException("Patient account required"));}
 public List<Branch> branches(String email){long id=patient(email).getId();return db.query("select branch from patient_branches where patient_id=? order by branch",(r,n)->Branch.valueOf(r.getString(1)),id);}
 @Transactional
 public ThreadItem open(String email,Branch branch){var p=patient(email);users.findByEmailForUpdate(email).orElseThrow();operations.checkPatient(p.getId(),branch);db.update("insert into support_threads(patient_id,branch) values (?,?) on conflict(patient_id,branch) do nothing",p.getId(),branch.name());return db.query("select t.*,u.full_name from support_threads t join users u on u.id=t.patient_id where t.patient_id=? and t.branch=?",(r,n)->thread(r),p.getId(),branch.name()).getFirst();}
 private ThreadItem thread(java.sql.ResultSet r)throws java.sql.SQLException{return new ThreadItem(r.getLong("id"),r.getLong("patient_id"),r.getString("full_name"),Branch.valueOf(r.getString("branch")),r.getString("state"),r.getObject("assigned_to",Long.class),r.getLong("version"),r.getTimestamp("updated_at").toInstant().toString());}
 private ThreadItem scoped(String email,long id,boolean staff,boolean lock){var t=db.query("select t.*,u.full_name from support_threads t join users u on u.id=t.patient_id where t.id=? and u.is_deleted=false"+(lock?" for update of t":""),(r,n)->thread(r),id).stream().findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Conversation not found"));if(staff)operations.require(email,t.branch(),false,false);else if(patient(email).getId()!=t.patientId())throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Conversation not found");return t;}
 public List<ThreadItem> inbox(String email,Branch branch,int page){operations.require(email,branch,false,false);return db.query("select t.*,u.full_name from support_threads t join users u on u.id=t.patient_id where t.branch=? and u.is_deleted=false order by t.updated_at desc,t.id desc limit 50 offset ?",(r,n)->thread(r),branch.name(),page*50);}
 public Page messages(String email,long id,boolean staff,Long before){scoped(email,id,staff,false);var rows=db.query("select m.*,u.full_name from support_messages m join users u on u.id=m.sender_id where m.thread_id=? and (cast(? as bigint) is null or m.id<?) order by m.id desc limit 51",(r,n)->new Message(r.getLong("id"),r.getString("sender_role"),r.getString("full_name"),r.getString("body"),r.getTimestamp("created_at").toInstant().toString(),r.getObject("client_id",UUID.class)),id,before,before);var items=new ArrayList<>(rows.stream().limit(50).toList());Collections.reverse(items);return new Page(items,rows.size()>50);}
 @Transactional
 public Message send(String email,long id,boolean staff,Send input,String requestId){var actor=staff?operations.staffUser(email):patient(email);users.findByEmailForUpdate(email).orElseThrow();var t=scoped(email,id,staff,true);var old=db.query("select body from support_messages where thread_id=? and sender_id=? and client_id=?",(r,n)->r.getString(1),id,actor.getId(),input.clientId());if(!old.isEmpty()){if(!old.getFirst().equals(input.body().trim()))throw new ResponseStatusException(HttpStatus.CONFLICT,"Message key already used with different text");return message(id,actor.getId(),input.clientId());}
  long recent=db.queryForObject("select count(*) from support_messages where sender_id=? and created_at>CURRENT_TIMESTAMP-INTERVAL '1 minute'",Long.class,actor.getId());if(recent>=20)throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"Please wait before sending another message");
  db.update("insert into support_messages(thread_id,sender_id,sender_role,client_id,body) values (?,?,?,?,?)",id,actor.getId(),staff?"STAFF":"PATIENT",input.clientId(),input.body().trim());db.update("update support_threads set state='OPEN',version=version+1,updated_at=CURRENT_TIMESTAMP where id=?",id);
  if(staff){audit.audit(actor.getId(),t.branch(),"SUPPORT_REPLIED","SUPPORT_THREAD",id,requestId);notifications.createNotification(users.findById(t.patientId()).orElseThrow(),"Clinic support replied","You have a new message from your clinic.",NotificationType.GENERAL,"SUPPORT",id,NotificationPriority.NORMAL);}
  return message(id,actor.getId(),input.clientId());
 }
 private Message message(long thread,long sender,UUID key){return db.query("select m.*,u.full_name from support_messages m join users u on u.id=m.sender_id where thread_id=? and sender_id=? and client_id=?",(r,n)->new Message(r.getLong("id"),r.getString("sender_role"),r.getString("full_name"),r.getString("body"),r.getTimestamp("created_at").toInstant().toString(),r.getObject("client_id",UUID.class)),thread,sender,key).getFirst();}
 @Transactional
 public void update(String email,long id,Update input,String requestId){var t=scoped(email,id,true,true);var actor=operations.staffUser(email);if(t.version()!=input.version())throw new ResponseStatusException(HttpStatus.CONFLICT,"Conversation changed. Refresh and retry");if(input.action().equals("CLAIM"))db.update("update support_threads set assigned_to=?,version=version+1,updated_at=CURRENT_TIMESTAMP where id=?",actor.getId(),id);else db.update("update support_threads set state=?,version=version+1,updated_at=CURRENT_TIMESTAMP where id=?",input.action().equals("RESOLVE")?"RESOLVED":"OPEN",id);audit.audit(actor.getId(),t.branch(),"SUPPORT_"+input.action(),"SUPPORT_THREAD",id,requestId);}
}
