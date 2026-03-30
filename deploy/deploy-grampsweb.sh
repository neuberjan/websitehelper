#!/bin/bash
source ~/.bcbeacon-secrets

sshpass -p "$PI_PASS" ssh -o StrictHostKeyChecking=no copilot@192.168.2.133 << EOF
  cat > /tmp/compose.yml << 'INNEREOF'
$(cat deploy/docker-compose-grampsweb.yml)
INNEREOF
  echo "$PI_PASS" | sudo -S mkdir -p /var/lib/casaos/apps/grampsweb
  echo "$PI_PASS" | sudo -S cp /tmp/compose.yml /var/lib/casaos/apps/grampsweb/docker-compose.yml
  echo "$PI_PASS" | sudo -S chown -R root:root /var/lib/casaos/apps/grampsweb
  echo "$PI_PASS" | sudo -S docker compose -f /var/lib/casaos/apps/grampsweb/docker-compose.yml up -d
  echo "$PI_PASS" | sudo -S systemctl restart casaos-app-management.service
EOF
