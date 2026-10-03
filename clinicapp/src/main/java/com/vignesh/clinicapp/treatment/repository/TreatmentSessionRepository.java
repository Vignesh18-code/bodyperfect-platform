package com.vignesh.clinicapp.treatment.repository;

import com.vignesh.clinicapp.treatment.enums.SessionStatus;
import com.vignesh.clinicapp.treatment.model.TreatmentSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface TreatmentSessionRepository extends JpaRepository<TreatmentSession, Long> {

    Optional<TreatmentSession> findByAppointmentId(Long appointmentId);

    List<TreatmentSession> findByProtocolIdAndIsDeletedFalseOrderBySessionNumberAsc(Long protocolId);

    List<TreatmentSession> findByUserIdAndIsDeletedFalseOrderBySessionDateAscSessionTimeAsc(Long userId);

    Optional<TreatmentSession> findByIdAndUserIdAndIsDeletedFalse(Long id, Long userId);

    @Query("SELECT s FROM TreatmentSession s WHERE s.protocol.id = :protocolId " +
           "AND s.sessionDate BETWEEN :startDate AND :endDate " +
           "AND s.isDeleted = false ORDER BY s.sessionDate ASC, s.sessionTime ASC")
    List<TreatmentSession> findByProtocolAndDateRange(
            @Param("protocolId") Long protocolId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    @Query("SELECT s FROM TreatmentSession s WHERE s.user.id = :userId " +
           "AND s.sessionDate = :date AND s.isDeleted = false " +
           "ORDER BY s.sessionTime ASC")
    List<TreatmentSession> findByUserAndDate(
            @Param("userId") Long userId,
            @Param("date") LocalDate date);

    long countByProtocolIdAndStatusAndIsDeletedFalse(Long protocolId, SessionStatus status);

    @Query("SELECT s FROM TreatmentSession s WHERE s.user.id = :userId " +
           "AND s.isDeleted = false " +
           "AND (s.status = 'IN_PROGRESS' " +
           "  OR (s.status = 'SCHEDULED' " +
           "      AND (s.sessionDate > :today OR (s.sessionDate = :today AND s.sessionTime >= :now)))) " +
           "ORDER BY CASE WHEN s.status = 'IN_PROGRESS' THEN 0 ELSE 1 END ASC, s.sessionDate ASC, s.sessionTime ASC")
    List<TreatmentSession> findUpcomingSessions(
            @Param("userId") Long userId,
            @Param("today") LocalDate today,
            @Param("now") java.time.LocalTime now);
}
