FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install everything in one layer, then clean up nginx defaults in the SAME layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx php8.2-fpm php8.2-mysql php8.2-curl php8.2-mbstring \
    php8.2-xml php8.2-zip php8.2-gd php8.2-bcmath php8.2-intl \
    mariadb-server mariadb-client \
    supervisor git curl unzip openssl ca-certificates bash coreutils procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    # Remove ALL default nginx configs — MUST be in same layer as apt-get
    && rm -rf /etc/nginx/sites-enabled/* /etc/nginx/sites-available/default /etc/nginx/conf.d/*

# Inline nginx config — no COPY needed, no symlink issues
RUN printf 'server {\n\
    listen 80;\n\
    server_name _;\n\
    root /var/www/mirza_pro;\n\
    index index.php index.html;\n\
\n\
    location / {\n\
        try_files $uri $uri/ =404;\n\
    }\n\
\n\
    location ~ \\.php$ {\n\
        include fastcgi_params;\n\
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;\n\
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\n\
        fastcgi_read_timeout 300;\n\
    }\n\
\n\
    location ~ /\\.ht {\n\
        deny all;\n\
    }\n\
}\n' > /etc/nginx/sites-available/mirza-pro \
    && ln -sf /etc/nginx/sites-available/mirza-pro /etc/nginx/sites-enabled/mirza-pro

# php-fpm — allow env vars to pass through
RUN sed -i 's|;clear_env = no|clear_env = no|' /etc/php/8.2/fpm/pool.d/www.conf

RUN mkdir -p /var/run/mysqld /var/log/supervisor /run/php /var/www/mirza_pro && \
    chown mysql:mysql /var/run/mysqld && \
    chown www-data:www-data /run/php

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-nginx.sh /start-nginx.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /start-nginx.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
