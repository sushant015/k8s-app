package com.votepoll.auth.controller;

import com.votepoll.auth.dto.*;
import com.votepoll.auth.service.AuthService;
import com.votepoll.auth.service.JwtService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthService authService;
    private final JwtService jwtService;

    public AuthController(AuthService authService, JwtService jwtService) {
        this.authService = authService;
        this.jwtService = jwtService;
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest request) {
        return authService.authenticate(request.email(), request.password())
                .<ResponseEntity<?>>map(admin -> ResponseEntity.ok(new LoginResponse(
                        authService.issueToken(admin),
                        admin.getId().toString(),
                        admin.getEmail(),
                        admin.getRole()
                )))
                .orElse(ResponseEntity.status(401).body(Map.of("error", "Invalid credentials")));
    }

    @GetMapping("/validate")
    public ResponseEntity<?> validate(@RequestHeader(value = "Authorization", required = false) String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return ResponseEntity.status(401).body(Map.of("valid", false));
        }
        String token = authHeader.substring(7);
        return jwtService.validateToken(token)
                .<ResponseEntity<?>>map(claims -> ResponseEntity.ok(new ValidateResponse(
                        true, claims.adminId(), claims.email(), claims.role())))
                .orElse(ResponseEntity.status(401).body(Map.of("valid", false)));
    }
}
