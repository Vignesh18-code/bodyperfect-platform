package com.vignesh.clinicapp.treatment.service;

import com.vignesh.clinicapp.common.dto.ApiResponse;
import com.vignesh.clinicapp.treatment.dto.ProtocolResponse;
import com.vignesh.clinicapp.treatment.dto.SessionResponse;
import com.vignesh.clinicapp.treatment.enums.SessionStatus;
import com.vignesh.clinicapp.treatment.model.TreatmentProtocol;
import com.vignesh.clinicapp.treatment.model.TreatmentSession;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.treatment.repository.TreatmentProtocolRepository;
import com.vignesh.clinicapp.treatment.repository.TreatmentSessionRepository;
import com.vignesh.clinicapp.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Comparator;
import java.time.ZoneId;
import java.time.LocalDateTime;
import org.springframework.beans.factory.annotation.Value;

@Service
@RequiredArgsConstructor
@Slf4j
public class TreatmentService {

    private static final int MAX_PROTOCOLS_RETURNED = 100;
    @Value("${app.clinic.time-zone:Asia/Dubai}")
    private String clinicTimeZone;
    private static final Comparator<TreatmentSession> SESSION_ORDER = Comparator
            .comparing(TreatmentSession::getSessionDate)
            .thenComparing(TreatmentSession::getSessionTime)
            .thenComparing(TreatmentSession::getSessionNumber);

    private final TreatmentProtocolRepository protocolRepository;
    private final TreatmentSessionRepository sessionRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public ApiResponse<ProtocolResponse> getActiveProtocol(String email) {
        User user = findUserOrThrow(email);

        var protocol = protocolRepository
                .findByUserIdAndStatusAndIsDeletedFalse(
                        user.getId(),
                        com.vignesh.clinicapp.treatment.enums.ProtocolStatus.ACTIVE)
                .orElse(null);

        if (protocol == null) {
            log.info("No active protocol for user: [{}]", email);
            return ApiResponse.success("No active treatment protocol", null);
        }

        List<TreatmentSession> allSessions = sessionRepository
                .findByProtocolIdAndIsDeletedFalseOrderBySessionNumberAsc(protocol.getId());

        long completed = allSessions.stream()
                .filter(s -> s.getStatus() == SessionStatus.COMPLETED)
                .count();

        int percent = protocol.getTotalSessions() > 0
                ? (int) (completed * 100 / protocol.getTotalSessions())
                : 0;

        TreatmentSession nextSession = findNextSession(allSessions);

        ProtocolResponse response = ProtocolResponse.builder()
                .id(protocol.getId())
                .protocolName(protocol.getProtocolName())
                .treatmentType(protocol.getTreatmentType())
                .status(protocol.getStatus().name())
                .weightKg(protocol.getWeightKg())
                .heightCm(protocol.getHeightCm())
                .bmi(protocol.getBmi())
                .goalWeightKg(protocol.getGoalWeightKg())
                .totalSessions(protocol.getTotalSessions())
                .completedSessions(completed)
                .progressPercent(percent)
                .instructions(protocol.getInstructions())
                .startDate(protocol.getStartDate())
                .endDate(protocol.getEndDate())
                .nextSession(nextSession != null ? toSessionResponse(nextSession) : null)
                .sessions(allSessions.stream().map(this::toSessionResponse).toList())
                .build();

        log.info("Active protocol fetched for user: [{}] → protocol: [{}], sessions: [{}]",
                email, protocol.getProtocolName(), allSessions.size());

        return ApiResponse.success("Treatment protocol loaded", response);
    }

    @Transactional(readOnly = true)
    public ApiResponse<List<ProtocolResponse>> getAllProtocols(String email) {
        User user = findUserOrThrow(email);

        List<TreatmentProtocol> protocols = protocolRepository
                .findByUserIdAndIsDeletedFalseOrderByCreatedAtDesc(
                        user.getId(), PageRequest.of(0, MAX_PROTOCOLS_RETURNED));

        List<ProtocolResponse> responses = protocols.stream()
                .map(protocol -> {
                    long completed = sessionRepository
                            .countByProtocolIdAndStatusAndIsDeletedFalse(
                                    protocol.getId(), SessionStatus.COMPLETED);

                    int percent = protocol.getTotalSessions() > 0
                            ? (int) (completed * 100 / protocol.getTotalSessions())
                            : 0;

                    return ProtocolResponse.builder()
                            .id(protocol.getId())
                            .protocolName(protocol.getProtocolName())
                            .treatmentType(protocol.getTreatmentType())
                            .status(protocol.getStatus().name())
                            .totalSessions(protocol.getTotalSessions())
                            .completedSessions(completed)
                            .progressPercent(percent)
                            .startDate(protocol.getStartDate())
                            .endDate(protocol.getEndDate())
                            .build();
                })
                .toList();

        log.info("All protocols fetched for user: [{}] → count: [{}]", email, responses.size());
        return ApiResponse.success("Protocols loaded", responses);
    }

    @Transactional(readOnly = true)
    public ApiResponse<ProtocolResponse> getProtocolById(String email, Long protocolId) {
        User user = findUserOrThrow(email);

        var protocol = protocolRepository
                .findByIdAndUserIdAndIsDeletedFalse(protocolId, user.getId())
                .orElse(null);

        if (protocol == null) {
            log.warn("Protocol not found → id: [{}], user: [{}]", protocolId, email);
            return ApiResponse.error("Treatment protocol not found");
        }

        List<TreatmentSession> allSessions = sessionRepository
                .findByProtocolIdAndIsDeletedFalseOrderBySessionNumberAsc(protocol.getId());

        long completed = allSessions.stream()
                .filter(s -> s.getStatus() == SessionStatus.COMPLETED)
                .count();

        int percent = protocol.getTotalSessions() > 0
                ? (int) (completed * 100 / protocol.getTotalSessions())
                : 0;

        TreatmentSession nextSession = findNextSession(allSessions);

        ProtocolResponse response = ProtocolResponse.builder()
                .id(protocol.getId())
                .protocolName(protocol.getProtocolName())
                .treatmentType(protocol.getTreatmentType())
                .status(protocol.getStatus().name())
                .weightKg(protocol.getWeightKg())
                .heightCm(protocol.getHeightCm())
                .bmi(protocol.getBmi())
                .goalWeightKg(protocol.getGoalWeightKg())
                .totalSessions(protocol.getTotalSessions())
                .completedSessions(completed)
                .progressPercent(percent)
                .instructions(protocol.getInstructions())
                .startDate(protocol.getStartDate())
                .endDate(protocol.getEndDate())
                .nextSession(nextSession != null ? toSessionResponse(nextSession) : null)
                .sessions(allSessions.stream().map(this::toSessionResponse).toList())
                .build();

        log.info("Protocol [{}] fetched for user: [{}]", protocolId, email);
        return ApiResponse.success("Protocol loaded", response);
    }

    @Transactional(readOnly = true)
    public ApiResponse<List<SessionResponse>> getSessionsByMonth(
            String email, Long protocolId, int year, int month) {

        User user = findUserOrThrow(email);

        var protocol = protocolRepository
                .findByIdAndUserIdAndIsDeletedFalse(protocolId, user.getId())
                .orElse(null);

        if (protocol == null) {
            return ApiResponse.error("Treatment protocol not found");
        }

        LocalDate startDate = LocalDate.of(year, month, 1);
        LocalDate endDate = startDate.withDayOfMonth(startDate.lengthOfMonth());

        List<TreatmentSession> sessions = sessionRepository
                .findByProtocolAndDateRange(protocolId, startDate, endDate);

        List<SessionResponse> responses = sessions.stream()
                .map(this::toSessionResponse)
                .toList();

        log.info("Sessions for protocol [{}], month [{}/{}] → count: [{}]",
                protocolId, year, month, responses.size());

        return ApiResponse.success("Sessions loaded", responses);
    }

    @Transactional(readOnly = true)
    public ApiResponse<List<SessionResponse>> getSessionsByDate(String email, LocalDate date) {
        User user = findUserOrThrow(email);

        List<TreatmentSession> sessions = sessionRepository
                .findByUserAndDate(user.getId(), date);

        List<SessionResponse> responses = sessions.stream()
                .map(this::toSessionResponse)
                .toList();

        log.info("Sessions for user [{}] on date [{}] → count: [{}]",
                email, date, responses.size());

        return ApiResponse.success("Sessions loaded", responses);
    }

    @Transactional(readOnly = true)
    public ApiResponse<SessionResponse> getNextSession(String email) {
        User user = findUserOrThrow(email);

        var clinicNow = LocalDateTime.now(ZoneId.of(clinicTimeZone));
        List<TreatmentSession> upcoming = sessionRepository
                .findUpcomingSessions(user.getId(), clinicNow.toLocalDate(), clinicNow.toLocalTime());

        if (upcoming.isEmpty()) {
            return ApiResponse.success("No upcoming sessions", null);
        }

        SessionResponse response = toSessionResponse(upcoming.get(0));

        log.info("Next session for user [{}] → session [{}] on [{}]",
                email, response.getSessionNumber(), response.getSessionDate());

        return ApiResponse.success("Next session loaded", response);
    }

    // ── Private Helpers ───────────────────────────────────

    private User findUserOrThrow(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> {
                    log.error("User not found: [{}]", email);
                    return new RuntimeException("User not found");
                });
    }

    private TreatmentSession findNextSession(List<TreatmentSession> sessions) {
        var clinicNow = LocalDateTime.now(ZoneId.of(clinicTimeZone));
        LocalDate today = clinicNow.toLocalDate();
        LocalTime now = clinicNow.toLocalTime();

        // IN_PROGRESS sessions are always considered "next" regardless of time
        TreatmentSession inProgress = sessions.stream()
                .filter(s -> s.getStatus() == SessionStatus.IN_PROGRESS)
                .min(SESSION_ORDER)
                .orElse(null);

        if (inProgress != null) {
            return inProgress;
        }

        return sessions.stream()
                .filter(s -> s.getStatus() == SessionStatus.SCHEDULED)
                .filter(s -> s.getSessionDate().isAfter(today)
                        || (s.getSessionDate().isEqual(today)
                            && !s.getSessionTime().isBefore(now)))
                .min(SESSION_ORDER)
                .orElse(null);
    }

    private SessionResponse toSessionResponse(TreatmentSession session) {
        return SessionResponse.builder()
                .id(session.getId())
                .protocolId(session.getProtocol().getId())
                .protocolName(session.getProtocol().getProtocolName())
                .sessionNumber(session.getSessionNumber())
                .sessionName(session.getSessionName())
                .sessionDate(session.getSessionDate())
                .sessionTime(session.getSessionTime())
                .durationMinutes(session.getDurationMinutes())
                .status(session.getStatus().name())
                .build();
    }
}
