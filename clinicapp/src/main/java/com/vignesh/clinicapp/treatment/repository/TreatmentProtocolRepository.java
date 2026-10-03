package com.vignesh.clinicapp.treatment.repository;

import com.vignesh.clinicapp.treatment.enums.ProtocolStatus;
import com.vignesh.clinicapp.treatment.model.TreatmentProtocol;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface TreatmentProtocolRepository extends JpaRepository<TreatmentProtocol, Long> {

    List<TreatmentProtocol> findByUserIdAndIsDeletedFalseOrderByCreatedAtDesc(Long userId, Pageable pageable);

    Optional<TreatmentProtocol> findByIdAndUserIdAndIsDeletedFalse(Long id, Long userId);

    Optional<TreatmentProtocol> findByUserIdAndStatusAndIsDeletedFalse(Long userId, ProtocolStatus status);

    boolean existsByUserIdAndStatusAndIsDeletedFalse(Long userId, ProtocolStatus status);
}
