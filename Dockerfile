FROM php:8.2-apache-bookworm

# ── سیستمی ──
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    mariadb-client \
    openssl \
    curl \
    git \
    unzip \
    supervisor \
    libapache2-mod-php8.2 \
    php8.2-mysql \
    php8.2-curl \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    php8.2-gd \
    php8.2-bcmath \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Apache modules ──
RUN a2enmod rewrite headers ssl

# ── MariaDB data dir ──
RUN mkdir -p /var/run/mysqld && chown mysql:mysql /var/run/mysqld

# ── Supervisor config ──
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# ── Entry point ──
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── حجم ──
VOLUME /var/lib/mysql
VOLUME /var/www/mirza_pro

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
