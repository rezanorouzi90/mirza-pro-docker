#!/bin/bash
# Wait for php-fpm socket before starting nginx
for i in $(seq 1 30); do
    [ -S /run/php/php8.2-fpm.sock ] && break
    sleep 1
done
exec /usr/sbin/nginx -g "daemon off;"
