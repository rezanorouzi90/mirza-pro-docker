#!/bin/bash
# Mirza Pro — entrypoint v8
# supervisord = nginx + php-fpm only (health check ready)
# MariaDB managed by entrypoint (no lock conflicts)

log()  { echo "[OK] $1"; }
warn() { echo "[WARN] $1"; }

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
    echo "Missing BOT_TOKEN / ADMIN_ID / BOT_USERNAME"; exit 1
fi

log "BOT @$BOT_USERNAME | ADMIN $ADMIN_ID | DOMAIN ${DOMAIN:-auto}"

# ═══ Phase 1: MariaDB init ═══
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || \
    mysql_install_db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || \
    mkdir -p /var/lib/mysql/mysql
    chown -R mysql:mysql /var/lib/mysql
fi

# Start MariaDB for setup
mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=127.0.0.1 --port=3306 &
MPID=$!
for i in $(seq 1 15); do
    mysqladmin --protocol=socket -u root ping >/dev/null 2>&1 && break
    sleep 1
done

# ═══ Phase 2: DB + Config ═══
mysql --protocol=socket -u root <<EOSQL 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
GRANT ALL ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
EOSQL
log "DB ready"

# Clone source
MIRZA="/var/www/mirza_pro"
if [ ! -f "$MIRZA/index.php" ]; then
    rm -rf "$MIRZA"
    git clone --depth 1 https://github.com/mahdiMGF2/mirza_pro.git "$MIRZA" 2>/dev/null || true
fi
chown -R www-data:www-data "$MIRZA" 2>/dev/null || true

# Create tables
[ -f "$MIRZA/table.php" ] && (cd "$MIRZA" && php table.php >/dev/null 2>&1) || true

# config.php
DOMAIN_VAL=""
[ -n "$DOMAIN" ] && DOMAIN_VAL="https://$DOMAIN"

cat > "$MIRZA/config.php" << PHPEOF
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
} catch(Exception \$e) { die("PDO error"); }
\$APIKEY       = '$BOT_TOKEN';
\$adminnumber  = '$ADMIN_ID';
\$domainhosts  = '$DOMAIN_VAL';
\$usernamebot  = '$BOT_USERNAME';
?>
PHPEOF

chown www-data:www-data "$MIRZA/config.php" 2>/dev/null
chmod 640 "$MIRZA/config.php" 2>/dev/null
log "config.php"

# Fix alireza
[ -f "$MIRZA/alireza_single.php" ] && [ ! -f "$MIRZA/alireza.php" ] && \
    mv "$MIRZA/alireza_single.php" "$MIRZA/alireza.php" 2>/dev/null || true

# Webhook
if [ -n "$DOMAIN" ]; then
    RESULT=$(curl -sf "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=https://${DOMAIN}/index.php" 2>/dev/null || echo "")
    echo "$RESULT" | grep -q '"ok":true' && log "Webhook: https://${DOMAIN}/index.php" || warn "Webhook failed"
else
    warn "No DOMAIN — webhook NOT set"
fi

# ═══ Phase 3: Start services ═══
# Stop temp mysqld (supervisord will NOT restart it — we manage it)
kill $MPID 2>/dev/null || true
wait $MPID 2>/dev/null || true
sleep 2

# Start nginx + php-fpm via supervisord (background)
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
SUPER_PID=$!

# Start MariaDB for runtime (background, kept alive by container)
mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=127.0.0.1 --port=3306 &
MYSQL_PID=$!

log "All services started. supervisord=$SUPER_PID mysql=$MYSQL_PID"

# Keep container alive — wait for supervisord
wait $SUPER_PID
