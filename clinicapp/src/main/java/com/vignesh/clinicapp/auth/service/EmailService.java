package com.vignesh.clinicapp.auth.service;

import com.vignesh.clinicapp.privacy.SecretCipher;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/** Queue inserts join the authentication transaction; Provider failures cannot lose committed codes. */
@Service
@lombok.extern.slf4j.Slf4j
@RequiredArgsConstructor
public class EmailService {
    private final JdbcTemplate db;
    private final SecretCipher cipher;
    private final MailDelivery delivery;
    private final TransactionTemplate transactions;
    @Value("${app.mail.worker-enabled:true}") private boolean enabled;

    public void sendOtpEmail(String email, String name, String otp) { enqueue(email, otp, false); }
    public void sendPasswordResetEmail(String email, String name, String otp) { enqueue(email, otp, true); }
    private void enqueue(String email, String otp, boolean reset) {
        String subject = reset ? "BodyPerfect password reset code" : "BodyPerfect verification code";
        String body = "Your code is " + otp + ". It expires in 5 minutes. If you did not request this, ignore this email.";
        db.update("insert into mail_outbox(recipient,payload) values (?,?)", email, cipher.encrypt(subject + "\n" + body));
    }

    @Scheduled(fixedDelayString="${app.mail.poll-ms:5000}", initialDelayString="30000")
    public void deliverPending() {
        if (!enabled) return;
        // One row per transaction bounds locking; SKIP LOCKED allows multiple instances.
        // Resend retries use a stable idempotency key; SMTP delivery remains at least once.
        for (int i=0; i<20; i++) {
            Boolean delivered = transactions.execute(status -> {
                db.update("delete from mail_outbox where expires_at<=current_timestamp");
                var rows = db.queryForList("select id,recipient,payload,attempts from mail_outbox where state='PENDING' and next_attempt<=current_timestamp order by id limit 1 for update skip locked");
                if (rows.isEmpty()) return false;
                var row=rows.getFirst(); long id=((Number)row.get("id")).longValue();
                try {
                    String[] payload=cipher.decrypt((String)row.get("payload")).split("\n",2);
                    delivery.send(id, (String)row.get("payload"), (String)row.get("recipient"), payload[0], payload[1]);
                    db.update("delete from mail_outbox where id=?",id);
                } catch (Exception failure) {
                    int attempts=((Number)row.get("attempts")).intValue()+1;
                    if(attempts>=5) {
                        log.warn("Authentication mail delivery exhausted retries for outbox entry {}",id);
                        db.update("delete from mail_outbox where id=?",id);
                    }
                    else db.update("update mail_outbox set attempts=?,next_attempt=current_timestamp+(? * interval '1 second') where id=?", attempts, Math.min(60,5*(1<<attempts)),id);
                    // Stop this batch on a provider failure, including throttling.
                    return false;
                }
                return true;
            });
            if (!Boolean.TRUE.equals(delivered)) break;
        }
    }
}
