package com.votepoll.poll.dto;

import java.util.UUID;

public record PollOptionDto(UUID id, String label, int sortOrder) {}
