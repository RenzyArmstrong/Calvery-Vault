-- Users
CREATE TABLE IF NOT EXISTS users (
    id            UUID PRIMARY KEY,
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    name          VARCHAR(255) NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Teams
CREATE TABLE IF NOT EXISTS teams (
    id         UUID PRIMARY KEY,
    name       VARCHAR(255) NOT NULL,
    plan       VARCHAR(50) NOT NULL DEFAULT 'starter',
    owner_id   UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Team members with RBAC
CREATE TABLE IF NOT EXISTS team_members (
    user_id    UUID NOT NULL REFERENCES users(id),
    team_id    UUID NOT NULL REFERENCES teams(id),
    role       VARCHAR(20) NOT NULL DEFAULT 'member',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, team_id)
);

-- Secrets (encrypted at rest)
CREATE TABLE IF NOT EXISTS secrets (
    id              UUID PRIMARY KEY,
    team_id         UUID NOT NULL REFERENCES teams(id),
    name            VARCHAR(255) NOT NULL,
    description     TEXT DEFAULT '',
    type            VARCHAR(50) NOT NULL DEFAULT 'other',
    encrypted_value TEXT NOT NULL,
    environment     VARCHAR(50) NOT NULL DEFAULT 'production',
    created_by      UUID NOT NULL REFERENCES users(id),
    updated_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    UNIQUE (team_id, name, environment)
);

CREATE INDEX IF NOT EXISTS idx_secrets_team_env ON secrets(team_id, environment) WHERE deleted_at IS NULL;

-- Secret version history
CREATE TABLE IF NOT EXISTS secret_versions (
    id              UUID PRIMARY KEY,
    secret_id       UUID NOT NULL REFERENCES secrets(id),
    encrypted_value TEXT NOT NULL,
    version         INT NOT NULL,
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Immutable audit log
CREATE TABLE IF NOT EXISTS audit_logs (
    id          UUID PRIMARY KEY,
    team_id     UUID NOT NULL REFERENCES teams(id),
    user_id     UUID NOT NULL REFERENCES users(id),
    user_email  VARCHAR(255) NOT NULL,
    action      VARCHAR(50) NOT NULL,
    resource    VARCHAR(50) NOT NULL,
    resource_id VARCHAR(255) NOT NULL,
    ip_address  VARCHAR(45),
    user_agent  TEXT,
    metadata    JSONB DEFAULT '{}',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_team_time ON audit_logs(team_id, created_at DESC);
