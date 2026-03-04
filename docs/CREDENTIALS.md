# Zugangsdaten & Infrastruktur-Übersicht

> **ACHTUNG:** Diese Datei enthält Passwörter. Nicht committen / nicht öffentlich teilen!

---

## Raspberry Pi 5 (CasaOS)

- **IP:** `192.168.2.133`
- **OS:** Raspberry Pi OS + CasaOS
- **Speicher:** 117 GB NVMe (`/dev/nvme0n1p2`), davon ~79 GB frei

### SSH-Zugänge

| Benutzer | Passwort | Zweck | sudo |
|----------|----------|-------|------|
| `jan` | *(nur Jan bekannt)* | Admin-Zugang (manuell) | ja |
| `copilot` | `***REMOVED***` | Copilot-Automatisierung (Scripts, Backups) | ja |

```bash
# Copilot-SSH
sshpass -p '***REMOVED***' ssh copilot@192.168.2.133

# Oder (interaktiv)
ssh copilot@192.168.2.133
```

### CasaOS Web-UI & API

| Eigenschaft | Wert |
|-------------|------|
| URL | `http://192.168.2.133:80` |
| Benutzername | `admin` |
| Passwort | `***REMOVED***` |
| Auth-Methode | JWT-Token im `Authorization`-Header (OHNE `Bearer`-Prefix) |

```bash
# Login → Token holen
curl -s -X POST http://192.168.2.133:80/v1/users/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"***REMOVED***"}'

# API-Aufrufe mit Token
curl -s http://192.168.2.133:80/v2/app_management/compose \
  -H "Authorization: <TOKEN>"
```

### Installierte Container-Apps

| App-ID | Service | Daten-Pfad (Host) | Port |
|--------|---------|-------------------|------|
| `n8n` | n8n | `/DATA/AppData/n8n` | 5678 |
| `qdrant-pi5` | qdrant | `/DATA/AppData/qdrant/storage`, `/DATA/AppData/qdrant/snapshots` | 6333 |
| `radiant_nico` | ollama | `/DATA/AppData/ollama` | 11434 |
| `stunning_sultan` | openedai-speech | `/DATA/AppData/openedai-speech/app/config` | – |

Weitere Apps in `/DATA/AppData/`:
- `big-bear-open-webui`
- `big-bear-stirling-pdf`
- `devhelper`, `DevHelperNginx`
- `kokoro`, `opentts`, `piper`, `piper-http`

---

## FRITZ.NAS (SMB/CIFS)

- **Hostname:** `fritz.nas` / via Finder oder `mount_smbfs`

### NAS-Benutzer

| Benutzer | Passwort | Zweck |
|----------|----------|-------|
| `BackupDocker` | `***REMOVED***` | Automatisierte Backups (Pi → NAS) |
| `copilot` | `***REMOVED***` | Copilot-Arbeitsdateien (Exports, Temp, Logs) |

```bash
# NAS als BackupDocker mounten (für Backups)
mount_smbfs //BackupDocker:***REMOVED***@fritz.nas/BackupDocker /mnt/backup

# NAS als Copilot mounten (für Arbeitsdateien)
mount_smbfs //copilot:***REMOVED***@fritz.nas/FRITZ.NAS /Volumes/FRITZ.NAS
```

---

## Service-URLs (Schnellzugriff)

| Service | URL |
|---------|-----|
| CasaOS | http://192.168.2.133:80 |
| n8n | http://192.168.2.133:5678 |
| Ollama | http://192.168.2.133:11434 |
| Qdrant | http://192.168.2.133:6333 |

---

## Backup

### Manuelles Backup (vom Mac aus)

```bash
sshpass -p '***REMOVED***' ssh copilot@192.168.2.133 "bash /home/copilot/backup-docker.sh"
```

- Script auf dem Pi: `/home/copilot/backup-docker.sh`
- Sichert: Alle `/DATA/AppData/*` Apps, Docker Volumes, CasaOS-Config, Compose-Dateien
- Ziel: `FRITZ.NAS → T7/Backup/pi-docker/<DATUM>/`
- Alte Backups (>7 Tage) werden automatisch gelöscht
- Erstes Backup: **2026-03-01** (8.8 GB)

### Tägliches Backup per Cron (optional)

Falls gewünscht, auf dem Pi als copilot-User einrichten:

```bash
# SSH auf den Pi
sshpass -p '***REMOVED***' ssh copilot@192.168.2.133

# Crontab öffnen
crontab -e

# Täglich um 03:00 Uhr Backup ausführen:
0 3 * * * /home/copilot/backup-docker.sh >> /home/copilot/backup-cron.log 2>&1
```

---

---

## Netcup / Plesk (Test-Server)

- **IP:** `202.61.232.76`
- **SSH-User:** `hosting236825`
- **SSH-Passwort:** `***REMOVED***`
- **DocumentRoot:** `/hosting236825.ae84c.netcup.net/httpdocs/`
- **Test-Domain:** `https://hosting236825.ae84c.netcup.net`
- **Live-Domain:** `https://bcbeacon.de`

### Test-Datenbank

| Eigenschaft | Wert |
|-------------|------|
| **Host** | `10.35.232.77:3306` |
| **Name** | `k349529_bcnewstest` |
| **User** | `k349529_bcnewstest` |
| **Passwort** | `***REMOVED***` |

### Live-Datenbank

| Eigenschaft | Wert |
|-------------|------|
| **Host** | `10.35.232.77:3306` |
| **Name** | `k349529_bcnews` |
| **User** | `k349529_bcnews` |
| **Passwort** | `***REMOVED***` |

### SMTP (Newsletter)

| Eigenschaft | Wert |
|-------------|------|
| **Host** | `mxe84e.netcup.net:465` |
| **User** | `newsletter@bcbeacon.de` |
| **Passwort** | `***REMOVED***` |
| **Encryption** | SSL |

### Laravel Admin

| Eigenschaft | Wert |
|-------------|------|
| **E-Mail** | `admin@bcbeacon.de` |
| **Passwort** | `***REMOVED***` |

### API-Key

```
***REMOVED***
```

**Verwendung:** Header `X-API-Key: ***REMOVED***`

---

## Regeln

- **`jan`** → Admin, nur manuell, Passwort nicht gespeichert
- **`copilot`** → Für alle automatisierten Copilot-Aktionen (SSH, Backups, Scripts)
- **`BackupDocker`** → Nur für Backup-Transfers zum NAS
- **`copilot` (NAS)** → Für Copilot-Arbeitsdateien auf dem NAS
- **Netcup-Passwörter** → Nur in dieser Datei, nicht in Git committen
- Keine Passwörter in Git committen (`.gitignore` prüfen!)
