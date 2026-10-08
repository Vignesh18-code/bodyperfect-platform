package com.vignesh.clinicapp.reports;

import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.operations.OperationsService;
import com.vignesh.clinicapp.operations.OperationsRepository;
import com.vignesh.clinicapp.privacy.SecretCipher;
import com.vignesh.clinicapp.support.SupportService;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import java.time.LocalDate;
import java.util.*;
import java.nio.charset.StandardCharsets;
import java.io.IOException;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class PatientReportService {
    private final JdbcTemplate db;
    private final OperationsService operations;
    private final OperationsRepository audit;
    private final SupportService support;
    private final SecretCipher cipher;
    @org.springframework.beans.factory.annotation.Value("${app.secrets.encryption-key:}")
    private String persistentEncryptionKey;
    public record Report(long id, String title, LocalDate reportDate, int sizeBytes, String branch) {}
    private List<Report> list(long patient, Branch branch) {
        return db.query("select id,title,report_date,size_bytes,branch from patient_reports where patient_id=? and withdrawn_at is null" +
                (branch == null ? "" : " and branch=?") + " order by report_date desc,id desc",
                (r,n) -> new Report(r.getLong(1),r.getString(2),r.getObject(3,LocalDate.class),r.getInt(4),r.getString(5)),
                branch == null ? new Object[]{patient} : new Object[]{patient,branch.name()});
    }
    public List<Report> mine(String email) { return list(support.patient(email).getId(), null); }
    public List<Report> staffList(String email, Branch branch, long patient) {
        operations.require(email,branch,true,false); operations.checkPatient(patient,branch);
        return list(patient,branch);
    }
    @Transactional
    public long upload(String email, Branch branch, long patient, String title, LocalDate date, MultipartFile file, String requestId) throws IOException {
        var actor=operations.require(email,branch,true,false); operations.checkPatient(patient,branch);
        if(persistentEncryptionKey.isBlank())
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Report storage requires a persistent encryption key");
        if(title==null || title.isBlank() || title.trim().length()>150 || date==null || date.isAfter(LocalDate.now()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Enter a report title and a valid report date");
        if(file.isEmpty() || file.getSize()>5242880 || !"application/pdf".equalsIgnoreCase(file.getContentType()))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Choose a PDF up to 5 MB");
        byte[] bytes=file.getBytes();
        if(bytes.length<8 || !new String(bytes,0,5,StandardCharsets.US_ASCII).equals("%PDF-") ||
                !new String(bytes,Math.max(0,bytes.length-1024),Math.min(1024,bytes.length),StandardCharsets.ISO_8859_1).contains("%%EOF"))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"The file is not a valid PDF document");
        // Serialize uploads per patient and bound storage. Lists never truncate silently.
        db.queryForList("select id from users where id=? for update",patient);
        if(db.queryForObject("select count(*) from patient_reports where patient_id=? and withdrawn_at is null",Integer.class,patient)>=100)
            throw new ResponseStatusException(HttpStatus.CONFLICT,"Report limit reached. Withdraw obsolete reports before uploading another.");
        long id=db.queryForObject("insert into patient_reports(patient_id,branch,title,report_date,size_bytes,encrypted_pdf,uploaded_by) values (?,?,?,?,?,?,?) returning id",
                Long.class,patient,branch.name(),title.trim(),date,bytes.length,cipher.encrypt(Base64.getEncoder().encodeToString(bytes)),actor.getId());
        audit.audit(actor.getId(),branch,"REPORT_PUBLISHED","PATIENT_REPORT",id,requestId);
        return id;
    }
    public byte[] download(String email,long id) {
        return content(support.patient(email).getId(),null,id);
    }
    @Transactional
    public byte[] staffDownload(String email,Branch branch,long patient,long id,String requestId) {
        var actor=operations.require(email,branch,true,false); operations.checkPatient(patient,branch);
        byte[] bytes=content(patient,branch,id);
        audit.audit(actor.getId(),branch,"REPORT_DOWNLOADED","PATIENT_REPORT",id,requestId);
        return bytes;
    }
    private byte[] content(long patient,Branch branch,long id) {
        var rows=db.query("select encrypted_pdf from patient_reports where id=? and patient_id=? and withdrawn_at is null"+
                (branch==null?"":" and branch=?"),(r,n)->r.getString(1),
                branch==null?new Object[]{id,patient}:new Object[]{id,patient,branch.name()});
        String encrypted=rows.stream().findFirst().orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Report not found"));
        return Base64.getDecoder().decode(cipher.decrypt(encrypted));
    }
    @Transactional
    public void withdraw(String email,Branch branch,long patient,long id,String requestId) {
        var actor=operations.require(email,branch,true,false); operations.checkPatient(patient,branch);
        if(db.update("update patient_reports set withdrawn_at=current_timestamp,encrypted_pdf=null where id=? and patient_id=? and branch=? and withdrawn_at is null",id,patient,branch.name())!=1)
            throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Report not found");
        audit.audit(actor.getId(),branch,"REPORT_WITHDRAWN","PATIENT_REPORT",id,requestId);
    }
}
