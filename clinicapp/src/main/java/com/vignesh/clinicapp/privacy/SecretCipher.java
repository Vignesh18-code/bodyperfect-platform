package com.vignesh.clinicapp.privacy;
import org.springframework.stereotype.Component;
import org.springframework.beans.factory.annotation.Value;
import javax.crypto.Cipher;
import javax.crypto.spec.*;
import java.security.SecureRandom;
import java.util.Base64;
@Component
public class SecretCipher {
 private final byte[] key;
 public SecretCipher(@Value("${app.secrets.encryption-key:}") String encoded){
  if(encoded.isBlank()){key=new byte[32];new SecureRandom().nextBytes(key);}else{key=Base64.getDecoder().decode(encoded);if(key.length!=32)throw new IllegalArgumentException("Encryption key must decode to 32 bytes");}
 }
 public String encrypt(String value){try{byte[] iv=new byte[12];new SecureRandom().nextBytes(iv);var c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.ENCRYPT_MODE,new SecretKeySpec(key,"AES"),new GCMParameterSpec(128,iv));return Base64.getEncoder().encodeToString(iv)+":"+Base64.getEncoder().encodeToString(c.doFinal(value.getBytes(java.nio.charset.StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException("Encryption unavailable");}}
 public String decrypt(String value){try{var parts=value.split(":");var c=Cipher.getInstance("AES/GCM/NoPadding");c.init(Cipher.DECRYPT_MODE,new SecretKeySpec(key,"AES"),new GCMParameterSpec(128,Base64.getDecoder().decode(parts[0])));return new String(c.doFinal(Base64.getDecoder().decode(parts[1])),java.nio.charset.StandardCharsets.UTF_8);}catch(Exception e){throw new IllegalStateException("Unable to decrypt secret");}}
}
