package com.vignesh.clinicapp.auth.service;
import com.vignesh.clinicapp.privacy.SecretCipher;
import com.vignesh.clinicapp.user.model.User;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import lombok.RequiredArgsConstructor;
import java.time.Instant;
import java.nio.ByteBuffer;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.security.SecureRandom;
@Service @RequiredArgsConstructor
public class StaffMfaService {
 private final JdbcTemplate db;private final SecretCipher cipher;
 private static final String ALPHABET="ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
 // Caller holds the user row lock throughout setup and verification.
 public String setup(User user){
  var rows=db.queryForList("select secret,enrolled from staff_totp where user_id=?",user.getId());
  if(!rows.isEmpty()){if(Boolean.TRUE.equals(rows.getFirst().get("enrolled")))throw new IllegalArgumentException("Authenticator already enrolled");return cipher.decrypt((String)rows.getFirst().get("secret"));}
  var random=new SecureRandom();var secret=new StringBuilder();for(int i=0;i<32;i++)secret.append(ALPHABET.charAt(random.nextInt(32)));
  db.update("insert into staff_totp(user_id,secret) values (?,?)",user.getId(),cipher.encrypt(secret.toString()));return secret.toString();
 }
 public String verify(User user,String code){
  var rows=db.queryForList("select * from staff_totp where user_id=? for update",user.getId());
  if(rows.isEmpty())return "MFA_SETUP_REQUIRED";
  var row=rows.getFirst();var locked=(java.sql.Timestamp)row.get("locked_until");
  if(locked!=null&&locked.toInstant().isAfter(Instant.now()))return "Authenticator temporarily locked. Try again later.";
  if(code==null||code.isBlank())return "MFA_REQUIRED";
  long now=Instant.now().getEpochSecond()/30,last=((Number)row.get("last_counter")).longValue();
  var secret=cipher.decrypt((String)row.get("secret"));
  for(long tick=now-1;tick<=now+1;tick++)if(tick>last&&java.security.MessageDigest.isEqual(totp(secret,tick).getBytes(java.nio.charset.StandardCharsets.US_ASCII),code.getBytes(java.nio.charset.StandardCharsets.US_ASCII))){
   db.update("update staff_totp set enrolled=true,last_counter=?,attempts=0,locked_until=null where user_id=?",tick,user.getId());return null;
  }
  int attempts=locked!=null?1:((Number)row.get("attempts")).intValue()+1;
  db.update("update staff_totp set attempts=?,locked_until=case when ?>=5 then current_timestamp+interval '15 minutes' else null end where user_id=?",attempts,attempts,user.getId());
  return "Invalid or already-used authenticator code";
 }
 static String totp(String secret,long counter){try{
  var bytes=new java.io.ByteArrayOutputStream();int buffer=0,bits=0;for(char c:secret.toCharArray()){buffer=(buffer<<5)|ALPHABET.indexOf(c);bits+=5;if(bits>=8){bits-=8;bytes.write((buffer>>bits)&255);}}
  Mac mac=Mac.getInstance("HmacSHA1");mac.init(new SecretKeySpec(bytes.toByteArray(),"HmacSHA1"));byte[] h=mac.doFinal(ByteBuffer.allocate(8).putLong(counter).array());int o=h[h.length-1]&15;int n=((h[o]&127)<<24)|((h[o+1]&255)<<16)|((h[o+2]&255)<<8)|(h[o+3]&255);return String.format("%06d",n%1000000);
 }catch(Exception e){throw new IllegalStateException("Authenticator unavailable");}}
}
