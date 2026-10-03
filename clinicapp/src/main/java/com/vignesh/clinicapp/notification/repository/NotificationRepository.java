package com.vignesh.clinicapp.notification.repository;

import com.vignesh.clinicapp.notification.model.Notification;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {

    List<Notification> findByUserIdAndIsDeletedFalseOrderByIsReadAscCreatedAtDesc(Long userId, Pageable pageable);

    Optional<Notification> findByIdAndUserIdAndIsDeletedFalse(Long id, Long userId);

    long countByUserIdAndIsReadFalseAndIsDeletedFalse(Long userId);

    boolean existsByUserIdAndTypeAndActionTypeAndActionIdAndIsDeletedFalse(
            Long userId,
            com.vignesh.clinicapp.notification.enums.NotificationType type,
            String actionType,
            Long actionId);

    @Modifying
    @Query("UPDATE Notification n SET n.isRead = true, n.readAt = CURRENT_TIMESTAMP, n.updatedAt = CURRENT_TIMESTAMP " +
           "WHERE n.user.id = :userId AND n.isRead = false AND n.isDeleted = false")
    int markAllAsRead(@Param("userId") Long userId);
}
