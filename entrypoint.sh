#!/bin/bash
# ============================================================
# Mirza Pro — Docker Entrypoint
# تشخیص خودکار متغیرها + راه‌اندازی کامل
# ============================================================
set -euo pipefail

R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' B='\033[1;34m' C='\033[1;36m' W='\033[0m'
log()  { echo -e "${G}[✔]${W} $1"; }
warn() { echo -e "${Y}[⚠]${W} $1"; }
err()  { echo -e "${R}[✘]${W} $1"; }
info() { echo -e "${B}[i]${W} $1"; }

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
DB_HOST="${DB_HOST:-127.0.0.1}"
PORT="${PORT:-80}"

# Railway domain
if [ -z "$DOMAIN" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    DOMAIN="$RAILWAY_PUBLIC_DOMAIN"
    info "دامنه Railway شناسایی شد: $DOMAIN"
fi

# Auto-generate DB password
if [ -z "$DB_PASS" ]; then
    DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c -24)
fi

# Validate required vars
MISSING=""
[ -z "$BOT_TOKEN" ]   && MISSING="$MISSING BOT_TOKEN"
[ -z "$ADMIN_ID" ]    && MISSING="$MISSING ADMIN_ID"
[ -z "$BOT_USERNAME" ] && MISSING="$MISSING BOT_USERNAME"

if [ -n "$MISSING" ]; then
    err "متغیرهای اجباری وارد نشده:$MISSING"
    exit 1
fi

info "BOT_TOKEN:   ${BOT_TOKEN:0:10}..."
info "ADMIN_ID:    $ADMIN_ID"
info "BOT_USERNAME: @$BOT_USERNAME"
info "DOMAIN:      ${DOMAIN:-'(خودکار)'}"
info "DB_NAME:     $DB_NAME"

# ============================================================
#  ۲. کلون Mirza Pro
# ============================================================
MIRZA_DIR="/var/www/mirza_pro"

if [ ! -f "$MIRZA_DIR/index.php" ]; then
    info "دانلود Mirza Pro..."
    rm -rf "$MIRZA_DIR"
    git clone --depth 1 https://github.com/mahdiMGF2/mirza_pro.git "$MIRZA_DIR" 2>/dev/null || {
        err "خطا در دانلود Mirza Pro"
        exit 1
    }
    log "Mirza Pro دانلود شد"
else
    info "Mirza Pro از قبل وجود دارد"
fi

chown -R www-data:www-data "$MIRZA_DIR"
chmod -R 755 "$MIRZA_DIR"

# ============================================================
#  ۳. راه‌اندازی MariaDB (skip-grant-tables برای setup)
# ============================================================
info "راه‌اندازی MariaDB..."

# Init DB if empty
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

# Start with skip-grant-tables for initial setup (no auth needed)
mysqld --user=mysql --datadir=/var/lib/mysql \
    --skip-grant-tables --skip-networking=0 \
    --port=3306 --bind-address=127.0.0.1 &
MYSQL_PID=$!

# Wait for ready — use socket, NOT TCP
info "صبر برای آماده شدن MariaDB..."
READY=0
for i in $(seq 1 30); do
    if mysqladmin ping --protocol=socket --silent 2>/dev/null; then
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
#  ۴. ساخت دیتابیس و کاربر (با socket connection)
# ============================================================
info "ساخت دیتابیس و کاربر..."

# Use socket connection for root (skip-grant-tables means no auth needed)
mysql --protocol=socket -u root <<SQLEOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQLEOF

log "دیتابیس '$DB_NAME' و کاربر '$DB_USER' ساخته شد"

# ============================================================
#  ۵. ساخت جداول
# ============================================================
if [ -f "$MIRZA_DIR/table.php" ]; then
    info "ساخت جداول..."
    cd "$MIRZA_DIR"
    if php table.php > /dev/null 2>&1; then
        log "جداول ساخته شد"
    else
        warn "جداول از قبل وجود دارند"
    fi
fi

# ============================================================
#  ۶. ساخت config.php (با Python — بدون heredoc bug)
# ============================================================
info "ساخت config.php..."

DOMAIN_VAL=""
[ -n "$DOMAIN" ] && DOMAIN_VAL="https://$DOMAIN"
export _DOMAIN_VAL="$DOMAIN_VAL"

python3 << PYEOF > "$MIRZA_DIR/config.php"
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

export _DOMAIN_VAL="$DOMAIN_VAL"

chown www-data:www-data "$MIRZA_DIR/config.php"
chmod 640 "$MIRZA_DIR/config.php"
log "config.php ساخته شد"

# ============================================================
#  ۷. تنظیم Apache
# ============================================================
info "تنظیم Apache..."

SERVER_NAME="${DOMAIN:-localhost}"

cat > /etc/apache2/sites-available/mirza-pro.conf << APACHEEOF
<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    DocumentRoot ${MIRZA_DIR}
    <Directory ${MIRZA_DIR}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/apache2/mirza_error.log
    CustomLog /var/log/apache2/mirza_access.log combined
</VirtualHost>
APACHEEOF

a2ensite mirza-pro.conf > /dev/null 2>&1
a2dissite 000-default.conf > /dev/null 2>&1
log "Apache تنظیم شد"

# ============================================================
#  ۸. رفع خطاهای Mirza Pro
# ============================================================
info "رفع خطاهای احتمالی..."

if [ -f "$MIRZA_DIR/alireza_single.php" ] && [ ! -f "$MIRZA_DIR/alireza.php" ]; then
    mv "$MIRZA_DIR/alireza_single.php" "$MIRZA_DIR/alireza.php" 2>/dev/null
    sed -i "s|require_once __DIR__ . '/alireza_single.php';|require_once __DIR__ . '/alireza.php';|g" "$MIRZA_DIR/panels.php" 2>/dev/null
fi

[ ! -f "$MIRZA_DIR/version" ] && echo "3.0" > "$MIRZA_DIR/version"

chown -R www-data:www-data "$MIRZA_DIR"
find "$MIRZA_DIR" -type d -exec chmod 755 {} \; 2>/dev/null || true
find "$MIRZA_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
chmod 640 "$MIRZA_DIR/config.php"

# ============================================================
#  ۹. توقف mysqld موقت (supervisord دوباره استارت می‌کنه)
# ============================================================
info "توقف mysqld موقت..."
kill "$MYSQL_PID" 2>/dev/null || true
wait "$MYSQL_PID" 2>/dev/null || true
sleep 2

# ============================================================
#  ۱۰. Webhook تلگرام
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
    warn "DOMAIN نیست — Webhook بعداً تنظیم کنید"
fi

# ============================================================
#  ۱۱. اطلاعات نهایی
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
#  ۱۲. اجرای Supervisor
# ============================================================
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
