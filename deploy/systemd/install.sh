#!/bin/bash
# Install CVSM API sebagai systemd service.
# Jalankan dengan sudo. Butuh binary cvsm-api sudah ada di direktori saat ini
# atau di /usr/local/bin.

set -e

if [ "$(id -u)" != "0" ]; then
    echo "Jalankan dengan sudo"
    exit 1
fi

BIN_SRC="${1:-./cvsm-api}"

# Buat user service
if ! id cvsm >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin cvsm
fi

# Install binary
if [ -f "$BIN_SRC" ]; then
    install -m 755 "$BIN_SRC" /usr/local/bin/cvsm-api
fi

# Config dir
mkdir -p /etc/cvsm /opt/cvsm
chown cvsm:cvsm /opt/cvsm
chmod 750 /etc/cvsm

# Config file (kalau belum ada)
if [ ! -f /etc/cvsm/cvsm.env ]; then
    cat > /etc/cvsm/cvsm.env <<'EOF'
# Edit dengan nilai real sebelum start!
PORT=8080
DATABASE_URL=postgres://cvsm:cvsm@localhost:5432/cvsm?sslmode=disable
JWT_SECRET=ganti_dengan_random_min_32_karakter
ENCRYPTION_KEY=ganti_dengan_openssl_rand_hex_32
BCRYPT_COST=12
ALLOWED_ORIGINS=https://calvery.xyz
APP_URL=https://calvery.xyz
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM=CVSM <noreply@calvery.xyz>
EOF
    chown root:cvsm /etc/cvsm/cvsm.env
    chmod 640 /etc/cvsm/cvsm.env
    echo "Buat /etc/cvsm/cvsm.env — edit dulu sebelum start service."
fi

# Install unit file
install -m 644 "$(dirname "$0")/cvsm-api.service" /etc/systemd/system/cvsm-api.service

systemctl daemon-reload
systemctl enable cvsm-api

echo ""
echo "Install selesai. Langkah selanjutnya:"
echo "  1. Edit config: sudo nano /etc/cvsm/cvsm.env"
echo "  2. Start service: sudo systemctl start cvsm-api"
echo "  3. Cek status: sudo systemctl status cvsm-api"
echo "  4. Lihat log: sudo journalctl -u cvsm-api -f"
