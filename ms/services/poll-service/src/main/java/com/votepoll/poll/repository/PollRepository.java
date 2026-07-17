package com.votepoll.poll.repository;

import com.votepoll.poll.model.Poll;
import com.votepoll.poll.model.PollStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PollRepository extends JpaRepository<Poll, UUID> {
    Optional<Poll> findBySlug(String slug);
    List<Poll> findByCreatedByOrderByStartAtDesc(UUID createdBy);

    @Modifying
    @Query("UPDATE Poll p SET p.status = :status WHERE p.status = :fromStatus AND p.endAt <= :now")
    int updateExpiredPolls(PollStatus status, PollStatus fromStatus, Instant now);
}
