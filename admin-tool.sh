#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# BC Beacon Admin Tool
# CLI-Wrapper für die Admin-API zur Verwaltung von
# Kategorien, Tags und Posts.
#
# Voraussetzungen: curl, jq
#
# Umgebungsvariablen:
#   BC_API_KEY  — Pflicht. API-Authentifizierungs-Schlüssel.
#   BC_API_URL  — Optional. API-Basis-URL
#                 (Standard: https://bcbeacon.de/api)
#
# Sicherheit:
#   - Der API-Key wird NIEMALS in Logs oder Ausgaben angezeigt.
#   - Alle Requests nutzen HTTPS.
#   - Authentifizierung über Bearer Token im Header.
# ═══════════════════════════════════════════════════════════

set -euo pipefail

# ── Farben (nur wenn Terminal interaktiv) ──
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' NC=''
fi

# ── Konfiguration ──
API_URL="${BC_API_URL:-https://bcbeacon.de/api}"
ADMIN_URL="${API_URL}/admin.php"

# ── Abhängigkeiten prüfen ──
check_deps() {
    local missing=()
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v jq   >/dev/null 2>&1 || missing+=("jq")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Fehler: Fehlende Abhängigkeiten: ${missing[*]}${NC}" >&2
        echo "Installieren mit: brew install ${missing[*]}" >&2
        exit 1
    fi
}

# ── API-Key prüfen ──
check_api_key() {
    if [[ -z "${BC_API_KEY:-}" ]]; then
        echo -e "${RED}Fehler: BC_API_KEY Umgebungsvariable nicht gesetzt.${NC}" >&2
        echo "" >&2
        echo "Setze den API-Key:" >&2
        echo "  export BC_API_KEY='dein-api-key-hier'" >&2
        echo "" >&2
        echo "Oder für einmalige Nutzung:" >&2
        echo "  BC_API_KEY='...' ./admin-tool.sh audit" >&2
        exit 1
    fi
}

# ── API-Request (GET) ──
api_get() {
    local url="$1"
    local response
    local http_code

    response=$(curl -sS -w "\n%{http_code}" \
        -H "Authorization: Bearer ${BC_API_KEY}" \
        -H "Accept: application/json" \
        "$url" 2>&1) || {
        echo -e "${RED}Fehler: Verbindung zu ${url} fehlgeschlagen.${NC}" >&2
        exit 1
    }

    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ge 400 ]]; then
        echo -e "${RED}API-Fehler (HTTP $http_code):${NC}" >&2
        echo "$body" | jq . 2>/dev/null || echo "$body" >&2
        exit 1
    fi

    echo "$body"
}

# ── API-Request (POST) ──
api_post() {
    local url="$1"
    local data="$2"
    local response
    local http_code

    response=$(curl -sS -w "\n%{http_code}" \
        -X POST \
        -H "Authorization: Bearer ${BC_API_KEY}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$data" \
        "$url" 2>&1) || {
        echo -e "${RED}Fehler: Verbindung zu ${url} fehlgeschlagen.${NC}" >&2
        exit 1
    }

    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ge 400 ]]; then
        echo -e "${RED}API-Fehler (HTTP $http_code):${NC}" >&2
        echo "$body" | jq . 2>/dev/null || echo "$body" >&2
        exit 1
    fi

    echo "$body"
}

# ── API-Request (PATCH) ──
api_patch() {
    local url="$1"
    local data="$2"
    local response
    local http_code

    response=$(curl -sS -w "\n%{http_code}" \
        -X PATCH \
        -H "Authorization: Bearer ${BC_API_KEY}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$data" \
        "$url" 2>&1) || {
        echo -e "${RED}Fehler: Verbindung zu ${url} fehlgeschlagen.${NC}" >&2
        exit 1
    }

    http_code=$(echo "$response" | tail -1)
    local body
    body=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ge 400 ]]; then
        echo -e "${RED}API-Fehler (HTTP $http_code):${NC}" >&2
        echo "$body" | jq . 2>/dev/null || echo "$body" >&2
        exit 1
    fi

    echo "$body"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Befehle
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cmd_audit() {
    echo -e "${BOLD}${BLUE}═══ BC Beacon Audit ═══${NC}"
    echo ""

    local result
    result=$(api_get "${ADMIN_URL}?action=audit")

    local count
    count=$(echo "$result" | jq '.issueCount')

    if [[ "$count" -eq 0 ]]; then
        echo -e "${GREEN}✓ Keine Probleme gefunden!${NC}"
        return
    fi

    echo -e "${YELLOW}⚠ ${count} Problem(e) gefunden:${NC}"
    echo ""

    echo "$result" | jq -r '.issues[] | 
        if .type == "english-category" then
            "  \(.severity | ascii_upcase) │ Kategorie │ \"\(.name)\" (ID: \(.id)) — Englischer Name"
        elif .type == "english-tag" then
            "  \(.severity | ascii_upcase) │ Tag       │ \"\(.name)\" (ID: \(.id)) — Englischer Name"
        elif .type == "orphan-category" then
            "  \(.severity | ascii_upcase) │ Kategorie │ \"\(.name)\" — Keine Posts zugeordnet"
        elif .type == "orphan-tag" then
            "  \(.severity | ascii_upcase) │ Tag       │ \"\(.name)\" — Keine Posts zugeordnet"
        elif .type == "unregistered-category" then
            "  \(.severity | ascii_upcase) │ Kategorie │ \"\(.name)\" — Existiert in Posts, aber nicht registriert"
        elif .type == "duplicate-category" then
            "  \(.severity | ascii_upcase) │ Kategorie │ \(.names | join(", ")) — Mögliche Duplikate"
        elif .type == "duplicate-tag" then
            "  \(.severity | ascii_upcase) │ Tag       │ \(.names | join(", ")) — Mögliche Duplikate"
        else
            "  \(.type) │ \(.suggestion)"
        end'

    echo ""
    echo -e "${CYAN}Tipp: Verwende 'merge-cat' oder 'merge-tag' um Duplikate zusammenzuführen.${NC}"
}

cmd_stats() {
    echo -e "${BOLD}${BLUE}═══ BC Beacon Statistiken ═══${NC}"
    echo ""

    local result
    result=$(api_get "${ADMIN_URL}?action=stats")

    local total
    total=$(echo "$result" | jq '.totalPosts')
    echo -e "${BOLD}Gesamtzahl Posts: ${total}${NC}"
    echo ""

    echo -e "${BOLD}Kategorien:${NC}"
    echo "$result" | jq -r '.categories[] | "  \(.name): \(.post_count) Posts"'
    echo ""

    echo -e "${BOLD}Tags:${NC}"
    echo "$result" | jq -r '.tags[] | "  \(.name): \(.post_count) Posts"'
}

cmd_categories() {
    echo -e "${BOLD}${BLUE}═══ Alle Kategorien ═══${NC}"
    echo ""

    local result
    result=$(api_get "${API_URL}/categories.php")

    echo "$result" | jq -r '.categories[] | "  ID \(.id) │ \(.name) │ \(.color // "—") │ slug: \(.slug)"'
    echo ""
    local total
    total=$(echo "$result" | jq '.total')
    echo -e "Gesamt: ${total}"
}

cmd_tags() {
    echo -e "${BOLD}${BLUE}═══ Alle Tags ═══${NC}"
    echo ""

    local result
    result=$(api_get "${API_URL}/tags.php?withCount=1")

    echo "$result" | jq -r '.tags[] | "  ID \(.id) │ \(.name) (\(.post_count // 0) Posts)"'
    echo ""
    local total
    total=$(echo "$result" | jq '.total')
    echo -e "Gesamt: ${total}"
}

cmd_merge_cat() {
    local from="${1:-}"
    local to="${2:-}"

    if [[ -z "$from" || -z "$to" ]]; then
        echo -e "${RED}Verwendung: $0 merge-cat <von> <nach>${NC}" >&2
        echo "  Beispiel: $0 merge-cat 'Development' 'Entwicklung'" >&2
        exit 1
    fi

    echo -e "${YELLOW}Kategorie zusammenführen: \"${from}\" → \"${to}\"${NC}"

    # Confirmation
    read -rp "Fortfahren? (j/N) " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        echo "Abgebrochen."
        exit 0
    fi

    local result
    result=$(api_post "${ADMIN_URL}?action=merge-category" \
        "$(jq -n --arg from "$from" --arg to "$to" '{from: $from, to: $to}')")

    echo ""
    echo -e "${GREEN}✓ Erfolgreich zusammengeführt!${NC}"
    echo "$result" | jq -r '"  Aktualisierte Posts: \(.updatedPosts)\n  Kategorie gelöscht: \(.deletedCategory)"'
}

cmd_merge_tag() {
    local from="${1:-}"
    local to="${2:-}"

    if [[ -z "$from" || -z "$to" ]]; then
        echo -e "${RED}Verwendung: $0 merge-tag <von> <nach>${NC}" >&2
        echo "  Beispiel: $0 merge-tag 'AI' 'KI'" >&2
        exit 1
    fi

    echo -e "${YELLOW}Tag zusammenführen: \"${from}\" → \"${to}\"${NC}"

    read -rp "Fortfahren? (j/N) " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        echo "Abgebrochen."
        exit 0
    fi

    local result
    result=$(api_post "${ADMIN_URL}?action=merge-tag" \
        "$(jq -n --arg from "$from" --arg to "$to" '{from: $from, to: $to}')")

    echo ""
    echo -e "${GREEN}✓ Erfolgreich zusammengeführt!${NC}"
    echo "$result" | jq -r '"  Verschobene Posts: \(.movedPosts)\n  Konflikte aufgelöst: \(.conflictResolved)\n  JSON aktualisiert: \(.jsonUpdated)"'
}

cmd_rename_cat() {
    local old="${1:-}"
    local new="${2:-}"

    if [[ -z "$old" || -z "$new" ]]; then
        echo -e "${RED}Verwendung: $0 rename-cat <alt> <neu>${NC}" >&2
        exit 1
    fi

    echo -e "${YELLOW}Kategorie umbenennen: \"${old}\" → \"${new}\"${NC}"

    read -rp "Fortfahren? (j/N) " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        echo "Abgebrochen."
        exit 0
    fi

    local result
    result=$(api_post "${ADMIN_URL}?action=rename-category" \
        "$(jq -n --arg name "$old" --arg newName "$new" '{name: $name, newName: $newName}')")

    echo ""
    echo -e "${GREEN}✓ Erfolgreich umbenannt!${NC}"
    echo "$result" | jq -r '"  Aktualisierte Posts: \(.updatedPosts)"'
}

cmd_rename_tag() {
    local old="${1:-}"
    local new="${2:-}"

    if [[ -z "$old" || -z "$new" ]]; then
        echo -e "${RED}Verwendung: $0 rename-tag <alt> <neu>${NC}" >&2
        exit 1
    fi

    echo -e "${YELLOW}Tag umbenennen: \"${old}\" → \"${new}\"${NC}"

    read -rp "Fortfahren? (j/N) " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        echo "Abgebrochen."
        exit 0
    fi

    local result
    result=$(api_post "${ADMIN_URL}?action=rename-tag" \
        "$(jq -n --arg name "$old" --arg newName "$new" '{name: $name, newName: $newName}')")

    echo ""
    echo -e "${GREEN}✓ Erfolgreich umbenannt!${NC}"
    echo "$result" | jq -r '"  JSON aktualisiert: \(.jsonUpdated)"'
}

cmd_update_post() {
    local id="${1:-}"
    local category="${2:-}"
    shift 2 2>/dev/null || true
    local tags=("$@")

    if [[ -z "$id" ]]; then
        echo -e "${RED}Verwendung: $0 update-post <id> [kategorie] [tag1 tag2 ...]${NC}" >&2
        echo "  Beispiel: $0 update-post 5 KI Azure Copilot" >&2
        exit 1
    fi

    local json_data
    if [[ -n "$category" && ${#tags[@]} -gt 0 ]]; then
        local tags_json
        tags_json=$(printf '%s\n' "${tags[@]}" | jq -R . | jq -s .)
        json_data=$(jq -n --argjson id "$id" --arg cat "$category" --argjson tags "$tags_json" \
            '{id: $id, category: $cat, tags: $tags}')
    elif [[ -n "$category" ]]; then
        json_data=$(jq -n --argjson id "$id" --arg cat "$category" '{id: $id, category: $cat}')
    else
        echo -e "${RED}Mindestens eine Kategorie oder Tags angeben.${NC}" >&2
        exit 1
    fi

    echo -e "${YELLOW}Post #${id} aktualisieren...${NC}"

    local result
    result=$(api_post "${ADMIN_URL}?action=update-post" "$json_data")

    echo ""
    echo -e "${GREEN}✓ Post aktualisiert!${NC}"
    echo "$result" | jq '.changes'
}

cmd_cleanup() {
    local dry_run="${1:-}"

    echo -e "${BOLD}${BLUE}═══ Verwaiste Einträge bereinigen ═══${NC}"
    echo ""

    # First do a dry run
    local preview
    preview=$(api_post "${ADMIN_URL}?action=cleanup-orphans" '{"dryRun": true}')

    local orphan_cats orphan_tags
    orphan_cats=$(echo "$preview" | jq -r '.orphanCategories | length')
    orphan_tags=$(echo "$preview" | jq -r '.orphanTags | length')

    if [[ "$orphan_cats" -eq 0 && "$orphan_tags" -eq 0 ]]; then
        echo -e "${GREEN}✓ Keine verwaisten Einträge gefunden.${NC}"
        return
    fi

    echo "Verwaiste Kategorien ($orphan_cats):"
    echo "$preview" | jq -r '.orphanCategories[] | "  - \(.)"'
    echo ""
    echo "Verwaiste Tags ($orphan_tags):"
    echo "$preview" | jq -r '.orphanTags[] | "  - \(.)"'
    echo ""

    if [[ "$dry_run" == "--dry-run" ]]; then
        echo -e "${CYAN}(Trockenlauf — keine Änderungen vorgenommen)${NC}"
        return
    fi

    read -rp "Alle verwaisten Einträge löschen? (j/N) " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        echo "Abgebrochen."
        exit 0
    fi

    local result
    result=$(api_post "${ADMIN_URL}?action=cleanup-orphans" '{"dryRun": false}')

    echo -e "${GREEN}✓ Bereinigung abgeschlossen!${NC}"
    echo "$result" | jq -r '"  Gelöschte Kategorien: \(.deletedCategories | length)\n  Gelöschte Tags: \(.deletedTags | length)"'
}

cmd_set_source() {
    local source="${1:-}"
    local flag="${2:-}"
    local value="${3:-}"
    local auto_confirm="${4:-}"

    if [[ -z "$source" || -z "$flag" || -z "$value" ]]; then
        echo -e "${RED}Verwendung: $0 set-source <autor> --url <muster> [--yes]${NC}" >&2
        echo -e "${RED}       oder: $0 set-source <autor> --from <alter-autor> [--yes]${NC}" >&2
        echo "" >&2
        echo "  Beispiel: $0 set-source 'Twity' --url 'twity'" >&2
        echo "  Beispiel: $0 set-source 'Twity' --from 'Unbekannt' --yes" >&2
        exit 1
    fi

    local json_data
    case "$flag" in
        --url)
            json_data=$(jq -n --arg source "$source" --arg url "$value" \
                '{source: $source, urlContains: $url, dryRun: true}')
            ;;
        --from)
            json_data=$(jq -n --arg source "$source" --arg from "$value" \
                '{source: $source, from: $from, dryRun: true}')
            ;;
        *)
            echo -e "${RED}Unbekanntes Flag: ${flag}. Verwende --url oder --from.${NC}" >&2
            exit 1
            ;;
    esac

    echo -e "${BOLD}${BLUE}═══ Autor/Quelle setzen ═══${NC}"
    echo ""

    # Dry run first
    local preview
    preview=$(api_post "${ADMIN_URL}?action=set-source" "$json_data")

    local count
    count=$(echo "$preview" | jq '.matchingCount')

    if [[ "$count" -eq 0 ]]; then
        echo -e "${YELLOW}Keine passenden Posts gefunden.${NC}"
        return
    fi

    echo -e "Neuer Autor: ${BOLD}${source}${NC}"
    echo -e "Betroffene Posts: ${count}"
    echo ""
    echo "$preview" | jq -r '.matchingPosts[] | "  ID \(.id) │ \(.source) │ \(.title)"'
    echo ""

    if [[ "$auto_confirm" != "--yes" ]]; then
        read -rp "Autor für diese ${count} Posts auf \"${source}\" setzen? (j/N) " confirm
        if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
            echo "Abgebrochen."
            exit 0
        fi
    fi

    # Execute
    local exec_data
    case "$flag" in
        --url)
            exec_data=$(jq -n --arg source "$source" --arg url "$value" \
                '{source: $source, urlContains: $url}')
            ;;
        --from)
            exec_data=$(jq -n --arg source "$source" --arg from "$value" \
                '{source: $source, from: $from}')
            ;;
    esac

    local result
    result=$(api_post "${ADMIN_URL}?action=set-source" "$exec_data")

    echo ""
    echo -e "${GREEN}✓ Autor aktualisiert!${NC}"
    echo "$result" | jq -r '"  Aktualisierte Posts: \(.updatedPosts)"'
}

# ── set-colors: Alle Kategoriefarben setzen ──
cmd_set_colors() {
    echo -e "${BOLD}${BLUE}═══ Kategoriefarben setzen ═══${NC}"
    echo ""

    # Curated color palette matching the design system
    local color_data='[
        {"name": "Development",     "color": "#7c3aed"},
        {"name": "Administration",  "color": "#d97706"},
        {"name": "Integration",     "color": "#059669"},
        {"name": "Performance",     "color": "#db2777"},
        {"name": "Security",        "color": "#dc2626"},
        {"name": "News",            "color": "#0284c7"},
        {"name": "Other",           "color": "#0d9488"},
        {"name": "Release",         "color": "#4f6ef7"},
        {"name": "Cloud",           "color": "#d97706"},
        {"name": "KI",              "color": "#db2777"},
        {"name": "DevOps",          "color": "#7c3aed"},
        {"name": "Community",       "color": "#0d9488"},
        {"name": "Konferenz",       "color": "#0d9488"},
        {"name": "Troubleshooting", "color": "#dc2626"},
        {"name": "Azure",           "color": "#0284c7"},
        {"name": "Licensing",       "color": "#d97706"},
        {"name": "Power Platform",  "color": "#059669"},
        {"name": "Reporting",       "color": "#7c3aed"},
        {"name": "Testing",         "color": "#db2777"},
        {"name": "Upgrade",         "color": "#0284c7"},
        {"name": "Workflow",        "color": "#059669"},
        {"name": "Migration",       "color": "#d97706"},
        {"name": "Data Management", "color": "#0d9488"},
        {"name": "API",             "color": "#4f6ef7"}
    ]'

    local count
    count=$(echo "$color_data" | jq 'length')
    echo -e "Setze Farben für ${BOLD}${count}${NC} Kategorien..."
    echo ""

    # Preview
    echo "$color_data" | jq -r '.[] | "  \(.color) │ \(.name)"'
    echo ""

    local auto_confirm="${1:-}"
    if [[ "$auto_confirm" != "--yes" ]]; then
        read -rp "Farben setzen? (j/N) " confirm
        if [[ "$confirm" != "j" && "$confirm" != "J" ]]; then
            echo -e "${YELLOW}Abgebrochen.${NC}"
            return
        fi
    fi

    local result
    result=$(api_patch "${API_URL}/categories.php" "$color_data")

    echo ""
    echo -e "${GREEN}✓ Farben aktualisiert!${NC}"
    echo "$result" | jq -r '"  Aktualisiert: \(.updated) von \(.total)"'
    if echo "$result" | jq -e '.errors | length > 0' >/dev/null 2>&1; then
        echo -e "${YELLOW}  Hinweise:${NC}"
        echo "$result" | jq -r '.errors[] | "  ⚠ \(.)"'
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Hilfe
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_help() {
    cat <<EOF
${BOLD}BC Beacon Admin Tool${NC}

${BOLD}Verwendung:${NC}
  $0 <befehl> [argumente]

${BOLD}Umgebungsvariablen:${NC}
  BC_API_KEY   Pflicht. API-Authentifizierungs-Schlüssel.
  BC_API_URL   Optional. API-Basis-URL (Standard: https://bcbeacon.de/api)

${BOLD}Befehle:${NC}

  ${CYAN}Analyse:${NC}
    audit                         Probleme und Duplikate finden
    stats                         Kategorie-/Tag-Statistiken anzeigen
    categories                    Alle Kategorien auflisten
    tags                          Alle Tags auflisten

  ${CYAN}Zusammenführen:${NC}
    merge-cat <von> <nach>        Kategorie zusammenführen
    merge-tag <von> <nach>        Tag zusammenführen

  ${CYAN}Umbenennen:${NC}
    rename-cat <alt> <neu>        Kategorie umbenennen
    rename-tag <alt> <neu>        Tag umbenennen

  ${CYAN}Posts:${NC}
    update-post <id> <kat> [tags] Post-Kategorie/Tags aktualisieren

  ${CYAN}Autoren:${NC}
    set-source <autor> --url <muster>   Autor anhand URL-Muster setzen
    set-source <autor> --from <alt>     Autor anhand altem Namen ändern

  ${CYAN}Farben:${NC}
    set-colors [--yes]                  Kategoriefarben setzen (Bulk)

  ${CYAN}Bereinigung:${NC}
    cleanup [--dry-run]           Verwaiste Kategorien/Tags löschen

${BOLD}Beispiele:${NC}
  $0 audit
  $0 merge-cat 'Development' 'Entwicklung'
  $0 merge-tag 'AI' 'KI'
  $0 rename-cat 'Devlopment' 'Entwicklung'
  $0 update-post 5 KI Azure Copilot
  $0 set-source 'Twity' --url 'twity'
  $0 set-source 'Twity' --from 'Unbekannt'
  $0 set-colors --yes
  $0 cleanup --dry-run

EOF
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Main
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    check_deps
    check_api_key

    local command="${1:-help}"
    shift 2>/dev/null || true

    case "$command" in
        audit)        cmd_audit ;;
        stats)        cmd_stats ;;
        categories)   cmd_categories ;;
        tags)         cmd_tags ;;
        merge-cat)    cmd_merge_cat "$@" ;;
        merge-tag)    cmd_merge_tag "$@" ;;
        rename-cat)   cmd_rename_cat "$@" ;;
        rename-tag)   cmd_rename_tag "$@" ;;
        update-post)  cmd_update_post "$@" ;;
        set-source)   cmd_set_source "$@" ;;
        set-colors)   cmd_set_colors "$@" ;;
        cleanup)      cmd_cleanup "$@" ;;
        help|--help|-h)
            show_help ;;
        *)
            echo -e "${RED}Unbekannter Befehl: ${command}${NC}" >&2
            echo "Verwende '$0 help' für eine Übersicht." >&2
            exit 1 ;;
    esac
}

main "$@"
