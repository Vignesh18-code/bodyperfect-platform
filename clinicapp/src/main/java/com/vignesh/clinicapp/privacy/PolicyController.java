package com.vignesh.clinicapp.privacy;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.*;
import org.springframework.web.util.HtmlUtils;
import java.util.Map;
import com.vignesh.clinicapp.common.dto.ApiResponse;
@RestController
public class PolicyController {
 @Value("${app.policy.privacy-url:}") private String privacy;
 @Value("${app.policy.terms-url:}") private String terms;
 @Value("${app.policy.contact-email:}") private String email;
 @Value("${app.policy.legal-name:}") private String name;
 @Value("${app.policy.retention-notice:}") private String retention;
 @GetMapping("/api/public/policies") public ApiResponse<?> policies(){return ApiResponse.success("Clinic policies",Map.of("privacyUrl",privacy,"termsUrl",terms,"contactEmail",email,"legalName",name,"retentionNotice",retention));}
 @GetMapping(value="/account-deletion",produces="text/html") public ResponseEntity<String> deletion(){
  if(email.isBlank()||name.isBlank()||retention.isBlank())return ResponseEntity.status(503).body("Account deletion contact details are awaiting clinic configuration.");
  return ResponseEntity.ok().header("Cache-Control","no-store").header("Content-Security-Policy","default-src 'none'; base-uri 'none'; frame-ancestors 'none'").body("<!doctype html><html lang='en'><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'><title>BodyPerfect account deletion</title><main><h1>Delete your BodyPerfect Clinic account</h1><p>"+HtmlUtils.htmlEscape(name)+"</p><p>Request deletion in the app under Profile, or email <a href='mailto:"+HtmlUtils.htmlEscape(email)+"'>"+HtmlUtils.htmlEscape(email)+"</a> with the subject Account deletion. Include your account email, but never your password or medical records. The clinic will verify your identity and confirm the request outcome.</p><h2>Data and retention</h2><p>"+HtmlUtils.htmlEscape(retention)+"</p></main></html>");
 }
}
