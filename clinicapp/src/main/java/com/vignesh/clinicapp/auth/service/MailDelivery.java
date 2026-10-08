package com.vignesh.clinicapp.auth.service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/** HTTPS delivery for hosted deployments; SMTP remains available for local testing. */
@Component
public class MailDelivery {
    private final JavaMailSender smtp;
    private final RestClient client;
    private final String provider, key, from;

    @Autowired
    public MailDelivery(JavaMailSender smtp,
            @Value("${app.mail.provider:smtp}") String provider,
            @Value("${app.mail.resend-api-key:}") String key,
            @Value("${app.mail.from:${spring.mail.username:}}") String from) {
        this(smtp, httpClient(), provider, key, from);
    }

    MailDelivery(JavaMailSender smtp, RestClient client, String provider, String key, String from) {
        this.smtp=smtp; this.client=client; this.provider=provider; this.key=key; this.from=from;
        if (!List.of("smtp", "resend").contains(provider))
            throw new IllegalStateException("MAIL_PROVIDER must be smtp or resend");
        if (provider.equals("resend") && (key.isBlank() || from.isBlank()))
            throw new IllegalStateException("Resend requires RESEND_API_KEY and MAIL_FROM");
    }

    private static RestClient httpClient() {
        var http=java.net.http.HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
        var factory=new JdkClientHttpRequestFactory(http);
        factory.setReadTimeout(Duration.ofSeconds(10));
        return RestClient.builder().baseUrl("https://api.resend.com").requestFactory(factory).build();
    }

    public void send(long id, String encryptedPayload, String recipient, String subject, String body) throws Exception {
        if (provider.equals("smtp")) {
            var message=new SimpleMailMessage();
            message.setFrom(from); message.setTo(recipient); message.setSubject(subject); message.setText(body);
            smtp.send(message);
            return;
        }
        // Stable across retries/restarts, distinct even if database IDs are reused after a restore.
        String digest=HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest((recipient+"\n"+encryptedPayload).getBytes(StandardCharsets.UTF_8)));
        try {
            var response=client.post().uri("/emails")
                    .header("Authorization", "Bearer "+key)
                    .header("Idempotency-Key", "bodyperfect-otp-"+id+"-"+digest)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of("from",from,"to",List.of(recipient),"subject",subject,"text",body))
                    .retrieve().body(com.fasterxml.jackson.databind.JsonNode.class);
            if (response==null || response.path("id").asText().isBlank())
                throw new IllegalStateException("Missing delivery acknowledgement");
        } catch (Exception failure) {
            // Provider responses can contain recipient information. Never propagate them to logs.
            throw new IllegalStateException("Resend delivery failed; message retained for retry");
        }
    }
}
