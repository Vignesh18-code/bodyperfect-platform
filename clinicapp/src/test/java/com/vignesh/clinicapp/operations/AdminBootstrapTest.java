package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.user.enums.Role;
import com.vignesh.clinicapp.user.enums.UserStatus;
import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.security.crypto.password.PasswordEncoder;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class AdminBootstrapTest {
    @Test void existingAdminSurvivesRestartWithoutBootstrapSecrets() {
        var users = mock(UserRepository.class);
        var encoder = mock(PasswordEncoder.class);
        when(users.existsByRole(Role.ADMIN)).thenReturn(true);
        assertDoesNotThrow(() -> new AdminBootstrap(users, encoder, new MockEnvironment()).run(null));
        verify(users).existsByRole(Role.ADMIN);
        verifyNoMoreInteractions(users);
        verifyNoInteractions(encoder);
    }
    @Test void missingSecretsCannotCreateFirstAdmin() {
        var users = mock(UserRepository.class);
        var encoder = mock(PasswordEncoder.class);
        assertThrows(IllegalStateException.class, () -> new AdminBootstrap(users, encoder, new MockEnvironment()).run(null));
        verify(users, never()).saveAndFlush(any());
        verifyNoInteractions(encoder);
    }
    @Test void firstAdminUsesEncodedPasswordAndActiveStatus() {
        var users = mock(UserRepository.class);
        var encoder = mock(PasswordEncoder.class);
        var env = new MockEnvironment().withProperty("BOOTSTRAP_ADMIN_EMAIL", " OWNER@example.test ")
            .withProperty("BOOTSTRAP_ADMIN_NAME", "Synthetic owner")
            .withProperty("BOOTSTRAP_ADMIN_PHONE", "999000001")
            .withProperty("BOOTSTRAP_ADMIN_PASSWORD", "Synthetic-only-pass1!");
        when(encoder.encode("Synthetic-only-pass1!")).thenReturn("encoded-test-value");
        when(users.saveAndFlush(any(User.class))).thenAnswer(call -> call.getArgument(0));
        new AdminBootstrap(users, encoder, env).run(null);
        verify(users, times(2)).saveAndFlush(argThat(u -> u.getRole() == Role.ADMIN
            && u.getStatus() == UserStatus.ACTIVE && u.getEmail().equals("owner@example.test")
            && u.getPassword().equals("encoded-test-value")));
    }
}
