#!/bin/bash
# Mirza Pro — entrypoint v14 (no heredoc issues)
# Guard file prevents re-run on container restart

log()  { echo "[OK] $1"; }
warn() { echo "[WARN] $1"; }

GUARD="/var/run/mirza-setup-done"

if [ -f "$GUARD" ]; then
    log "Setup already done. Starting supervisord..."
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi

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
    echo "ERROR: Missing BOT_TOKEN / ADMIN_ID / BOT_USERNAME"
    exit 1
fi

log "BOT @$BOT_USERNAME | ADMIN $ADMIN_ID | DOMAIN ${DOMAIN:-auto}"

MIRZA="/var/www/mirza_pro"

# ═══ PHASE 1: Init MariaDB ═══
if [ ! -d "/var/lib/mysql/mysql" ]; then
    log "Initializing MariaDB..."
    mkdir -p /var/lib/mysql
    chown -R mysql:mysql /var/lib/mysql
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || \
    mysql_install_db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || true
    chown -R mysql:mysql /var/lib/mysql
fi

# ═══ PHASE 2: Start temp MariaDB ═══
mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=127.0.0.1 --port=3306 &
MPID=$!

for i in $(seq 1 30); do
    mysqladmin --protocol=socket -u root ping >/dev/null 2>&1 && break
    sleep 1
done
log "MariaDB ready"

mysql --protocol=socket -u root <<'EOSQL' 2>/dev/null || true
CREATE DATABASE IF NOT EXISTS `mirza_pro` CHARACTER SET utf8mb4;
EOSQL

mysql --protocol=socket -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}'; CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}'; GRANT ALL ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost'; GRANT ALL ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1'; FLUSH PRIVILEGES;" 2>/dev/null || true
log "Database ready"

# ═══ PHASE 3: Generate config.php (no heredoc!) ═══
DOMAIN_VAL=""
[ -n "$DOMAIN" ] && DOMAIN_VAL="https://$DOMAIN"

CFG="$MIRZA/config.php"
printf '%s\n' '<?php' 'if(!defined("index")) define("index", true);' > "$CFG"
printf '%s\n' "\$dbname     = \"$DB_NAME\";" >> "$CFG"
printf '%s\n' "\$usernedb   = \"$DB_USER\";" >> "$CFG"
printf '%s\n' "\$passworddh = \"$DB_PASS\";" >> "$CFG"
cat >> "$CFG" << 'PHPEOF'
$connect = mysqli_connect("127.0.0.1", $usernedb, $passworddh, $dbname);
if (!$connect) die("Database connection failed!");
mysqli_set_charset($connect, "utf8mb4");
try {
    $pdo = new PDO("mysql:host=127.0.0.1;dbname=$dbname;charset=utf8mb4", $usernedb, $passworddh, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC
    ]);
} catch(Exception $e) { die("PDO error: " . $e->getMessage()); }
PHPEOF

printf '%s\n' "\$APIKEY       = \"$BOT_TOKEN\";" >> "$CFG"
printf '%s\n' "\$adminnumber  = \"$ADMIN_ID\";" >> "$CFG"
printf '%s\n' "\$domainhosts  = \"$DOMAIN_VAL\";" >> "$CFG"
printf '%s\n' "\$usernamebot  = \"$BOT_USERNAME\";" >> "$CFG"
printf '%s\n' '?>' >> "$CFG"

chown www-data:www-data "$CFG" 2>/dev/null
chmod 640 "$CFG" 2>/dev/null
log "config.php generated"

[ -f "$MIRZA/table.php" ] && (cd "$MIRZA" && php table.php >/dev/null 2>&1) || true
log "DB tables initialized"

[ -f "$MIRZA/alireza_single.php" ] && [ ! -f "$MIRZA/alireza.php" ] && \
    mv "$MIRZA/alireza_single.php" "$MIRZA/alireza.php" 2>/dev/null || true

# Stop temp mysqld
kill "$MPID" 2>/dev/null || true
wait "$MPID" 2>/dev/null || true
sleep 2

# ═══ PHASE 4: Webhook ═══
if [ -n "$DOMAIN" ]; then
    RESULT=$(curl -sf "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=https://${DOMAIN}/index.php" 2>/dev/null || echo "")
    echo "$RESULT" | grep -q '"ok":true' && log "Webhook set" || warn "Webhook failed"
else
    warn "No DOMAIN"
fi

# ═══ PHASE 5: Start supervisord ═══
touch "$GUARD"
log "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
