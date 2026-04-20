# Changelog

Semua perubahan penting di Calvery Vault. Format mengikuti [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- Interactive server installer (`scripts/server-install.sh`) — domain prompt, auto-generate keys, pilih Docker/systemd, create admin account
- Calvery Community License v1.0 (BSL-style) — self-host bebas, managed service reselling dilarang
- Public/private split — source code proprietary, hanya binary + deploy manifests yang di-publish
- Multi-platform binary via GoReleaser — Linux/macOS/Windows/FreeBSD × amd64/arm64/armv7
- Docker multi-arch image di `ghcr.io/renzyarmstrong/cvsm-api`
- Bootstrap + FontAwesome UI migration
- Command palette (⌘K), keyboard shortcuts, skeleton loading, empty states, toast undo
- Multi-select + bulk delete di Secrets
- URL-synced filters (`?env=production&q=STRIPE`)
- SMTP integration — email verification, password reset, team invite via email
- Personal Access Tokens (long-lived `cvsm_*` tokens)
- Admin panel (is_admin users) — kelola user/team/plan
- Cloudflare IP allowlist di nginx — blok akses IP langsung

### Security

- CORS exact-match (fix: `*.calvery.xyz.evil.com` tidak lagi lolos)
- Request body size limit 1MB (DoS protection)
- Secret value max 64KB, name 200, env 50
- Default nginx returns 444 untuk request tanpa Host valid
- Suspended user tidak bisa login
- Email verification token hash SHA-256, expire 24 jam
- Password reset token expire 1 jam, one-time use
- Team invite token expire 7 hari

## [0.1.0] - 2026-04-01

### Initial release

- Go API server dengan AES-256-GCM encryption
- JWT authentication (HS256, 24 jam)
- PostgreSQL storage dengan migrations
- RBAC: owner, admin, member, viewer
- Audit log immutable
- Secret version history
- CLI tool `cvsm`
- Rate limiting per-IP
- Docker Compose deployment
