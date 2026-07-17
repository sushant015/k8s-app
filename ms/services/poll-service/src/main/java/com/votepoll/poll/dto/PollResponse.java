package com.votepoll.poll.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record PollResponse(
        UUID id,
        String slug,
        String title,
        String description,
        String status,
        Instant startAt,
        Instant endAt,
        List<PollOptionDto> options
) {}
