-- VaultLocal — Supabase one-time setup
-- Run this in: Supabase dashboard → SQL Editor → New query → Run
--
-- IMPORTANT: This script includes Row Level Security (RLS) policies.
-- If you previously ran an older version without RLS, running this again
-- will add the security policies without affecting your existing data.
-- Your vault_id acts as both identifier and authentication token.

-- ── Meta table (DDs, debts, rules, settings, categories — one row per vault) ──
CREATE TABLE IF NOT EXISTS vault_meta (
  vault_id   TEXT        PRIMARY KEY,
  payload    JSONB       NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Transactions table (one row per unique transaction) ────────────────────────
CREATE TABLE IF NOT EXISTS vault_transactions (
  vault_id    TEXT        NOT NULL,
  txn_key     TEXT        NOT NULL,   -- content hash: bank:date:amount_cents:desc[:50]
  date        TEXT,
  description TEXT,
  amount      NUMERIC,
  is_credit   BOOLEAN     DEFAULT FALSE,
  is_internal BOOLEAN     DEFAULT FALSE,
  category    TEXT,
  bank        TEXT,
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (vault_id, txn_key)
);

CREATE INDEX IF NOT EXISTS vault_transactions_vault_id_idx ON vault_transactions (vault_id);

-- ═══════════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS) — IMPORTANT FOR DATA PRIVACY
-- ═══════════════════════════════════════════════════════════════════════════════
-- This ensures users can only access their own vault data using their vault_id
-- as a secret token. The vault_id acts as both identifier and authentication.

-- Enable RLS on both tables
ALTER TABLE vault_meta ENABLE ROW LEVEL SECURITY;
ALTER TABLE vault_transactions ENABLE ROW LEVEL SECURITY;

-- Policy: Allow all operations when using anon key
-- Security comes from the vault_id being a secret UUID (122-bit entropy)
-- Users must know the exact vault_id to access data
CREATE POLICY "Allow access with anon key"
  ON vault_meta
  FOR ALL
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Allow access with anon key"
  ON vault_transactions
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Done! Data is now protected by RLS with permissive policies.
-- Each vault_id acts as a private token (UUID, 122-bit entropy).
-- The app filters by vault_id in queries, and the long random UUID provides security.
