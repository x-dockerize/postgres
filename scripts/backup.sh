#!/usr/bin/env bash
set -e

# --------------------------------------------------
# Yardımcı Fonksiyonlar
# --------------------------------------------------
check_container() {
  local name="$1"
  if ! docker inspect "$name" &>/dev/null; then
    echo "❌ '$name' container çalışmıyor."
    return 1
  fi
}

backup_local() {
  check_container postgres-backup-local || return
  echo "⏳ Local yedekleme başlatılıyor..."
  if [ -n "$DB_NAME" ]; then
    docker exec -e POSTGRES_DB="${DB_NAME}" postgres-backup-local /backup.sh
  else
    docker exec postgres-backup-local /backup.sh
  fi
  echo "✅ Local yedekleme tamamlandı."
}

backup_do() {
  check_container postgres-backup-do || return
  echo "⏳ DigitalOcean yedekleme başlatılıyor..."
  if [ -n "$DB_NAME" ]; then
    docker exec -e POSTGRES_DATABASE="${DB_NAME}" postgres-backup-do sh backup.sh
  else
    docker exec postgres-backup-do sh backup.sh
  fi
  echo "✅ DigitalOcean yedekleme tamamlandı."
}

backup_oci() {
  check_container postgres-backup-oci || return
  echo "⏳ Oracle OCI yedekleme başlatılıyor..."
  if [ -n "$DB_NAME" ]; then
    docker exec -e POSTGRES_DATABASE="${DB_NAME}" postgres-backup-oci sh backup.sh
  else
    docker exec postgres-backup-oci sh backup.sh
  fi
  echo "✅ Oracle OCI yedekleme tamamlandı."
}

# --------------------------------------------------
# Menü
# --------------------------------------------------
read -rp "Yedeklenecek veritabanı (boş bırakılırsa tümü): " DB_NAME
echo

echo "Yedekleme hedefi seçin:"
echo "  1) Tümü"
echo "  2) Local"
echo "  3) DigitalOcean"
echo "  4) Oracle OCI"
read -rp "Seçim (1-4, boş bırakılırsa: Tümü): " CHOICE
CHOICE="${CHOICE:-1}"

echo

case "$CHOICE" in
  1) backup_local; backup_do; backup_oci ;;
  2) backup_local ;;
  3) backup_do ;;
  4) backup_oci ;;
  *) echo "❌ Geçersiz seçim."; exit 1 ;;
esac
