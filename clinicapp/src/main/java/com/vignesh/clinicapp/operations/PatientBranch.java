package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.appointment.enums.Branch;
import jakarta.persistence.*;
import lombok.*;
import java.io.Serializable;

@Entity
@Table(name="patient_branches")
@IdClass(PatientBranch.Key.class)
@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class PatientBranch {
    @Id @Column(name="patient_id") private Long patientId;
    @Id @Enumerated(EnumType.STRING) @Column(length=30) private Branch branch;
    @Data @NoArgsConstructor @AllArgsConstructor
    public static class Key implements Serializable {private Long patientId;private Branch branch;}
}
