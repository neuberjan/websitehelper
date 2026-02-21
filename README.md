# BC Beacon — Website Helper

Tooling, Workflows und Setup-Skripte für [bcbeacon.de](https://bcbeacon.de).

## Struktur

```
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

## Verbundenes Repository

Die Live-Website liegt in einem separaten Repo und wird direkt auf `bcbeacon.de` deployed.
