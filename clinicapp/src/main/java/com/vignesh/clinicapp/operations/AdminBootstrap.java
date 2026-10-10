package com.vignesh.clinicapp.operations;

import com.vignesh.clinicapp.user.model.User;
import com.vignesh.clinicapp.user.enums.*;
import com.vignesh.clinicapp.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.env.Environment;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

@Component
@ConditionalOnProperty(name="app.bootstrap.enabled",havingValue="true")
@RequiredArgsConstructor
@Slf4j
public class AdminBootstrap implements ApplicationRunner {
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final Environment env;
    @Override @Transactional public void run(ApplicationArguments args) {
        // This one-time operation must run in a single deployment job, never on every replica.
        if (users.existsByRole(Role.ADMIN)) {
            log.warn("Administrator already exists; bootstrap skipped. Disable APP_BOOTSTRAP_ENABLED and remove the bootstrap password.");
            return;
        }
        String password=env.getRequiredProperty("BOOTSTRAP_ADMIN_PASSWORD");
        if(password.length()<14||password.getBytes(StandardCharsets.UTF_8).length>72)throw new IllegalStateException("Bootstrap password must be 14-72 bytes");
        String email=env.getRequiredProperty("BOOTSTRAP_ADMIN_EMAIL").trim().toLowerCase(Locale.ROOT);
        String phone=env.getRequiredProperty("BOOTSTRAP_ADMIN_PHONE");
        if(!email.matches("[^@\\s]+@[^@\\s]+\\.[^@\\s]+")||!phone.matches("[0-9]{9,15}"))throw new IllegalStateException("Valid administrator email and phone required");
        User u=users.saveAndFlush(User.builder().fullName(env.getRequiredProperty("BOOTSTRAP_ADMIN_NAME"))
                .email(email).phone(phone).password(encoder.encode(password)).role(Role.ADMIN).build());
        u.setStatus(UserStatus.ACTIVE);users.saveAndFlush(u);
    }
}
