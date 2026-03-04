# BC Beacon — Upgrade-Plan: PHP-App → Laravel

Dieses Dokument beschreibt den reproduzierbaren Upgrade-Prozess von der alten
PHP/Vanilla-JS-Website auf die neue Laravel-12-Anwendung.

> **Status:** Getestet auf `hosting236825.ae84c.netcup.net` (Netcup Testserver)

---

## Voraussetzungen

| Komponente      | Anforderung                                    |
| --------------- | ---------------------------------------------- |
| PHP             | ≥ 8.3 (Laravel 12 braucht 8.4+, läuft mit `--ignore-platform-reqs`) |
| MySQL / MariaDB | ≥ 5.7 / 10.3                                  |
| Composer        | ≥ 2.7                                          |
| SSH-Zugang      | Für CLI-Commands (artisan)                     |
| Plesk           | Domain + DB-Zugang                             |

---

## Architektur

```
websitehelper/
└── deploy/
    ├── reset-and-upgrade-test.sh   ← Wiederholbarer Testlauf
    └── UPGRADE-PLAN.md             ← Dieses Dokument

laravel/
├── database/migrations/
│   ├── 2026_03_02_000001_rename_legacy_tables.php    ← Umbenennung der alten Tabellen
│   └── 2026_03_03_000002_create_bc_content_tables.php  ← Neue Struktur
└── app/Console/Commands/
    └── MigrateLegacyData.php       ← Daten-Kopie legacy_* → neue Tabellen
```

---

## Migrations-Reihenfolge

```
0001_01_01_000000  → users, sessions, password_reset_tokens     (neu)
0001_01_01_000001  → cache, cache_locks                          (neu)
0001_01_01_000002  → jobs, job_batches, failed_jobs              (neu)
2026_03_02_000001  → RENAME legacy tables (categories → legacy_categories, …)
2026_03_03_000001  → Social-Login-Felder + invite_tokens         (neu)
2026_03_03_000002  → categories, tags, posts, post_tags          (neue Struktur)
2026_03_03_000003  → newsletter_subscribers, send_log, subscriber_tags
2026_03_03_000004  → weekly_summaries (LONGBLOB fix)
```

### Schema-Änderungen (Legacy → Laravel)

| Tabelle                | Änderung                                                              |
| ---------------------- | --------------------------------------------------------------------- |
| `posts.source_url`     | VARCHAR(1000) → VARCHAR(768) (MySQL-Index-Limit)                      |
| `posts.category`       | VARCHAR(50) DEFAULT 'News' → VARCHAR(100) NULLABLE                    |
| `posts.tags`           | JSON-Spalte entfällt (Daten leben in `post_tags` Pivot-Tabelle)       |
| `tags.color`           | Neue Spalte (VARCHAR(7), nullable)                                    |
| `categories.color`     | Neue Spalte (VARCHAR(7), nullable)                                    |
| `newsletter_send_log`  | Neuer UNIQUE-Constraint auf (subscriber_id, kw, year)                 |
| NEU: `subscriber_tags` | Subscriber ↔ Tags Pivot-Tabelle                                      |
| NEU: `users`           | Laravel Auth mit Social-Login-Feldern                                 |
| NEU: `invite_tokens`   | Einladungssystem                                                      |
| NEU: `sessions`        | Laravel Sessions                                                      |
| NEU: `cache`           | Laravel Cache                                                         |
| NEU: `jobs`            | Laravel Queue                                                         |

---

## Automatisierter Testlauf

Das Script `reset-and-upgrade-test.sh` führt den kompletten Prozess automatisch durch:

```bash
# Aus dem websitehelper-Verzeichnis:
./deploy/reset-and-upgrade-test.sh                     # Komplett (frischer DB-Dump + Upgrade)
./deploy/reset-and-upgrade-test.sh --skip-dump         # Ohne neuen Dump (schneller)
./deploy/reset-and-upgrade-test.sh --dry-run           # Nur Dry-Run
./deploy/reset-and-upgrade-test.sh --laravel-dir /pfad # Custom Laravel-Pfad
```

### Was das Script macht

1. **SSH prüfen** — Verbindung zum Testserver
2. **Live-DB → Test-DB** — Frischer Dump der Live-Daten in die Test-DB
3. **Code deployen** — Laravel-Archiv erstellen & hochladen
4. **Composer install** — Dependencies installieren
5. **Migrations** — Legacy-Tabellen umbenennen + neue Struktur anlegen
6. **Verifizierung** — Legacy-Tabellen vorhanden? Neue Tabellen da?
7. **Datenmigration** — Dry-Run, dann Execute mit Admin-User
8. **Endcheck** — Datensatz-Zählung + HTTP-Checks

---

## Manueller Upgrade-Prozess (für Live)

### Phase 1: Vorbereitung (Downtime: 0 Min.)

```bash
# 1. Backup der Live-Datenbank erstellen
mysqldump -h HOST -u USER -p DB_NAME > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. Laravel-Code auf Server hochladen
cd /path/to/laravel
tar czf laravel-deploy.tar.gz --exclude=node_modules --exclude=.git --exclude=vendor .
scp laravel-deploy.tar.gz user@server:~/

# 3. Auf dem Server: Archiv entpacken
ssh user@server
cd ~/domain.de/httpdocs
tar xzf ~/laravel-deploy.tar.gz

# 4. Composer-Abhängigkeiten installieren
composer install --no-dev --optimize-autoloader --ignore-platform-reqs

# 5. .env konfigurieren (DB-Credentials, APP_URL, MAIL_*, API_KEY)
cp .env.example .env
nano .env
```

### Phase 2: Wartungsmodus + Migration (Downtime: ~2-5 Min.)

```bash
# 6. Wartungsmodus aktivieren
php artisan down --secret="upgrade-2026"

# 7. Alle Migrations ausführen
php artisan migrate --force

# 8. Daten-Migration: Dry-Run zuerst
php artisan bcbeacon:migrate-legacy

# 9. Daten-Migration: Ausführen
php artisan bcbeacon:migrate-legacy --execute --with-admin

# 10. Verifizierung
php artisan tinker --execute="
    echo 'Posts: ' . \DB::table('posts')->count() . PHP_EOL;
    echo 'Categories: ' . \DB::table('categories')->count() . PHP_EOL;
    echo 'Tags: ' . \DB::table('tags')->count() . PHP_EOL;
    echo 'Post-Tags: ' . \DB::table('post_tags')->count() . PHP_EOL;
    echo 'Subscribers: ' . \DB::table('newsletter_subscribers')->count() . PHP_EOL;
    echo 'Send-Log: ' . \DB::table('newsletter_send_log')->count() . PHP_EOL;
    echo 'Summaries: ' . \DB::table('weekly_summaries')->count() . PHP_EOL;
"
```

### Phase 3: Go Live (Downtime Ende)

```bash
# 11. Caches leeren
php artisan optimize:clear

# 12. Root .htaccess prüfen (Rewrite auf public/)
cat .htaccess
# Sollte enthalten: RewriteRule ^(.*)$ public/$1 [L]

# 13. Wartungsmodus beenden
php artisan up

# 14. Funktionstest im Browser
#     - Homepage lädt, Posts werden angezeigt
#     - API: /api/posts gibt JSON zurück
#     - Login mit admin@bcbeacon.de funktioniert
#     - Newsletter-Seite funktioniert
```

### Phase 4: Aufräumen (optional, nach 1-2 Wochen)

```bash
# Legacy-Tabellen entfernen (wenn alles stabil läuft)
php artisan tinker --execute="
    \$tables = ['legacy_post_tags', 'legacy_posts', 'legacy_tags',
                'legacy_categories', 'legacy_newsletter_send_log',
                'legacy_newsletter_subscribers', 'legacy_weekly_summaries'];
    foreach (\$tables as \$t) {
        \Illuminate\Support\Facades\Schema::dropIfExists(\$t);
        echo \"Dropped: \$t\" . PHP_EOL;
    }
"
```

---

## Rollback-Plan

```bash
# Option A: Datenbank-Backup wiederherstellen
mysql -h HOST -u USER -p DB_NAME < backup_YYYYMMDD_HHMMSS.sql

# Option B: Legacy-Tabellen zurückbenennen
php artisan migrate:rollback --step=5
```

---

## Bekannte Einschränkungen (Shared Hosting / Plesk)

| Problem                | Workaround                                                   |
| ---------------------- | ------------------------------------------------------------ |
| `open_basedir`         | Kein `config:cache` / `route:cache` verwenden                |
| PHP 8.3 statt 8.4+    | `composer install --ignore-platform-reqs`                    |
| Kein Node.js           | Vite-Build lokal ausführen, `public/build/` mit hochladen    |
| Composer nicht global  | `/local/bin/composer` im chroot                              |

---

## Erwartete Datensätze (Stand: März 2026)

| Tabelle                  | Erwartet  |
| ------------------------ | --------- |
| `posts`                  | ~259      |
| `categories`             | ~25       |
| `tags`                   | ~228      |
| `post_tags`              | ~790      |
| `newsletter_subscribers` | ~8        |
| `newsletter_send_log`    | variabel  |
| `weekly_summaries`       | variabel  |
| `users`                  | 1 (Admin) |

---

## Server-Zugänge (Testserver)

| Zugang          | Wert                                           |
| --------------- | ---------------------------------------------- |
| SSH             | `hosting236825@202.61.232.76`                  |
| Test-Domain     | `http://hosting236825.ae84c.netcup.net`        |
| Test-DB         | `k349529_bcnewstest` auf `10.35.232.77:3306`  |
| DB-User (Test)  | `k349529_bcnewstest`                           |
| httpdocs        | `/hosting236825.ae84c.netcup.net/httpdocs`     |
| Composer        | `/local/bin/composer`                           |
| PHP (CLI)       | 8.5.0 (Server), 8.3.28 (Web/Plesk)            |

> **Hinweis:** Im Plesk-chroot ist `HOME=/`. Pfade beginnen daher mit `/`
> statt `/home/hosting236825/`.
