-- FinTrack email-sync D1 schema.
-- Already applied to the live DB (fintrack-email-sync / 45339d6a-...).
-- Kept here so the DB can be recreated with `npm run schema`.

CREATE TABLE IF NOT EXISTS devices (
  device_token TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL,
  platform     TEXT NOT NULL DEFAULT 'ios',
  created_at   INTEGER NOT NULL,
  updated_at   INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);

CREATE TABLE IF NOT EXISTS pending_txns (
  id                 TEXT PRIMARY KEY,
  user_id            TEXT NOT NULL,
  fingerprint        TEXT NOT NULL,
  bank_name          TEXT,
  sender             TEXT,
  subject            TEXT,
  snippet            TEXT,
  message_id         TEXT,
  received_at        INTEGER,
  amount             REAL,
  currency           TEXT,
  merchant_raw       TEXT,
  merchant           TEXT,
  direction          TEXT,
  card_last4         TEXT,
  available_balance  REAL,
  reference          TEXT,
  suggested_category TEXT,
  confidence         REAL,
  status             TEXT NOT NULL DEFAULT 'pending',
  created_at         INTEGER NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pending_dedup ON pending_txns(user_id, fingerprint);
CREATE INDEX IF NOT EXISTS idx_pending_user_status ON pending_txns(user_id, status, created_at);
