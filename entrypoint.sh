#!/bin/bash
# ============================================================
# Mirza Pro — Docker Entrypoint
# تشخیص خودکار متغیرها + راه‌اندازی کامل
# ============================================================
set -euo pipefail

# ── رنگ‌ها ──
R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' B='\033[1;34m' C='\033[1;36m' W='\033[0m'

log()  { echo -e "${G}[✔]${W} $1"; }
warn() { echo -e "${Y}[⚠]${W} $1"; }
err()  { echo -e "${R}[✘]${W} $1"; }
info() { echo -e "${B}[i]${W} $1"; }

# ============================================================
#  ۱. تشخیص متغیرهای محیطی
# ============================================================
BOT_TOKEN="${BOT_TOKEN:-}"
ADMIN_ID="${ADMIN_ID:-}"
BOT_USERNAME="${BOT_USERNAME:-}"
DOMAIN="${DOMAIN:-}"
DB_NAME="${DB_NAME:-mirza_pro}"
DB_USER="${DB_USER:-mirza_user}"
DB_PASS="${DB_PASS:-}"
DB_HOST="${DB_HOST:-127.0.0.1}"

# ── تشخیص خودکار دامنه Railway ──
if [ -z "$DOMAIN" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    DOMAIN="$RAILWAY_PUBLIC_DOMAIN"
    info "دامنه Railway شناسایی شد: $DOMAIN"
fi

# ── تشخیص پورت Railway ──
PORT="${PORT:-80}"

# ── تولید رمز دیتابیس ──
if [ -z "$DB_PASS" ]; then
    DB_PASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c -24)
    info "رمز دیتابیس تولید شد: $DB_PASS"
fi

# ── بررسی متغیرهای اجباری ──
MISSING=""
[ -z "$BOT_TOKEN" ]   && MISSING="$MISSING BOT_TOKEN"
[ -z "$ADMIN_ID" ]    && MISSING="$MISSING ADMIN_ID"
[ -z "$BOT_USERNAME" ] && MISSING="$MISSING BOT_USERNAME"

if [ -n "$MISSING" ]; then
    err "متغیرهای اجباری وارد نشده:$MISSING"
    echo ""
    echo -e "${C}نحوه استفاده:${W}"
    echo "  docker run -e BOT_TOKEN=xxx -e ADMIN_ID=123 -e BOT_USERNAME=mybot mirza-pro"
    exit 1
fi

info "متغیرها شناسایی شد:"
info "  BOT_TOKEN:    ${BOT_TOKEN:0:10}..."
info "  ADMIN_ID:     $ADMIN_ID"
info "  BOT_USERNAME: @$BOT_USERNAME"
info "  DOMAIN:       ${DOMAIN:-'(خودکار)'}"
info "  DB_NAME:      $DB_NAME"
info "  DB_USER:      $DB_USER"
info "  PORT:         $PORT"

# ============================================================
#  ۲. کلون کردن Mirza Pro
# ============================================================
MIRZA_DIR="/var/www/mirza_pro"

if [ ! -f "$MIRZA_DIR/index.php" ]; then
    info "دانلود Mirza Pro..."
    rm -rf "$MIRZA_DIR"
    if ! git clone --depth 1 https://github.com/mahdiMGF2/mirza_pro.git "$MIRZA_DIR" 2>/dev/null; then
        err "خطا در دانلود Mirza Pro"
        exit 1
    fi
    log "Mirza Pro دانلود شد"
else
    info "Mirza Pro از قبل وجود دارد"
fi

chown -R www-data:www-data "$MIRZA_DIR"
chmod -R 755 "$MIRZA_DIR"

# ============================================================
#  ۳. راه‌اندازی MariaDB
# ============================================================
info "راه‌اندازی MariaDB..."

# اگر دیتا دایرکتوری خالی باشه، اینیشیالایز کن
if [ ! -d "/var/lib/mysql/mysql" ]; then
    # تشخیص دستور اینیشیالایز
    if command -v mariadb-install-db &>/dev/null; then
        mariadb-install-db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1
    elif command -v mysql_install_db &>/dev/null; then
        mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1
    else
        # روش دستی
        mkdir -p /var/lib/mysql/mysql
        chown -R mysql:mysql /var/lib/mysql
    fi
    log "MariaDB اینیشیالایز شد"
fi

# استارت MariaDB در بک‌گراند (موقت)
mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking=0 --port=3306 &
MYSQL_PID=$!

# صبر برای آماده شدن
for i in $(seq 1 30); do
    if mysqladmin ping -h 127.0.0.1 --silent 2>/dev/null; then
        break
    fi
    sleep 1
done

if ! mysqladmin ping -h 127.0.0.1 --silent 2>/dev/null; then
    err "MariaDB آماده نشد!"
    exit 1
fi
log "MariaDB آماده شد"

# ============================================================
#  ۴. ساخت دیتابیس و کاربر
# ============================================================
info "ساخت دیتابیس و کاربر..."

mysql -u root -h 127.0.0.1 <<SQLEOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQLEOF

log "دیتابیس '$DB_NAME' و کاربر '$DB_USER' ساخته شد"

# ============================================================
#  ۵. ساخت config.php
# ============================================================
info "ساخت config.php..."

# ساخت با Python برای اجتناب از مشکلات heredoc
python3 -c "
import os
bot_token = os.environ['BOT_TOKEN']
admin_id = os.environ['ADMIN_ID']
bot_username = os.environ['BOT_USERNAME']
domain = os.environ.get('DOMAIN', '')
db_name = os.environ.get('DB_NAME', 'mirza_pro')
db_user = os.environ.get('DB_USER', 'mirza_user')
db_pass = os.environ['DB_PASS']
db_host = os.environ.get('DB_HOST', '127.0.0.1')
domain_val = f'https://{domain}' if domain else ''

config = f'''<?php
if(!defined(\"index\")) define(\"index\", true);

\$dbname     = '{db_name}';
\$usernamedb = '{db_user}';
\$passworddh = '{db_pass}';

\$connect = mysqli_connect(\"{db_host}\", \$usernamedb, \$passworddh, \$dbname);
if (!\$connect) die(\"Database connection failed!\");

mysqli_set_charset(\$connect, \"utf8mb4\");

try {{
    \$pdo = new PDO(\"mysql:host={db_host};dbname={db_name};charset=utf8mb4\", \$usernedb, \$passworddh, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
}} catch(Exception \$e) {{
    die(\"PDO connection error\");
}}

\$APIKEY       = '{bot_token}';
\$adminnumber  = '{admin_id}';
\$domainhosts  = '{domain_val}';
\$usernamebot  = '{bot_username}';
?>
'''
with open('{mira_dir}/config.php', 'w') as f:
    f.write(config)
" 2>/dev/null || {
    # fallback: نوشتن مستقیم
    cat > "$MIRZA_DIR/config.php" << 'PHPEOF'
<?php
if(!defined("index")) define("index", true);
PHPEOF

    # نوشتن خط به خط با Python
    python3 << PYEOF > "$MIRZA_DIR/config.php"
import os
bot_token = os.environ['BOT_TOKEN']
admin_id = os.environ['ADMIN_ID']
bot_username = os.environ['BOT_USERNAME']
domain = os.environ.get('DOMAIN', '')
db_name = os.environ.get('DB_NAME', 'mirza_pro')
db_user = os.environ.get('DB_USER', 'mirza_user')
db_pass = os.environ['DB_PASS']
db_host = os.environ.get('DB_HOST', '127.0.0.1')
domain_val = f'https://{domain}' if domain else ''

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
print(f"\\$usernamebot  = '{bot_username}';")
print('?>')
PYEOF
}

chown www-data:www-data "$MIRZA_DIR/config.php"
chmod 640 "$MIRZA_DIR/config.php"
log "config.php ساخته شد"

# ============================================================
#  ۶. ساخت جداول
# ============================================================
if [ -f "$MIRZA_DIR/table.php" ]; then
    info "ساخت جداول..."
    cd "$MIRZA_DIR"
    if php table.php > /dev/null 2>&1; then
        log "جداول ساخته شد"
    else
        warn "جداول از قبل وجود دارند یا خطا"
    fi
fi

# ============================================================
#  ۷. تنظیم Apache
# ============================================================
info "تنظیم Apache..."

DOMAIN_VAL="${DOMAIN:-localhost}"

cat > /etc/apache2/sites-available/mirza-pro.conf << APACHEEOF
<VirtualHost *:80>
    ServerName ${DOMAIN_VAL}
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
#  ۸. رفع خطاهای احتمالی
# ============================================================
info "رفع خطاهای احتمالی..."

# Fix alireza_single.php
if [ -f "$MIRZA_DIR/alireza_single.php" ] && [ ! -f "$MIRZA_DIR/alireza.php" ]; then
    mv "$MIRZA_DIR/alireza_single.php" "$MIRZA_DIR/alireza.php" 2>/dev/null
    sed -i "s|require_once __DIR__ . '/alireza_single.php';|require_once __DIR__ . '/alireza.php';|g" "$MIRZA_DIR/panels.php" 2>/dev/null
    log "alireza_single.php -> alireza.php تغییر نام داده شد"
fi

# Fix version file
[ ! -f "$MIRZA_DIR/version" ] && echo "3.0" > "$MIRZA_DIR/version"
chown www-data:www-data "$MIRZA_DIR/version" 2>/dev/null

# Fix permissions
chown -R www-data:www-data "$MIRZA_DIR"
find "$MIRZA_DIR" -type d -exec chmod 755 {} \; 2>/dev/null
find "$MIRZA_DIR" -type f -exec chmod 644 {} \; 2>/dev/null
chmod 640 "$MIRZA_DIR/config.php"

# ============================================================
#  ۹. توقف mysqld موقت (supervisord دوباره استارت می‌کنه)
# ============================================================
info "توقف mysqld موقت..."
kill "$MYSQL_PID" 2>/dev/null || true
wait "$MYSQL_PID" 2>/dev/null || true
sleep 2

# ============================================================
#  ۱۰. تنظیم Webhook تلگرام
# ============================================================
if [ -n "$DOMAIN" ]; then
    info "تنظیم Webhook..."
    WEBHOOK_URL="https://${DOMAIN}/index.php"
    WEBHOOK_RESULT=$(curl -sf "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=${WEBHOOK_URL}" 2>/dev/null || echo '{"ok":false}')
    if echo "$WEBHOOK_RESULT" | grep -q '"ok":true'; then
        log "Webhook تنظیم شد: $WEBHOOK_URL"
    else
        warn "Webhook تنظیم نشد — بعداً دستی تنظیم کنید"
        warn "دستور: curl 'https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=${WEBHOOK_URL}'"
    fi
else
    warn "DOMAIN تنظیم نشده — Webhook تنظیم نمیشود"
    warn "بعداً با: curl 'https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=YOUR_DOMAIN/index.php'"
fi

# ============================================================
#  ۱۱. نمایش اطلاعات نهایی
# ============================================================
echo ""
echo -e "${G}╔══════════════════════════════════════════════════╗${W}"
echo -e "${G}║        ✅ Mirza Pro با موفقیت راه‌اندازی شد     ║${W}"
echo -e "${G}╚══════════════════════════════════════════════════╝${W}"
echo ""
echo -e "${C}📋 اطلاعات:${W}"
echo -e "  🤖 Bot:       @$BOT_USERNAME"
echo -e "  👑 Admin ID:  $ADMIN_ID"
[ -n "$DOMAIN" ] && echo -e "  🌐 Domain:    https://$DOMAIN"
echo -e "  🗄️  Database:  $DB_NAME"
echo -e "  👤 DB User:   $DB_USER"
echo -e "  🔑 DB Pass:   ${DB_PASS}"
echo -e "  📁 Files:     $MIRZA_DIR"
echo -e "  🔌 Port:      $PORT"
echo ""
echo -e "${Y}⚠️  رمز دیتابیس را در جای امنی ذخیره کنید!${W}"
echo ""

# ============================================================
#  ۱۲. اجرای Supervisor (Apache + MariaDB)
# ============================================================
info "شروع سرویس‌ها..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
