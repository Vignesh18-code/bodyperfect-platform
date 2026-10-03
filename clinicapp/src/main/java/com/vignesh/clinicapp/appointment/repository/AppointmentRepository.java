package com.vignesh.clinicapp.appointment.repository;

import com.vignesh.clinicapp.appointment.model.Appointment;
import com.vignesh.clinicapp.appointment.enums.AppointmentStatus;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

@Repository
public interface AppointmentRepository extends JpaRepository<Appointment, Long> {

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select a from Appointment a where a.id = :id")
    java.util.Optional<Appointment> findByIdForUpdate(@Param("id") Long id);

    List<Appointment> findByUserIdAndIsDeletedFalseOrderByAppointmentDateDescAppointmentTimeDesc(
            Long userId,
            Pageable pageable);

    boolean existsByUserIdAndAppointmentDateAndAppointmentTimeAndIsDeletedFalse(
            Long userId,
            LocalDate date,
            LocalTime time);

    /**
     * Active appointment = not deleted AND (appointment date in future OR
     * appointment is today and time hasn't passed yet).
     */
    @Query("SELECT a FROM Appointment a WHERE a.user.id = :userId " +
           "AND a.isDeleted = false AND a.status IN ('PENDING', 'CONFIRMED') " +
           "AND (a.appointmentDate > :today " +
           "  OR (a.appointmentDate = :today AND a.appointmentTime > :now)) " +
           "ORDER BY a.appointmentDate ASC, a.appointmentTime ASC")
    List<Appointment> findActiveByUserId(
            @Param("userId") Long userId,
            @Param("today") LocalDate today,
            @Param("now") LocalTime now);

    @Query("SELECT a FROM Appointment a WHERE a.user.id = :userId " +
           "AND a.id <> :appointmentId " +
           "AND a.isDeleted = false AND a.status IN ('PENDING', 'CONFIRMED') " +
           "AND (a.appointmentDate > :today " +
           "  OR (a.appointmentDate = :today AND a.appointmentTime > :now)) " +
           "ORDER BY a.appointmentDate ASC, a.appointmentTime ASC")
    List<Appointment> findOtherActiveByUserId(
            @Param("userId") Long userId,
            @Param("appointmentId") Long appointmentId,
            @Param("today") LocalDate today,
            @Param("now") LocalTime now);

    @Query("SELECT a FROM Appointment a JOIN FETCH a.user " +
           "WHERE a.isDeleted = false " +
           "AND a.status = :status " +
           "AND a.appointmentDate BETWEEN :startDate AND :endDate")
    List<Appointment> findUpcomingReminderCandidates(
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate,
            @Param("status") AppointmentStatus status);

}
