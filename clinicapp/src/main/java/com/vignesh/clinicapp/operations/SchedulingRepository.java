package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.time.*;
import java.util.*;

@Repository
@RequiredArgsConstructor
public class SchedulingRepository {
    private final JdbcTemplate db;
    public record ServiceItem(long id,String name,int durationMinutes) {}
    public record Resource(long id,Branch branch,String name,String timezone) {}
    public record Hours(int weekday,String opens,String closes) {}
    public record ServiceInput(@NotBlank @Size(max=120) String name,@Min(5) @Max(480) int durationMinutes) {}
    public record ResourceInput(@NotNull Branch branch,@NotBlank @Size(max=120) String name,@NotBlank @Size(max=80) String timezone) {}
    public record HoursInput(@Min(1) @Max(7) int weekday,@NotNull LocalTime opens,@NotNull LocalTime closes) {}
    public record BlockInput(@NotNull Instant startsAt,@NotNull Instant endsAt,@NotBlank @Size(max=200) String reason) {}
    public List<ServiceItem> services(){return db.query("select id,name,duration_minutes from clinic_services where active=true order by name,id",(r,n)->new ServiceItem(r.getLong(1),r.getString(2),r.getInt(3)));}
    public List<Resource> resources(Branch branch){return db.query("select id,branch,name,timezone from clinic_resources where branch=? and active=true order by name,id",(r,n)->resource(r),branch.name());}
    private Resource resource(java.sql.ResultSet r)throws java.sql.SQLException{return new Resource(r.getLong(1),Branch.valueOf(r.getString(2)),r.getString(3),r.getString(4));}
    public Resource resource(long id,boolean lock){return db.query("select id,branch,name,timezone from clinic_resources where id=? and active=true"+(lock?" for update":""),(r,n)->resource(r),id).stream().findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Resource not found"));}
    public ServiceItem service(long id){return db.query("select id,name,duration_minutes from clinic_services where id=? and active=true",(r,n)->new ServiceItem(r.getLong(1),r.getString(2),r.getInt(3)),id).stream().findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Service not found"));}
    public List<Hours> hours(long resource){return db.query("select weekday,opens,closes from resource_hours where resource_id=? order by weekday",(r,n)->new Hours(r.getInt(1),r.getString(2),r.getString(3)),resource);}
    public long createService(ServiceInput input){return db.queryForObject("insert into clinic_services(name,duration_minutes) values (?,?) returning id",Long.class,input.name().trim(),input.durationMinutes());}
    public long createResource(ResourceInput input){try{ZoneId.of(input.timezone());}catch(DateTimeException e){throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Use an IANA timezone such as Asia/Dubai");}return db.queryForObject("insert into clinic_resources(branch,name,timezone) values (?,?,?) returning id",Long.class,input.branch().name(),input.name().trim(),input.timezone());}
    public void hours(long id,HoursInput input){if(!input.closes().isAfter(input.opens()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Closing time must follow opening time");db.update("insert into resource_hours(resource_id,weekday,opens,closes) values (?,?,?,?) on conflict(resource_id,weekday) do update set opens=excluded.opens,closes=excluded.closes",id,input.weekday(),input.opens(),input.closes());}
    public void block(long id,BlockInput input){if(!input.endsAt().isAfter(input.startsAt()))throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"End must follow start");db.update("insert into resource_blocks(resource_id,starts_at,ends_at,reason) values (?,?,?,?)",id,java.sql.Timestamp.from(input.startsAt()),java.sql.Timestamp.from(input.endsAt()),input.reason());}
    public boolean free(long resource,Instant start,Instant end,Long exclude){
        var a=java.sql.Timestamp.from(start);var b=java.sql.Timestamp.from(end);
        return db.queryForObject("select count(*) from appointments where resource_id=? and is_deleted=false and status in ('PENDING','CONFIRMED','CHECKED_IN','IN_CONSULTATION') and starts_at < ? and ends_at > ? and (cast(? as bigint) is null or id<>?)",Long.class,resource,b,a,exclude,exclude)==0
            && db.queryForObject("select count(*) from resource_blocks where resource_id=? and starts_at < ? and ends_at > ?",Long.class,resource,b,a)==0;
    }
    public List<Instant> slots(long resourceId,long serviceId,LocalDate day){
        Resource resource=resource(resourceId,false);ServiceItem service=service(serviceId);ZoneId zone=ZoneId.of(resource.timezone());
        var hours=hours(resourceId).stream().filter(h->h.weekday()==day.getDayOfWeek().getValue()).findFirst();if(hours.isEmpty())return List.of();
        LocalDateTime local=day.atTime(LocalTime.parse(hours.get().opens())),last=day.atTime(LocalTime.parse(hours.get().closes()));
        record Interval(Instant start,Instant end) {}
        var dayStart=java.sql.Timestamp.from(day.atStartOfDay(zone).toInstant());
        var dayEnd=java.sql.Timestamp.from(day.plusDays(1).atStartOfDay(zone).toInstant());
        // Fetch occupied intervals once per day rather than issuing queries for every slot.
        var occupied=db.query("select starts_at,ends_at from appointments where resource_id=? and is_deleted=false and status in ('PENDING','CONFIRMED','CHECKED_IN','IN_CONSULTATION') and starts_at < ? and ends_at > ? union all select starts_at,ends_at from resource_blocks where resource_id=? and starts_at < ? and ends_at > ?",
            (r,n)->new Interval(r.getTimestamp(1).toInstant(),r.getTimestamp(2).toInstant()),resourceId,dayEnd,dayStart,resourceId,dayEnd,dayStart);
        List<Instant> result=new ArrayList<>();
        for(;!local.plusMinutes(service.durationMinutes()).isAfter(last);local=local.plusMinutes(service.durationMinutes())) {
            // Skip nonexistent or ambiguous local times; no silent DST adjustment.
            var offsets=zone.getRules().getValidOffsets(local);if(offsets.size()!=1)continue;
            Instant start=local.toInstant(offsets.getFirst()),end=start.plusSeconds(service.durationMinutes()*60L);
            if(start.isAfter(Instant.now())&&end.atZone(zone).toLocalDateTime().equals(local.plusMinutes(service.durationMinutes()))&&occupied.stream().noneMatch(i->i.start().isBefore(end)&&i.end().isAfter(start)))result.add(start);
        }
        return result;
    }
    public void validate(Resource resource,long serviceId,Instant start,Long exclude){
        ServiceItem service=service(serviceId);ZoneId zone=ZoneId.of(resource.timezone());var local=start.atZone(zone);var hours=hours(resource.id()).stream().filter(h->h.weekday()==local.getDayOfWeek().getValue()).findFirst();
        if(!start.isAfter(Instant.now())||hours.isEmpty())throw new ResponseStatusException(HttpStatus.CONFLICT,"Slot is unavailable");
        LocalTime opens=LocalTime.parse(hours.get().opens()),closes=LocalTime.parse(hours.get().closes());Instant end=start.plusSeconds(service.durationMinutes()*60L);
        long offset=java.time.Duration.between(opens,local.toLocalTime()).getSeconds();
        if(zone.getRules().getValidOffsets(local.toLocalDateTime()).size()!=1||!end.atZone(zone).toLocalDateTime().equals(local.toLocalDateTime().plusMinutes(service.durationMinutes()))||offset<0||offset%(service.durationMinutes()*60L)!=0||local.getNano()!=0||!end.atZone(zone).toLocalDate().equals(local.toLocalDate())||end.atZone(zone).toLocalTime().isAfter(closes)||!free(resource.id(),start,end,exclude))throw new ResponseStatusException(HttpStatus.CONFLICT,"Slot is unavailable");
    }
    public String replay(long actor,String operation,String key,String hash){var results=db.query("select request_hash,response_json from appointment_idempotency where actor_id=? and operation=? and key=?",(r,n)->new String[]{r.getString(1),r.getString(2)},actor,operation,key);if(results.isEmpty())return null;if(!hash.equals(results.getFirst()[0]))throw new ResponseStatusException(HttpStatus.CONFLICT,"Idempotency key was used with different data");return results.getFirst()[1];}
    public void remember(long actor,String operation,String key,String hash,long id,String response){db.update("insert into appointment_idempotency(actor_id,operation,key,request_hash,appointment_id,response_json) values (?,?,?,?,?,?)",actor,operation,key,hash,id,response);}
    public void event(long id,long actor,String from,String to,Instant oldStart,Instant newStart,String reason){db.update("insert into appointment_events(appointment_id,actor_id,from_status,to_status,old_start,new_start,reason) values (?,?,?,?,?,?,?)",id,actor,from,to,oldStart==null?null:java.sql.Timestamp.from(oldStart),newStart==null?null:java.sql.Timestamp.from(newStart),reason);}
}
