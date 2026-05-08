// ================================================================
// PFA DevSecOps Dashboard - Main Server
// Node.js Express application
// Connects to PostgreSQL for deployment history
// ================================================================

require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
const PORT = process.env.APP_PORT || 3000;

// ──────────────────────────────────────────────────────────────
// DATABASE CONNECTION
// ──────────────────────────────────────────────────────────────

const pool = new Pool({
  host:     process.env.DB_HOST || 'psql-rami-pfa.postgres.database.azure.com',
  port:     process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'pfa_app_db',
  user:     process.env.DB_USER || 'psqladmin',
  password: process.env.DB_PASSWORD,
  ssl:      { rejectUnauthorized: false }
});

// ──────────────────────────────────────────────────────────────
// DATABASE INITIALIZATION
// Creates tables if they don't exist
// ──────────────────────────────────────────────────────────────

async function initDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS deployments (
        id          SERIAL PRIMARY KEY,
        version     VARCHAR(50) NOT NULL,
        deployed_at TIMESTAMP DEFAULT NOW(),
        deployed_by VARCHAR(100) DEFAULT 'GitHub Actions',
        status      VARCHAR(20) DEFAULT 'success',
        notes       TEXT
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS infrastructure_checks (
        id           SERIAL PRIMARY KEY,
        component    VARCHAR(100) NOT NULL,
        status       VARCHAR(20) NOT NULL,
        response_ms  INTEGER,
        checked_at   TIMESTAMP DEFAULT NOW(),
        message      TEXT
      )
    `);

    // Insert initial deployment record
    const existing = await pool.query('SELECT COUNT(*) FROM deployments');
    if (parseInt(existing.rows[0].count) === 0) {
      await pool.query(`
        INSERT INTO deployments (version, deployed_by, status, notes)
        VALUES ('v1.0', 'Rami (manual)', 'success', 'Initial deployment')
      `);
    }

    console.log('Database initialized successfully');
  } catch (err) {
    console.error('Database init error:', err.message);
  }
}

// ──────────────────────────────────────────────────────────────
// MIDDLEWARE
// ──────────────────────────────────────────────────────────────

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ──────────────────────────────────────────────────────────────
// API ROUTES
// ──────────────────────────────────────────────────────────────

// Health check endpoint
app.get('/api/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      version: process.env.APP_VERSION || 'v1.0',
      database: 'connected',
      uptime: Math.floor(process.uptime()) + 's'
    });
  } catch (err) {
    res.status(500).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: err.message
    });
  }
});

// Get deployment history
app.get('/api/deployments', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM deployments ORDER BY deployed_at DESC LIMIT 10'
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Record new deployment (called by GitHub Actions)
app.post('/api/deployments', async (req, res) => {
  try {
    const { version, deployed_by, status, notes } = req.body;
    const result = await pool.query(
      'INSERT INTO deployments (version, deployed_by, status, notes) VALUES ($1, $2, $3, $4) RETURNING *',
      [version, deployed_by || 'GitHub Actions', status || 'success', notes]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get infrastructure checks
app.get('/api/checks', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM infrastructure_checks ORDER BY checked_at DESC LIMIT 20'
    );
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Infrastructure status (live)
app.get('/api/status', (req, res) => {
  res.json({
    vm_ip: '20.215.191.94',
    region: 'polandcentral',
    environment: process.env.APP_ENV || 'production',
    version: process.env.APP_VERSION || 'v1.0',
    uptime: Math.floor(process.uptime()) + 's',
    timestamp: new Date().toISOString()
  });
});

// Serve dashboard for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// ──────────────────────────────────────────────────────────────
// START SERVER
// ──────────────────────────────────────────────────────────────

app.listen(PORT, async () => {
  console.log(`DevSecOps PFA Dashboard running on port ${PORT}`);
  await initDatabase();
});