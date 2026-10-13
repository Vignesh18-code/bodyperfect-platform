package com.vignesh.clinicapp.privacy;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;
import java.nio.file.*;

/** Retryable physical cleanup. Completion is recorded only after all account photos are removed. */
@Component @RequiredArgsConstructor
public class PrivacyFileCleanup {
 private final JdbcTemplate db;
 private final TransactionTemplate tx;
 @Value("${app.upload.dir:uploads}") private String uploads;
 @Scheduled(fixedDelayString="${app.privacy.cleanup-ms:60000}",initialDelay=60000)
 public void run(){
  for(long id:db.queryForList("select patient_id from privacy_file_cleanup order by created_at limit 100",Long.class)){
   try{
    Path dir=Path.of(uploads,"profiles").toAbsolutePath().normalize();
    if(Files.exists(dir))try(var entries=Files.newDirectoryStream(dir,"user-"+id+"-*")){
     for(Path file:entries){if(Files.isDirectory(file,LinkOption.NOFOLLOW_LINKS))throw new java.io.IOException("Unexpected profile directory");Files.deleteIfExists(file);}
    }
    tx.executeWithoutResult(status->{db.update("update account_closures set photo_cleanup_complete=true where patient_id=?",id);db.update("update privacy_requests set state='COMPLETED',updated_at=current_timestamp where id=(select request_id from account_closures where patient_id=?)",id);db.update("delete from privacy_file_cleanup where patient_id=?",id);});
   }catch(java.io.IOException e){/* Keep durable queue entry and retry; never claim completion on failure. */}
  }
 }
}
