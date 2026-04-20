# Calvery Vault (CVSM)

> **Self-hostable secret manager untuk developer & tim.**
> Encrypted (AES-256-GCM) · RBAC · Audit log · Version history · CLI-driven

[![License](https://img.shields.io/badge/license-Calvery_Community-blue)](LICENSE)
[![Docker](https://img.shields.io/badge/docker-ghcr.io-blue)](https://github.com/RenzyArmstrong/Calvery-Vault/pkgs/container/cvsm-api)
[![Release](https://img.shields.io/github/v/release/RenzyArmstrong/Calvery-Vault)](https://github.com/RenzyArmstrong/Calvery-Vault/releases)

Alternatif HashiCorp Vault yang **simpel, siap pakai, dan terjangkau** — dibuat untuk developer Indonesia. Self-host gratis, atau pakai managed cloud di [calvery.xyz](https://calvery.xyz).

> Repo ini adalah **distribution-only**. Berisi Docker images reference, binary download link, deploy manifests, SQL migrations, dan docs install. **Source code proprietary dan tidak dipublish.**

---

## 🚀 Quick Start

### Opsi A — Managed cloud (paling cepat)

[Daftar gratis di calvery.xyz](https://calvery.xyz). Langsung pakai dashboard, CLI, dan API tanpa deploy apa-apa.

### Opsi B — Self-host dengan Docker Compose

Cukup untuk tim teknis yang OK dengan CLI-only management.

```bash
git clone https://github.com/RenzyArmstrong/Calvery-Vault.git
cd Calvery-Vault
cp .env.example .env
nano .env
```

Isi `.env`:

```bash
# Generate dengan:
#   openssl rand -base64 48   # untuk JWT_SECRET
#   openssl rand -hex 32      # untuk ENCRYPTION_KEY (tepat 64 hex char)

JWT_SECRET=...
ENCRYPTION_KEY=...
DB_PASSWORD=...
```

Lalu:

```bash
docker compose up -d
curl http://localhost:8080/health
# → {"status":"ok"}
```

### Opsi C — **Interactive installer** (termudah)

Prompt domain, email admin, pilih Docker/systemd, auto-generate JWT+ENC keys, sekaligus buat akun admin. 2 menit selesai.

```bash
curl -sL https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/master/scripts/server-install.sh | sudo bash
```

### Opsi D — Linux native (systemd manual)

```bash
curl -sL https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/master/deploy/systemd/install.sh | sudo bash
sudo nano /etc/cvsm/cvsm.env
sudo systemctl start cvsm-api
sudo journalctl -u cvsm-api -f
```

### Opsi D — Kubernetes

```bash
cd deploy/k8s
# Edit secret.yaml dulu (isi JWT_SECRET, ENCRYPTION_KEY, dll)
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml
kubectl apply -f postgres.yaml
kubectl apply -f api.yaml
# kubectl apply -f ingress.yaml  (opsional, butuh nginx-ingress + cert-manager)
```

---

## 📥 Install CLI

```bash
curl -sL https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/master/scripts/install.sh | bash
```

Manual download: [Releases page](https://github.com/RenzyArmstrong/Calvery-Vault/releases)

Platform didukung:
- Linux (amd64, arm64, armv7)
- macOS (amd64, arm64)
- Windows (amd64)
- FreeBSD (amd64)

---

## 🔑 Usage (CLI)

```bash
# Login — akan ditanya API URL, email, password
cvsm login

# Atau pakai Personal Access Token (non-interaktif, cocok untuk CI/CD)
cvsm login --token cvsm_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# CRUD
cvsm list
cvsm list --env production
cvsm get DATABASE_URL
cvsm set DATABASE_URL "postgres://..." --env production
cvsm set STRIPE_KEY "sk_live_xxx" --env production --type api_key
cvsm delete OLD_API_KEY

# Export ke file
cvsm export --env production --output .env
cvsm export --env production --format json > secrets.json

# Kelola token
cvsm token create "ci-production" --expires 90
cvsm token list
cvsm token revoke <TOKEN_ID>

# Gunakan di shell script / CI
export DATABASE_URL=$(cvsm get DATABASE_URL)
node server.js
```

---

## 🌐 REST API

Semua operasi di CLI juga tersedia via REST API. Dokumentasi lengkap di [docs.calvery.xyz](https://docs.calvery.xyz/api).

Contoh:

```bash
# Login
TOKEN=$(curl -sX POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","password":"..."}' | jq -r .token)

# List secrets
curl http://localhost:8080/api/v1/teams/$TEAM_ID/secrets \
  -H "Authorization: Bearer $TOKEN"

# Create secret
curl -X POST http://localhost:8080/api/v1/teams/$TEAM_ID/secrets \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"DB_URL","value":"postgres://...","type":"env","environment":"production"}'
```

---

## 📦 Apa yang ada di repo ini

```
├── docker-compose.yml       # Deploy API + Postgres (image dari ghcr.io)
├── .env.example             # Template config
├── migrations/              # SQL untuk init database
│   ├── 001_init.sql
│   ├── 002_api_tokens.sql
│   ├── 003_admin.sql
│   └── 004_email_flows.sql
├── deploy/
│   ├── systemd/             # Unit file + installer Linux native
│   └── k8s/                 # Kubernetes manifests
├── nginx/
│   └── cvsm.conf.example    # Reverse proxy template
├── scripts/
│   └── install.sh           # CLI installer one-liner
├── README.md (ini)
├── SECURITY.md
├── INSTALL.md
└── LICENSE
```

**Binary** dari [GitHub Releases](https://github.com/RenzyArmstrong/Calvery-Vault/releases).  
**Docker image** dari [ghcr.io/renzyarmstrong/cvsm-api](https://github.com/RenzyArmstrong/Calvery-Vault/pkgs/container/cvsm-api).

---

## 🎨 Butuh Web UI?

Repo ini **tidak include web dashboard** (proprietary). Kalau butuh UI visual untuk kelola secret:

→ Pakai **managed cloud** di [calvery.xyz](https://calvery.xyz) — sudah include:
- Web dashboard (create/edit/reveal secret, audit timeline, team management)
- SSO (Google Workspace, Microsoft)
- 2FA / TOTP
- Backup otomatis off-site
- Priority support + SLA
- Compliance reports

Mulai **gratis** untuk 50 secrets pertama.

Atau self-host CVSM ini + tulis UI sendiri via REST API.

---

## 🔒 Security

Laporkan vulnerability via [GitHub Security Advisory](https://github.com/RenzyArmstrong/Calvery-Vault/security/advisories/new).
**Jangan** buka issue publik untuk security bug. Detail: [SECURITY.md](SECURITY.md).

Checklist production:
- [ ] `JWT_SECRET` minimal 32 karakter random
- [ ] `ENCRYPTION_KEY` tepat 64 hex char
- [ ] `ALLOWED_ORIGINS` specific
- [ ] TLS wajib (Cloudflare, Let's Encrypt, atau reverse proxy)
- [ ] PostgreSQL di balik firewall
- [ ] Backup DB berkala ke off-site
- [ ] Rotasi `JWT_SECRET` & `ENCRYPTION_KEY` berkala

---

## 📝 License — Calvery Community License

Lisensi mirip Business Source License (BSL):

✅ **BOLEH:**
- Self-host untuk kebutuhan internal perusahaan kamu
- Develop / test / production untuk bisnis sendiri
- Fork binary + modifikasi internal
- Integrasi dengan aplikasi kamu sendiri

❌ **TIDAK BOLEH** (tanpa izin tertulis dari Calvery):
- Jual / sublicense produk ini sebagai managed service / SaaS ke pihak ketiga
- Rebrand dan jual sebagai produk kompetisi
- Menggunakan merek "Calvery", "CVSM", atau "Calvery Vault" tanpa izin

**Trademark**: "Calvery", "CVSM", dan "Calvery Vault" adalah merek dagang terdaftar di Indonesia.

Detail lengkap: [LICENSE](LICENSE).

---

## 🆘 Support

- **Bug / feature request**: [GitHub Issues](https://github.com/RenzyArmstrong/Calvery-Vault/issues)
- **Security**: [Security Advisory](https://github.com/RenzyArmstrong/Calvery-Vault/security/advisories/new)
- **Commercial support & SLA**: support@calvery.xyz
- **Docs**: [docs.calvery.xyz](https://docs.calvery.xyz)

---

Made with ☕ in Indonesia by [Renzy](https://github.com/RenzyArmstrong).
