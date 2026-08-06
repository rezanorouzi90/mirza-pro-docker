FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# ── نصب همه چیز با apt ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    apache2 libapache2-mod-php8.2 \
    php8.2 php8.2-cli php8.2-mysql php8.2-curl php8.2-mbstring \
    php8.2-xml php8.2-zip php8.2-gd php8.2-bcmath php8.2-intl \
    mariadb-server mariadb-client \
    supervisor git curl unzip openssl ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── فقط mpm_prefork ──
RUN a2dismod mpm_event mpm_worker 2>/dev/null; \
    a2enmod mpm_prefork rewrite headers ssl

# ── پوسته‌ها ──
RUN mkdir -p /var/run/mysqld /var/log/supervisor /run/apache2 && \
    chown mysql:mysql /var/run/mysqld && \
    chown www-data:www-data /run/apache2

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -sf http://localhost/ > /dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
