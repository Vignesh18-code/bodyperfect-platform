package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.*;
import static com.vignesh.clinicapp.operations.OperationsContracts.*;

@Repository
@RequiredArgsConstructor
public class OperationsRepository {
    private final JdbcTemplate db;
    private final PatientBranchRepository patientBranches;
    public List<Membership> memberships(long userId) {
        return db.query("select branch,staff_role from staff_memberships where user_id=? and active=true order by branch",
            (rs,n)->new Membership(Branch.valueOf(rs.getString(1)),StaffRole.valueOf(rs.getString(2))),userId);
    }
    public boolean containsPatient(long id, Branch branch) {
        return db.queryForObject("select count(*) from patient_branches pb join users u on u.id=pb.patient_id where pb.patient_id=? and pb.branch=? and u.role='PATIENT' and u.is_deleted=false",Long.class,id,branch.name())>0;
    }
    public void associate(long patient, Branch branch) {
        if (!patientBranches.existsById(new PatientBranch.Key(patient,branch))) patientBranches.saveAndFlush(new PatientBranch(patient,branch));
    }
    public List<Patient> patients(Branch branch,String query,int page,int size) {
        String term="%"+query.toLowerCase(Locale.ROOT).replace("!","!!").replace("%","!%").replace("_","!_")+"%";
        return db.query("select u.id,u.full_name,u.email,u.phone,u.status,u.profile_version from users u join patient_branches pb on pb.patient_id=u.id where pb.branch=? and u.role='PATIENT' and u.is_deleted=false and (lower(u.full_name) like ? escape '!' or lower(u.email) like ? escape '!' or u.phone like ? escape '!') order by lower(u.full_name),u.id limit ? offset ?",
            (rs,n)->new Patient(rs.getLong(1),rs.getString(2),rs.getString(3),rs.getString(4),rs.getString(5),rs.getLong(6)),branch.name(),term,term,term,size+1,(long)page*size);
    }
    public Patient patient(long id) {
        return db.queryForObject("select id,full_name,email,phone,status,profile_version from users where id=?",
            (rs,n)->new Patient(rs.getLong(1),rs.getString(2),rs.getString(3),rs.getString(4),rs.getString(5),rs.getLong(6)),id);
    }
    public boolean edit(long id,PatientEdit input) {
        return db.update("update users set full_name=?,phone=?,profile_version=profile_version+1,updated_at=CURRENT_TIMESTAMP where id=? and profile_version=?",
            input.fullName().trim(),input.phone(),id,input.version())==1;
    }
    public void member(long id,MemberInput input) {
        int updated=db.update("update staff_memberships set staff_role=?,active=? where user_id=? and branch=?",input.staffRole().name(),input.active(),id,input.branch().name());
        if(updated==0) db.update("insert into staff_memberships(user_id,branch,staff_role,active) values (?,?,?,?)",id,input.branch().name(),input.staffRole().name(),input.active());
    }
    public List<Staff> staff(Branch branch) {
        return db.query("select u.id,u.full_name,u.email,u.status,m.branch,m.staff_role,m.active from staff_memberships m join users u on u.id=m.user_id where m.branch=? and u.is_deleted=false order by u.full_name,u.id limit 200",
            (rs,n)->new Staff(rs.getLong(1),rs.getString(2),rs.getString(3),rs.getString(4),Branch.valueOf(rs.getString(5)),StaffRole.valueOf(rs.getString(6)),rs.getBoolean(7)),branch.name());
    }
    public void audit(long actor,Branch branch,String action,String type,Long entity,String requestId) {
        db.update("insert into audit_events(actor_id,branch,action,entity_type,entity_id,request_id) values (?,?,?,?,?,?)",actor,branch==null?null:branch.name(),action,type,entity,requestId);
    }
    public List<Audit> audit(Branch branch,int page,int size) {
        return db.query("select id,actor_id,action,entity_type,entity_id,occurred_at,request_id from audit_events where branch=? order by occurred_at desc,id desc limit ? offset ?",
            (rs,n)->new Audit(rs.getLong(1),rs.getLong(2),rs.getString(3),rs.getString(4),rs.getObject(5,Long.class),rs.getString(6),rs.getString(7)),branch.name(),size+1,(long)page*size);
    }
    public List<AppointmentItem> appointments(Branch branch,java.time.LocalDate from,java.time.LocalDate to,int page,int size,Long patient) {
        return db.query("select a.id,a.user_id,u.full_name,a.appointment_date,a.appointment_time,a.status,a.branch,a.resource_id,a.service_id,a.version,a.starts_at from appointments a join users u on u.id=a.user_id where a.branch=? and a.is_deleted=false and a.appointment_date between ? and ? and (cast(? as bigint) is null or a.user_id=?) order by a.appointment_date,a.appointment_time,a.id limit ? offset ?",
            (rs,n)->new AppointmentItem(rs.getLong(1),rs.getLong(2),rs.getString(3),rs.getString(4),rs.getString(5),rs.getString(6),rs.getString(7),rs.getObject(8,Long.class),rs.getObject(9,Long.class),rs.getLong(10),rs.getString(11)),branch.name(),from,to,patient,patient,size+1,(long)page*size);
    }
    public Overview overview(Branch branch,java.time.LocalDate day) {
        long patients=db.queryForObject("select count(*) from patient_branches pb join users u on u.id=pb.patient_id where pb.branch=? and u.is_deleted=false and u.role='PATIENT'",Long.class,branch.name());
        return db.queryForObject("select count(*) filter(where appointment_date=?),count(*) filter(where appointment_date>?),count(*) filter(where status='PENDING') from appointments where branch=? and is_deleted=false",
            (rs,n)->new Overview(patients,rs.getLong(1),rs.getLong(2),rs.getLong(3)),day,day,branch.name());
    }
}
