#!/bin/bash
# Mirza Pro — entrypoint v5 (minimal, no crash)

log()  { echo "[OK] $1"; }
warn() { echo "[WARN] $1"; }
err()  { echo "[ERR] $1"; }

BOT_TOKEN="${BOT_TOKEN:-}"
ADMIN_ID="${ADMIN_ID:-}"
BOT_USERNAME="${BOT_USERNAME:-}"
DOMAIN="${DOMAIN:-}"
DB_NAME="${DB_NAME:-mirza_pro}"
DB_USER="${DB_USER:-mirza_user}"
DB_PASS="${DB_PASS:-}"

[ -z "$DOMAIN" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ] && DOMAIN="$RAILWAY_PUBLIC_DOMAIN"
[ -z "$DB_PASS" ] && DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c -24)

if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_ID" ] || [ -z "$BOT_USERNAME" ]; then
    err "Missing: BOT_TOKEN, ADMIN_ID, BOT_USERNAME"
    exit 1
fi

log "BOT: @$BOT_USERNAME | ADMIN: $ADMIN_ID | DOMAIN: ${DOMAIN:-auto}"

# Clone Mirza Pro
MIRZA_DIR="/var/www/mirza_pro"
if [ ! -f "$MIRZA_DIR/index.php" ]; then
    rm -rf "$MIRZA_DIR"
    git clone --depth 1 https://github.com/mahdiMGF2/mirza_pro.git "$MIRZA_DIR" 2>/dev/null || true
fi
chown -R www-data:www-data "$MIRZA_DIR" 2>/dev/null || true

# Init MariaDB
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || \
    mysql_install_db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || \
    mkdir -p /var/lib/mysql/mysql
    chown -R mysql:mysql /var/lib/mysql 2>/dev/null || true
fi

# Start MariaDB temporarily
mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=127.0.0.1 --port=3306 &
sleep 3

# Create DB
mysql --protocol=socket -u root <<EOSQL 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
EOSQL
log "DB ready"

# Tables
[ -f "$MIRZA_DIR/table.php" ] && (cd "$MIRZA_DIR" && php table.php >/dev/null 2>&1) || true

# config.php
DOMAIN_VAL=""
[ -n "$DOMAIN" ] && DOMAIN_VAL="https://$DOMAIN"

cat > "$MIRZA_DIR/config.php" << 'PHPEOF'
<?php
if(!defined("index")) define("index", true);
PHPEOF

cat >> "$MIRZA_DIR/config.php" << EOF
\$dbname     = '$DB_NAME';
\$usernedb = '$DB_USER';
\$passworddh = '$DB_PASS';
\$connect = mysqli_connect("127.0.0.1", \$usernedb, \$passworddh, \$dbname);
if (!\$connect) die("Database connection failed!");
mysqli_set_charset(\$connect, "utf8mb4");
try {
    \$pdo = new PDO("mysql:host=127.0.0.1;dbname=$DB_NAME;charset=utf8mb4", \$usernedb, \$passworddh, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
} catch(Exception \$e) { die("PDO error"); }
\$APIKEY       = '$BOT_TOKEN';
\$adminnumber  = '$ADMIN_ID';
\$domainhosts  = '$DOMAIN_VAL';
\$usernamebot  = '$BOT_USERNAME';
?>
EOF

chown www-data:www-data "$MIRZA_DIR/config.php" 2>/dev/null || true
chmod 640 "$MIRZA_DIR/config.php" 2>/dev/null || true
log "config.php"

# Fix alireza
[ -f "$MIRZA_DIR/alireza_single.php" ] && [ ! -f "$MIRZA_DIR/alireza.php" ] && \
    mv "$MIRZA_DIR/alireza_single.php" "$MIRZA_DIR/alireza.php" 2>/dev/null || true
[ ! -f "$MIRZA_DIR/version" ] && echo "3.0" > "$MIRZA_DIR/version"

# Stop temp mysqld
kill %1 2>/dev/null; sleep 2

# Webhook
if [ -n "$DOMAIN" ]; then
    curl -sf "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=https://${DOMAIN}/index.php" >/dev/null 2>&1 && \
        log "Webhook OK" || warn "Webhook failed"
else
    warn "No DOMAIN — set webhook manually"
fi

log "Starting services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
