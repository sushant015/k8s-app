package com.votepoll.poll.dto;

import java.time.Instant;
import java.util.List;

public record CreatePollRequest(
        String title,
        String description,
        String slug,
        Instant startAt,
        Instant endAt,
        List<String> options
) {}
