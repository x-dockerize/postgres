# PostgreSQL Backup Setup

## 🎯 Amaç

* PostgreSQL veritabanlarını **otomatik ve düzenli** yedeklemek
* Yedekleri **iki farklı cloud** üzerinde saklamak
* Disk şişmesini önlemek (retention policy)
* Manuel script / cron yazmadan sürdürülebilir yapı kurmak

## Kurulum

1. Bu repo’yu klonlayın:
```shell
git clone https://github.com/x-dockerize/postgreSQL.git
```

2. PostgreSQL Network Oluşturulması
Kurulumanan sonra, PostgreSQL container’ının çalıştığı network’ü oluşturun:
```shell
docker network create postgres-network
```

3. .env.example dosyasını .env olarak kopyalayın ve içindeki değerleri kendi ortamınıza göre düzenleyin:
```shell
cp .env.example .env
```

4. docker-compose.production.yml dosyasını docker-compose.yml olarak kopyalayın:
```shell
cp docker-compose.production.yml docker-compose.yml
```

5. Docker Compose ile container’ları başlatın:
```shell
docker-compose up -d
```

---

## 🧱 Mimari Özet

* PostgreSQL: Docker container
* Backup: Ayrı bir container (cron + pg_dump)
* Public erişim: ❌ yok

```text
Postgres → Backup Container →
  ├─ DigitalOcean Spaces (S3)
  └─ Oracle Object Storage (S3 compatible)
```

---

## 📁 Dizin Yapısı

```text
postgres/
├── .docker/
│   ├── postgres/
│   │   └── data/      # DB data volume
│   └── postgres-backup/
│       └── backups/       # Lokal geçici yedekler
├── .env
├── .env.example
├── docker-compose.production.yml
└── docker-compose.yml
```

---

## 🐳 Kullanılan Docker Image’lar

| Servis     | Image                                   |
| ---------- | --------------------------------------- |
| PostgreSQL | `postgres:16`                           |
| Backup     | `prodrigestivill/postgres-backup-local` |

---

## ⏱ Yedekleme Zamanlaması

Yedekleme zamanlaması `.env` dosyası üzerinden yapılır:

```env
SCHEDULE=@daily
```

Alternatif örnekler:

```env
SCHEDULE=@hourly
SCHEDULE=@weekly
SCHEDULE="0 3 * * *"   # Her gece 03:00
```

> Cron container içinde otomatik çalışır.

---

## ♻️ Retention (Temizlik Politikası)

```env
BACKUP_KEEP_DAYS=7
BACKUP_KEEP_WEEKS=4
BACKUP_KEEP_MONTHS=6
```

* Günlük: 7 gün
* Haftalık: 4 hafta
* Aylık: 6 ay

Eski yedekler otomatik silinir.

---

## ☁️ Backup Hedefleri

### DigitalOcean Spaces

```env
S3_ENDPOINT=https://ams3.digitaloceanspaces.com
S3_BUCKET=pg-backups
S3_PREFIX=devops/postgres
S3_REGION=ams3
```

### Oracle Object Storage (S3 Compatible)

```env
S3_ENDPOINT_2=https://<namespace>.compat.objectstorage.eu-amsterdam-1.oraclecloud.com
S3_BUCKET_2=pg-backups
S3_PREFIX_2=devops/postgres
S3_REGION_2=eu-amsterdam-1
```

📌 Tek yedek → **iki farklı cloud’a aynı anda** gönderilir.

---

## 🗄 Çoklu Database Desteği

Aynı PostgreSQL instance içindeki **tüm database’ler otomatik yedeklenir**.

İstersen sadece belirli DB’ler:

```env
POSTGRES_DB=app_db,app_db_2
```

---

## 🔐 Güvenlik Notları

* PostgreSQL **public açık değildir**
* Backup credential’ları sadece `.env` içindedir

---

## 🧪 Test & Doğrulama

### Log kontrolü

```bash
docker logs postgres-backup
```

### Manuel backup tetikleme

```bash
docker exec postgres-backup /backup.sh
```

---

### Uygulama veritabanı oluşturma

Her uygulama için ayrı bir veritabanı ve kullanıcı oluşturmak için aşağıdaki komutu kullanabilirsiniz:

```bash
./app_db_setup.sh
```

---

## 🚀 Olası Geliştirmeler

* WAL / PITR (Point-in-Time Recovery)
* pgBouncer
* Backup encryption (GPG)
* Restore test otomasyonu
* Prometheus postgres-exporter

---

## ✅ Sonuç

Bu yapı:

* Production uyumlu
* Cloud bağımsız
* Az bakım gerektiren
* Güvenli ve genişletilebilir

DevOps merkez sunucusu için **ideal PostgreSQL backup çözümüdür**.
