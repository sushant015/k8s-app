const express = require('express');
const crypto = require('crypto');
const { Pool } = require('pg');

const PORT = process.env.PORT || 8080;
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const app = express();
app.use(express.json());

function fingerprint(req) {
  const raw = [
    req.headers['x-forwarded-for'] || req.ip,
    req.headers['user-agent'] || '',
    req.headers['x-voter-id'] || '',
  ].join('|');
  return crypto.createHash('sha256').update(raw).digest('hex');
}

app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'UP', service: 'vote-service' });
  } catch (err) {
    res.status(503).json({ status: 'DOWN', error: err.message });
  }
});

app.post('/votes/:slug', async (req, res) => {
  const { optionId } = req.body;
  if (!optionId) {
    return res.status(400).json({ error: 'optionId is required' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const pollResult = await client.query(
      `SELECT p.id, p.status, p.start_at, p.end_at
       FROM polls.polls p WHERE p.slug = $1`,
      [req.params.slug]
    );
    if (pollResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Poll not found' });
    }

    const poll = pollResult.rows[0];
    if (poll.status !== 'ACTIVE') {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: `Poll is not active for voting. Current status: ${poll.status}` });
    }

    const now = new Date();
    if (now < new Date(poll.start_at) || now > new Date(poll.end_at)) {
      return res.status(403).json({ error: 'Poll is not open for voting' });
    }

    const optionCheck = await client.query(
      'SELECT id FROM polls.options WHERE id = $1 AND poll_id = $2',
      [optionId, poll.id]
    );
    if (optionCheck.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Invalid option for this poll' });
    }

    const fp = fingerprint(req);
    const insert = await client.query(
      `INSERT INTO votes.votes (poll_id, option_id, voter_fingerprint)
       VALUES ($1, $2, $3)
       ON CONFLICT (poll_id, voter_fingerprint) DO NOTHING
       RETURNING id`,
      [poll.id, optionId, fp]
    );

    await client.query('COMMIT');

    if (insert.rows.length === 0) {
      return res.status(409).json({ error: 'You have already voted on this poll' });
    }

    res.status(201).json({ message: 'Vote recorded', voteId: insert.rows[0].id });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

app.listen(PORT, () => {
  console.log(`Vote service listening on port ${PORT}`);
});
