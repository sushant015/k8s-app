package com.votepoll.poll.scheduler;

import com.votepoll.poll.service.PollService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class PollExpiryScheduler {
    private final PollService pollService;

    public PollExpiryScheduler(PollService pollService) {
        this.pollService = pollService;
    }

    @Scheduled(fixedRate = 60000)
    public void expirePolls() {
        pollService.expirePolls();
    }
}
