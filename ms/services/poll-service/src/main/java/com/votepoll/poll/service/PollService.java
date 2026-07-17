package com.votepoll.poll.service;

import com.votepoll.poll.dto.*;
import com.votepoll.poll.model.*;
import com.votepoll.poll.repository.PollRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class PollService {
    private final PollRepository pollRepository;

    public PollService(PollRepository pollRepository) {
        this.pollRepository = pollRepository;
    }

    @Transactional
    public PollResponse createPoll(CreatePollRequest req, UUID adminId) {
        if (pollRepository.findBySlug(req.slug()).isPresent()) {
            throw new IllegalArgumentException("Slug already exists");
        }
        if (req.options() == null || req.options().size() < 2) {
            throw new IllegalArgumentException("At least 2 options required");
        }

        Poll poll = new Poll();
        poll.setSlug(req.slug());
        poll.setTitle(req.title());
        poll.setDescription(req.description());
        poll.setCreatedBy(adminId);
        poll.setStartAt(req.startAt());
        poll.setEndAt(req.endAt());
        poll.setStatus(PollStatus.ACTIVE);

        for (int i = 0; i < req.options().size(); i++) {
            PollOption option = new PollOption();
            option.setLabel(req.options().get(i));
            option.setSortOrder(i);
            poll.addOption(option);
        }

        Poll saved = pollRepository.save(poll);
        return toResponse(saved);
    }

    public List<PollResponse> listByAdmin(UUID adminId) {
        return pollRepository.findByCreatedByOrderByStartAtDesc(adminId)
                .stream().map(this::toResponse).toList();
    }

    public PollResponse getBySlug(String slug) {
        return pollRepository.findBySlug(slug)
                .map(this::toResponse)
                .orElseThrow(() -> new IllegalArgumentException("Poll not found"));
    }

    @Transactional
    public PollResponse publish(UUID pollId, UUID adminId) {
        Poll poll = pollRepository.findById(pollId)
                .orElseThrow(() -> new IllegalArgumentException("Poll not found"));
        if (!poll.getCreatedBy().equals(adminId)) {
            throw new SecurityException("Not authorized");
        }
        if (poll.getStatus() != PollStatus.ENDED && poll.getStatus() != PollStatus.ACTIVE) {
            throw new IllegalStateException("Poll cannot be published in current status");
        }
        poll.setStatus(PollStatus.PUBLISHED);
        return toResponse(pollRepository.save(poll));
    }

    @Transactional
    public void expirePolls() {
        pollRepository.updateExpiredPolls(PollStatus.ENDED, PollStatus.ACTIVE, Instant.now());
    }

    private PollResponse toResponse(Poll poll) {
        List<PollOptionDto> options = poll.getOptions().stream()
                .map(o -> new PollOptionDto(o.getId(), o.getLabel(), o.getSortOrder()))
                .toList();
        return new PollResponse(
                poll.getId(), poll.getSlug(), poll.getTitle(), poll.getDescription(),
                poll.getStatus().name(), poll.getStartAt(), poll.getEndAt(), options
        );
    }
}
