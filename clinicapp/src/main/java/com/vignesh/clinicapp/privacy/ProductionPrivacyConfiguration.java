package com.vignesh.clinicapp.privacy;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import java.net.URI;
@Configuration @Profile("prod")
public class ProductionPrivacyConfiguration {
 public ProductionPrivacyConfiguration(Environment env){
  for(String key:new String[]{"app.secrets.encryption-key","app.policy.privacy-url","app.policy.terms-url","app.policy.contact-email","app.policy.legal-name","app.policy.retention-notice"}){
   String value=env.getProperty(key,"");if(value.isBlank())throw new IllegalStateException("Required production setting is missing: "+key);
   if(key.endsWith("-url")){URI uri=URI.create(value);if(!"https".equals(uri.getScheme())||uri.getHost()==null||uri.getUserInfo()!=null)throw new IllegalStateException("Production policy URLs must use HTTPS: "+key);}
  }
  if ("smtp".equals(env.getProperty("app.mail.provider", "smtp"))) {
   for (String key : new String[]{"spring.mail.username", "spring.mail.password"})
    if (env.getProperty(key, "").isBlank()) throw new IllegalStateException("SMTP requires MAIL_USERNAME and MAIL_PASSWORD; use MAIL_PROVIDER=resend for HTTPS delivery");
  }
  if(!env.getProperty("app.staff.mfa-required",Boolean.class,false))throw new IllegalStateException("Staff MFA is required in production");
 }
}
