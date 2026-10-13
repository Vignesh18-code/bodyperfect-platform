package com.vignesh.clinicapp.privacy;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import org.springframework.web.bind.annotation.*;
import org.springframework.validation.annotation.Validated;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.security.Principal;
import lombok.RequiredArgsConstructor;
@RestController @RequiredArgsConstructor @Validated
public class PrivacyController {
 private final PrivacyService service;
 private final AccountClosureService closures;
 @GetMapping("/api/staff/privacy/deletion/{id}/preview") public ApiResponse<?> preview(Principal p,@PathVariable @Positive long id){return ApiResponse.success("Deletion review",closures.preview(p.getName(),id));}
 @PostMapping("/api/staff/privacy/deletion/{id}/fulfill") public ApiResponse<?> fulfill(Principal p,@PathVariable @Positive long id,@Valid @RequestBody AccountClosureService.Fulfillment body){closures.fulfill(p.getName(),id,body);return ApiResponse.success("Account access revoked and non-clinical data removed. File cleanup is queued before completion.");}
 @GetMapping("/api/user/deletion-requests") public ApiResponse<?> status(Principal p){return ApiResponse.success("Account requests",service.requests(p.getName()));}
 @PostMapping("/api/user/deletion-requests") public ApiResponse<?> request(Principal p,@Valid @RequestBody PrivacyService.Deletion body){return ApiResponse.success("Deletion request received. The clinic will review the request; your account has not yet been deleted.",service.request(p.getName(),body));}
 @PostMapping("/api/support/assistant/{id}/report") public ApiResponse<?> report(Principal p,@PathVariable @Positive long id,@Valid @RequestBody PrivacyService.Report body){service.report(p.getName(),id,body);return ApiResponse.success("Report received for review");}
 @GetMapping("/api/staff/privacy/{kind}") public ApiResponse<?> queue(Principal p,@PathVariable @Pattern(regexp="deletion|reports") String kind,@RequestParam(defaultValue="0") @Min(0) @Max(10000) int page){return ApiResponse.success("Privacy review",service.queue(p.getName(),kind,page));}
 @PostMapping("/api/staff/privacy/reports/{id}/review") public ApiResponse<?> review(Principal p,@PathVariable @Positive long id,@Valid @RequestBody PrivacyService.Review body){service.reviewReport(p.getName(),id,body);return ApiResponse.success("Report reviewed");}
 @PostMapping("/api/staff/privacy/deletion/{id}/review") public ApiResponse<?> deletion(Principal p,@PathVariable @Positive long id){service.beginDeletionReview(p.getName(),id);return ApiResponse.success("Request under review");}
}
