FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx php8.2-fpm php8.2-mysql php8.2-curl php8.2-mbstring \
    php8.2-xml php8.2-zip php8.2-gd php8.2-bcmath php8.2-intl \
    mariadb-server mariadb-client \
    supervisor git curl unzip openssl ca-certificates bash coreutils procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# nginx — remove ALL default configs to avoid duplicate default_server
# Must be in same RUN as apt-get to avoid layer caching issues
COPY nginx.conf /etc/nginx/sites-available/mirza-pro
RUN rm -rf /etc/nginx/sites-enabled/* /etc/nginx/conf.d/* && \
    ln -sf /etc/nginx/sites-available/mirza-pro /etc/nginx/sites-enabled/mirza-pro

# php-fpm
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
