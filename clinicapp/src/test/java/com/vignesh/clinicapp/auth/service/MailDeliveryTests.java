package com.vignesh.clinicapp.auth.service;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;
import java.util.ArrayList;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.*;
import static org.springframework.test.web.client.response.MockRestResponseCreators.*;

class MailDeliveryTests {
    @Test void resendRetriesKeepKeyAndSeparateMessagesUseDifferentKeys() throws Exception {
        var builder=RestClient.builder().baseUrl("https://api.resend.com");
        var server=MockRestServiceServer.bindTo(builder).build();
        var smtp=mock(JavaMailSender.class);
        var delivery=new MailDelivery(smtp,builder.build(),"resend","test-only-key","BodyPerfect <noreply@zylinq.com>");
        var keys=new ArrayList<String>();
        for(int i=0;i<3;i++) {
            var expectation=server.expect(requestTo("https://api.resend.com/emails"))
                .andExpect(method(HttpMethod.POST)).andExpect(header("Authorization","Bearer test-only-key"))
                .andExpect(request->keys.add(request.getHeaders().getFirst("Idempotency-Key")))
                .andExpect(content().json("{\"from\":\"BodyPerfect <noreply@zylinq.com>\",\"to\":[\"synthetic@example.invalid\"],\"subject\":\"Verification\",\"text\":\"Synthetic code\"}"));
            if(i==0) expectation.andRespond(withStatus(HttpStatus.TOO_MANY_REQUESTS).body("PRIVATE_PROVIDER_ERROR").contentType(MediaType.TEXT_PLAIN));
            else expectation.andRespond(withSuccess("{\"id\":\"synthetic-id\"}",MediaType.APPLICATION_JSON));
        }
        var error=assertThrows(IllegalStateException.class,()->delivery.send(7,"encrypted-A","synthetic@example.invalid","Verification","Synthetic code"));
        assertFalse(error.toString().contains("PRIVATE_PROVIDER_ERROR")); assertNull(error.getCause());
        delivery.send(7,"encrypted-A","synthetic@example.invalid","Verification","Synthetic code");
        delivery.send(7,"encrypted-B","synthetic@example.invalid","Verification","Synthetic code");
        assertEquals(keys.get(0),keys.get(1)); assertNotEquals(keys.get(1),keys.get(2));
        verifyNoInteractions(smtp); server.verify();
    }
    @Test void missingAcknowledgementFailsForRetry() {
        var builder=RestClient.builder().baseUrl("https://api.resend.com");
        var server=MockRestServiceServer.bindTo(builder).build();
        server.expect(requestTo("https://api.resend.com/emails")).andRespond(withSuccess("{}",MediaType.APPLICATION_JSON));
        var delivery=new MailDelivery(mock(JavaMailSender.class),builder.build(),"resend","test-key","noreply@zylinq.com");
        assertThrows(IllegalStateException.class,()->delivery.send(1,"ciphertext","synthetic@example.invalid","Test","Test"));
        server.verify();
    }
    @Test void configurationRejectsMissingCredentialsAndUnknownProviders() {
        var smtp=mock(JavaMailSender.class); var client=RestClient.create();
        assertThrows(IllegalStateException.class,()->new MailDelivery(smtp,client,"resend","","sender@example.invalid"));
        assertThrows(IllegalStateException.class,()->new MailDelivery(smtp,client,"resend","test-key",""));
        assertThrows(IllegalStateException.class,()->new MailDelivery(smtp,client,"typo","test-key","sender@example.invalid"));
    }
    @Test void localSmtpStillDelivers() throws Exception {
        var smtp=mock(JavaMailSender.class);
        new MailDelivery(smtp,RestClient.create(),"smtp","","sender@example.invalid")
            .send(1,"ciphertext","synthetic@example.invalid","Subject","Body");
        var capture=org.mockito.ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(smtp).send(capture.capture());
        assertEquals("Body",capture.getValue().getText());
        assertEquals("sender@example.invalid",capture.getValue().getFrom());
    }
}
