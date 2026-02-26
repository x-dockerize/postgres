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
psql_exec() {
  docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
    psql -U "${POSTGRES_USER}" -tAc "$1"
}

# --------------------------------------------------
# Veritabanı Bilgileri
# --------------------------------------------------
read -rp "Silinecek DB adı: " DB_NAME

if [ -z "$DB_NAME" ]; then
  echo "❌ DB adı boş bırakılamaz."
  exit 1
fi

DB_EXISTS=$(psql_exec "SELECT datname FROM pg_database WHERE datname='${DB_NAME}';")

if [ -z "$DB_EXISTS" ]; then
  echo "❌ '${DB_NAME}' veritabanı bulunamadı."
  exit 1
fi

# --------------------------------------------------
# Onay
# --------------------------------------------------
echo "⚠️  '${DB_NAME}' veritabanı ve tüm içeriği kalıcı olarak silinecek."
read -rp "Onaylamak için DB adını tekrar girin: " CONFIRM

if [ "$CONFIRM" != "$DB_NAME" ]; then
  echo "İptal edildi."
  exit 0
fi

# --------------------------------------------------
# Kullanıcıyı da Sil?
# --------------------------------------------------
read -rp "İlişkili DB kullanıcısı da silinsin mi? (boş bırakılırsa atlanır): " DB_USER

# --------------------------------------------------
# Aktif Bağlantıları Kes ve Veritabanını Sil
# --------------------------------------------------
psql_exec "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${DB_NAME}' AND pid <> pg_backend_pid();"
psql_exec "DROP DATABASE \"${DB_NAME}\";"

if [ -n "$DB_USER" ]; then
  USER_EXISTS=$(psql_exec "SELECT usename FROM pg_user WHERE usename='${DB_USER}';")

  if [ -n "$USER_EXISTS" ]; then
    psql_exec "DROP USER \"${DB_USER}\";"
    echo "🗑️  Kullanıcı silindi: $DB_USER"
  else
    echo "⚠️  '${DB_USER}' kullanıcısı bulunamadı, atlandı."
  fi
fi

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ Veritabanı başarıyla silindi"
echo "-----------------------------------------------"
echo "🗄️ Veritabanı    : $DB_NAME"
echo "==============================================="
