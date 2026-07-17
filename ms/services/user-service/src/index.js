const express = require('express');
const { Pool } = require('pg');

const PORT = process.env.PORT || 8080;
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const app = express();
app.use(express.json());

app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'UP', service: 'user-service' });
  } catch (err) {
    res.status(503).json({ status: 'DOWN', error: err.message });
  }
});

app.get('/api/users/me', async (req, res) => {
  const adminId = req.headers['x-admin-id'];
  if (!adminId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  try {
    const { rows } = await pool.query(
      'SELECT id, email, display_name, created_at FROM users.profiles WHERE id = $1',
      [adminId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/users/:id', async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, email, display_name, created_at FROM users.profiles WHERE id = $1',
      [req.params.id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`User service listening on port ${PORT}`);
});
