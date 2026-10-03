package com.vignesh.clinicapp.treatment.model;

import com.vignesh.clinicapp.treatment.enums.ProtocolStatus;
import com.vignesh.clinicapp.user.model.User;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "treatment_protocols")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TreatmentProtocol {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 150)
    private String protocolName;

    @Column(length = 200)
    private String treatmentType;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private ProtocolStatus status = ProtocolStatus.ACTIVE;

    @Column(precision = 5, scale = 1)
    private BigDecimal weightKg;

    @Column(precision = 5, scale = 1)
    private BigDecimal heightCm;

    @Column(precision = 4, scale = 1)
    private BigDecimal bmi;

    @Column(precision = 5, scale = 1)
    private BigDecimal goalWeightKg;

    @Column(nullable = false)
    @Builder.Default
    private Integer totalSessions = 0;

    @Column(columnDefinition = "TEXT")
    private String instructions;

    private LocalDate startDate;

    private LocalDate endDate;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(nullable = false)
    @Builder.Default
    private Boolean isDeleted = false;

    @Column(nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(nullable = false)
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "protocol", fetch = FetchType.LAZY)
    @Builder.Default
    private List<TreatmentSession> sessions = new ArrayList<>();

    @Enumerated(EnumType.STRING)
    @Column(length = 30)
    private com.vignesh.clinicapp.appointment.enums.Branch branch;
    private Long templateVersionId;
    private Long approvedBy;
    private java.time.Instant approvedAt;
    @Version
    @Column(nullable = false)
    private long version;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = createdAt;
        if (status == null) status = ProtocolStatus.ACTIVE;
        if (isDeleted == null) isDeleted = false;
        if (totalSessions == null) totalSessions = 0;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
