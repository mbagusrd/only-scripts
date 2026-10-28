#!/usr/bin/env bash
set -euo pipefail

# ponytail: pakai file profil sharing dengan mysql_sync.sh; upgrade ke vault jika butuh enkripsi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$SCRIPT_DIR/.mysql_sync_profiles"
touch "$PROFILE_FILE"
chmod 600 "$PROFILE_FILE"

# Pilih koneksi tersimpan atau baru
USE_SAVED=0
PROFILES=()
if [ -s "$PROFILE_FILE" ]; then
    echo "=== MySQL Connection ==="
    echo "0) Buat koneksi baru"
    IDX=1
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        PROFILES+=("$line")
        IFS='|' read -r P_NAME P_HOST P_PORT P_USER P_PASS <<< "$line"
        echo "$IDX) $P_NAME ($P_USER@$P_HOST:$P_PORT)"
        IDX=$((IDX + 1))
    done < "$PROFILE_FILE"

    read -rp "Pilihan koneksi [0]: " CONN_OPT
    CONN_OPT=${CONN_OPT:-0}
    if [ "$CONN_OPT" -gt 0 ] && [ "$CONN_OPT" -le "${#PROFILES[@]}" ]; then
        SELECTED="${PROFILES[$((CONN_OPT - 1))]}"
        IFS='|' read -r _ DB_HOST DB_PORT DB_USER DB_PASS <<< "$SELECTED"
        USE_SAVED=1
    fi
fi

if [ "$USE_SAVED" -eq 0 ]; then
    read -rp "Host DB [127.0.0.1]: " DB_HOST
    DB_HOST=${DB_HOST:-127.0.0.1}

    read -rp "Port DB [3306]: " DB_PORT
    DB_PORT=${DB_PORT:-3306}

    read -rp "User DB Admin [root]: " DB_USER
    DB_USER=${DB_USER:-root}

    read -rsp "Password DB Admin (kosongkan jika auth_socket/sudo): " DB_PASS
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
    [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && USE_SUDO="sudo"
    CONN_ARGS=(-u "$DB_USER")
else
    CONN_ARGS=(-h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER")
fi

run_sql() {
    $USE_SUDO mysql "${CONN_ARGS[@]}" -e "$1"
}

echo ""
echo "=== MySQL User Management ==="
echo "1) List Users"
echo "2) Create User"
echo "3) Change Password"
echo "4) Rename / Change Host Scope"
echo "5) Grant Privileges"
echo "6) Show Grants"
echo "7) Drop User"
read -rp "Pilihan aksi [1-7]: " ACT

case "$ACT" in
    1)
        echo "--- Daftar User MySQL ---"
        run_sql "SELECT user, host, plugin FROM mysql.user ORDER BY user, host;"
        ;;
    2)
        read -rp "Username baru: " NEW_USER
        read -rp "Host scope [%]: " NEW_HOST
        NEW_HOST=${NEW_HOST:-%}
        read -rsp "Password: " NEW_PASS
        echo ""

        if [ -z "$NEW_USER" ]; then
            echo "Error: Username tidak boleh kosong."
            exit 1
        fi

        SQL_CMD="CREATE USER '${NEW_USER}'@'${NEW_HOST}' IDENTIFIED BY '${NEW_PASS}';"
        run_sql "$SQL_CMD"
        echo "User '${NEW_USER}'@'${NEW_HOST}' berhasil dibuat."
        ;;
    3)
        read -rp "Username: " CHG_USER
        read -rp "Host scope [%]: " CHG_HOST
        CHG_HOST=${CHG_HOST:-%}
        read -rsp "Password baru: " CHG_PASS
        echo ""

        if [ -z "$CHG_USER" ]; then
            echo "Error: Username tidak boleh kosong."
            exit 1
        fi

        SQL_CMD="ALTER USER '${CHG_USER}'@'${CHG_HOST}' IDENTIFIED BY '${CHG_PASS}'; FLUSH PRIVILEGES;"
        run_sql "$SQL_CMD"
        echo "Password '${CHG_USER}'@'${CHG_HOST}' berhasil diubah."
        ;;
    4)
        read -rp "Username saat ini: " CUR_USER
        read -rp "Host saat ini [localhost]: " CUR_HOST
        CUR_HOST=${CUR_HOST:-localhost}
        read -rp "Username baru [$CUR_USER]: " TARGET_USER
        TARGET_USER=${TARGET_USER:-$CUR_USER}
        read -rp "Host baru [%]: " TARGET_HOST
        TARGET_HOST=${TARGET_HOST:-%}

        if [ -z "$CUR_USER" ]; then
            echo "Error: Username saat ini tidak boleh kosong."
            exit 1
        fi

        SQL_CMD="RENAME USER '${CUR_USER}'@'${CUR_HOST}' TO '${TARGET_USER}'@'${TARGET_HOST}'; FLUSH PRIVILEGES;"
        run_sql "$SQL_CMD"
        echo "User '${CUR_USER}'@'${CUR_HOST}' berhasil diubah menjadi '${TARGET_USER}'@'${TARGET_HOST}'."
        ;;
    5)
        read -rp "Username: " GR_USER
        read -rp "Host scope [%]: " GR_HOST
        GR_HOST=${GR_HOST:-%}
        read -rp "Target Database [*]: " GR_DB
        GR_DB=${GR_DB:-*}
        read -rp "Target Tabel [*]: " GR_TBL
        GR_TBL=${GR_TBL:-*}

        echo "Pilih Privileges:"
        echo "1) ALL PRIVILEGES"
        echo "2) SELECT, INSERT, UPDATE, DELETE"
        echo "3) SELECT only (read-only)"
        echo "4) Custom"
        read -rp "Pilihan privilege [1-4]: " PRIV_OPT

        case "$PRIV_OPT" in
            1) PRIV_STR="ALL PRIVILEGES" ;;
            2) PRIV_STR="SELECT, INSERT, UPDATE, DELETE" ;;
            3) PRIV_STR="SELECT" ;;
            4)
                read -rp "Privilege custom (contoh: SELECT, INSERT): " PRIV_STR
                ;;
            *)
                echo "Pilihan privilege tidak valid."
                exit 1
                ;;
        esac

        if [ "$GR_DB" = "*" ]; then
            TARGET="\`*\`"
            TARGET_STR="*.*"
        else
            if [ "$GR_TBL" = "*" ]; then
                TARGET_STR="\`${GR_DB}\`.*"
            else
                TARGET_STR="\`${GR_DB}\`.\`${GR_TBL}\`"
            fi
        fi

        SQL_CMD="GRANT ${PRIV_STR} ON ${TARGET_STR} TO '${GR_USER}'@'${GR_HOST}'; FLUSH PRIVILEGES;"
        run_sql "$SQL_CMD"
        echo "Privilege '${PRIV_STR}' diberikan ke '${GR_USER}'@'${GR_HOST}' pada ${TARGET_STR}."
        ;;
    6)
        read -rp "Username: " SH_USER
        read -rp "Host scope [%]: " SH_HOST
        SH_HOST=${SH_HOST:-%}

        if [ -z "$SH_USER" ]; then
            echo "Error: Username tidak boleh kosong."
            exit 1
        fi

        echo "--- Grants '${SH_USER}'@'${SH_HOST}' ---"
        run_sql "SHOW GRANTS FOR '${SH_USER}'@'${SH_HOST}';"
        ;;
    7)
        read -rp "Username yang akan dihapus: " DEL_USER
        read -rp "Host scope [%]: " DEL_HOST
        DEL_HOST=${DEL_HOST:-%}

        if [ -z "$DEL_USER" ]; then
            echo "Error: Username tidak boleh kosong."
            exit 1
        fi

        read -rp "Yakin hapus user '${DEL_USER}'@'${DEL_HOST}'? [y/N]: " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            run_sql "DROP USER '${DEL_USER}'@'${DEL_HOST}';"
            echo "User '${DEL_USER}'@'${DEL_HOST}' berhasil dihapus."
        else
            echo "Batal hapus user."
        fi
        ;;
    *)
        echo "Pilihan tidak valid."
        exit 1
        ;;
esac
