
package com.cyat.ecommerce;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class AppController {
    @GetMapping("/")
    public String home() {
        return "<html><head><style>body { font-family: Arial; background: #f4f4f9; color: #333; text-align: center; padding: 50px; }</style></head>" +
               "<body><h1>Welcome to CEEYIT E-Commerce Backend</h1><p>This is a sample API running on Spring Boot.</p></body></html>";
    }
}
