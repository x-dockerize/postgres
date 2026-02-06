#!/usr/bin/env bash
set -euo pipefail

# =============================
# LOAD .env (if exists)
# =============================
if [ -f ".env" ]; then
  echo "📦 .env dosyası yüklendi"
  set -a
  source .env
  set +a
else
  echo "⚠️  .env bulunamadı, varsayılanlar kullanılacak"
fi

# =============================
# DEFAULTS
# =============================
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-postgres}"
POSTGRES_USER="${POSTGRES_USER:-dba}"

echo
echo "🧙 PostgreSQL Application DB Wizard"
echo "----------------------------------"
echo "Postgres container: $POSTGRES_CONTAINER"
echo "Postgres superuser: $POSTGRES_USER"
echo

# =============================
# STEP 1: DB USER
# =============================
read -rp "1️⃣ Veritabanı kullanıcı adı: " DB_USER
if [ -z "$DB_USER" ]; then
  echo "❌ Kullanıcı adı boş olamaz!"
  exit 1
fi

# =============================
# STEP 2: DB NAME
# =============================
read -rp "2️⃣ Veritabanı adı: " DB_NAME
if [ -z "$DB_NAME" ]; then
  echo "❌ Veritabanı adı boş olamaz!"
  exit 1
fi

# =============================
# STEP 3: PASSWORD (optional)
# =============================
read -rsp "3️⃣ Şifre (boş bırak → otomatik oluşturulur): " DB_PASS
echo

AUTO_PASS=false
if [ -z "$DB_PASS" ]; then
  DB_PASS="$(openssl rand -base64 32 | tr -d '=+/')"
  AUTO_PASS=true
fi

# =============================
# SUMMARY
# =============================
echo
echo "📋 Özet"
echo "----------------------------------"
echo "DB User: $DB_USER"
echo "DB Name: $DB_NAME"
echo "Password: $( [ "$AUTO_PASS" = true ] && echo 'AUTO-GENERATED' || echo 'CUSTOM' )"
echo
echo "⚠️  Bu işlem mevcut DB ve kullanıcıyı SİLER."
read -rp "Devam edilsin mi? (y/N): " CONFIRM
CONFIRM="${CONFIRM,,}"

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "yes" ]]; then
  echo "⛔ İşlem iptal edildi"
  exit 0
fi

# =============================
# SQL: ROLE + DATABASE
# =============================
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" <<SQL
-- Aktif bağlantıları kapat
REVOKE CONNECT ON DATABASE $DB_NAME FROM PUBLIC;
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '$DB_NAME'
  AND pid <> pg_backend_pid();

-- Temizle
DROP DATABASE IF EXISTS $DB_NAME;
DROP ROLE IF EXISTS $DB_USER;

-- Kullanıcı
CREATE ROLE $DB_USER
  LOGIN
  PASSWORD '$DB_PASS'
  NOSUPERUSER
  NOCREATEDB
  NOCREATEROLE;

-- Veritabanı
CREATE DATABASE $DB_NAME
  OWNER $DB_USER
  ENCODING 'UTF8'
  LC_COLLATE 'C'
  LC_CTYPE 'C'
  TEMPLATE template0;

GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
SQL

# =============================
# SQL: SCHEMA + PRIVILEGES
# =============================
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$DB_NAME" <<SQL
-- public schema sahipliği (Ecto için KRİTİK)
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public AUTHORIZATION $DB_USER;

GRANT ALL ON SCHEMA public TO $DB_USER;

-- Default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON TABLES TO $DB_USER;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON SEQUENCES TO $DB_USER;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON FUNCTIONS TO $DB_USER;

-- Güvenlik
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE $DB_NAME FROM PUBLIC;
SQL

# =============================
# RESULT
# =============================
echo
echo "==============================================="
echo "✅ Veritabanı başarıyla oluşturuldu!"
echo "-----------------------------------------------"
echo "Veritabanı: $DB_NAME"
echo "Kullanıcı Adı: $DB_USER"
echo "Şifre: $DB_PASS"
echo "-----------------------------------------------"
echo "⚠️  Bu bilgileri güvenli bir yerde saklayın!"
echo "==============================================="
