#!/bin/bash
set -euo pipefail

R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' B='\033[1;34m' W='\033[0m'
log()  { echo -e "${G}[✔]${W} $1"; }
warn() { echo -e "${Y}[⚠]${W} $1"; }
err()  { echo -e "${R}[✘]${W} $1"; }
info() { echo -e "${B}[i]${W} $1"; }

GUARD="/var/run/mirza-setup-done"
if [ -f "$GUARD" ]; then
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi

# ── متغیرها ──
BOT_TOKEN="${BOT_TOKEN:-}"
ADMIN_ID="${ADMIN_ID:-}"
BOT_USERNAME="${BOT_USERNAME:-}"
DOMAIN="${DOMAIN:-}"
DB_NAME="${DB_NAME:-mirza_pro}"
DB_USER="${DB_USER:-mirza_user}"
DB_PASS="${DB_PASS:-}"

[ -z "$DOMAIN" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ] && DOMAIN="$RAILWAY_PUBLIC_DOMAIN"
[ -z "$DB_PASS" ] && DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c -24)

MISSING=""
[ -z "$BOT_TOKEN" ]   && MISSING="$MISSING BOT_TOKEN"
[ -z "$ADMIN_ID" ]    && MISSING="$MISSING ADMIN_ID"
[ -z "$BOT_USERNAME" ] && MISSING="$MISSING BOT_USERNAME"
if [ -n "$MISSING" ]; then err "متغیرها:$MISSING"; exit 1; fi

info "BOT_TOKEN: ${BOT_TOKEN:0:10}..."
info "ADMIN_ID: $ADMIN_ID"
info "BOT: @$BOT_USERNAME"
info "DOMAIN: ${DOMAIN:-'(خودکار)'}"

# ── کلون ──
MIRZA_DIR="/var/www/mirza_pro"
if [ ! -f "$MIRZA_DIR/index.php" ]; then
    info "دانلود Mirza Pro..."
    rm -rf "$MIRZA_DIR"
    git clone --depth 1 https://github.com/mahdiMGF2/mirza_pro.git "$MIRZA_DIR"
    log "دانلود شد"
fi
chown -R www-data:www-data "$MIRZA_DIR"
chmod -R 755 "$MIRZA_DIR"

# ── MariaDB ──
info "MariaDB..."
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1 || \
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1 || \
    { mkdir -p /var/lib/mysql/mysql && chown -R mysql:mysql /var/lib/mysql; }
fi

mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=127.0.0.1 --port=3306 &
MYSQL_PID=$!

for i in $(seq 1 30); do
    mysqladmin ping --protocol=socket 2>/dev/null && break
    sleep 1
done
log "MariaDB آماده"

# ── دیتابیس ──
mysql --protocol=socket -u root <<EOSQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
EOSQL
log "دیتابیس ساخته شد"

# ── جداول ──
[ -f "$MIRZA_DIR/table.php" ] && cd "$MIRZA_DIR" && php table.php > /dev/null 2>&1 && log "جداول" || true

# ── config.php (纯bash) ──
DOMAIN_VAL=""
[ -n "$DOMAIN" ] && DOMAIN_VAL="https://$DOMAIN"

cat > "$MIRZA_DIR/config.php" << CFGEOF
<?php
if(!defined("index")) define("index", true);
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
} catch(Exception \$e) { die("PDO connection error"); }
\$APIKEY       = '$BOT_TOKEN';
\$adminnumber  = '$ADMIN_ID';
\$domainhosts  = '$DOMAIN_VAL';
\$usernamebot  = '$BOT_USERNAME';
?>
CFGEOF

chown www-data:www-data "$MIRZA_DIR/config.php"
chmod 640 "$MIRZA_DIR/config.php"
log "config.php"

# ── رفع خطا ──
[ -f "$MIRZA_DIR/alireza_single.php" ] && [ ! -f "$MIRZA_DIR/alireza.php" ] && \
    mv "$MIRZA_DIR/alireza_single.php" "$MIRZA_DIR/alireza.php" 2>/dev/null
[ ! -f "$MIRZA_DIR/version" ] && echo "3.0" > "$MIRZA_DIR/version"
chown -R www-data:www-data "$MIRZA_DIR"

# ── توقف mysqld ──
kill "$MYSQL_PID" 2>/dev/null || true
wait "$MYSQL_PID" 2>/dev/null || true
sleep 2

# ── Webhook ──
if [ -n "$DOMAIN" ]; then
    WEBHOOK_URL="https://${DOMAIN}/index.php"
    RESULT=$(curl -sf "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=${WEBHOOK_URL}" 2>/dev/null || echo '{"ok":false}')
    echo "$RESULT" | grep -q '"ok":true' && log "Webhook: $WEBHOOK_URL" || warn "Webhook نشد"
else
    warn "DOMAIN نیست"
fi

echo ""
echo -e "${G}✅ Mirza Pro راه‌اندازی شد${W}"
echo -e "  🤖 @$BOT_USERNAME | 👑 $ADMIN_ID"
[ -n "$DOMAIN" ] && echo -e "  🌐 https://$DOMAIN"
echo -e "  🔑 DB: $DB_PASS"
echo ""

touch "$GUARD"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
