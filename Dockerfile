FROM php:8.2-apache-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# ── بسته‌های سیستمی ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-server \
    mariadb-client \
    openssl \
    curl \
    git \
    unzip \
    supervisor \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── افزونه‌های PHP ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    libzip-dev libonig-dev libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_mysql mysqli gd zip mbstring xml bcmath \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── فقط mpm_prefork (حذف mpm_event) ──
RUN a2dismod mpm_event 2>/dev/null || true && \
    a2enmod mpm_prefork rewrite headers

# ── پوسته‌ها ──
RUN mkdir -p /var/run/mysqld /var/log/supervisor && \
    chown mysql:mysql /var/run/mysqld

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
