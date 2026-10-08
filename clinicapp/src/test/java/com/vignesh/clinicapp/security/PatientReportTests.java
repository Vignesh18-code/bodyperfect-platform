package com.vignesh.clinicapp.security;

import com.vignesh.clinicapp.reports.PatientReportService;
import com.vignesh.clinicapp.operations.*;
import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import com.vignesh.clinicapp.auth.service.AuthSessionService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static com.vignesh.clinicapp.operations.OperationsContracts.*;

@SpringBootTest(properties="app.secrets.encryption-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=") @AutoConfigureMockMvc @ActiveProfiles("test")
@EnabledIfSystemProperty(named="spring.flyway.enabled",matches="true")
class PatientReportTests {
 @Autowired PatientReportService reports;
 @Autowired OperationsRepository ops;
 @Autowired UserRepository users;
 @Autowired JdbcTemplate db;
 @Autowired MockMvc mvc;
 @Autowired AuthSessionService auth;
 static final byte[] PDF="%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n".getBytes(StandardCharsets.US_ASCII);
 User user(Role role){String id=UUID.randomUUID().toString().substring(0,8);var u=users.saveAndFlush(User.builder().email(id+"@example.test").phone(id).fullName("Synthetic report test").password("unused").role(role).build());u.setStatus(UserStatus.ACTIVE);return users.saveAndFlush(u);}
 User clinician(){var u=user(Role.STAFF);ops.member(u.getId(),new MemberInput(Branch.MARINA,StaffRole.CLINICIAN,true));return u;}
 User patient(){var u=user(Role.PATIENT);ops.associate(u.getId(),Branch.MARINA);return u;}
 MockMultipartFile pdf(){return new MockMultipartFile("file","report.pdf","application/pdf",PDF);}
 long upload(User c,User p)throws Exception{return reports.upload(c.getEmail(),Branch.MARINA,p.getId(),"Synthetic report",LocalDate.now(),pdf(),"test");}
 String token(User u){return "Bearer "+auth.issue(u).getAccessToken();}
 @Test void listAndDownloadOnlyOwnedReportsWithPrivateHeaders()throws Exception{
  var c=clinician();var p=patient();var other=patient();long id=upload(c,p);
  assertEquals(1,reports.mine(p.getEmail()).size());assertTrue(reports.mine(other.getEmail()).isEmpty());assertArrayEquals(PDF,reports.download(p.getEmail(),id));
  assertThrows(ResponseStatusException.class,()->reports.download(other.getEmail(),id));
  String ciphertext=db.queryForObject("select encrypted_pdf from patient_reports where id=?",String.class,id);
  assertFalse(ciphertext.contains("%PDF"));assertFalse(ciphertext.contains(java.util.Base64.getEncoder().encodeToString(PDF)));
  mvc.perform(get("/api/reports/{id}/download",id)).andExpect(status().isUnauthorized());
  mvc.perform(get("/api/reports/{id}/download",id).header("Authorization",token(other))).andExpect(status().isNotFound());
  mvc.perform(get("/api/reports/{id}/download",id).header("Authorization",token(p))).andExpect(status().isOk()).andExpect(content().bytes(PDF))
   .andExpect(header().string("Cache-Control","no-store")).andExpect(header().string("Content-Disposition","attachment; filename=\"bodyperfect-report-"+id+".pdf\""));
  mvc.perform(get("/api/reports").header("Authorization",token(p))).andExpect(status().isOk()).andExpect(jsonPath("$.data[0].title").value("Synthetic report")).andExpect(jsonPath("$.data[0].encryptedPdf").doesNotExist());
 }
 @Test void branchAndClinicalPermissionsAlsoProtectUploadAndWithdrawal()throws Exception{
  var c=clinician();var p=patient();var reception=user(Role.STAFF);ops.member(reception.getId(),new MemberInput(Branch.MARINA,StaffRole.RECEPTION,true));long id=upload(c,p);
  assertThrows(AccessDeniedException.class,()->reports.staffList(reception.getEmail(),Branch.MARINA,p.getId()));
  assertThrows(AccessDeniedException.class,()->reports.upload(c.getEmail(),Branch.BURJUMAN,p.getId(),"Test",LocalDate.now(),pdf(),"test"));
  assertThrows(AccessDeniedException.class,()->reports.withdraw(reception.getEmail(),Branch.MARINA,p.getId(),id,"test"));
  var outsider=user(Role.PATIENT);assertThrows(ResponseStatusException.class,()->upload(c,outsider));
  assertThrows(AccessDeniedException.class,()->reports.mine(c.getEmail()));
 }
 @Test void withdrawHidesListAndDisablesDownloadButKeepsAudit()throws Exception{
  var c=clinician();var p=patient();long id=upload(c,p);reports.withdraw(c.getEmail(),Branch.MARINA,p.getId(),id,"test");
  assertTrue(reports.mine(p.getEmail()).isEmpty());assertThrows(ResponseStatusException.class,()->reports.download(p.getEmail(),id));
  assertNull(db.queryForObject("select encrypted_pdf from patient_reports where id=?",String.class,id));
  assertEquals(1,db.queryForObject("select count(*) from audit_events where entity_type='PATIENT_REPORT' and entity_id=? and action='REPORT_WITHDRAWN'",Integer.class,id));
 }
 @Test void invalidAndOversizedFilesDoNotPublish()throws Exception{
  var c=clinician();var p=patient();
  for(var file:new MockMultipartFile[]{new MockMultipartFile("file","fake.pdf","application/pdf","not pdf".getBytes()),new MockMultipartFile("file","big.pdf","application/pdf",new byte[5242881]),new MockMultipartFile("file","bad.html","text/html",PDF)}){
   assertThrows(ResponseStatusException.class,()->reports.upload(c.getEmail(),Branch.MARINA,p.getId(),"Test",LocalDate.now(),file,"test"));
  }
  assertThrows(ResponseStatusException.class,()->reports.upload(c.getEmail(),Branch.MARINA,p.getId()," ",LocalDate.now(),pdf(),"test"));
  assertTrue(reports.mine(p.getEmail()).isEmpty());
 }
 @Test void staffMultipartEndpointRequiresCsrfAndPublishes()throws Exception{
  var c=clinician();var p=patient();String token=token(c);String path="/api/staff/patients/"+p.getId()+"/reports";
  mvc.perform(multipart(path).file(pdf()).param("branch","MARINA").param("title","Test PDF").param("reportDate",LocalDate.now().toString()).header("Authorization",token)).andExpect(status().isForbidden());
  var csrf=mvc.perform(get("/api/staff-auth/csrf")).andReturn().getResponse();
  String csrfValue=new com.fasterxml.jackson.databind.ObjectMapper().readTree(csrf.getContentAsString()).get("token").asText();
  mvc.perform(multipart(path).file(pdf()).param("branch","MARINA").param("title","Test PDF").param("reportDate",LocalDate.now().toString()).header("Authorization",token).cookie(csrf.getCookies()).header("X-XSRF-TOKEN",csrfValue)).andExpect(status().isOk());
  assertEquals(1,reports.mine(p.getEmail()).size());
 }
}
