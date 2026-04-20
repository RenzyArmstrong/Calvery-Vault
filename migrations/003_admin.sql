-- Admin flag di users
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN NOT NULL DEFAULT FALSE;

-- Plan billing pakai kolom existing (teams.plan) — tambah fields detail
ALTER TABLE teams ADD COLUMN IF NOT EXISTS max_secrets INTEGER NOT NULL DEFAULT 50;
ALTER TABLE teams ADD COLUMN IF NOT EXISTS max_members INTEGER NOT NULL DEFAULT 5;
ALTER TABLE teams ADD COLUMN IF NOT EXISTS billing_email VARCHAR(255);
ALTER TABLE teams ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(20) NOT NULL DEFAULT 'active';

CREATE INDEX IF NOT EXISTS idx_users_admin ON users(is_admin) WHERE is_admin = TRUE;
