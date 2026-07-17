-- Vote Polling Platform — Cloud SQL initialization
-- Run once after Cloud SQL instance is created

CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS users;
CREATE SCHEMA IF NOT EXISTS polls;
CREATE SCHEMA IF NOT EXISTS votes;
CREATE SCHEMA IF NOT EXISTS results;

-- Auth schema
CREATE TABLE IF NOT EXISTS auth.admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'ADMIN',
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS auth.refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES auth.admins(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Users schema (admin profiles)
CREATE TABLE IF NOT EXISTS users.profiles (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Polls schema
CREATE TABLE IF NOT EXISTS polls.polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    created_by UUID NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_window CHECK (end_at > start_at)
);

CREATE TABLE IF NOT EXISTS polls.options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES polls.polls(id) ON DELETE CASCADE,
    label VARCHAR(500) NOT NULL,
    sort_order INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_polls_slug ON polls.polls(slug);
CREATE INDEX IF NOT EXISTS idx_polls_status ON polls.polls(status);

-- Votes schema
CREATE TABLE IF NOT EXISTS votes.votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL,
    option_id UUID NOT NULL,
    voter_fingerprint VARCHAR(64) NOT NULL,
    voted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (poll_id, voter_fingerprint)
);

CREATE INDEX IF NOT EXISTS idx_votes_poll ON votes.votes(poll_id);

-- Results schema
CREATE TABLE IF NOT EXISTS results.snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID UNIQUE NOT NULL,
    total_votes INT NOT NULL DEFAULT 0,
    published BOOLEAN NOT NULL DEFAULT FALSE,
    published_at TIMESTAMPTZ,
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS results.option_totals (
    snapshot_id UUID NOT NULL REFERENCES results.snapshots(id) ON DELETE CASCADE,
    option_id UUID NOT NULL,
    option_label VARCHAR(500) NOT NULL,
    vote_count INT NOT NULL DEFAULT 0,
    percentage NUMERIC(5,2) NOT NULL DEFAULT 0,
    PRIMARY KEY (snapshot_id, option_id)
);

-- Seed default admin (password: password — change in production)
INSERT INTO auth.admins (email, password_hash, role)
VALUES ('admin@votepoll.local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'ADMIN')
ON CONFLICT (email) DO NOTHING;

INSERT INTO users.profiles (id, email, display_name)
SELECT id, email, 'System Admin' FROM auth.admins WHERE email = 'admin@votepoll.local'
ON CONFLICT (email) DO NOTHING;
