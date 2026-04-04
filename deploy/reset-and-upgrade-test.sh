#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════
# BC Beacon — Repeatable Upgrade Test
#
# HINWEIS: Das Testsystem (hosting236825.ae84c.netcup.net) wird nicht mehr
# für BC Beacon genutzt — dort läuft jetzt die Lyst-API.
# Dieses Script ist daher obsolet.
#
# Setzt die Test-DB auf ein frisches Live-Abbild zurück und spielt
# den kompletten Laravel-Upgrade-Prozess durch.
# Eigenständig lauffähig aus dem websitehelper-Repo.
#
# Nutzung:
#   ./deploy/reset-and-upgrade-test.sh                  # Alles automatisch
#   ./deploy/reset-and-upgrade-test.sh --dry-run        # Nur Dry-Run
#   ./deploy/reset-and-upgrade-test.sh --skip-dump      # Kein neuer Live-Dump
#   ./deploy/reset-and-upgrade-test.sh --laravel-dir /path/to/laravel
#
# Voraussetzungen:
#   - sshpass installiert (brew install hudochenkov/sshpass/sshpass)
#   - SSH-Zugang zum Testserver
#   - Laravel-Repo lokal vorhanden (Standard: ../laravel relativ zu websitehelper)
# ═══════════════════════════════════════════════════════════════════════

# ─── Konfiguration ────────────────────────────────────────────────────

SSH_HOST="202.61.232.76"
SSH_USER="hosting236825"
SSH_PASS="${SSH_PASS:?'SSH_PASS env var must be set'}"

DB_HOST="10.35.232.77"

LIVE_DB="k349529_bcnews"
LIVE_USER="k349529_bcnews"
LIVE_PASS="${LIVE_DB_PASS:?'LIVE_DB_PASS env var must be set'}"

TEST_DB="k349529_bcnewstest"
TEST_USER="k349529_bcnewstest"
TEST_PASS="${TEST_DB_PASS:?'TEST_DB_PASS env var must be set'}"

HTTPDOCS="/hosting236825.ae84c.netcup.net/httpdocs"
COMPOSER="/local/bin/composer"
TEST_DOMAIN="https://hosting236825.ae84c.netcup.net"

# Laravel-Repo Pfad (Standard: neben websitehelper)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LARAVEL_DIR="${SCRIPT_DIR}/../../laravel"

# ─── Farben (nur wenn Terminal interaktiv) ────────────────────────────

if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
    BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

# ─── Hilfsfunktionen ─────────────────────────────────────────────────

step()  { echo -e "\n${BLUE}${BOLD}▶ $1${NC}"; }
ok()    { echo -e "  ${GREEN}✓ $1${NC}"; }
warn()  { echo -e "  ${YELLOW}⚠ $1${NC}"; }
fail()  { echo -e "  ${RED}✗ $1${NC}"; exit 1; }
info()  { echo -e "  ${NC}$1"; }

ssh_cmd() {
    export SSHPASS="$SSH_PASS"
    sshpass -e ssh -o StrictHostKeyChecking=no "${SSH_USER}@${SSH_HOST}" "$1" 2>&1
}

mysql_live() {
    ssh_cmd "mysql -h ${DB_HOST} -u ${LIVE_USER} -p'${LIVE_PASS}' ${LIVE_DB} -e \"$1\" 2>/dev/null"
}

mysql_test() {
    ssh_cmd "mysql -h ${DB_HOST} -u ${TEST_USER} -p'${TEST_PASS}' ${TEST_DB} -e \"$1\" 2>/dev/null"
}

artisan() {
    ssh_cmd "cd ${HTTPDOCS} && php artisan $1 2>&1"
}

# ─── Argumente parsen ─────────────────────────────────────────────────

DRY_RUN=false
SKIP_DUMP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)      DRY_RUN=true; shift ;;
        --skip-dump)    SKIP_DUMP=true; shift ;;
        --laravel-dir)  LARAVEL_DIR="$2"; shift 2 ;;
        --help|-h)
            echo "Nutzung: $0 [--dry-run] [--skip-dump] [--laravel-dir /path]"
            echo ""
            echo "  --dry-run       Nur Dry-Run der Datenmigration"
            echo "  --skip-dump     Kein neuer Live-Dump (nutzt bestehende Test-DB)"
            echo "  --laravel-dir   Pfad zum Laravel-Repo (Standard: ../laravel)"
            exit 0
            ;;
        *) echo "Unbekanntes Argument: $1"; exit 1 ;;
    esac
done

# Laravel-Pfad auflösen
LARAVEL_DIR="$(cd "$LARAVEL_DIR" 2>/dev/null && pwd)" || fail "Laravel-Verzeichnis nicht gefunden: $LARAVEL_DIR"

# ═══════════════════════════════════════════════════════════════════════
echo -e "${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   BC Beacon — Upgrade Test (Live → Laravel)          ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "  Modus:       ${YELLOW}DRY-RUN${NC}"
else
    echo -e "  Modus:       ${GREEN}EXECUTE${NC}"
fi
echo -e "  Live-DB:     ${LIVE_DB}"
echo -e "  Test-DB:     ${TEST_DB}"
echo -e "  Laravel:     ${LARAVEL_DIR}"
echo -e "  Datum:       $(date '+%Y-%m-%d %H:%M:%S')"
START_TIME=$(date +%s)

# ─── Voraussetzungen prüfen ───────────────────────────────────────────

command -v sshpass >/dev/null 2>&1 || fail "sshpass nicht installiert (brew install hudochenkov/sshpass/sshpass)"
command -v curl    >/dev/null 2>&1 || fail "curl nicht installiert"
[[ -f "${LARAVEL_DIR}/artisan" ]] || fail "Keine artisan-Datei in ${LARAVEL_DIR}"

# ─── Schritt 1: SSH-Verbindung prüfen ────────────────────────────────

step "1/8  SSH-Verbindung prüfen"
SSH_TEST=$(ssh_cmd "echo ok" 2>&1) || fail "SSH-Verbindung fehlgeschlagen"
ok "Verbindung zu ${SSH_HOST} steht"

# ─── Schritt 2: Live-DB Snapshot → Test-DB ───────────────────────────

if [[ "$SKIP_DUMP" == "false" ]]; then
    step "2/8  Live-DB → Test-DB kopieren (frisches Abbild)"

    # 2a: Live-Zählung (Referenzwerte)
    info "Zähle Live-Datensätze..."
    LIVE_COUNTS=$(ssh_cmd "mysql -h ${DB_HOST} -u ${LIVE_USER} -p'${LIVE_PASS}' ${LIVE_DB} -N -e \"
        SELECT 'posts', COUNT(*) FROM posts
        UNION ALL SELECT 'categories', COUNT(*) FROM categories
        UNION ALL SELECT 'tags', COUNT(*) FROM tags
        UNION ALL SELECT 'post_tags', COUNT(*) FROM post_tags
        UNION ALL SELECT 'newsletter_subscribers', COUNT(*) FROM newsletter_subscribers
        UNION ALL SELECT 'newsletter_send_log', COUNT(*) FROM newsletter_send_log
        UNION ALL SELECT 'weekly_summaries', COUNT(*) FROM weekly_summaries;
    \" 2>/dev/null")
    echo "$LIVE_COUNTS" | while read -r table count; do
        info "  Live $table: $count"
    done

    # 2b: Alle Tabellen in Test-DB droppen
    info "Lösche alle Tabellen in Test-DB..."
    ssh_cmd "mysql -h ${DB_HOST} -u ${TEST_USER} -p'${TEST_PASS}' ${TEST_DB} -N -e \"
        SET FOREIGN_KEY_CHECKS = 0;
        SELECT CONCAT('DROP TABLE IF EXISTS \\\`', table_name, '\\\`;')
          FROM information_schema.tables
          WHERE table_schema = '${TEST_DB}';
    \" 2>/dev/null | grep -v '^\$' > /tmp/drop_tables.sql" || true

    ssh_cmd "if [ -s /tmp/drop_tables.sql ]; then
        mysql -h ${DB_HOST} -u ${TEST_USER} -p'${TEST_PASS}' ${TEST_DB} -e 'SET FOREIGN_KEY_CHECKS=0; SOURCE /tmp/drop_tables.sql; SET FOREIGN_KEY_CHECKS=1;' 2>/dev/null
    fi" || true

    # Verify empty
    REMAINING=$(mysql_test "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${TEST_DB}';" | tail -1 | tr -d '[:space:]')
    if [[ "${REMAINING:-0}" -gt 0 ]]; then
        warn "Noch ${REMAINING} Tabellen übrig, versuche Einzel-Drop..."
        ssh_cmd "mysql -h ${DB_HOST} -u ${TEST_USER} -p'${TEST_PASS}' ${TEST_DB} -N -e \"
            SET FOREIGN_KEY_CHECKS=0;
            SET @tbls = (SELECT GROUP_CONCAT('DROP TABLE IF EXISTS \\\`', table_name, '\\\`' SEPARATOR '; ')
                         FROM information_schema.tables WHERE table_schema='${TEST_DB}');
            PREPARE stmt FROM @tbls;
            EXECUTE stmt;
            SET FOREIGN_KEY_CHECKS=1;
        \" 2>/dev/null" || true
    fi
    ok "Test-DB geleert"

    # 2c: Dump von Live → Import in Test
    info "Dumpe Live-DB und importiere in Test-DB (das dauert etwas)..."
    ssh_cmd "mysqldump -h ${DB_HOST} -u ${LIVE_USER} -p'${LIVE_PASS}' --single-transaction --routines --triggers ${LIVE_DB} 2>/dev/null | mysql -h ${DB_HOST} -u ${TEST_USER} -p'${TEST_PASS}' ${TEST_DB} 2>/dev/null"
    ok "Live-Daten in Test-DB importiert"

    # 2d: Verifizierung
    info "Verifiziere Import..."
    TEST_POST_COUNT=$(ssh_cmd "mysql -h ${DB_HOST} -u ${TEST_USER} -p'${TEST_PASS}' ${TEST_DB} -N -e 'SELECT COUNT(*) FROM posts;' 2>/dev/null" | tr -d '[:space:]')
    ok "Test-DB hat ${TEST_POST_COUNT} Posts"
else
    step "2/8  Live-DB Dump übersprungen (--skip-dump)"
    warn "Nutze bestehende Test-DB-Daten"
fi

# ─── Schritt 3: Laravel-Code deployen ────────────────────────────────

step "3/8  Laravel-Code auf Server aktualisieren"

info "Erstelle Archiv aus ${LARAVEL_DIR}..."
tar czf /tmp/laravel-upgrade.tar.gz \
    --exclude=node_modules --exclude=.git --exclude=vendor \
    -C "$LARAVEL_DIR" .

info "Lade Archiv auf Server..."
export SSHPASS="$SSH_PASS"
sshpass -e scp -o StrictHostKeyChecking=no /tmp/laravel-upgrade.tar.gz \
    "${SSH_USER}@${SSH_HOST}:laravel-upgrade.tar.gz" 2>/dev/null

info "Entpacke auf Server (ohne .env und storage zu überschreiben)..."
ssh_cmd "cd ${HTTPDOCS} && tar xzf ~/laravel-upgrade.tar.gz --exclude='.env' --exclude='storage/logs' --exclude='vendor' 2>/dev/null"
ok "Code aktualisiert"

# Aufräumen
rm -f /tmp/laravel-upgrade.tar.gz

# ─── Schritt 4: Composer install ──────────────────────────────────────

step "4/8  Composer install"
COMPOSER_OUT=$(ssh_cmd "cd ${HTTPDOCS} && ${COMPOSER} install --no-dev --optimize-autoloader --ignore-platform-reqs --no-interaction 2>&1 | tail -5")
echo "$COMPOSER_OUT" | while read -r line; do info "  $line"; done
ok "Composer install fertig"

# ─── Schritt 5: Laravel Migrations ───────────────────────────────────

step "5/8  Laravel Migrations ausführen"
MIGRATION_OUT=$(artisan "migrate --force 2>&1")
echo "$MIGRATION_OUT" | while read -r line; do info "  $line"; done
ok "Migrations ausgeführt"

# ─── Schritt 6: Legacy-Tabellen prüfen ───────────────────────────────

step "6/8  Legacy-Tabellen verifizieren"
LEGACY_CHECK=$(mysql_test "SELECT table_name FROM information_schema.tables WHERE table_schema='${TEST_DB}' AND table_name LIKE 'legacy_%' ORDER BY table_name;" | tail -n +2)
if [[ -z "$LEGACY_CHECK" ]]; then
    fail "Keine legacy_* Tabellen gefunden! Migration hat nicht funktioniert."
fi
echo "$LEGACY_CHECK" | while read -r tbl; do
    ok "$tbl"
done

# Prüfe ob neue Tabellen existieren
for tbl in categories tags posts post_tags newsletter_subscribers newsletter_send_log weekly_summaries users sessions; do
    EXISTS=$(mysql_test "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${TEST_DB}' AND table_name='${tbl}';" | tail -1 | tr -d '[:space:]')
    if [[ "$EXISTS" == "1" ]]; then
        ok "Neue Tabelle: $tbl"
    else
        fail "Neue Tabelle fehlt: $tbl"
    fi
done

# ─── Schritt 7: Datenmigration ───────────────────────────────────────

step "7/8  Datenmigration (Legacy → Laravel)"

# Immer zuerst Dry-Run
info "Dry-Run..."
DRYRUN_OUT=$(artisan "bcbeacon:migrate-legacy 2>&1")
echo "$DRYRUN_OUT" | while read -r line; do info "  $line"; done

if [[ "$DRY_RUN" == "true" ]]; then
    warn "Dry-Run Modus — Datenmigration wird nicht ausgeführt."
else
    info "Execute mit --with-admin..."
    EXEC_OUT=$(artisan "bcbeacon:migrate-legacy --execute --with-admin 2>&1")
    echo "$EXEC_OUT" | while read -r line; do info "  $line"; done
    ok "Datenmigration abgeschlossen"
fi

# ─── Schritt 8: Verifizierung ────────────────────────────────────────

step "8/8  Verifizierung"

if [[ "$DRY_RUN" == "false" ]]; then
    info "Zähle Datensätze in neuen Tabellen..."
    VERIFY=$(ssh_cmd "mysql -h ${DB_HOST} -u ${TEST_USER} -p'${TEST_PASS}' ${TEST_DB} -N -e \"
        SELECT 'posts', COUNT(*) FROM posts
        UNION ALL SELECT 'categories', COUNT(*) FROM categories
        UNION ALL SELECT 'tags', COUNT(*) FROM tags
        UNION ALL SELECT 'post_tags', COUNT(*) FROM post_tags
        UNION ALL SELECT 'newsletter_subscribers', COUNT(*) FROM newsletter_subscribers
        UNION ALL SELECT 'newsletter_send_log', COUNT(*) FROM newsletter_send_log
        UNION ALL SELECT 'weekly_summaries', COUNT(*) FROM weekly_summaries
        UNION ALL SELECT 'users', COUNT(*) FROM users;
    \" 2>/dev/null")

    echo ""
    echo -e "  ${BOLD}Tabelle                    Neue DB${NC}"
    echo -e "  ──────────────────────────────────"
    echo "$VERIFY" | while read -r table count; do
        printf "  %-26s %s\n" "$table" "$count"
    done

    # HTTP-Check
    echo ""
    info "HTTP-Checks..."
    for path in "/" "/api/posts" "/login"; do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${TEST_DOMAIN}${path}" 2>/dev/null || echo "000")
        if [[ "$HTTP_CODE" =~ ^(200|302)$ ]]; then
            ok "${path} → ${HTTP_CODE}"
        else
            warn "${path} → ${HTTP_CODE}"
        fi
    done

    # API-Post-Count
    API_COUNT=$(curl -s "${TEST_DOMAIN}/api/posts" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('meta',{}).get('total', d.get('total','?')))" 2>/dev/null || echo "?")
    info "API gibt ${API_COUNT} Posts zurück"
fi

# ─── Ergebnis ─────────────────────────────────────────────────────────

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${BOLD}║   ${YELLOW}DRY-RUN abgeschlossen${NC}${BOLD} (${DURATION}s)                       ║${NC}"
else
    echo -e "${BOLD}║   ${GREEN}UPGRADE TEST ERFOLGREICH${NC}${BOLD} (${DURATION}s)                    ║${NC}"
fi
echo -e "${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
