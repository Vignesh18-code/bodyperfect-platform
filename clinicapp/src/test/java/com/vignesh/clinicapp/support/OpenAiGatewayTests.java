package com.vignesh.clinicapp.support;
import org.junit.jupiter.api.Test;
import com.fasterxml.jackson.databind.ObjectMapper;
import static org.junit.jupiter.api.Assertions.*;
class OpenAiGatewayTests {
 final OpenAiGateway gateway=new OpenAiGateway(new ObjectMapper(),true,"test-key","test-model");
 @Test void rawResponsesOutputIsParsedAndIncompleteRejected()throws Exception{assertEquals("Plan summary",gateway.extract("{\"status\":\"completed\",\"output\":[{\"type\":\"reasoning\"},{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"Plan summary\"}]}]}"));assertThrows(IllegalStateException.class,()->gateway.extract("{\"status\":\"incomplete\",\"output\":[]}"));assertThrows(IllegalStateException.class,()->gateway.extract("{\"status\":\"completed\",\"output\":[]}"));}
 @Test void missingConfigurationDisablesProvider(){assertFalse(new OpenAiGateway(new ObjectMapper(),true,"","model").available());assertFalse(new OpenAiGateway(new ObjectMapper(),false,"key","model").available());}
 @Test void observedIvMarketingClaimsAreNotPresentedAsMedicalBenefits()throws Exception {
  var json=new ObjectMapper();var result=json.readTree(gateway.applyClinicalBoundary("{\"answer\":\"IV therapy boosts energy and helps you absorb nutrients quickly.\",\"sourceIds\":[\"S1\"]}","What is IV therapy?"));
  assertFalse(result.path("answer").asText().contains("boosts"));
  assertTrue(result.path("answer").asText().contains("risks"));
  assertEquals("S1",result.path("sourceIds").get(0).asText());
 }
 @Test void dialogueRolesAreReplayedAndMemoryOptOutExcludesThem()throws Exception {
  var context=java.util.Map.of("profile",java.util.Map.of("full_name","Elena"),"conversationMemory",java.util.Map.of("enabled",true,"recentConversation",java.util.List.of(java.util.Map.of("question","I want a diet plan","answer","Start with a consultation"))));
  var messages=gateway.conversationInput("What next?",context);
  assertEquals(4,messages.size());assertEquals("assistant",messages.get(2).get("role"));assertEquals("What next?",messages.getLast().get("content"));assertTrue(messages.getFirst().get("content").contains("Elena"));
  var off=java.util.Map.of("conversationMemory",java.util.Map.of("enabled",false,"recentConversation",java.util.List.of(java.util.Map.of("question","HIDDEN_HISTORY","answer","HIDDEN_REPLY"))));
  assertFalse(gateway.conversationInput("Hi",off).toString().contains("HIDDEN"));
 }
}
