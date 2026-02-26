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

# --------------------------------------------------
# Kullanıcı Bilgileri
# --------------------------------------------------
read -rp "Şifresi sıfırlanacak kullanıcı: " DB_USER

if [ -z "$DB_USER" ]; then
  echo "❌ Kullanıcı adı boş bırakılamaz."
  exit 1
fi

USER_EXISTS=$(docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
  psql -U "${POSTGRES_USER}" -tAc "SELECT usename FROM pg_user WHERE usename='${DB_USER}';")

if [ -z "$USER_EXISTS" ]; then
  echo "❌ '${DB_USER}' kullanıcısı bulunamadı."
  exit 1
fi

read -rsp "Yeni şifre (boş bırakılırsa otomatik oluşturulur): " INPUT_PASSWORD
echo

if [ -z "$INPUT_PASSWORD" ]; then
  NEW_PASSWORD="$(gen_password)"
  echo "🔐 Otomatik oluşturulan şifre: $NEW_PASSWORD"
else
  NEW_PASSWORD="$INPUT_PASSWORD"
fi

# --------------------------------------------------
# Şifreyi Güncelle
# --------------------------------------------------
docker exec -e PGPASSWORD="${POSTGRES_PASSWORD}" postgres \
  psql -U "${POSTGRES_USER}" -c "ALTER USER \"${DB_USER}\" WITH PASSWORD '${NEW_PASSWORD}';"

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ Şifre başarıyla sıfırlandı"
echo "-----------------------------------------------"
echo "👤 Kullanıcı     : $DB_USER"
echo "🔑 Yeni Şifre    : $NEW_PASSWORD"
echo "-----------------------------------------------"
echo "⚠️ Şifreyi güvenli bir yerde saklayın!"
echo "==============================================="
