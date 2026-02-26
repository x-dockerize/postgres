#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"

# --------------------------------------------------
# Kontroller
# --------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  echo "❌ $ENV_FILE bulunamadı. Önce install.sh çalıştırın."
  exit 1
fi

if ! docker inspect postgres &>/dev/null; then
  echo "❌ PostgreSQL container çalışmıyor. Önce 'docker compose up -d' çalıştırın."
  exit 1
fi

# --------------------------------------------------
# Admin Bilgilerini Oku
# --------------------------------------------------
POSTGRES_USER="$(grep -E '^POSTGRES_USER=' "$ENV_FILE" | cut -d '=' -f2-)"
POSTGRES_PASSWORD="$(grep -E '^POSTGRES_PASSWORD=' "$ENV_FILE" | cut -d '=' -f2-)"

if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ]; then
  echo "❌ POSTGRES_USER veya POSTGRES_PASSWORD .env içinde boş."
  exit 1
fi

# --------------------------------------------------
# Yardımcı Fonksiyonlar
# --------------------------------------------------
gen_password() {
  openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20
}

psql_exec() {
  docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
    psql -U "${POSTGRES_USER}" -tAc "$1"
}

# --------------------------------------------------
# Veritabanı Bilgileri
# --------------------------------------------------
read -rp "DB adı: " DB_NAME

if [ -z "$DB_NAME" ]; then
  echo "❌ DB adı boş bırakılamaz."
  exit 1
fi

read -rp "DB kullanıcısı (boş bırakılırsa: ${DB_NAME}): " DB_USER
DB_USER="${DB_USER:-$DB_NAME}"

read -rsp "DB şifresi (boş bırakılırsa otomatik oluşturulur): " INPUT_DB_PASSWORD
echo

if [ -z "$INPUT_DB_PASSWORD" ]; then
  DB_PASSWORD="$(gen_password)"
  echo "🔐 Otomatik oluşturulan DB şifresi: $DB_PASSWORD"
else
  DB_PASSWORD="$INPUT_DB_PASSWORD"
fi

# --------------------------------------------------
# Mevcut Kontrol
# --------------------------------------------------
DB_EXISTS=$(psql_exec "SELECT datname FROM pg_database WHERE datname='${DB_NAME}';")

if [ -n "$DB_EXISTS" ]; then
  echo "⚠️  '${DB_NAME}' veritabanı zaten mevcut."
  read -rp "Devam etmek istiyor musunuz? (e/H): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[eE]$ ]]; then
    echo "İptal edildi."
    exit 0
  fi
fi

USER_EXISTS=$(psql_exec "SELECT usename FROM pg_user WHERE usename='${DB_USER}';")

if [ -n "$USER_EXISTS" ]; then
  echo "⚠️  '${DB_USER}' kullanıcısı zaten mevcut. Şifre değiştirilmeyecek."
  echo "   Şifreyi güncellemek için reset-password.sh kullanın."
  read -rp "Yine de devam etmek istiyor musunuz? (e/H): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[eE]$ ]]; then
    echo "İptal edildi."
    exit 0
  fi
fi

# --------------------------------------------------
# Veritabanı ve Kullanıcı Oluştur
# --------------------------------------------------
psql_exec "CREATE DATABASE \"${DB_NAME}\";" 2>/dev/null || true
psql_exec "CREATE USER \"${DB_USER}\" WITH PASSWORD '${DB_PASSWORD}';" 2>/dev/null || true
psql_exec "GRANT ALL PRIVILEGES ON DATABASE \"${DB_NAME}\" TO \"${DB_USER}\";"
psql_exec "ALTER DATABASE \"${DB_NAME}\" OWNER TO \"${DB_USER}\";"

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ Veritabanı başarıyla oluşturuldu"
echo "-----------------------------------------------"
echo "🗄️ Veritabanı    : $DB_NAME"
echo "👤 Kullanıcı     : $DB_USER"
echo "🔑 Şifre         : $DB_PASSWORD"
echo "🌐 Host          : postgres"
echo "🔌 Port          : 5432"
echo "-----------------------------------------------"
echo "⚠️ Şifreyi güvenli bir yerde saklayın!"
echo "==============================================="
