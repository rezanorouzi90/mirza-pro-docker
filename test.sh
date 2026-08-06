#!/bin/bash
# ============================================================
# 🧪 Mirza Pro Docker — 50 Test Validation Suite
# اجرای ۵۰ تست برای تضمین کیفیت
# ============================================================
set -uo pipefail

# ── شمارنده ──
TOTAL=0
PASSED=0
FAILED=0
ERRORS=""

# ── رنگ‌ها ──
R='\033[1;31m' G='\033[1;32m' Y='\033[1;33m' C='\033[1;36m' W='\033[0m' B='\033[1m'

pass() { ((TOTAL++)); ((PASSED++)); echo -e "  ${G}✓${W} $1"; }
fail() { ((TOTAL++)); ((FAILED++)); echo -e "  ${R}✗${W} $1"; ERRORS="$ERRORS\n    ✗ $1"; }

DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${B}"
echo "╔══════════════════════════════════════════════════╗"
echo "║   🧪 Mirza Pro Docker — 50 Test Suite           ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${W}"

# ============================================================
#  بخش ۱: بررسی فایل‌ها (۱۰ تست)
# ============================================================
echo -e "${C}━━━ بخش ۱: بررسی فایل‌ها ━━━${W}"

[ -f "$DIR/Dockerfile" ]          && pass "Dockerfile وجود دارد" || fail "Dockerfile وجود ندارد"
[ -f "$DIR/entrypoint.sh" ]       && pass "entrypoint.sh وجود دارد" || fail "entrypoint.sh وجود ندارد"
[ -f "$DIR/supervisord.conf" ]    && pass "supervisord.conf وجود دارد" || fail "supervisord.conf وجود ندارد"
[ -f "$DIR/docker-compose.yml" ]  && pass "docker-compose.yml وجود دارد" || fail "docker-compose.yml وجود ندارد"
[ -f "$DIR/deploy.sh" ]           && pass "deploy.sh وجود دارد" || fail "deploy.sh وجود ندارد"
[ -f "$DIR/.env.example" ]        && pass ".env.example وجود دارد" || fail ".env.example وجود ندارد"
[ -f "$DIR/README.md" ]           && pass "README.md وجود دارد" || fail "README.md وجود ندارد"
[ -f "$DIR/.gitignore" ]          && pass ".gitignore وجود دارد" || fail ".gitignore وجود ندارد"

# بررسی حجم فایل‌ها (خالی نباشن)
[ -s "$DIR/Dockerfile" ]          && pass "Dockerfile خالی نیست" || fail "Dockerfile خالی است"
[ -s "$DIR/entrypoint.sh" ]       && pass "entrypoint.sh خالی نیست" || fail "entrypoint.sh خالی است"

# ============================================================
#  بخش ۲: Dockerfile (۱۰ تست)
# ============================================================
echo -e "\n${C}━━━ بخش ۲: Dockerfile ━━━${W}"

# بررسی VOLUME (نباید وجود داشته باشه)
if grep -qi "^VOLUME" "$DIR/Dockerfile"; then
    fail "Dockerfile حاوی VOLUME است (Railway پشتیبانی نمی‌کند)"
else
    pass "Dockerfile حاوی VOLUME نیست"
fi

# بررسی FROM
grep -q "FROM.*php.*apache" "$DIR/Dockerfile" && pass "FROM php:apache" || fail "FROM php:apache یافت نشد"

# بررسی نصب mariadb
grep -q "mariadb-server" "$DIR/Dockerfile" && pass "mariadb-server نصب شده" || fail "mariadb-server یافت نشد"
grep -q "mariadb-client" "$DIR/Dockerfile" && pass "mariadb-client نصب شده" || fail "mariadb-client یافت نشد"

# بررسی نصب supervisor
grep -q "supervisor" "$DIR/Dockerfile" && pass "supervisor نصب شده" || fail "supervisor یافت نشد"

# بررسی PHP extensions
grep -q "pdo_mysql" "$DIR/Dockerfile" && pass "pdo_mysql نصب شده" || fail "pdo_mysql یافت نشد"
grep -q "mysqli" "$DIR/Dockerfile" && pass "mysqli نصب شده" || fail "mysqli یافت نشد"

# بررسی Apache modules
grep -q "a2enmod.*rewrite" "$DIR/Dockerfile" && pass "mod_rewrite فعال" || fail "mod_rewrite یافت نشد"

# بررسی ENTRYPOINT
grep -q 'ENTRYPOINT.*entrypoint.sh' "$DIR/Dockerfile" && pass "ENTRYPOINT تنظیم شده" || fail "ENTRYPOINT یافت نشد"

# بررسی EXPOSE
grep -q "EXPOSE 80" "$DIR/Dockerfile" && pass "EXPOSE 80 تنظیم شده" || fail "EXPOSE 80 یافت نشد"

# ============================================================
#  بخش ۳: entrypoint.sh (۱۵ تست)
# ============================================================
echo -e "\n${C}━━━ بخش ۳: entrypoint.sh ━━━${W}"

# بررسی shebang
head -1 "$DIR/entrypoint.sh" | grep -q "#!/bin/bash" && pass "shebang bash" || fail "shebang bash یافت نشد"

# بررسی set -e
grep -q "set -e" "$DIR/entrypoint.sh" && pass "set -e فعال" || fail "set -e یافت نشد"

# بررسی تشخیص متغیرها
grep -q 'BOT_TOKEN.*BOT_TOKEN:-' "$DIR/entrypoint.sh" && pass "تشخیص BOT_TOKEN" || fail "تشخیص BOT_TOKEN یافت نشد"
grep -q 'ADMIN_ID.*ADMIN_ID:-' "$DIR/entrypoint.sh" && pass "تشخیص ADMIN_ID" || fail "تشخیص ADMIN_ID یافت نشد"
grep -q 'BOT_USERNAME.*BOT_USERNAME:-' "$DIR/entrypoint.sh" && pass "تشخیص BOT_USERNAME" || fail "تشخیص BOT_USERNAME یافت نشد"
grep -q 'DOMAIN.*DOMAIN:-' "$DIR/entrypoint.sh" && pass "تشخیص DOMAIN" || fail "تشخیص DOMAIN یافت نشد"
grep -q 'DB_NAME.*DB_NAME:-' "$DIR/entrypoint.sh" && pass "تشخیص DB_NAME" || fail "تشخیص DB_NAME یافت نشد"
grep -q 'DB_USER.*DB_USER:-' "$DIR/entrypoint.sh" && pass "تشخیص DB_USER" || fail "تشخیص DB_USER یافت نشد"
grep -q 'DB_PASS.*DB_PASS:-' "$DIR/entrypoint.sh" && pass "تشخیص DB_PASS" || fail "تشخیص DB_PASS یافت نشد"

# بررسی Railway domain detection
grep -q 'RAILWAY_PUBLIC_DOMAIN' "$DIR/entrypoint.sh" && pass "تشخیص دامنه Railway" || fail "تشخیص دامنه Railway یافت نشد"

# بررسی اعتبارسنجی
grep -q 'MISSING.*BOT_TOKEN' "$DIR/entrypoint.sh" && pass "اعتبارسنجی BOT_TOKEN" || fail "اعتبارسنجی BOT_TOKEN یافت نشد"

# بررسی git clone
grep -q 'git clone.*mirza_pro' "$DIR/entrypoint.sh" && pass "git clone mirza_pro" || fail "git clone mirza_pro یافت نشد"

# بررسی MariaDB init
grep -q 'mysql_install_db\|mariadb-install-db' "$DIR/entrypoint.sh" && pass "MariaDB init" || fail "MariaDB init یافت نشد"

# بررسی Apache config
grep -q 'a2ensite' "$DIR/entrypoint.sh" && pass "Apache vhost setup" || fail "Apache vhost setup یافت نشد"

# بررسی Webhook
grep -q 'setWebhook' "$DIR/entrypoint.sh" && pass "Telegram Webhook" || fail "Telegram Webhook یافت نشد"

# بررسی supervisord exec
grep -q 'exec.*supervisord' "$DIR/entrypoint.sh" && pass "supervisord exec" || fail "supervisord exec یافت نشد"

# ============================================================
#  بخش ۴: supervisord.conf (۵ تست)
# ============================================================
echo -e "\n${C}━━━ بخش ۴: supervisord.conf ━━━${W}"

grep -q "\[program:mariadb\]" "$DIR/supervisord.conf" && pass "برنامه mariadb" || fail "برنامه mariadb یافت نشد"
grep -q "\[program:apache\]" "$DIR/supervisord.conf" && pass "برنامه apache" || fail "برنامه apache یافت نشد"
grep -q "nodaemon=true" "$DIR/supervisord.conf" && pass "nodaemon=true" || fail "nodaemon=true یافت نشد"
grep -q "autorestart=true" "$DIR/supervisord.conf" && pass "autorestart=true" || fail "autorestart=true یافت نشد"
grep -q "stdout_logfile=/dev/stdout" "$DIR/supervisord.conf" && pass "stdout به stdout" || fail "stdout به stdout یافت نشد"

# ============================================================
#  بخش ۵: docker-compose.yml (۵ تست)
# ============================================================
echo -e "\n${C}━━━ بخش ۵: docker-compose.yml ━━━${W}"

grep -q "BOT_TOKEN" "$DIR/docker-compose.yml" && pass "BOT_TOKEN در compose" || fail "BOT_TOKEN در compose یافت نشد"
grep -q "ADMIN_ID" "$DIR/docker-compose.yml" && pass "ADMIN_ID در compose" || fail "ADMIN_ID در compose یافت نشد"
grep -q "BOT_USERNAME" "$DIR/docker-compose.yml" && pass "BOT_USERNAME در compose" || fail "BOT_USERNAME در compose یافت نشد"
grep -q "restart:" "$DIR/docker-compose.yml" && pass "restart policy" || fail "restart policy یافت نشد"
grep -q "ports:" "$DIR/docker-compose.yml" && pass "port mapping" || fail "port mapping یافت نشد"

# ============================================================
#  بخش ۶: deploy.sh (۵ تست)
# ============================================================
echo -e "\n${C}━━━ بخش ۶: deploy.sh ━━━${W}"

head -1 "$DIR/deploy.sh" | grep -q "#!/bin/bash" && pass "deploy.sh shebang" || fail "deploy.sh shebang یافت نشد"
grep -q "docker build" "$DIR/deploy.sh" && pass "docker build در deploy" || fail "docker build در deploy یافت نشد"
grep -q "docker run" "$DIR/deploy.sh" && pass "docker run در deploy" || fail "docker run در deploy یافت نشد"
grep -q "BOT_TOKEN" "$DIR/deploy.sh" && pass "BOT_TOKEN در deploy" || fail "BOT_TOKEN در deploy یافت نشد"
grep -q "ADMIN_ID" "$DIR/deploy.sh" && pass "ADMIN_ID در deploy" || fail "ADMIN_ID در deploy یافت نشد"

# ============================================================
#  بخش ۷: امنیت (۵ تست)
# ============================================================
echo -e "\n${C}━━━ بخش ۷: امنیت ━━━${W}"

# بررسی نبودن رمز در فایل‌ها
if grep -r "password123\|admin123\|changeme" "$DIR"/*.sh "$DIR"/*.yml 2>/dev/null | grep -v ".example" | grep -v "README" | grep -v "deploy.sh" | grep -v "تولید شد"; then
    fail "رمز پیش‌فرض در فایل‌ها یافت شد"
else
    pass "رمز پیش‌فرض در فایل‌ها یافت نشد"
fi

# بررسی نبودن توکن واقعی
if grep -r "ghp_\|sk-\|ak_" "$DIR"/*.sh "$DIR"/*.yml 2>/dev/null | grep -v "README" | grep -v "deploy.sh" | grep -v ".example"; then
    fail "توکن واقعی در فایل‌ها یافت شد"
else
    pass "توکن واقعی در فایل‌ها یافت نشد"
fi

# بررسی chmod config.php
grep -q "chmod 640.*config.php" "$DIR/entrypoint.sh" && pass "config.php chmod 640" || fail "config.php chmod 640 یافت نشد"

# بررسی .gitignore
grep -q "\.env" "$DIR/.gitignore" && pass ".env در gitignore" || fail ".env در gitignore یافت نشد"
grep -q "mysql_data" "$DIR/.gitignore" && pass "mysql_data در gitignore" || fail "mysql_data در gitignore یافت نشد"

# ============================================================
#  بخش ۸: README.md (۵ تست)
# ============================================================
echo -e "\n${C}━━━ بخش ۸: README.md ━━━${W}"

grep -q "BOT_TOKEN" "$DIR/README.md" && pass "BOT_TOKEN در README" || fail "BOT_TOKEN در README یافت نشد"
grep -q "ADMIN_ID" "$DIR/README.md" && pass "ADMIN_ID در README" || fail "ADMIN_ID در README یافت نشد"
grep -q "docker" "$DIR/README.md" && pass "docker در README" || fail "docker در README یافت نشد"
grep -q "Docker" "$DIR/README.md" && pass "Docker در README" || fail "Docker در README یافت نشد"
grep -qi "mirza" "$DIR/README.md" && pass "Mirza در README" || fail "Mirza در README یافت نشد"

# ============================================================
#  گزارش نهایی
# ============================================================
echo ""
echo -e "${B}╔══════════════════════════════════════════════════╗${W}"
echo -e "${B}║   📊 گزارش تست                                  ║${W}"
echo -e "${B}╚══════════════════════════════════════════════════╝${W}"
echo ""
echo -e "  ${G}✓ موفق: $PASSED${W}"
echo -e "  ${R}✗ ناموفق: $FAILED${W}"
echo -e "  ${C}📊 کل: $TOTAL${W}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${G}🎉 همه ۵۰ تست با موفقیت رد شد!${W}"
    exit 0
else
    echo -e "${R}❌ $FAILED تست ناموفق بود:${W}"
    echo -e "$ERRORS"
    exit 1
fi
