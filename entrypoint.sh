#!/bin/bash
# ============================================================
# Mirza Pro — Docker Entrypoint v4
# nginx + php-fpm + MariaDB
# ============================================================
set -euo pipefail

R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' B='\033[1;34m' C='\033[1;36m' W='\033[0m'
log()  { echo -e "${G}[✔]${W} $1"; }
warn() { echo -e "${Y}[⚠]${W} $1"; }
err()  { echo -e "${R}[✘]${W} $1"; }
info() { echo -e "${B}[i]${W} $1"; }

# ── Guard ──
GUARD="/var/run/mirza-setup-done"
if [ -f "$GUARD" ]; then
    info "Setup قبلاً انجام شده — فقط سرویس‌ها"
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi

# ============================================================
#  ۱. تشخیص متغیرها
# ============================================================
BOT_TOKEN="${BOT_TOKEN:-}"
ADMIN_ID="${ADMIN_ID:-}"
BOT_USERNAME="${BOT_USERNAME:-}"
DOMAIN="${DOMAIN:-}"
DB_NAME="${DB_NAME:-mirza_pro}"
DB_USER="${DB_USER:-mirza_user}"
DB_PASS="${DB_PASS:-}"
PORT="${PORT:-80}"

if [ -z "$DOMAIN" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    DOMAIN="$RAILWAY_PUBLIC_DOMAIN"
fi

if [ -z "$DB_PASS" ]; then
    DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c -24)
fi

MISSING=""
[ -z "$BOT_TOKEN" ]   && MISSING="$MISSING BOT_TOKEN"
[ -z "$ADMIN_ID" ]    && MISSING="$MISSING ADMIN_ID"
[ -z "$BOT_USERNAME" ] && MISSING="$MISSING BOT_USERNAME"

if [ -n "$MISSING" ]; then
    err "متغیرهای اجباری:$MISSING"
    exit 1
fi

info "BOT_TOKEN:   ${BOT_TOKEN:0:10}..."
info "ADMIN_ID:    $ADMIN_ID"
info "BOT_USERNAME: @$BOT_USERNAME"
info "DOMAIN:      ${DOMAIN:-'(خودکار)'}"

# ============================================================
#  ۲. کلون Mirza Pro
# ============================================================
MIRZA_DIR="/var/www/mirza_pro"

if [ ! -f "$MIRZA_DIR/index.php" ]; then
    info "دانلود Mirza Pro..."
    rm -rf "$MIRZA_DIR"
    git clone --depth 1 https://github.com/mahdiMGF2/mirza_pro.git "$MIRZA_DIR" 2>/dev/null || {
        err "خطا در دانلود"
        exit 1
    }
    log "Mirza Pro دانلود شد"
fi

chown -R www-data:www-data "$MIRZA_DIR"
chmod -R 755 "$MIRZA_DIR"

# ============================================================
#  ۳. MariaDB
# ============================================================
info "راه‌اندازی MariaDB..."

if [ ! -d "/var/lib/mysql/mysql" ]; then
    if command -v mariadb-install-db &>/dev/null; then
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1
    elif command -v mysql_install_db &>/dev/null; then
        mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1
    else
        mkdir -p /var/lib/mysql/mysql
        chown -R mysql:mysql /var/lib/mysql
    fi
    log "MariaDB اینیشیالایز شد"
fi

mysqld --user=mysql --datadir=/var/lib/mysql \
    --bind-address=127.0.0.1 --port=3306 &
MYSQL_PID=$!

info "صبر برای MariaDB..."
READY=0
for i in $(seq 1 30); do
    if mysqladmin ping --protocol=socket 2>/dev/null; then
        READY=1
        break
    fi
    sleep 1
done

if [ "$READY" -eq 0 ]; then
    err "MariaDB آماده نشد!"
    exit 1
fi
log "MariaDB آماده شد"

# ============================================================
#  ۴. ساخت دیتابیس
# ============================================================
info "ساخت دیتابیس..."

mysql --protocol=socket -u root <<SQLEOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQLEOF

log "دیتابیس '$DB_NAME' ساخته شد"

# ============================================================
#  ۵. ساخت جداول
# ============================================================
if [ -f "$MIRZA_DIR/table.php" ]; then
    info "ساخت جداول..."
    cd "$MIRZA_DIR"
    php table.php > /dev/null 2>&1 && log "جداول ساخته شد" || warn "جداول از قبل وجود دارند"
fi

# ============================================================
#  ۶. config.php
# ============================================================
info "ساخت config.php..."

DOMAIN_VAL=""
[ -n "$DOMAIN" ] && DOMAIN_VAL="https://$DOMAIN"
export _DOMAIN_VAL="$DOMAIN_VAL"
export BOT_TOKEN ADMIN_ID BOT_USERNAME DB_NAME DB_USER DB_PASS DB_HOST="127.0.0.1"

python3 << 'PYEOF' > "$MIRZA_DIR/config.php"
import os

bot_token  = os.environ['BOT_TOKEN']
admin_id   = os.environ['ADMIN_ID']
bot_user   = os.environ['BOT_USERNAME']
domain_val = os.environ.get('_DOMAIN_VAL', '')
db_name    = os.environ.get('DB_NAME', 'mirza_pro')
db_user    = os.environ.get('DB_USER', 'mirza_user')
db_pass    = os.environ['DB_PASS']
db_host    = os.environ.get('DB_HOST', '127.0.0.1')

print('<?php')
print('if(!defined("index")) define("index", true);')
print()
print(f"\\$dbname     = '{db_name}';")
print(f"\\$usernedb = '{db_user}';")
print(f"\\$passworddh = '{db_pass}';")
print()
print(f'\\$connect = mysqli_connect("{db_host}", \\$usernedb, \\$passworddh, \\$dbname);')
print('if (!\\$connect) die("Database connection failed!");')
print()
print('mysqli_set_charset(\\$connect, "utf8mb4");')
print()
print('try {')
print(f'    \\$pdo = new PDO("mysql:host={db_host};dbname={db_name};charset=utf8mb4", \\$usernedb, \\$passworddh, [')
print('        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,')
print('        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC')
print('    ]);')
print('} catch(Exception \\$e) {')
print('    die("PDO connection error");')
print('}')
print()
print(f"\\$APIKEY       = '{bot_token}';")
print(f"\\$adminnumber  = '{admin_id}';")
print(f"\\$domainhosts  = '{domain_val}';")
print(f"\\$usernamebot  = '{bot_user}';")
print('?>')
PYEOF

chown www-data:www-data "$MIRZA_DIR/config.php"
chmod 640 "$MIRZA_DIR/config.php"
log "config.php ساخته شد"

# ============================================================
#  ۷. رفع خطاهای Mirza Pro
# ============================================================
if [ -f "$MIRZA_DIR/alireza_single.php" ] && [ ! -f "$MIRZA_DIR/alireza.php" ]; then
    mv "$MIRZA_DIR/alireza_single.php" "$MIRZA_DIR/alireza.php" 2>/dev/null
    sed -i "s|require_once __DIR__ . '/alireza_single.php';|require_once __DIR__ . '/alireza.php';|g" "$MIRZA_DIR/panels.php" 2>/dev/null
fi

[ ! -f "$MIRZA_DIR/version" ] && echo "3.0" > "$MIRZA_DIR/version"
chown -R www-data:www-data "$MIRZA_DIR"

# ============================================================
#  ۸. توقف mysqld موقت
# ============================================================
info "توقف mysqld..."
kill "$MYSQL_PID" 2>/dev/null || true
wait "$MYSQL_PID" 2>/dev/null || true
sleep 2

# ============================================================
#  ۹. Webhook
# ============================================================
if [ -n "$DOMAIN" ]; then
    info "تنظیم Webhook..."
    WEBHOOK_URL="https://${DOMAIN}/index.php"
    RESULT=$(curl -sf "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=${WEBHOOK_URL}" 2>/dev/null || echo '{"ok":false}')
    if echo "$RESULT" | grep -q '"ok":true'; then
        log "Webhook: $WEBHOOK_URL"
    else
        warn "Webhook تنظیم نشد"
    fi
else
    warn "DOMAIN نیست — Webhook بعداً"
fi

# ============================================================
#  ۱۰. اطلاعات
# ============================================================
echo ""
echo -e "${G}╔══════════════════════════════════════════════════╗${W}"
echo -e "${G}║        ✅ Mirza Pro راه‌اندازی شد               ║${W}"
echo -e "${G}╚══════════════════════════════════════════════════╝${W}"
echo ""
echo -e "  🤖 Bot:       @$BOT_USERNAME"
echo -e "  👑 Admin ID:  $ADMIN_ID"
[ -n "$DOMAIN" ] && echo -e "  🌐 Domain:    https://$DOMAIN"
echo -e "  🗄️  Database:  $DB_NAME"
echo -e "  🔑 DB Pass:   $DB_PASS"
echo ""

# ============================================================
#  ۱۱. شروع سرویس‌ها
# ============================================================
touch "$GUARD"
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
