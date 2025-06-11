package com.cyat.ecommerce;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.ResponseEntity;
import java.util.Collections;
import java.util.Map;

@RestController
public class AppController {
    
    // Keep your existing homepage
    @GetMapping("/")
    public String home() {
        return "<html><head><style>body { font-family: Arial; background: #f4f4f9; color: #333; text-align: center; padding: 50px; }</style></head>" +
               "<body><h1>Welcome to CEEYIT E-Commerce Backend</h1><p>This is a sample API running on Spring Boot.</p></body></html>";
    }

    // Add these health endpoints (required for Kubernetes)
    @GetMapping("/actuator/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Collections.singletonMap("status", "UP"));
    }

    @GetMapping("/health")
    public String simpleHealth() {
        return "OK";
    }

    // Add a basic API endpoint
    @GetMapping("/api/status")
    public Map<String, String> apiStatus() {
        return Collections.singletonMap("status", "Operational");
    }
}