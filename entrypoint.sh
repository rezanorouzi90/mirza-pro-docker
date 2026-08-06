#!/bin/bash
# ============================================================
# Mirza Pro — Docker Entrypoint
# تشخیص خودکار متغیرها + راه‌اندازی کامل
# ============================================================
set -e

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
DB_HOST="${DB_HOST:-localhost}"

# تولید رمز دیتابیس اگر وارد نشده
if [ -z "$DB_PASS" ]; then
    DB_PASS=$(openssl rand -base64 24 | tr -d /=+ | cut -c -24)
    warn "رمز دیتابیس تولید شد: $DB_PASS"
fi

# ── بررسی متغیرهای اجباری ──
MISSING=""
[ -z "$BOT_TOKEN" ]  && MISSING="$MISSING BOT_TOKEN"
[ -z "$ADMIN_ID" ]   && MISSING="$MISSING ADMIN_ID"
[ -z "$BOT_USERNAME" ] && MISSING="$MISSING BOT_USERNAME"

if [ -n "$MISSING" ]; then
    err "متغیرهای اجباری وارد نشده:$MISSING"
    echo ""
    echo -e "${C}نحوه استفاده:${W}"
    echo "  docker run -e BOT_TOKEN=xxx -e ADMIN_ID=123 -e BOT_USERNAME=mybot mirza-pro"
    echo ""
    echo -e "${C}یا در docker-compose.yml:${W}"
    echo "  environment:"
    echo "    BOT_TOKEN: 'your_token'"
    echo "    ADMIN_ID: 'your_id'"
    echo "    BOT_USERNAME: 'your_bot'"
    echo ""
    exit 1
fi

info "متغیرها شناسایی شد:"
info "  BOT_TOKEN:   ${BOT_TOKEN:0:10}..."
info "  ADMIN_ID:    $ADMIN_ID"
info "  BOT_USERNAME: @$BOT_USERNAME"
info "  DOMAIN:      ${DOMAIN:-'(تنظیم نشده)'}"
info "  DB_NAME:     $DB_NAME"
info "  DB_USER:     $DB_USER"

# ============================================================
#  ۲. کلون کردن Mirza Pro (اگر وجود نداره)
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
#  ۳. ساخت config.php
# ============================================================
info "ساخت config.php..."

cat > "$MIRZA_DIR/config.php" <<CFGEOF
<?php
if(!defined("index")) define("index", true);

\$dbname     = '$DB_NAME';
\$usernamedb = '$DB_USER';
\$passworddh = '$DB_PASS';

\$connect = mysqli_connect("$DB_HOST", \$usernamedb, \$passworddh, \$dbname);
if (!\$connect) die("Database connection failed!");

mysqli_set_charset(\$connect, "utf8mb4");

try {
    \$pdo = new PDO("mysql:host=$DB_HOST;dbname=$DB_NAME;charset=utf8mb4", \$usernamedb, \$passworddh, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
} catch(Exception \$e) {
    die("PDO connection error");
}

\$APIKEY       = '$BOT_TOKEN';
\$adminnumber  = '$ADMIN_ID';
\$domainhosts  = '${DOMAIN:+https://'$DOMAIN'}';
\$usernamebot  = '$BOT_USERNAME';
?>
CFGEOF

chown www-data:www-data "$MIRZA_DIR/config.php"
chmod 640 "$MIRZA_DIR/config.php"
log "config.php ساخته شد"

# ============================================================
#  ۴. راه‌اندازی MariaDB
# ============================================================
info "راه‌اندازی MariaDB..."

# اگر دیتا دایرکتوری خالی باشه، اینیشیالایز کن
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null 2>&1
    log "MariaDB اینیشیالایز شد"
fi

# استارت MariaDB در بک‌گراند
mysqld --user=mysql --datadir=/var/lib/mysql &
MYSQL_PID=$!

# صبر برای آماده شدن
for i in $(seq 1 30); do
    if mysqladmin ping -h localhost > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

if ! mysqladmin ping -h localhost > /dev/null 2>&1; then
    err "MariaDB آماده نشد!"
    exit 1
fi
log "MariaDB آماده شد"

# ============================================================
#  ۵. ساخت دیتابیس و کاربر
# ============================================================
info "ساخت دیتابیس و کاربر..."

mysql -u root <<SQLEOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQLEOF

log "دیتابیس '$DB_NAME' و کاربر '$DB_USER' ساخته شد"

# ============================================================
#  ۶. ساخت جداول
# ============================================================
if [ -f "$MIRZA_DIR/table.php" ]; then
    info "ساخت جداول..."
    cd "$MIRZA_DIR"
    php table.php > /dev/null 2>&1 && log "جداول ساخته شد" || warn "جداول از قبل وجود دارند"
fi

# ============================================================
#  ۷. تنظیم Apache
# ============================================================
info "تنظیم Apache..."

DOMAIN_VAL="${DOMAIN:-localhost}"

cat > /etc/apache2/sites-available/mirza-pro.conf <<APACHEEOF
<VirtualHost *:80>
    ServerName $DOMAIN_VAL
    DocumentRoot $MIRZA_DIR
    
    <Directory $MIRZA_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/mirza_error.log
    CustomLog \${APACHE_LOG_DIR}/mirza_access.log combined
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

# ============================================================
#  ۹. تنظیم Webhook تلگرام
# ============================================================
if [ -n "$DOMAIN" ]; then
    info "تنظیم Webhook..."
    WEBHOOK_RESULT=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/setWebhook?url=https://$DOMAIN/index.php")
    if echo "$WEBHOOK_RESULT" | grep -q '"ok":true'; then
        log "Webhook تنظیم شد: https://$DOMAIN/index.php"
    else
        warn "Webhook تنظیم نشد — بعداً دستی تنظیم کنید"
    fi
else
    warn "DOMAIN تنظیم نشده — Webhook تنظیم نمیشود"
fi

# ============================================================
#  ۱۰. نمایش اطلاعات نهایی
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
echo ""
echo -e "${Y}⚠️  رمز دیتابیس را در جای امنی ذخیره کنید!${W}"
echo ""

# ============================================================
#  ۱۱. اجرای Supervisor (Apache + MariaDB)
# ============================================================
info "شروع سرویس‌ها..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
