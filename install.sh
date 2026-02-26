#!/usr/bin/env bash
set -e

ENV_EXAMPLE=".env.example"
ENV_FILE=".env"

# --------------------------------------------------
# Kontroller
# --------------------------------------------------
if [ ! -f "$ENV_EXAMPLE" ]; then
  echo "❌ $ENV_EXAMPLE bulunamadı."
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  echo "✅ $ENV_EXAMPLE → $ENV_FILE kopyalandı"
else
  echo "ℹ️  $ENV_FILE zaten mevcut, devam ediliyor"
fi

# --------------------------------------------------
# Yardımcı Fonksiyonlar
# --------------------------------------------------
gen_password() {
  openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | head -c 20
}

set_env () {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    echo "${key}=${value}" >> "$ENV_FILE"
  fi
}

# --------------------------------------------------
# PostgreSQL Kullanıcı Bilgileri
# --------------------------------------------------
read -rp "POSTGRES_USER (boş bırakılırsa: dba): " INPUT_USER
POSTGRES_USER="${INPUT_USER:-dba}"

read -rsp "POSTGRES_PASSWORD (boş bırakılırsa otomatik oluşturulur): " INPUT_PASSWORD
echo

if [ -z "$INPUT_PASSWORD" ]; then
  POSTGRES_PASSWORD="$(gen_password)"
  echo "🔐 Otomatik oluşturulan POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
else
  POSTGRES_PASSWORD="$INPUT_PASSWORD"
fi

# --------------------------------------------------
# .env Güncelle
# --------------------------------------------------
set_env POSTGRES_USER "$POSTGRES_USER"
set_env POSTGRES_PASSWORD "$POSTGRES_PASSWORD"

# --------------------------------------------------
# Docker Network
# --------------------------------------------------
NETWORK_NAME="postgres-network"
if docker network inspect "$NETWORK_NAME" > /dev/null 2>&1; then
  echo "ℹ️  Docker network '$NETWORK_NAME' zaten mevcut"
else
  docker network create "$NETWORK_NAME"
  echo "✅ Docker network '$NETWORK_NAME' oluşturuldu"
fi

# --------------------------------------------------
# Sonuçları Göster
# --------------------------------------------------
echo
echo "==============================================="
echo "✅ PostgreSQL .env başarıyla hazırlandı"
echo "-----------------------------------------------"
echo "👤 Kullanıcı Adı     : $POSTGRES_USER"
echo "🔑 Şifre             : $POSTGRES_PASSWORD"
echo "-----------------------------------------------"
echo "⚠️  Şifreyi güvenli bir yerde saklayın!"
echo "==============================================="
