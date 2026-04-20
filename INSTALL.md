# Install Calvery Vault

Calvery Vault (CVSM) distributed sebagai **binary + Docker image + config
manifest**. Source code tidak di-publish. Pilih metode deploy yang paling
cocok.

## Pilih metode

| Metode | Use case | Difficulty |
|--------|----------|-----------|
| [Managed cloud](https://calvery.xyz) | Tercepat, tanpa infra | ⭐ |
| [Docker Compose](#1-docker-compose) | VPS / server kecil | ⭐⭐ |
| [systemd](#2-systemd) | Linux native, no Docker | ⭐⭐ |
| [Kubernetes](#3-kubernetes) | Production cluster | ⭐⭐⭐ |
| [CLI only](#4-install-cli-only) | Connect ke CVSM existing | ⭐ |

---

## 1. Docker Compose

Butuh: Docker + Docker Compose v2.

```bash
git clone https://github.com/RenzyArmstrong/Calvery-Vault.git
cd Calvery-Vault

cp .env.example .env
nano .env
```

Isi minimal `.env`:

```bash
# Database
DB_NAME=cvsm
DB_USER=cvsm
DB_PASSWORD=ganti_password_kuat
DATABASE_URL=postgres://cvsm:ganti_password_kuat@postgres:5432/cvsm?sslmode=disable

# Security — WAJIB generate ulang
JWT_SECRET=$(openssl rand -base64 48)
ENCRYPTION_KEY=$(openssl rand -hex 32)
BCRYPT_COST=12

# App
PORT=8080
ALLOWED_ORIGINS=https://yourdomain.com
APP_URL=https://yourdomain.com

# SMTP (opsional — email verifikasi, reset password, invite)
SMTP_HOST=smtp.resend.com
SMTP_PORT=587
SMTP_USER=resend
SMTP_PASSWORD=re_xxxxxxxxxxxx
SMTP_FROM=CVSM <noreply@yourdomain.com>
```

Jalankan:

```bash
docker compose up -d
curl http://localhost:8080/health
# → {"status":"ok"}
```

Pasang reverse proxy (nginx / Caddy) untuk TLS. Contoh nginx:
[`nginx/cvsm.conf.example`](nginx/cvsm.conf.example).

### Upgrade

Ganti tag di `docker-compose.yml`:

```yaml
api:
  image: ghcr.io/renzyarmstrong/cvsm-api:v1.2.3   # atau :latest
```

```bash
docker compose pull
docker compose up -d
```

Migrations baru akan auto-jalan.

---

## 2. systemd (Linux native, tanpa Docker)

Butuh: PostgreSQL 14+ running.

```bash
curl -sL https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/master/deploy/systemd/install.sh | sudo bash
```

Script ini:
1. Download binary `cvsm-api` dari GitHub Releases (auto-detect arch)
2. Buat user `cvsm`, install ke `/usr/local/bin/cvsm-api`
3. Create systemd unit di `/etc/systemd/system/cvsm-api.service`
4. Create config template di `/etc/cvsm/cvsm.env`

Edit config:

```bash
sudo nano /etc/cvsm/cvsm.env
```

Run migrations (sekali saja, saat pertama kali):

```bash
sudo -u postgres psql -c "CREATE USER cvsm WITH PASSWORD 'ganti_password';"
sudo -u postgres psql -c "CREATE DATABASE cvsm OWNER cvsm;"
for f in migrations/*.sql; do
  sudo -u postgres psql -d cvsm -f "$f"
done
```

Start:

```bash
sudo systemctl start cvsm-api
sudo systemctl enable cvsm-api
sudo journalctl -u cvsm-api -f
```

---

## 3. Kubernetes

Butuh: kubectl + cluster (minimum 2 vCPU, 2GB RAM).

```bash
cd deploy/k8s
nano secret.yaml   # Isi JWT_SECRET, ENCRYPTION_KEY, dll
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml
kubectl apply -f postgres.yaml
kubectl apply -f api.yaml

# Opsional: ingress (butuh nginx-ingress + cert-manager)
kubectl apply -f ingress.yaml

kubectl -n cvsm get pods
```

---

## 4. Install CLI only

Kalau kamu hanya butuh CLI untuk connect ke CVSM instance yang sudah ada
(managed cloud atau self-host orang lain):

```bash
curl -sL https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/master/scripts/install.sh | bash
cvsm login
```

Atau download manual dari [Releases](https://github.com/RenzyArmstrong/Calvery-Vault/releases) — pilih binary sesuai OS + arch:

- `cvsm_vX.Y.Z_linux_amd64.tar.gz`
- `cvsm_vX.Y.Z_linux_arm64.tar.gz`
- `cvsm_vX.Y.Z_darwin_arm64.tar.gz`
- `cvsm_vX.Y.Z_windows_amd64.zip`
- ...dll

Extract dan pindah ke `$PATH`:

```bash
tar xzf cvsm_*.tar.gz
sudo mv cvsm /usr/local/bin/
cvsm --version
```

---

## Checklist pre-production

- [ ] `JWT_SECRET` generated dengan `openssl rand -base64 48` (min 32 char)
- [ ] `ENCRYPTION_KEY` generated dengan `openssl rand -hex 32` (exactly 64 char)
- [ ] `ALLOWED_ORIGINS` specific (bukan `*`)
- [ ] PostgreSQL password kuat + tidak expose port ke publik
- [ ] TLS aktif (wajib)
- [ ] Reverse proxy pass `X-Forwarded-For` + `X-Real-IP`
- [ ] Backup DB terjadwal (cron `pg_dump` → S3/R2/off-site)
- [ ] Restore dari backup pernah di-test
- [ ] SMTP configured kalau mau pakai email verify/reset/invite
- [ ] Monitoring / alerting (uptime, log aggregation)

---

## Butuh Web UI?

Repo ini **tidak include web dashboard** (proprietary Calvery).

Untuk UI visual:
- **Paling gampang**: pakai [calvery.xyz](https://calvery.xyz) managed cloud
- **Self-host**: tulis sendiri via REST API — dokumentasi [docs.calvery.xyz/api](https://docs.calvery.xyz/api)

Semua operasi CLI juga bisa lewat API langsung, jadi CVSM self-hosted tetap
fully usable tanpa UI.
