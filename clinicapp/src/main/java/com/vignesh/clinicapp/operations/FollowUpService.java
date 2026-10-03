package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.time.LocalDate;
import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly=true)
public class FollowUpService {
 private final OperationsService operations;
 private final OperationsRepository audit;
 private final JdbcTemplate db;
 public record Assignee(long id,String name) {}
 public record Task(long id,long patientId,String patientName,long assignedTo,String assignee,String title,LocalDate dueDate,String state,String resolution,long version) {}
 public record Input(@Positive long patientId,@Positive long assignedTo,@NotBlank @Size(max=200) String title,@NotNull LocalDate dueDate) {}
 public enum State {OPEN,DONE,CANCELLED}
 public record Resolve(@NotNull State state,@NotBlank @Size(max=1000) String resolution,@PositiveOrZero long version) {}
 public List<Assignee> assignees(String email,Branch branch) {
  operations.require(email,branch,false,false);
  return db.query("select u.id,u.full_name from users u join staff_memberships m on m.user_id=u.id where m.branch=? and m.active=true and u.status='ACTIVE' and u.is_deleted=false order by u.full_name,u.id limit 200",(r,n)->new Assignee(r.getLong(1),r.getString(2)),branch.name());
 }
 public OperationsContracts.Page<Task> list(String email,Branch branch,State state,int page) {
  operations.require(email,branch,false,false);
  var values=db.query("select t.id,t.patient_id,p.full_name,t.assigned_to,a.full_name,t.title,t.due_date,t.state,t.resolution,t.version from follow_up_tasks t join users p on p.id=t.patient_id join users a on a.id=t.assigned_to where t.branch=? and t.state=? order by t.due_date,t.id limit 51 offset ?",
   (r,n)->new Task(r.getLong(1),r.getLong(2),r.getString(3),r.getLong(4),r.getString(5),r.getString(6),r.getObject(7,LocalDate.class),r.getString(8),r.getString(9),r.getLong(10)),branch.name(),state.name(),page*50);
  return new OperationsContracts.Page<>(values.stream().limit(50).toList(),page,50,values.size()>50);
 }
 @Transactional
 public long create(String email,Branch branch,Input input,String requestId) {
  var actor=operations.require(email,branch,false,false);operations.checkPatient(input.patientId(),branch);
  if(assignees(email,branch).stream().noneMatch(a->a.id()==input.assignedTo()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose an active branch staff member");
  long id=db.queryForObject("insert into follow_up_tasks(branch,patient_id,assigned_to,created_by,title,due_date) values (?,?,?,?,?,?) returning id",Long.class,branch.name(),input.patientId(),input.assignedTo(),actor.getId(),input.title().trim(),input.dueDate());
  audit.audit(actor.getId(),branch,"FOLLOW_UP_CREATED","FOLLOW_UP",id,requestId);return id;
 }
 @Transactional
 public void resolve(String email,Branch branch,long id,Resolve input,String requestId) {
  var actor=operations.require(email,branch,false,false);
  if(input.state()==State.OPEN)throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose done or cancelled");
  int changed=db.update("update follow_up_tasks set state=?,resolution=?,version=version+1,resolved_at=CURRENT_TIMESTAMP where id=? and branch=? and state='OPEN' and version=?",input.state().name(),input.resolution().trim(),id,branch.name(),input.version());
  if(changed!=1)throw new ResponseStatusException(HttpStatus.CONFLICT,"Task is unavailable or changed. Refresh and try again");
  audit.audit(actor.getId(),branch,"FOLLOW_UP_"+input.state(),"FOLLOW_UP",id,requestId);
 }
}
