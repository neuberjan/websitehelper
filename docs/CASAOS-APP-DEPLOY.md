# CasaOS App-Deployment via docker compose

So deployst du eine neue App auf dem Raspberry Pi 5 (CasaOS) ohne die Web-UI — direkt per SSH und docker compose.

## Voraussetzungen

- SSH-Zugang als `copilot` (siehe CREDENTIALS.md)
- Docker compose-Datei mit korrektem `x-casaos`-Block (siehe Format weiter unten)
- Image idealerweise schon auf dem Pi vorhanden (`docker pull …`)

---

## Schritt-für-Schritt

### 1. App-Verzeichnis anlegen & Compose-Datei platzieren

CasaOS registriert Apps automatisch, wenn eine `docker-compose.yml` unter `/var/lib/casaos/apps/<app-name>/` liegt.

```bash
# Verzeichnis anlegen
echo '***REMOVED***' | sudo -S mkdir -p /var/lib/casaos/apps/<app-name>

# Compose-Datei hineinkopieren (vom Mac aus)
cat docker-compose-<app-name>.yml | sshpass -p '***REMOVED***' ssh copilot@192.168.2.133 \
  "cat > /tmp/compose.yml && echo '***REMOVED***' | sudo -S cp /tmp/compose.yml /var/lib/casaos/apps/<app-name>/docker-compose.yml"

# Ownership korrigieren (root muss Owner sein)
echo '***REMOVED***' | sudo -S chown -R root:root /var/lib/casaos/apps/<app-name>
```

### 2. Container starten

```bash
echo '***REMOVED***' | sudo -S docker compose \
  -f /var/lib/casaos/apps/<app-name>/docker-compose.yml up -d
```

### 3. CasaOS App-Management neu starten

Damit die App in der CasaOS-UI erscheint:

```bash
echo '***REMOVED***' | sudo -S systemctl restart casaos-app-management.service
```

Danach erscheint die App in der CasaOS-UI unter `http://192.168.2.133:80`.

---

## Alles in einem Befehl (vom Mac aus)

```bash
cat docker-compose-<app-name>.yml | sshpass -p '***REMOVED***' ssh copilot@192.168.2.133 "
  cat > /tmp/compose.yml
  echo '***REMOVED***' | sudo -S mkdir -p /var/lib/casaos/apps/<app-name>
  echo '***REMOVED***' | sudo -S cp /tmp/compose.yml /var/lib/casaos/apps/<app-name>/docker-compose.yml
  echo '***REMOVED***' | sudo -S chown -R root:root /var/lib/casaos/apps/<app-name>
  echo '***REMOVED***' | sudo -S docker compose -f /var/lib/casaos/apps/<app-name>/docker-compose.yml up -d
  echo '***REMOVED***' | sudo -S systemctl restart casaos-app-management.service
"
```

---

## App entfernen

```bash
sshpass -p '***REMOVED***' ssh copilot@192.168.2.133 "
  echo '***REMOVED***' | sudo -S docker compose -f /var/lib/casaos/apps/<app-name>/docker-compose.yml down
  echo '***REMOVED***' | sudo -S rm -rf /var/lib/casaos/apps/<app-name>
  echo '***REMOVED***' | sudo -S systemctl restart casaos-app-management.service
"
```

---

## Compose-Datei Format für CasaOS

Das Format orientiert sich an bestehenden CasaOS-Apps (z.B. n8n). Wichtig:

- `network_mode: bridge` statt Standard-Netzwerk
- `deploy.resources.limits/reservations` für Speicherlimits (in Bytes)
- `cpu_shares: 90` als Standard
- `labels.icon` für das App-Icon in der UI
- `x-casaos` Block **sowohl** im Service als auch auf Top-Level

```yaml
name: <app-name>

services:
  <service-name>:
    cpu_shares: 90
    command: []
    container_name: <app-name>
    deploy:
      resources:
        limits:
          memory: "2147483648"       # 2 GB in Bytes
        reservations:
          memory: "536870912"        # 512 MB in Bytes
    environment:
      MY_VAR: wert
    hostname: <app-name>
    image: <image>:latest
    labels:
      icon: https://example.com/icon.png
    network_mode: bridge
    ports:
      - target: 8080
        published: "8080"
        protocol: tcp
    restart: unless-stopped
    volumes:
      - type: bind
        source: /DATA/AppData/<app-name>
        target: /data
    x-casaos:
      envs:
        - container: MY_VAR
          description:
            en_us: Description of the variable
            de_de: Beschreibung der Variable
      ports:
        - container: "8080"
          description:
            en_us: Web UI port
            de_de: Web-UI Port
      volumes:
        - container: /data
          description:
            en_us: Data directory
            de_de: Datenverzeichnis

x-casaos:
  architectures:
    - amd64
    - arm64
  author: Jan Neuber
  category: Utilities
  description:
    en_us: "English description"
    de_de: "Deutsche Beschreibung"
  icon: https://example.com/icon.png
  index: /          # Pfad der im Browser geöffnet wird (z.B. /ui oder /playground)
  port_map: "8080"
  title:
    en_us: App Name
    de_de: App Name
  developer: Developer Name
  tagline:
    en_us: Short tagline
    de_de: Kurzer Slogan
```

### Speicherlimits in Bytes (Referenz)

| RAM   | Bytes          |
|-------|----------------|
| 512 MB | `536870912`   |
| 1 GB  | `1073741824`   |
| 2 GB  | `2147483648`   |
| 3 GB  | `3221225472`   |
| 4 GB  | `4294967296`   |
| 8 GB  | `8589934592`   |

### Hinweise

- **RAM-Limits** werden auf dem RPi 5 ignoriert (cgroup nicht gemountet) — stören aber nicht.
- **Daten** immer unter `/DATA/AppData/<app-name>/` ablegen (CasaOS-Konvention).
- **Image vorher pullen** verhindert Timeouts beim Start: `docker pull <image>:latest`
