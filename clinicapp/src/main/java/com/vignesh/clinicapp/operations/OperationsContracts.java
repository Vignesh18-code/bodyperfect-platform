package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import jakarta.validation.constraints.*;
import java.util.List;

public final class OperationsContracts {
    private OperationsContracts() {}
    public enum StaffRole { RECEPTION, CLINICIAN, BRANCH_MANAGER }
    public record Membership(Branch branch, StaffRole role) {}
    public record Me(long id, String fullName, String role, List<Membership> memberships) {}
    public record Patient(long id, String fullName, String email, String phone, String status, long version) {}
    public record Page<T>(List<T> items, int page, int size, boolean hasNext) {}
    public record PatientInput(@NotBlank @Size(min=2,max=100) String fullName,
                               @NotBlank @Email @Size(max=150) String email,
                               @NotBlank @Pattern(regexp="[0-9]{9,15}") String phone) {}
    public record PatientEdit(@NotBlank @Size(min=2,max=100) String fullName,
                              @NotBlank @Pattern(regexp="[0-9]{9,15}") String phone,
                              @Min(0) long version) {}
    public record StaffInput(@NotBlank @Size(min=2,max=100) String fullName,
                             @NotBlank @Email @Size(max=150) String email,
                             @NotBlank @Pattern(regexp="[0-9]{9,15}") String phone,
                             @NotNull Branch branch, @NotNull StaffRole staffRole) {}
    public record MemberInput(@NotNull Branch branch, @NotNull StaffRole staffRole, boolean active) {}
    public record Staff(long id, String fullName, String email, String status, Branch branch, StaffRole staffRole, boolean active) {}
    public record Audit(long id, long actorId, String action, String entityType, Long entityId, String occurredAt, String requestId) {}
    public record AppointmentItem(long id, long patientId, String patientName, String date, String time, String status, String branch, Long resourceId, Long serviceId, long version, String startsAt) {}
    public record Overview(long patients, long today, long upcoming, long pending) {}
}
