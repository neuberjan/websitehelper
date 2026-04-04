# BC Beacon — Website Helper

Tooling, Workflows und Setup-Skripte für [bcbeacon.de](https://bcbeacon.de).

## Struktur

```
├── deploy/                 # Deployment & Upgrade-Tools
│   ├── reset-and-upgrade-test.sh    # Wiederholbarer Upgrade-Test (Live→Laravel)
│   └── UPGRADE-PLAN.md             # Upgrade-Dokumentation
├── n8n/                    # n8n Workflow-Dateien
│   ├── BC MVP Weekly News-10.json   # Haupt-Workflow
│   └── _validate.py                 # Workflow-Validierung
├── db/                     # Datenbank-Setup
│   ├── schema.sql                   # DB-Schema
│   └── setup_db.php                 # Setup-Skript
├── docs/                   # Dokumentation
│   └── SETUP-NETCUP.md             # Server-Setup Netcup
└── admin-tool.sh           # Admin-CLI für die REST-API
```

## Nutzung

### n8n Workflow validieren
```bash
cd n8n
python3 _validate.py
# oder: python3 _validate.py <workflow-datei.json>
```

### Admin-Tool
```bash
./admin-tool.sh help
./admin-tool.sh audit
./admin-tool.sh stats
./admin-tool.sh categories
```

### Datenbank einrichten
Schema importieren und `setup_db.php` ausführen – siehe [docs/SETUP-NETCUP.md](docs/SETUP-NETCUP.md).

### Laravel Upgrade testen

> **Hinweis:** Das Testsystem (hosting236825.ae84c.netcup.net) wird nicht mehr für BC Beacon genutzt — dort läuft jetzt die Lyst-API. Diese Scripts sind daher obsolet.

```bash
# Kompletter Testlauf: Frische Live-DB → Laravel-Upgrade
./deploy/reset-and-upgrade-test.sh

# Nur Dry-Run (keine Daten schreiben)
./deploy/reset-and-upgrade-test.sh --dry-run

# Ohne neuen DB-Dump (schneller, nutzt bestehende Test-DB)
./deploy/reset-and-upgrade-test.sh --skip-dump
```
Siehe [deploy/UPGRADE-PLAN.md](deploy/UPGRADE-PLAN.md) für den vollständigen Upgrade-Plan.

## Verbundenes Repository

Die Live-Website liegt in einem separaten Repo und wird direkt auf `bcbeacon.de` deployed.
