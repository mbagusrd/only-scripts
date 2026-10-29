#!/usr/bin/env bash
set -euo pipefail

# ponytail: simpan profil di file flat-text plain di direktori script; upgrade ke secret store jika butuh enkripsi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$SCRIPT_DIR/.mysql_sync_profiles"
touch "$PROFILE_FILE"
chmod 600 "$PROFILE_FILE"

echo "=== MySQL Backup & Restore ==="
echo "1) Backup DB (.sql)"
echo "2) Restore DB (.sql)"
read -rp "Pilihan aksi [1/2]: " ACT

# Pilih koneksi tersimpan atau baru
USE_SAVED=0
PROFILES=()
if [ -s "$PROFILE_FILE" ]; then
    while true; do
        PROFILES=()
        echo ""
        echo "Pilih koneksi:"
        echo "0) Buat koneksi baru"
        IDX=1
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            PROFILES+=("$line")
            IFS='|' read -r P_NAME P_HOST P_PORT P_USER P_PASS <<< "$line"
            echo "$IDX) $P_NAME ($P_USER@$P_HOST:$P_PORT)"
            IDX=$((IDX + 1))
        done < "$PROFILE_FILE"
        echo "d) Hapus profil"

        read -rp "Pilihan koneksi [0]: " CONN_OPT
        CONN_OPT=${CONN_OPT:-0}

        if [ "$CONN_OPT" = "d" ] || [ "$CONN_OPT" = "D" ]; then
            read -rp "Pilih nomor profil yang ingin dihapus [1-${#PROFILES[@]}]: " DEL_OPT
            if [ -n "$DEL_OPT" ] && [ "$DEL_OPT" -gt 0 ] && [ "$DEL_OPT" -le "${#PROFILES[@]}" ] 2>/dev/null; then
                DEL_IDX=$((DEL_OPT - 1))
                IFS='|' read -r DEL_NAME _ <<< "${PROFILES[$DEL_IDX]}"
                unset 'PROFILES[DEL_IDX]'
                printf "%s\n" "${PROFILES[@]}" > "$PROFILE_FILE"
                echo "Profil '$DEL_NAME' berhasil dihapus."
                [ ! -s "$PROFILE_FILE" ] && break
            else
                echo "Pilihan tidak valid."
            fi
            continue
        fi

        if [ "$CONN_OPT" -gt 0 ] && [ "$CONN_OPT" -le "${#PROFILES[@]}" ] 2>/dev/null; then
            SELECTED="${PROFILES[$((CONN_OPT - 1))]}"
            IFS='|' read -r _ DB_HOST DB_PORT DB_USER DB_PASS <<< "$SELECTED"
            USE_SAVED=1
        fi
        break
    done
fi

if [ "$USE_SAVED" -eq 0 ]; then
    read -rp "Host DB [127.0.0.1]: " DB_HOST
    DB_HOST=${DB_HOST:-127.0.0.1}

    read -rp "Port DB [3306]: " DB_PORT
    DB_PORT=${DB_PORT:-3306}

    read -rp "User DB [root]: " DB_USER
    DB_USER=${DB_USER:-root}

    read -rsp "Password DB (kosongkan jika auth_socket/sudo): " DB_PASS
    echo ""

    read -rp "Simpan profil koneksi ini? [y/N]: " SAVE_OPT
    if [[ "$SAVE_OPT" =~ ^[Yy]$ ]]; then
        read -rp "Nama label profil: " P_LABEL
        P_LABEL=${P_LABEL:-"$DB_USER@$DB_HOST"}
        echo "${P_LABEL}|${DB_HOST}|${DB_PORT}|${DB_USER}|${DB_PASS}" >> "$PROFILE_FILE"
        echo "Profil tersimpan di $PROFILE_FILE."
    fi
fi

CONN_ARGS=()
USE_SUDO=""
if [ -n "$DB_PASS" ]; then
    export MYSQL_PWD="$DB_PASS"
    CONN_ARGS=(-h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER")
elif [ "$DB_HOST" = "127.0.0.1" ] || [ "$DB_HOST" = "localhost" ]; then
    # auth_socket wajib lewat local socket file, flag -h 127.0.0.1 paksa TCP networking dan bikin ditolak
    [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && USE_SUDO="sudo"
    CONN_ARGS=(-u "$DB_USER")
else
    CONN_ARGS=(-h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER")
fi

read -rp "Nama Database: " DB_NAME
if [ -z "$DB_NAME" ]; then
    echo "Error: Nama database wajib diisi."
    exit 1
fi

case "$ACT" in
    1)
        FILE_OUT="${DB_NAME}_backup_$(date +%Y%m%d_%H%M%S).sql"
        echo "Dump $DB_NAME dari $DB_HOST:$DB_PORT..."
        $USE_SUDO mysqldump "${CONN_ARGS[@]}" \
            --single-transaction --quick --routines --triggers "$DB_NAME" > "$FILE_OUT"
        echo "Backup sukses: $FILE_OUT"
        ;;
    2)
        SQL_FILES=(*.sql)
        FILE_IN=""

        if [ -e "${SQL_FILES[0]}" ]; then
            echo ""
            echo "Daftar file .sql di direktori aktif:"
            echo "0) Masukkan path manual"
            for i in "${!SQL_FILES[@]}"; do
                echo "$((i + 1))) ${SQL_FILES[$i]}"
            done
            read -rp "Pilih file [1-${#SQL_FILES[@]} atau 0]: " SQL_OPT
            if [ -n "$SQL_OPT" ] && [ "$SQL_OPT" -gt 0 ] && [ "$SQL_OPT" -le "${#SQL_FILES[@]}" ]; then
                FILE_IN="${SQL_FILES[$((SQL_OPT - 1))]}"
            fi
        fi

        if [ -z "$FILE_IN" ]; then
            read -rp "Path file .sql: " FILE_IN
        fi

        if [ ! -f "$FILE_IN" ]; then
            echo "Error: File $FILE_IN tidak ditemukan."
            exit 1
        fi

        echo "Restore $FILE_IN ke $DB_NAME di $DB_HOST:$DB_PORT..."
        $USE_SUDO mysql "${CONN_ARGS[@]}" -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"
        $USE_SUDO mysql "${CONN_ARGS[@]}" "$DB_NAME" < "$FILE_IN"
        echo "Restore sukses."
        ;;
    *)
        echo "Pilihan tidak valid."
        exit 1
        ;;
esac
