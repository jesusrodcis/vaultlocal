-- VaultLocal — Supabase one-time setup
-- Run this in: Supabase dashboard → SQL Editor → New query → Run

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

-- Done. No RLS needed — vault_id acts as a private token (UUID, 122-bit entropy).
-- The anon key is embedded in the app HTML; data is isolated by vault_id.
