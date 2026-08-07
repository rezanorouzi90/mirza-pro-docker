FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Copy nginx config first
COPY nginx.conf /tmp/mirza-pro-nginx.conf

# Install packages + cleanup + configure nginx ALL in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx php8.2-fpm php8.2-mysql php8.2-curl php8.2-mbstring \
    php8.2-xml php8.2-zip php8.2-gd php8.2-bcmath php8.2-intl \
    mariadb-server mariadb-client \
    supervisor git curl unzip openssl ca-certificates bash coreutils procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && rm -rf /etc/nginx/sites-enabled/* /etc/nginx/sites-available/default /etc/nginx/conf.d/* \
    && cp /tmp/mirza-pro-nginx.conf /etc/nginx/sites-available/mirza-pro \
    && ln -sf /etc/nginx/sites-available/mirza-pro /etc/nginx/sites-enabled/mirza-pro \
    && rm -f /tmp/mirza-pro-nginx.conf \
    && sed -i 's|;clear_env = no|clear_env = no|' /etc/php/8.2/fpm/pool.d/www.conf

# Pre-clone mirza_pro source into image
RUN mkdir -p /var/www/mirza_pro \
    && git clone --depth 1 https://github.com/mahdiMGF2/mirza_pro.git /var/www/mirza_pro \
    && chown -R www-data:www-data /var/www/mirza_pro \
    && rm -rf /var/www/mirza_pro/.git

RUN mkdir -p /var/run/mysqld /var/log/supervisor /run/php \
    && chown mysql:mysql /var/run/mysqld \
    && chown www-data:www-data /run/php

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-nginx.sh /start-nginx.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /start-nginx.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
