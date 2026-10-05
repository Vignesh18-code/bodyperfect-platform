package com.vignesh.clinicapp.auth.service;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
import com.vignesh.clinicapp.privacy.SecretCipher;
class StaffMfaServiceTest {
 @Test void rfc6238Sha1VectorsTruncatedToSixDigits(){
  String secret="GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";
  assertEquals("287082",StaffMfaService.totp(secret,59L/30));
  assertEquals("081804",StaffMfaService.totp(secret,1111111109L/30));
  assertEquals("050471",StaffMfaService.totp(secret,1111111111L/30));
 }
 @Test void authenticatedEncryptionRejectsWrongKeyAndUsesUniqueNonce(){
  var a=new SecretCipher(java.util.Base64.getEncoder().encodeToString(new byte[32]));
  var b=new SecretCipher(java.util.Base64.getEncoder().encodeToString(new byte[32]));
  String first=a.encrypt("private");assertEquals("private",b.decrypt(first));assertNotEquals(first,a.encrypt("private"));
  byte[] other=new byte[32];other[0]=1;var wrong=new SecretCipher(java.util.Base64.getEncoder().encodeToString(other));
  assertThrows(IllegalStateException.class,()->wrong.decrypt(first));
 }
}
