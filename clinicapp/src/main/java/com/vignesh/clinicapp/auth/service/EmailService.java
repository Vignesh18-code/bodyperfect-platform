package com.vignesh.clinicapp.auth.service;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;

    @Value("${spring.mail.username}")
    private String fromEmail;


    @Async("emailTaskExecutor")
    public void sendOtpEmail(String toEmail, String fullName, String otp) {

        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true);

            helper.setFrom(fromEmail);
            helper.setTo(toEmail);
            helper.setSubject("ANT Clinic - Your Verification Code");

            String body = """
                <html>
                <body style="font-family: Arial, sans-serif; padding: 20px;">

                    <h2 style="color: #2E86C1;">Welcome to Bodyperfect Clinic! 🏥</h2>

                    <p>Hi <strong>%s</strong>,</p>

                    <p>Your verification code is:</p>

                    <div style="
                        background: #F0F0F0;
                        padding: 20px;
                        text-align: center;
                        font-size: 32px;
                        font-weight: bold;
                        letter-spacing: 8px;
                        color: #2E86C1;
                        border-radius: 10px;
                        margin: 20px 0;">
                        %s
                    </div>

                    <p>⏰ This code expires in <strong>5 minutes</strong>.</p>

                    <p>If you did not request this, please ignore this email.</p>

                    <br>
                    <p style="color: #888;">— ANT Clinic Team</p>

                </body>
                </html>
                """.formatted(fullName, otp);

            helper.setText(body, true);

            mailSender.send(message);

            log.info("OTP email sent to: [{}]", toEmail);

        } catch (MessagingException e) {
            log.error("Failed to send OTP email to: [{}] Error: {}", toEmail, e.getMessage());
        }
    }

    @Async("emailTaskExecutor")
    public void sendPasswordResetEmail(String toEmail, String fullName, String otp) {

        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true);

            helper.setFrom(fromEmail);
            helper.setTo(toEmail);
            helper.setSubject("ANT Clinic - Password Reset Code");

            String body = """
                <html>
                <body style="font-family: Arial, sans-serif; padding: 20px;">

                    <h2 style="color: #E74C3C;">Password Reset Request 🔐</h2>

                    <p>Hi <strong>%s</strong>,</p>

                    <p>We received a request to reset your password. Your reset code is:</p>

                    <div style="
                        background: #FFF3F3;
                        padding: 20px;
                        text-align: center;
                        font-size: 32px;
                        font-weight: bold;
                        letter-spacing: 8px;
                        color: #E74C3C;
                        border-radius: 10px;
                        margin: 20px 0;">
                        %s
                    </div>

                    <p>⏰ This code expires in <strong>5 minutes</strong>.</p>

                    <p>If you did not request a password reset, please ignore this email. Your password will remain unchanged.</p>

                    <br>
                    <p style="color: #888;">— ANT Clinic Team</p>

                </body>
                </html>
                """.formatted(fullName, otp);

            helper.setText(body, true);

            mailSender.send(message);

            log.info("Password reset email sent to: [{}]", toEmail);

        } catch (MessagingException e) {
            log.error("Failed to send password reset email to: [{}] Error: {}", toEmail, e.getMessage());
        }
    }
}
