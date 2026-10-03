package com.vignesh.clinicapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;
import lombok.extern.slf4j.Slf4j;

@SpringBootApplication
@EnableScheduling
@Slf4j
public class ClinicappApplication {

	public static void main(String[] args) {
		SpringApplication.run(ClinicappApplication.class, args);
		log.info("Clinic App is running");
	}
}
