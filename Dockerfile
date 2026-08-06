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

# ── ماژول‌های PHP ──
RUN docker-php-ext-install pdo pdo_mysql mysqli

# ── افزونه‌های PHP ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libonig-dev \
    libxml2-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd zip mbstring xml bcmath \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── ماژول‌های Apache ──
RUN a2enmod rewrite headers

# ── پوسته‌های مورد نیاز ──
RUN mkdir -p /var/run/mysqld /var/log/supervisor && \
    chown mysql:mysql /var/run/mysqld

# ── فایل‌های پیکربندی ──
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -sf http://localhost/ > /dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
