package com.vignesh.clinicapp.auth.repository;

import com.vignesh.clinicapp.auth.model.RefreshSession;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import java.time.Instant;
import java.util.*;

public interface RefreshSessionRepository extends JpaRepository<RefreshSession, UUID> {
    Optional<RefreshSession> findByTokenHash(String tokenHash);
    boolean existsByFamilyIdAndUserIdAndConsumedFalseAndRevokedFalseAndExpiresAtAfter(
            UUID familyId, Long userId, Instant now);

    @Modifying
    @Query("update RefreshSession s set s.revoked = true where s.familyId = :family")
    void revokeFamily(@Param("family") UUID family);

    @Modifying
    @Query("update RefreshSession s set s.revoked = true where s.user.id = :userId")
    void revokeUser(@Param("userId") Long userId);
}
