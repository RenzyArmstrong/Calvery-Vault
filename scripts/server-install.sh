#!/bin/bash
# Calvery Vault (CVSM) — Interactive Server Installer
# Usage:
#   curl -sL https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/master/scripts/server-install.sh | sudo bash
#
# Script ini:
#   - Deteksi OS + arch
#   - Tanya domain, email admin, SMTP (opsional)
#   - Generate JWT_SECRET, ENCRYPTION_KEY, DB_PASSWORD otomatis
#   - Pilih deploy method: Docker Compose ATAU systemd native
#   - Setup database PostgreSQL + run migrations
#   - Start service
#   - Print instruksi lanjut (DNS, TLS, CLI)

set -e

# ── Colors ───────────────────────────────────────────────────
RED=$(tput setaf 1 2>/dev/null || echo)
GREEN=$(tput setaf 2 2>/dev/null || echo)
YELLOW=$(tput setaf 3 2>/dev/null || echo)
BLUE=$(tput setaf 6 2>/dev/null || echo)
BOLD=$(tput bold 2>/dev/null || echo)
RESET=$(tput sgr0 2>/dev/null || echo)

banner() {
    cat <<'EOF'

   ██████╗ ██╗   ██╗███████╗███╗   ███╗
  ██╔════╝ ██║   ██║██╔════╝████╗ ████║
  ██║      ██║   ██║███████╗██╔████╔██║
  ██║       ██╗ ██╔╝╚════██║██║╚██╔╝██║
  ╚██████╗  ╚████╔╝ ███████║██║ ╚═╝ ██║
   ╚═════╝   ╚═══╝  ╚══════╝╚═╝     ╚═╝

  Calvery Vault Secret Manager · Server Installer

EOF
}

info()  { echo "${BLUE}➜${RESET} $1"; }
ok()    { echo "${GREEN}✓${RESET} $1"; }
warn()  { echo "${YELLOW}⚠${RESET} $1"; }
error() { echo "${RED}✗${RESET} $1" >&2; }

ask() {
    local prompt="$1"; local default="$2"; local answer
    if [ -n "$default" ]; then
        read -r -p "  ${BOLD}${prompt}${RESET} [${default}]: " answer < /dev/tty
        echo "${answer:-$default}"
    else
        read -r -p "  ${BOLD}${prompt}${RESET}: " answer < /dev/tty
        echo "$answer"
    fi
}

ask_secret() {
    local prompt="$1"; local answer
    read -r -s -p "  ${BOLD}${prompt}${RESET}: " answer < /dev/tty
    echo "" >&2
    echo "$answer"
}

confirm() {
    local prompt="$1"; local default="${2:-y}"; local answer
    local hint="[Y/n]"; [ "$default" = "n" ] && hint="[y/N]"
    read -r -p "  ${BOLD}${prompt}${RESET} ${hint}: " answer < /dev/tty
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy] ]]
}

# ── Pre-flight ───────────────────────────────────────────────
if [ "$(id -u)" != "0" ]; then
    error "Jalankan dengan sudo:  curl -sL ... | sudo bash"
    exit 1
fi

case "$(uname -s)" in
    Linux*) OS=linux ;;
    Darwin*) OS=darwin ;;
    *) error "OS $(uname -s) belum didukung installer ini. Lihat INSTALL.md untuk manual."; exit 1 ;;
esac

case "$(uname -m)" in
    x86_64|amd64) ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) error "Arsitektur $(uname -m) belum didukung. Lihat INSTALL.md."; exit 1 ;;
esac

for cmd in curl tar openssl; do
    if ! command -v $cmd >/dev/null 2>&1; then
        error "Butuh '$cmd' — install dulu (apt install $cmd / yum install $cmd)"
        exit 1
    fi
done

banner

info "Detected: ${BOLD}${OS}/${ARCH}${RESET}"
echo ""

# ── Wizard ───────────────────────────────────────────────────
echo "${BOLD}───── Konfigurasi Dasar ─────${RESET}"
echo ""

DOMAIN=$(ask "Domain publik untuk API" "api.example.com")
APP_URL=$(ask "URL app utama (landing/UI — bisa sama dg domain kalau tanpa UI)" "https://${DOMAIN/api./}")
ADMIN_EMAIL=$(ask "Email admin (untuk akun pertama + kontak)" "")

[ -z "$ADMIN_EMAIL" ] && { error "Email admin wajib."; exit 1; }

echo ""
echo "${BOLD}───── Deployment Method ─────${RESET}"
echo ""
echo "  1) Docker Compose (rekomendasi — include Postgres)"
echo "  2) systemd native (butuh Postgres yang sudah running)"
echo ""
DEPLOY_METHOD=$(ask "Pilih (1/2)" "1")

echo ""
echo "${BOLD}───── Database ─────${RESET}"
echo ""

if [ "$DEPLOY_METHOD" = "1" ]; then
    DB_HOST="postgres"
    DB_NAME="cvsm"
    DB_USER="cvsm"
    DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
    info "Database password di-generate otomatis"
else
    DB_HOST=$(ask "PostgreSQL host" "localhost")
    DB_PORT=$(ask "PostgreSQL port" "5432")
    DB_NAME=$(ask "Database name" "cvsm")
    DB_USER=$(ask "Database user" "cvsm")
    DB_PASSWORD=$(ask_secret "Database password")
    [ -z "$DB_PASSWORD" ] && { error "Password DB wajib."; exit 1; }
fi

echo ""
echo "${BOLD}───── SMTP (opsional — email verify, reset password, invite) ─────${RESET}"
echo ""

if confirm "Setup SMTP sekarang?" "n"; then
    SMTP_HOST=$(ask "SMTP host" "smtp.resend.com")
    SMTP_PORT=$(ask "SMTP port" "587")
    SMTP_USER=$(ask "SMTP user" "resend")
    SMTP_PASSWORD=$(ask_secret "SMTP password / API key")
    SMTP_FROM=$(ask "From address" "CVSM <noreply@${DOMAIN/api./}>")
else
    SMTP_HOST=""
    SMTP_PORT="587"
    SMTP_USER=""
    SMTP_PASSWORD=""
    SMTP_FROM="CVSM <noreply@example.com>"
    warn "SMTP di-skip — email verifikasi/reset/invite tidak akan terkirim"
fi

echo ""
echo "${BOLD}───── Port API ─────${RESET}"
echo ""
PORT=$(ask "Port API (internal, di-proxy via Nginx/Caddy)" "8080")

# ── Generate crypto keys ─────────────────────────────────────
info "Generate cryptographic keys"
JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
ENCRYPTION_KEY=$(openssl rand -hex 32)
ok "JWT_SECRET: ${JWT_SECRET:0:12}… (48 bytes base64)"
ok "ENCRYPTION_KEY: ${ENCRYPTION_KEY:0:12}… (32 bytes hex)"

echo ""
echo "${BOLD}───── Review Konfigurasi ─────${RESET}"
echo ""
echo "  Domain:        $DOMAIN"
echo "  App URL:       $APP_URL"
echo "  Admin email:   $ADMIN_EMAIL"
echo "  Deploy method: $([ "$DEPLOY_METHOD" = "1" ] && echo 'Docker Compose' || echo 'systemd native')"
echo "  Database:      $DB_USER@$DB_HOST/$DB_NAME"
echo "  SMTP:          $([ -n "$SMTP_HOST" ] && echo "$SMTP_HOST:$SMTP_PORT" || echo 'skipped')"
echo "  Port:          $PORT"
echo ""

if ! confirm "Lanjut install?" "y"; then
    warn "Aborted by user"
    exit 0
fi

INSTALL_DIR=${INSTALL_DIR:-/opt/cvsm}
mkdir -p "$INSTALL_DIR"

# ── Generate .env ────────────────────────────────────────────
ENV_FILE="$INSTALL_DIR/.env"
cat > "$ENV_FILE" <<EOF
# Calvery Vault — generated $(date)
# KEEP PRIVATE. Do not commit to git.

PORT=$PORT

# Database
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DATABASE_URL=postgres://$DB_USER:$(printf '%s' "$DB_PASSWORD" | sed 's/@/%40/g; s/#/%23/g; s/!/%21/g')@$DB_HOST:${DB_PORT:-5432}/$DB_NAME?sslmode=disable

# Security
JWT_SECRET=$JWT_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY
BCRYPT_COST=12

# CORS
ALLOWED_ORIGINS=https://${DOMAIN/api./}
APP_URL=$APP_URL

# SMTP
SMTP_HOST=$SMTP_HOST
SMTP_PORT=$SMTP_PORT
SMTP_USER=$SMTP_USER
SMTP_PASSWORD=$SMTP_PASSWORD
SMTP_FROM=$SMTP_FROM
EOF
chmod 600 "$ENV_FILE"
ok "Config disimpan di $ENV_FILE (mode 600)"

# ── Deploy ──────────────────────────────────────────────────
if [ "$DEPLOY_METHOD" = "1" ]; then
    # Docker Compose
    if ! command -v docker >/dev/null 2>&1; then
        warn "Docker belum terinstall. Install dulu via:"
        echo "  curl -fsSL https://get.docker.com | sh"
        exit 1
    fi

    info "Resolve latest release tag"
    VERSION=$(curl -sL "https://api.github.com/repos/RenzyArmstrong/Calvery-Vault/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    # Fallback ke master kalau belum ada release (pas fresh public repo)
    REPO_REF="${VERSION:-master}"
    info "Using repo ref: ${BOLD}${REPO_REF}${RESET}"

    info "Download migrations + docker-compose.yml dari GitHub"
    REPO_RAW="https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/${REPO_REF}"
    mkdir -p "$INSTALL_DIR/migrations"
    for f in 001_init.sql 002_api_tokens.sql 003_admin.sql 004_email_flows.sql; do
        curl -fsSL "$REPO_RAW/migrations/$f" -o "$INSTALL_DIR/migrations/$f"
    done
    curl -fsSL "$REPO_RAW/docker-compose.yml" -o "$INSTALL_DIR/docker-compose.yml"

    info "Start services"
    cd "$INSTALL_DIR"
    docker compose up -d

    info "Menunggu health check…"
    for i in $(seq 1 30); do
        if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
            ok "API siap di http://127.0.0.1:$PORT"
            break
        fi
        sleep 2
    done

else
    # systemd
    info "Download cvsm-api binary ke /usr/local/bin/"
    VERSION=$(curl -sL "https://api.github.com/repos/RenzyArmstrong/Calvery-Vault/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    VERSION_NUM="${VERSION#v}"
    TMP=$(mktemp -d)
    URL="https://github.com/RenzyArmstrong/Calvery-Vault/releases/download/$VERSION/cvsm-server_${VERSION_NUM}_${OS}_${ARCH}.tar.gz"
    curl -fL --progress-bar "$URL" -o "$TMP/cvsm-server.tar.gz"
    tar xzf "$TMP/cvsm-server.tar.gz" -C "$TMP"
    install -m 755 "$TMP/cvsm-api" /usr/local/bin/cvsm-api
    rm -rf "$TMP"

    # User service
    if ! id cvsm >/dev/null 2>&1; then
        useradd --system --no-create-home --shell /usr/sbin/nologin cvsm
    fi

    # Config di /etc/cvsm
    mkdir -p /etc/cvsm
    cp "$ENV_FILE" /etc/cvsm/cvsm.env
    chown root:cvsm /etc/cvsm/cvsm.env
    chmod 640 /etc/cvsm/cvsm.env

    # systemd unit
    cat > /etc/systemd/system/cvsm-api.service <<EOF
[Unit]
Description=Calvery Vault API
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=simple
User=cvsm
Group=cvsm
EnvironmentFile=/etc/cvsm/cvsm.env
ExecStart=/usr/local/bin/cvsm-api
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
CapabilityBoundingSet=

[Install]
WantedBy=multi-user.target
EOF

    # Run migrations — pinned ke tag release yang sama dengan binary (VERSION)
    info "Apply migrations (ref: ${VERSION:-master})"
    REPO_REF="${VERSION:-master}"
    REPO_RAW="https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/${REPO_REF}"
    for f in 001_init.sql 002_api_tokens.sql 003_admin.sql 004_email_flows.sql; do
        curl -fsSL "$REPO_RAW/migrations/$f" | \
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USER" -d "$DB_NAME" || true
    done

    systemctl daemon-reload
    systemctl enable cvsm-api
    systemctl start cvsm-api

    sleep 3
    if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null; then
        ok "API siap"
    else
        warn "API belum merespon. Cek: sudo journalctl -u cvsm-api -f"
    fi
fi

# ── Install CLI ──────────────────────────────────────────────
if confirm "Install CLI 'cvsm' ke /usr/local/bin?" "y"; then
    curl -sL https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/master/scripts/install.sh | bash
fi

# ── Create admin user ──────────────────────────────────────
echo ""
echo "${BOLD}───── Buat Akun Admin ─────${RESET}"
echo ""

ADMIN_PASSWORD=$(ask_secret "Password admin (min 8 char)")
if [ ${#ADMIN_PASSWORD} -ge 8 ]; then
    info "Register akun admin via API"
    REGISTER_RES=$(curl -sX POST "http://127.0.0.1:$PORT/api/v1/auth/register" \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"name\":\"Admin\"}")

    if echo "$REGISTER_RES" | grep -q '"token"'; then
        ok "Akun admin dibuat: $ADMIN_EMAIL"

        # Promote jadi is_admin=true langsung di DB.
        # Pakai psql variable binding (:'email') supaya email dengan apostrof tetap aman.
        PROMOTE_SQL="UPDATE users SET is_admin=TRUE, email_verified=TRUE WHERE email=:'email';"
        if [ "$DEPLOY_METHOD" = "1" ]; then
            docker exec -i cvsm-postgres psql -U "$DB_USER" -d "$DB_NAME" \
                -v email="$ADMIN_EMAIL" -c "$PROMOTE_SQL" >/dev/null
        else
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USER" -d "$DB_NAME" \
                -v email="$ADMIN_EMAIL" -c "$PROMOTE_SQL" >/dev/null
        fi
        ok "Promoted $ADMIN_EMAIL jadi admin (email auto-verified)"
    else
        warn "Register gagal: $REGISTER_RES"
    fi
else
    warn "Password terlalu pendek, skip pembuatan admin. Register manual nanti via CLI."
fi

# ── Done ────────────────────────────────────────────────────
echo ""
echo "${GREEN}${BOLD}═══════════════════════════════════════════════${RESET}"
echo "${GREEN}${BOLD}  SELESAI. CVSM running di http://127.0.0.1:$PORT${RESET}"
echo "${GREEN}${BOLD}═══════════════════════════════════════════════${RESET}"
echo ""
echo "${BOLD}Next steps:${RESET}"
echo ""
echo "  1. Point DNS ${BOLD}$DOMAIN${RESET} ke IP server ini"
echo ""
echo "  2. Setup reverse proxy dengan TLS (nginx/Caddy/Cloudflare Tunnel)"
echo "     Template: https://raw.githubusercontent.com/RenzyArmstrong/Calvery-Vault/master/nginx/cvsm.conf.example"
echo ""
echo "  3. Test:"
echo "     ${BLUE}curl https://$DOMAIN/health${RESET}"
echo ""
echo "  4. Login via CLI:"
echo "     ${BLUE}cvsm login${RESET}"
echo "     (API URL: https://$DOMAIN)"
echo ""
echo "  5. Create team pertama:"
echo "     ${BLUE}curl -X POST https://$DOMAIN/api/v1/teams \\"
echo "       -H \"Authorization: Bearer \$(cvsm config get token)\" \\"
echo "       -H \"Content-Type: application/json\" \\"
echo "       -d '{\"name\":\"My Team\"}'${RESET}"
echo ""
echo "  6. Simpan ${YELLOW}${ENV_FILE}${RESET} di safe place (contains secrets)"
echo ""
echo "${BOLD}Logs:${RESET}"
if [ "$DEPLOY_METHOD" = "1" ]; then
    echo "  ${BLUE}docker compose -f $INSTALL_DIR/docker-compose.yml logs -f${RESET}"
else
    echo "  ${BLUE}sudo journalctl -u cvsm-api -f${RESET}"
fi
echo ""
echo "${BOLD}Docs:${RESET} https://docs.calvery.xyz"
echo "${BOLD}Support:${RESET} support@calvery.xyz"
echo ""
