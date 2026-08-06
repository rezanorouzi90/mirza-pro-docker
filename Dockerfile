FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# ── نصب nginx + php-fpm + mariadb ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx php8.2-fpm php8.2-mysql php8.2-curl php8.2-mbstring \
    php8.2-xml php8.2-zip php8.2-gd php8.2-bcmath php8.2-intl \
    mariadb-server mariadb-client \
    supervisor git curl unzip openssl ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── پیکربندی nginx ──
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /var/www/mirza_pro; \
    index index.php; \
    location / { \
        try_files $uri $uri/ /index.php?$query_string; \
    } \
    location ~ \.php$ { \
        include fastcgi_params; \
        fastcgi_pass unix:/run/php/php8.2-fpm.sock; \
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \
    } \
}' > /etc/nginx/sites-available/mirza-pro && \
    rm -f /etc/nginx/sites-enabled/default && \
    ln -sf /etc/nginx/sites-available/mirza-pro /etc/nginx/sites-enabled/mirza-pro

# ── پوسته‌ها ──
RUN mkdir -p /var/run/mysqld /var/log/supervisor /run/php /var/www/mirza_pro && \
    chown mysql:mysql /var/run/mysqld && \
    chown www-data:www-data /run/php

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
