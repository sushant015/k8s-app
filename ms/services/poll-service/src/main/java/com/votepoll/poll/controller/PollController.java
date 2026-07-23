package com.votepoll.poll.controller;

import com.votepoll.poll.dto.CreatePollRequest;
import com.votepoll.poll.dto.PollResponse;
import com.votepoll.poll.dto.UpdatePollStatusRequest;
import com.votepoll.poll.service.PollService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/polls")
public class PollController {

    private final PollService pollService;

    public PollController(PollService pollService) {
        this.pollService = pollService;
    }

    @PostMapping
    public ResponseEntity<PollResponse> createPoll(@RequestBody CreatePollRequest req,
                                                   @RequestHeader("X-User-Id") UUID adminId) {
        PollResponse pollResponse = pollService.createPoll(req, adminId);
        return new ResponseEntity<>(pollResponse, HttpStatus.CREATED);
    }

    @GetMapping
    public ResponseEntity<List<PollResponse>> listPollsByAdmin(@RequestHeader("X-User-Id") UUID adminId) {
        return ResponseEntity.ok(pollService.listByAdmin(adminId));
    }

    @GetMapping("/{slug}")
    public ResponseEntity<PollResponse> getPollBySlug(@PathVariable String slug) {
        return ResponseEntity.ok(pollService.getBySlug(slug));
    }

    @PatchMapping("/{slug}/status")
    public ResponseEntity<PollResponse> updatePollStatus(@PathVariable String slug,
                                                         @RequestBody UpdatePollStatusRequest req,
                                                         @RequestHeader("X-User-Id") UUID adminId) {
        PollResponse pollResponse = pollService.updatePollStatus(slug, req, adminId);
        return ResponseEntity.ok(pollResponse);
    }
}