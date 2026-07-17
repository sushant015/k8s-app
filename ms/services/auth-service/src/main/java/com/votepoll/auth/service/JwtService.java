package com.votepoll.auth.service;

import com.votepoll.auth.model.Admin;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;

@Service
public class JwtService {
    private final SecretKey key;
    private final long expirationMs;

    public JwtService(
            @Value("${jwt.secret}") String secret,
            @Value("${jwt.expiration-ms:86400000}") long expirationMs) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMs = expirationMs;
    }

    public String generateToken(Admin admin) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(admin.getId().toString())
                .claim("email", admin.getEmail())
                .claim("role", admin.getRole())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plusMillis(expirationMs)))
                .signWith(key)
                .compact();
    }

    public Optional<AdminClaims> validateToken(String token) {
        try {
            var claims = Jwts.parser().verifyWith(key).build()
                    .parseSignedClaims(token).getPayload();
            return Optional.of(new AdminClaims(
                    claims.getSubject(),
                    claims.get("email", String.class),
                    claims.get("role", String.class)
            ));
        } catch (Exception e) {
            return Optional.empty();
        }
    }

    public record AdminClaims(String adminId, String email, String role) {}
}
