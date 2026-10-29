#!/usr/bin/env bash
set -euo pipefail

# ponytail: pakai PPA ondrej/php untuk Ubuntu/Debian multi-versi PHP.

[[ $EUID -ne 0 ]] && echo "Jalankan pakai sudo/root." && exit 1

export DEBIAN_FRONTEND=noninteractive

echo "=== LEMP Stack Installer ==="
echo "0) Install All"
echo "1) Nginx"
echo "2) PHP-FPM"
echo "3) Composer"
echo "4) Certbot (HTTPS)"
echo "5) MySQL Server"
echo ""
read -rp "Pilih nomor (contoh: 0 atau 1,2,3 atau spasi 1 3): " CHOICES

# Default semua mati
INS_NGINX=N
INS_PHP=N
INS_COMPOSER=N
INS_SSL=N
INS_DB=N

# Parse input
for c in ${CHOICES//,/ }; do
    case "$c" in
        0) INS_NGINX=Y; INS_PHP=Y; INS_COMPOSER=Y; INS_SSL=Y; INS_DB=Y; break ;;
        1) INS_NGINX=Y ;;
        2) INS_PHP=Y ;;
        3) INS_COMPOSER=Y ;;
        4) INS_SSL=Y ;;
        5) INS_DB=Y ;;
        *) echo "Pilihan '$c' diabaikan (tidak valid)." ;;
    esac
done

apt-get update

if [[ "$INS_NGINX" =~ ^[Yy]$ ]]; then
    apt-get install -y nginx
    systemctl enable --now nginx
    echo "[OK] Nginx terpasang dan berjalan."
fi

if [[ "$INS_PHP" =~ ^[Yy]$ ]]; then
    # Tambah PPA ondrej/php untuk support multi-versi PHP (8.2, 8.3, 8.4)
    if ! grep -rq "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        apt-get install -y software-properties-common
        add-apt-repository -y ppa:ondrej/php
        apt-get update
    fi

    # Versi default 8.3 (aman Laravel 11+)
    read -rp "Pilih versi PHP (contoh: 8.2 / 8.3 / 8.4, default 8.3): " PHP_VER
    PHP_VER=${PHP_VER:-8.3}
    PKG_PREFIX="php${PHP_VER}"

    apt-get install -y "${PKG_PREFIX}-fpm" "${PKG_PREFIX}-cli" "${PKG_PREFIX}-mysql" \
                       "${PKG_PREFIX}-curl" "${PKG_PREFIX}-gd" "${PKG_PREFIX}-mbstring" \
                       "${PKG_PREFIX}-xml" "${PKG_PREFIX}-zip" "${PKG_PREFIX}-bcmath" \
                       "${PKG_PREFIX}-sqlite3" "${PKG_PREFIX}-intl" "${PKG_PREFIX}-redis"
    
    SYSTEMD_PHP="php${PHP_VER}-fpm"
    systemctl enable --now "$SYSTEMD_PHP"
    echo "[OK] PHP-FPM ${PHP_VER} terpasang."
fi

if [[ "$INS_COMPOSER" =~ ^[Yy]$ ]]; then
    # ponytail: curl installer langsung ke /usr/local/bin. Skip sha checksum, pasang versi latest.
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    echo "[OK] Composer terpasang."
fi

if [[ "$INS_SSL" =~ ^[Yy]$ ]]; then
    apt-get install -y certbot python3-certbot-nginx
    echo "[OK] Certbot + Nginx plugin terpasang."
fi

if [[ "$INS_DB" =~ ^[Yy]$ ]]; then
    apt-get install -y mysql-server
    systemctl enable --now mysql
    
    read -rp "Set root password MySQL sekarang? [y/N]: " SET_PASS
    if [[ "$SET_PASS" =~ ^[Yy]$ ]]; then
        read -rsp "Masukkan password root MySQL baru: " DB_PASS
        echo ""
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASS}'; FLUSH PRIVILEGES;" || \
        mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${DB_PASS}'; FLUSH PRIVILEGES;"
        echo "[OK] Password root MySQL diset."
    fi
    echo "[OK] MySQL terpasang."
fi

echo "=== Selesai ==="
