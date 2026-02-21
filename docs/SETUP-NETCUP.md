# BC Beacon — Netcup Server-Setup

## Wie funktioniert es?

Credentials stehen **nicht** im Git-Repo. Stattdessen gibt es eine Datei `config.local.php`, die **nur auf dem Server** existiert und von `.gitignore` ausgeschlossen ist. Die PHP-Dateien laden sie automatisch, falls vorhanden.

---

## 1. `config.local.php` auf dem Server erstellen

Nach dem Deployment (git pull) erstellst du **einmalig** die Datei `config.local.php` im **Root der Website** (dort wo `index.html` liegt).

### Per Plesk Dateimanager:
1. **Plesk** → **Websites & Domains** → **Dateimanager**
2. Ins Document Root navigieren (`httpdocs/`)
3. **Neue Datei** → Name: `config.local.php`
4. Inhalt einfügen:

```php
<?php
// ── Datenbank ──
putenv('DB_HOST=10.35.232.77');
putenv('DB_PORT=3306');
putenv('DB_NAME=k349529_bcnews');
putenv('DB_USER=k349529_bcnews');
putenv('DB_PASS=DEIN_DB_PASSWORT');

// ── API-Key für Write-Endpoint (n8n) ──
putenv('BC_API_KEY=DEIN_API_KEY');

// ── CORS: Erlaubte Domain ──
putenv('ALLOWED_ORIGIN=https://deine-domain.de');
```

5. **Speichern**

> **Diese Datei wird von Git ignoriert** — sie überlebt jeden `git pull`.

---

## 2. API-Key & Passwort

Da die alten Werte im Git-Verlauf standen (wurden entfernt), solltest du sie sicherheitshalber rotieren:

### Neuen API-Key generieren (Terminal):
```bash
uuidgen
# Beispiel: A1B2C3D4-E5F6-7890-ABCD-EF1234567890
```

Diesen Key an zwei Stellen eintragen:
1. **`config.local.php`** auf dem Server (`BC_API_KEY`)
2. **n8n Workflow** → HTTP-Request-Node → Header `Authorization: Bearer NEUER_KEY`

### DB-Passwort ändern (empfohlen):
1. **Plesk** → Websites & Domains → Datenbanken → Benutzer → Passwort ändern
2. Neues Passwort in `config.local.php` eintragen

---

## 3. Schutz prüfen

Die `.htaccess` im Repo blockiert bereits den Zugriff auf `config.local.php` und andere sensible Dateien. Nach dem Deployment testen:

```
https://deine-domain.de/config.local.php  → muss 403 Forbidden zeigen
https://deine-domain.de/db_config.php     → muss 403 Forbidden zeigen
```

---

## Checkliste

- [ ] `git pull` auf dem Server ausgeführt
- [ ] `config.local.php` im Document Root erstellt
- [ ] DB-Zugangsdaten eingetragen (ggf. neues Passwort)
- [ ] Neuen API-Key generiert und eingetragen
- [ ] Gleichen API-Key in n8n Workflow aktualisiert
- [ ] `ALLOWED_ORIGIN` auf eigene Domain gesetzt
- [ ] `config.local.php` im Browser nicht abrufbar (403-Test!)
- [ ] Website testen: Posts laden, Favicon
- [ ] n8n testen: Neuer Post schreiben funktioniert

---

## Variablen-Übersicht

| Variable | Wo gesetzt | Beschreibung |
|---|---|---|
| `DB_HOST` | `config.local.php` | Datenbank-Host (IP) |
| `DB_PORT` | `config.local.php` | Datenbank-Port (Standard: 3306) |
| `DB_NAME` | `config.local.php` | Datenbankname |
| `DB_USER` | `config.local.php` | DB-Benutzername |
| `DB_PASS` | `config.local.php` | DB-Passwort |
| `BC_API_KEY` | `config.local.php` + n8n | API-Key für Write-Endpoint |
| `ALLOWED_ORIGIN` | `config.local.php` | Erlaubte Domain für CORS |
