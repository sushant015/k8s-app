package com.votepoll.poll.model;

public enum PollStatus {
    DRAFT,     // Poll created but not yet scheduled or active
    SCHEDULED, // Poll is created but not yet started
    ACTIVE,    // Poll is open for voting
    PAUSED,    // Admin has temporarily suspended voting
    ENDED,     // Voting period is over, results not public
    PUBLISHED  // Final results are public
}