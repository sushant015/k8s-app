package com.votepoll.poll.model;

import jakarta.persistence.*;
import java.util.UUID;

@Entity
@Table(name = "options", schema = "polls")
public class PollOption {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "poll_id", nullable = false)
    private Poll poll;

    @Column(nullable = false)
    private String label;

    @Column(name = "sort_order")
    private int sortOrder;

    public UUID getId() { return id; }
    public String getLabel() { return label; }
    public void setLabel(String label) { this.label = label; }
    public int getSortOrder() { return sortOrder; }
    public void setSortOrder(int sortOrder) { this.sortOrder = sortOrder; }
    public void setPoll(Poll poll) { this.poll = poll; }
}
