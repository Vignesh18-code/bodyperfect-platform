package com.vignesh.clinicapp.support;
import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.validation.annotation.Validated;
import java.security.Principal;
@RestController @RequestMapping("/api/support") @RequiredArgsConstructor @Validated
public class SupportController {
 private final SupportService service;
 private final AssistantService assistant;
 @GetMapping("/branches") public ApiResponse<?> branches(Principal p){return ApiResponse.success("Your clinics",service.branches(p.getName()));}
 @PostMapping("/threads") public ApiResponse<?> open(Principal p,@RequestParam Branch branch){return ApiResponse.success("Conversation",service.open(p.getName(),branch));}
 @GetMapping("/threads/{id}/messages") public ApiResponse<?> messages(Principal p,@PathVariable @Positive long id,@RequestParam(required=false) @Positive Long before){return ApiResponse.success("Messages",service.messages(p.getName(),id,false,before));}
 @PostMapping("/threads/{id}/messages") public ApiResponse<?> send(Principal p,@PathVariable @Positive long id,@Valid @RequestBody SupportService.Send input){return ApiResponse.success("Message saved",service.send(p.getName(),id,false,input,null));}
 @GetMapping("/assistant") public ApiResponse<?> status(Principal p){service.patient(p.getName());return ApiResponse.success("Assistant",assistant.status(p.getName()));}
 @GetMapping("/assistant/history") public ApiResponse<?> history(Principal p,@RequestParam(required=false) @Positive Long before){return ApiResponse.success("Assistant history",assistant.history(p.getName(),before));}
 @GetMapping("/assistant/preferences") public ApiResponse<?> preferences(Principal p){return ApiResponse.success("Assistant preferences",assistant.preferences(p.getName()));}
 @PutMapping("/assistant/preferences") public ApiResponse<?> preferences(Principal p,@Valid @RequestBody AssistantService.Preferences input){return ApiResponse.success("Assistant preferences saved",assistant.savePreferences(p.getName(),input));}
 @DeleteMapping("/assistant/history") public ApiResponse<?> clearHistory(Principal p){assistant.clearHistory(p.getName());return ApiResponse.success("AI history and memory cleared",null);}
 @PostMapping("/assistant") public ApiResponse<?> ask(Principal p,@Valid @RequestBody AssistantService.Ask input){return ApiResponse.success("AI response",assistant.ask(p.getName(),input));}
}
