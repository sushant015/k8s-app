package com.votepoll.poll.dto;

import com.votepoll.poll.model.PollStatus;

public record UpdatePollStatusRequest(PollStatus status) {
}