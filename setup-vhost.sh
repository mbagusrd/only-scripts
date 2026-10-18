#!/usr/bin/env bash
set -euo pipefail

# ponytail: skip full nginx parser. Edit pakai $EDITOR langsung pada vhost file.

[[ $EUID -ne 0 ]] && echo "Jalankan pakai sudo/root." && exit 1

detect_php_sock() {
    find /run/php/ -name "php*-fpm.sock" 2>/dev/null | sort -V | tail -n 1
}

create_vhost() {
    read -rp "Domain (contoh: app.example.com): " DOMAIN
    [[ -z "$DOMAIN" ]] && echo "Domain kosong." && exit 1

    CONF_PATH="/etc/nginx/sites-available/$DOMAIN"
    [[ -f "$CONF_PATH" ]] && echo "Config $CONF_PATH sudah ada. Pakai menu Edit." && exit 1

    read -rp "Webroot path [/var/www/$DOMAIN]: " WEBROOT
    WEBROOT=${WEBROOT:-/var/www/$DOMAIN}

    PHP_SOCK=$(detect_php_sock)
    read -rp "PHP-FPM socket path [$PHP_SOCK]: " INPUT_SOCK
    PHP_SOCK=${INPUT_SOCK:-$PHP_SOCK}
    [[ -z "$PHP_SOCK" ]] && echo "PHP socket tidak ketemu." && exit 1

    read -rp "Email Let's Encrypt (kosongkan jika tanpa SSL sekarang): " EMAIL

    mkdir -p "$WEBROOT"
    chown -R www-data:www-data "$WEBROOT"

    cat > "$CONF_PATH" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root $WEBROOT;

    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_SOCK;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    ln -sf "$CONF_PATH" /etc/nginx/sites-enabled/
    nginx -t
    systemctl reload nginx

    if [[ -n "$EMAIL" ]]; then
        certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
    fi
    echo "Vhost $DOMAIN aktif."
}

edit_vhost() {
    echo "Daftar vhost:"
    select CONF in /etc/nginx/sites-available/*; do
        [[ -n "$CONF" ]] && break
        echo "Pilihan tidak valid."
    done

    DOMAIN=$(basename "$CONF")
    EDITOR=${EDITOR:-nano}
    "$EDITOR" "$CONF"

    nginx -t && systemctl reload nginx && echo "Nginx reload sukses."

    read -rp "Pasang/Update SSL Certbot untuk $DOMAIN? [y/N]: " SETUP_SSL
    if [[ "$SETUP_SSL" =~ ^[Yy]$ ]]; then
        read -rp "Email Let's Encrypt: " EMAIL
        [[ -n "$EMAIL" ]] && certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" --redirect
    fi
}

renew_ssl() {
    read -rp "Domain khusus (kosongkan untuk renew semua): " DOMAIN
    if [[ -n "$DOMAIN" ]]; then
        certbot certonly --nginx -d "$DOMAIN" --force-renewal
    else
        certbot renew
    fi
    systemctl reload nginx
    echo "SSL renew selesai."
}

echo "1) Create vhost"
echo "2) Edit vhost"
echo "3) Renew SSL"
read -rp "Pilih [1-3]: " MENU

case "$MENU" in
    1) create_vhost ;;
    2) edit_vhost ;;
    3) renew_ssl ;;
    *) echo "Pilihan salah." && exit 1 ;;
esac
