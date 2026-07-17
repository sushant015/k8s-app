package com.votepoll.poll.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Optional;
import java.util.UUID;

@Service
public class JwtValidator {
    private final SecretKey key;

    public JwtValidator(@Value("${jwt.secret}") String secret) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public Optional<UUID> extractAdminId(String authHeader) {
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            return Optional.empty();
        }
        try {
            var claims = Jwts.parser().verifyWith(key).build()
                    .parseSignedClaims(authHeader.substring(7)).getPayload();
            return Optional.of(UUID.fromString(claims.getSubject()));
        } catch (Exception e) {
            return Optional.empty();
        }
    }
}
