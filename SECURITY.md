# Security Policy

## Reporting a vulnerability

**Jangan** buka issue publik untuk security bug — akan berisiko exploit
sebelum di-patch.

### Cara lapor (pilih salah satu)

1. **GitHub Security Advisory** (rekomendasi — privat, built-in):
   [Submit advisory →](https://github.com/RenzyArmstrong/Calvery-Vault/security/advisories/new)

2. **Email PGP-encrypted**:
   `security@calvery.xyz`
   PGP public key: [keys.openpgp.org/vks/v1/by-email/security@calvery.xyz](https://keys.openpgp.org/vks/v1/by-email/security@calvery.xyz)

### Timeline respon

| Stage | Target |
|-------|--------|
| Acknowledgment | ≤ 48 jam |
| Initial severity assessment | ≤ 7 hari |
| Patch + coordinated disclosure | ≤ 90 hari (tergantung severity) |
| Public CVE disclosure | Setelah patch dirilis dan sebagian user sudah upgrade |

### Kami menghargai

- Credit di release notes & security advisory (kalau kamu mau)
- Bug bounty untuk vulnerability **High / Critical** (range Rp 500rb – Rp 10jt,
  case-by-case)
- Swag Calvery untuk reporter pertama dari masing-masing issue

## Scope

### In-scope

Semua binary dan Docker image yang dipublikasikan di:
- https://github.com/RenzyArmstrong/Calvery-Vault/releases
- ghcr.io/renzyarmstrong/cvsm-api

Dan managed service di calvery.xyz (api.calvery.xyz, dash.calvery.xyz).

### Out-of-scope

- Bug di fork / modifikasi pihak ketiga
- Social engineering terhadap karyawan Calvery
- Physical attack
- DDoS tanpa bukti auth/authorization bypass
- Rate-limit bypass tanpa impact konkret
- Self-XSS
- Missing security headers tanpa exploit chain
- Vulnerability di dependency yang sudah di-publish di upstream tapi
  belum di-patch di CVSM (kasih tahu kami ya, tapi tidak bounty)

## Supported versions

Hanya versi latest + 1 minor version sebelumnya yang menerima security patch.

| Version | Status |
|---------|--------|
| 1.x (latest) | ✅ Security patches |
| Previous minor | ✅ Critical security patches only |
| Older | ❌ Tidak didukung — upgrade |

## Security best practices untuk self-host

### Kunci kriptografi

```bash
# JWT_SECRET — minimal 32 karakter random
openssl rand -base64 48

# ENCRYPTION_KEY — WAJIB tepat 64 karakter hex (32 bytes AES-256)
openssl rand -hex 32
```

### Konfigurasi

| Setting | Production |
|---------|-----------|
| `ALLOWED_ORIGINS` | Specific (jangan `*`) |
| `BCRYPT_COST` | 12+ |
| Database | Di balik firewall, **tidak** expose ke publik |
| TLS | Wajib (Cloudflare / Let's Encrypt / reverse proxy) |
| Reverse proxy | Nginx / Caddy dengan `X-Real-IP`, `X-Forwarded-For` |
| Database backup | Off-site, encrypted-at-rest, tested restore |
| Log | Jangan commit log dengan secret |

### Rotasi key

- Rotasi `JWT_SECRET` tiap 6–12 bulan (semua user harus re-login)
- Rotasi `ENCRYPTION_KEY` butuh migration — **rencanakan khusus**:
  1. Deploy versi yang support dual key (lama + baru)
  2. Re-encrypt semua secret dengan key baru
  3. Remove key lama

### Monitoring

- Tail audit log untuk pattern mencurigakan (akses banyak dalam waktu singkat)
- Alert kalau ada login dari IP baru
- Alert kalau ada `ENCRYPTION_KEY` decrypt failure (bisa jadi tanda DB tampered)

## Kriptografi yang dipakai

| Komponen | Algoritma |
|----------|-----------|
| Password | bcrypt (cost ≥ 12) |
| Secret encryption | AES-256-GCM, nonce unik per secret |
| Session token | JWT HS256, expire 24 jam |
| Personal Access Token | SHA-256 hashed at rest, prefix `cvsm_` |
| Email verify / reset token | SHA-256 hashed, expire 1 jam (reset) / 24 jam (verify) |
| Invite token | SHA-256 hashed, expire 7 hari |

Tidak ada custom crypto. Semua implementasi pakai `crypto/*` standar Go.
