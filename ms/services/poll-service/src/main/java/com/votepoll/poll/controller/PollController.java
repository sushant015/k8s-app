package com.votepoll.poll.controller;

import com.votepoll.poll.dto.*;
import com.votepoll.poll.service.JwtValidator;
import com.votepoll.poll.service.PollService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/polls")
public class PollController {
    private final PollService pollService;
    private final JwtValidator jwtValidator;

    public PollController(PollService pollService, JwtValidator jwtValidator) {
        this.pollService = pollService;
        this.jwtValidator = jwtValidator;
    }

    @PostMapping
    public ResponseEntity<?> create(
            @RequestHeader(value = "Authorization", required = false) String auth,
            @RequestBody CreatePollRequest request) {
        return jwtValidator.extractAdminId(auth)
                .<ResponseEntity<?>>map(adminId -> {
                    try {
                        return ResponseEntity.status(201).body(pollService.createPoll(request, adminId));
                    } catch (IllegalArgumentException e) {
                        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
                    }
                })
                .orElse(ResponseEntity.status(401).body(Map.of("error", "Unauthorized")));
    }

    @GetMapping
    public ResponseEntity<?> list(@RequestHeader(value = "Authorization", required = false) String auth) {
        return jwtValidator.extractAdminId(auth)
                .<ResponseEntity<?>>map(adminId -> ResponseEntity.ok(pollService.listByAdmin(adminId)))
                .orElse(ResponseEntity.status(401).body(Map.of("error", "Unauthorized")));
    }

    @GetMapping("/{slug}")
    public ResponseEntity<?> getBySlug(@PathVariable String slug) {
        try {
            return ResponseEntity.ok(pollService.getBySlug(slug));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(404).body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping("/{id}/publish")
    public ResponseEntity<?> publish(
            @PathVariable UUID id,
            @RequestHeader(value = "Authorization", required = false) String auth) {
        return jwtValidator.extractAdminId(auth)
                .<ResponseEntity<?>>map(adminId -> {
                    try {
                        return ResponseEntity.ok(pollService.publish(id, adminId));
                    } catch (Exception e) {
                        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
                    }
                })
                .orElse(ResponseEntity.status(401).body(Map.of("error", "Unauthorized")));
    }
}
