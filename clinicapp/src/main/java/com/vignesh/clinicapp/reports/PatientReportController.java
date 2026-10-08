package com.vignesh.clinicapp.reports;

import com.vignesh.clinicapp.appointment.enums.Branch;
import com.vignesh.clinicapp.common.dto.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.format.annotation.DateTimeFormat;
import java.security.Principal;
import java.time.LocalDate;
import java.util.List;
import java.io.IOException;

@RestController
@RequiredArgsConstructor
public class PatientReportController {
    private final PatientReportService reports;
    @GetMapping("/api/reports")
    public ResponseEntity<ApiResponse<List<PatientReportService.Report>>> mine(Principal p) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(ApiResponse.success("Reports",reports.mine(p.getName())));
    }
    @GetMapping("/api/reports/{id}/download")
    public ResponseEntity<byte[]> download(Principal p,@PathVariable long id) { return pdf(id,reports.download(p.getName(),id)); }
    @GetMapping("/api/staff/patients/{patient}/reports")
    public ResponseEntity<ApiResponse<List<PatientReportService.Report>>> list(Principal p,@RequestParam Branch branch,@PathVariable long patient) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(ApiResponse.success("Reports",reports.staffList(p.getName(),branch,patient)));
    }
    @PostMapping(value="/api/staff/patients/{patient}/reports",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<Long> upload(Principal p,@RequestParam Branch branch,@PathVariable long patient,@RequestParam String title,
            @RequestParam @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate reportDate,@RequestParam MultipartFile file,HttpServletRequest r) throws IOException {
        return ApiResponse.success("Report published",reports.upload(p.getName(),branch,patient,title,reportDate,file,String.valueOf(r.getAttribute("requestId"))));
    }
    @GetMapping("/api/staff/patients/{patient}/reports/{id}/download")
    public ResponseEntity<byte[]> staffDownload(Principal p,@RequestParam Branch branch,@PathVariable long patient,@PathVariable long id,HttpServletRequest r) {
        return pdf(id,reports.staffDownload(p.getName(),branch,patient,id,String.valueOf(r.getAttribute("requestId"))));
    }
    @DeleteMapping("/api/staff/patients/{patient}/reports/{id}")
    public ApiResponse<Void> withdraw(Principal p,@RequestParam Branch branch,@PathVariable long patient,@PathVariable long id,HttpServletRequest r) {
        reports.withdraw(p.getName(),branch,patient,id,String.valueOf(r.getAttribute("requestId"))); return ApiResponse.success("Report withdrawn");
    }
    private ResponseEntity<byte[]> pdf(long id,byte[] bytes) {
        return ResponseEntity.ok().contentType(MediaType.APPLICATION_PDF).contentLength(bytes.length).cacheControl(CacheControl.noStore())
                .header("X-Content-Type-Options","nosniff").header("Content-Security-Policy","sandbox")
                .header(HttpHeaders.CONTENT_DISPOSITION,ContentDisposition.attachment().filename("bodyperfect-report-"+id+".pdf").build().toString()).body(bytes);
    }
}
