#!/bin/bash

################################################################################
# Script de Déploiement Automatique - Stack Monitoring Complète
# Loki + Grafana + Alertmanager + SNMP
################################################################################

set -e  # Arrêter en cas d'erreur

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables
STACK_NAME="monitoring-stack-complete"
INSTALL_DIR="$HOME/projectRims/test/$STACK_NAME"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Déploiement Stack Monitoring Complète                    ║${NC}"
echo -e "${BLUE}║      Loki + Grafana + Alertmanager + SNMP                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}\n"

################################################################################
# ÉTAPE 1 : Vérification des prérequis
################################################################################

echo -e "${CYAN}[1/10] Vérification des prérequis...${NC}"

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker n'est pas installé${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker installé${NC}"

# Vérifier Docker Compose
if ! docker compose version &> /dev/null; then
    echo -e "${RED}✗ Docker Compose V2 n'est pas installé${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose V2 installé${NC}"

# Vérifier les ports disponibles
REQUIRED_PORTS=(3000 3100 9093 9464 8888 162 8080 12345)
for PORT in "${REQUIRED_PORTS[@]}"; do
    if sudo lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ Port $PORT déjà utilisé${NC}"
    fi
done

################################################################################
# ÉTAPE 2 : Création de la structure des répertoires
################################################################################

echo -e "\n${CYAN}[2/10] Création de la structure des répertoires...${NC}"

# Créer le répertoire principal
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Créer tous les sous-répertoires
mkdir -p loki/rules/fake
mkdir -p grafana/provisioning/datasources
mkdir -p grafana/provisioning/dashboards
mkdir -p alertmanager
mkdir -p alloy
mkdir -p snmptrapd
mkdir -p trap-viewer

echo -e "${GREEN}✓ Structure créée dans $INSTALL_DIR${NC}"

################################################################################
# ÉTAPE 3 : Création du docker-compose.yml
################################################################################

echo -e "\n${CYAN}[3/10] Création du docker-compose.yml...${NC}"

cat > docker-compose.yml << 'EOF'
networks:
  monitoring:
    driver: bridge

volumes:
  loki-data:
  grafana-data:

services:
  # Loki - Stockage et analyse de logs
  loki:
    image: grafana/loki:2.9.3
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki/loki-config.yml:/etc/loki/config.yml
      - ./loki/rules:/loki/rules
      - loki-data:/loki
    command: -config.file=/etc/loki/config.yml
    networks:
      - monitoring
    restart: unless-stopped

  # Alloy - Collecteur de logs
  alloy:
    image: grafana/alloy:latest
    container_name: alloy
    ports:
      - "12345:12345"
    volumes:
      - ./alloy/config.alloy:/etc/alloy/config.alloy
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/log:/var/log:ro
    command: run --server.http.listen-addr=0.0.0.0:12345 --storage.path=/var/lib/alloy/data /etc/alloy/config.alloy
    networks:
      - monitoring
    restart: unless-stopped

  # Grafana - Visualisation
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=false
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    networks:
      - monitoring
    restart: unless-stopped

  # Alertmanager - Gestion des alertes
  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    ports:
      - "9093:9093"
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    networks:
      - monitoring
    restart: unless-stopped

  # SNMP Notifier - Conversion alertes → SNMP
  snmp-notifier:
    image: maxwo/snmp-notifier:latest
    container_name: snmp-notifier
    ports:
      - "9464:9464"
    environment:
      - SNMP_NOTIFIER_COMMUNITY=public
      - SNMP_NOTIFIER_SNMP_DESTINATION=snmptrapd:162
    networks:
      - monitoring
    restart: unless-stopped

  # SNMPtrapd - Réception des traps
  snmptrapd:
    build:
      context: ./snmptrapd
      dockerfile: Dockerfile
    container_name: snmptrapd
    ports:
      - "162:162/udp"
    networks:
      - monitoring
    restart: unless-stopped

  # Trap Viewer - Interface web pour visualiser les traps
  trap-viewer:
    build:
      context: ./trap-viewer
      dockerfile: Dockerfile
    container_name: trap-viewer
    ports:
      - "8888:8888"
    volumes:
      - ./trap-viewer/traps:/app/traps
    networks:
      - monitoring
    restart: unless-stopped

  # Nginx Demo - Application de test
  nginx-demo:
    image: nginx:alpine
    container_name: nginx-demo
    ports:
      - "8080:80"
    networks:
      - monitoring
    restart: unless-stopped
EOF

echo -e "${GREEN}✓ docker-compose.yml créé${NC}"

################################################################################
# ÉTAPE 4 : Configuration Loki
################################################################################

echo -e "\n${CYAN}[4/10] Configuration de Loki...${NC}"

cat > loki/loki-config.yml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

ruler:
  storage:
    type: local
    local:
      directory: /loki/rules
  rule_path: /loki/rules-temp
  alertmanager_url: http://alertmanager:9093
  ring:
    kvstore:
      store: inmemory
  enable_api: true
  enable_alertmanager_v2: true
  evaluation_interval: 1m
  poll_interval: 1m

limits_config:
  retention_period: 744h
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_cache_freshness_per_query: 10m
  split_queries_by_interval: 15m
  per_stream_rate_limit: 512M
  per_stream_rate_limit_burst: 1024M
  cardinality_limit: 200000
  max_query_series: 10000

table_manager:
  retention_deletes_enabled: true
  retention_period: 744h
EOF

echo -e "${GREEN}✓ Configuration Loki créée${NC}"

################################################################################
# ÉTAPE 5 : Règles d'alertes Loki
################################################################################

echo -e "\n${CYAN}[5/10] Création des règles d'alertes...${NC}"

cat > loki/rules/fake/rules.yml << 'EOF'
groups:
  # Alertes instantanées (déclenchement rapide)
  - name: instant_alerts
    interval: 15s
    rules:
      - alert: InstantError
        expr: count_over_time({job=~".+"} |~ "(?i)error" [30s]) > 0
        for: 15s
        labels:
          severity: critical
          category: instant
        annotations:
          summary: "ERROR détecté dans les logs"
          description: "Le mot ERROR apparaît dans les logs"
      
      - alert: InstantCritical
        expr: count_over_time({job=~".+"} |~ "(?i)critical" [30s]) > 0
        for: 15s
        labels:
          severity: critical
          category: instant
        annotations:
          summary: "CRITICAL détecté dans les logs"
          description: "Le mot CRITICAL apparaît dans les logs"

  # Alertes critiques
  - name: critical_alerts
    interval: 1m
    rules:
      - alert: HighErrorRate
        expr: sum(rate({job=~".+"} |~ "(?i)error|fatal" [2m])) > 5
        for: 2m
        labels:
          severity: critical
          category: errors
        annotations:
          summary: "Taux d'erreur critique"
          description: "Plus de 5 erreurs/sec pendant 2 minutes"
      
      - alert: ServiceDown
        expr: sum(rate({job=~".+"} [5m])) == 0
        for: 5m
        labels:
          severity: critical
          category: availability
        annotations:
          summary: "Service ne produit plus de logs"
          description: "Aucun log depuis 5 minutes"
      
      - alert: ContainerRestarting
        expr: sum(count_over_time({job=~".+"} |~ "(?i)restart|restarting" [10m])) > 3
        for: 1m
        labels:
          severity: critical
          category: stability
        annotations:
          summary: "Conteneur redémarre fréquemment"
          description: "Plus de 3 redémarrages en 10 minutes"

  # Alertes warning
  - name: warning_alerts
    interval: 1m
    rules:
      - alert: HighWarningRate
        expr: sum(rate({job=~".+"} |~ "(?i)warn|warning" [5m])) > 10
        for: 5m
        labels:
          severity: warning
          category: warnings
        annotations:
          summary: "Taux de warnings élevé"
          description: "Plus de 10 warnings/sec pendant 5 minutes"
      
      - alert: HighLogVolume
        expr: sum(rate({job=~".+"} [5m])) > 50
        for: 5m
        labels:
          severity: warning
          category: performance
        annotations:
          summary: "Volume de logs très élevé"
          description: "Plus de 50 logs/sec"
EOF

echo -e "${GREEN}✓ Règles d'alertes créées (10 règles)${NC}"

################################################################################
# ÉTAPE 6 : Configuration Alloy
################################################################################

echo -e "\n${CYAN}[6/10] Configuration d'Alloy...${NC}"

cat > alloy/config.alloy << 'EOF'
loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}

loki.source.docker "containers" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.containers.targets
  forward_to = [loki.write.default.receiver]
  relabel_rules = discovery.relabel.docker.rules
}

discovery.docker "containers" {
  host = "unix:///var/run/docker.sock"
}

discovery.relabel "docker" {
  targets = discovery.docker.containers.targets

  rule {
    source_labels = ["__meta_docker_container_name"]
    target_label  = "container"
  }

  rule {
    source_labels = ["__meta_docker_container_log_stream"]
    target_label  = "stream"
  }
}

loki.source.file "system" {
  targets = [
    {__path__ = "/var/log/syslog", job = "syslog"},
    {__path__ = "/var/log/auth.log", job = "auth"},
  ]
  forward_to = [loki.write.default.receiver]
}
EOF

echo -e "${GREEN}✓ Configuration Alloy créée${NC}"

################################################################################
# ÉTAPE 7 : Configuration Alertmanager
################################################################################

echo -e "\n${CYAN}[7/10] Configuration d'Alertmanager...${NC}"

cat > alertmanager/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  receiver: 'snmp-notifier'
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

receivers:
  - name: 'snmp-notifier'
    webhook_configs:
      - url: 'http://snmp-notifier:9464/alerts'
        send_resolved: true

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname']
EOF

echo -e "${GREEN}✓ Configuration Alertmanager créée${NC}"

################################################################################
# ÉTAPE 8 : Configuration Grafana
################################################################################

echo -e "\n${CYAN}[8/10] Configuration de Grafana...${NC}"

# Datasource Loki
cat > grafana/provisioning/datasources/loki.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
    uid: P8E80F9AEF21F6940
    editable: false
    jsonData:
      maxLines: 1000
EOF

# Configuration des dashboards
cat > grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
      foldersFromFilesStructure: true
EOF

echo -e "${GREEN}✓ Configuration Grafana créée${NC}"

################################################################################
# ÉTAPE 9 : Configuration SNMP
################################################################################

echo -e "\n${CYAN}[9/10] Configuration SNMP...${NC}"

# SNMPtrapd Dockerfile
cat > snmptrapd/Dockerfile << 'EOF'
FROM alpine:latest

RUN apk add --no-cache net-snmp net-snmp-tools curl

RUN mkdir -p /var/log/snmptrapd

COPY snmptrapd.conf /etc/snmp/snmptrapd.conf
COPY traphandle.sh /usr/local/bin/traphandle.sh
RUN chmod +x /usr/local/bin/traphandle.sh

EXPOSE 162/udp

CMD ["sh", "-c", "snmptrapd -f -Lo -c /etc/snmp/snmptrapd.conf"]
EOF

# Configuration SNMPtrapd
cat > snmptrapd/snmptrapd.conf << 'EOF'
authCommunity log,execute,net public
traphandle default /usr/local/bin/traphandle.sh
EOF

# Script traphandle
cat > snmptrapd/traphandle.sh << 'EOF'
#!/bin/sh
read host
read ip
vars=""
while read oid val; do
    vars="$vars $oid = $val"
done

timestamp=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$timestamp] TRAP from $ip:$vars" | tee -a /var/log/snmptrapd/traps.log

curl -X POST http://trap-viewer:8888/trap \
     -H "Content-Type: application/json" \
     -d "{\"timestamp\":\"$timestamp\",\"source\":\"$ip\",\"vars\":\"$vars\"}" \
     2>/dev/null || true
EOF

chmod +x snmptrapd/traphandle.sh

# Trap Viewer Dockerfile
cat > trap-viewer/Dockerfile << 'EOF'
FROM python:3.9-slim

WORKDIR /app

RUN pip install flask

COPY app.py /app/
RUN mkdir -p /app/traps

EXPOSE 8888

CMD ["python", "app.py"]
EOF

# Application Trap Viewer
cat > trap-viewer/app.py << 'EOF'
from flask import Flask, request, jsonify, render_template_string
import json
import os
from datetime import datetime

app = Flask(__name__)
TRAPS_DIR = '/app/traps'
os.makedirs(TRAPS_DIR, exist_ok=True)

@app.route('/')
def index():
    traps = []
    for filename in sorted(os.listdir(TRAPS_DIR), reverse=True)[:100]:
        with open(os.path.join(TRAPS_DIR, filename)) as f:
            traps.append(json.load(f))
    
    return render_template_string('''
<!DOCTYPE html>
<html>
<head>
    <title>SNMP Trap Viewer</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #1e1e1e; color: #fff; }
        h1 { color: #4CAF50; }
        .trap { background: #2d2d2d; padding: 15px; margin: 10px 0; border-left: 4px solid #4CAF50; }
        .critical { border-left-color: #f44336; }
        .warning { border-left-color: #ff9800; }
        .timestamp { color: #888; font-size: 0.9em; }
        .source { color: #2196F3; }
        .vars { color: #aaa; margin-top: 10px; }
        .count { color: #4CAF50; font-size: 1.2em; margin-bottom: 20px; }
    </style>
    <script>
        setInterval(function(){ location.reload(); }, 10000);
    </script>
</head>
<body>
    <h1>🔔 SNMP Trap Viewer</h1>
    <div class="count">Total traps reçus: {{ traps|length }}</div>
    {% for trap in traps %}
    <div class="trap">
        <div class="timestamp">{{ trap.timestamp }}</div>
        <div class="source">Source: {{ trap.source }}</div>
        <div class="vars">{{ trap.vars }}</div>
    </div>
    {% endfor %}
</body>
</html>
    ''', traps=traps)

@app.route('/trap', methods=['POST'])
def receive_trap():
    data = request.json
    filename = f"{datetime.now().strftime('%Y%m%d%H%M%S%f')}.json"
    with open(os.path.join(TRAPS_DIR, filename), 'w') as f:
        json.dump(data, f)
    return jsonify({'status': 'ok'})

@app.route('/health')
def health():
    return 'OK'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8888)
EOF

mkdir -p trap-viewer/traps

echo -e "${GREEN}✓ Configuration SNMP créée${NC}"

################################################################################
# ÉTAPE 10 : Démarrage de la stack
################################################################################

echo -e "\n${CYAN}[10/10] Démarrage de la stack...${NC}"

# Arrêter les conteneurs existants
sudo docker compose down 2>/dev/null || true

# Démarrer la stack
sudo docker compose up -d --build

echo -e "\n${YELLOW}⏳ Attente du démarrage des services (45 secondes)...${NC}"
for i in {1..45}; do
    echo -n "."
    sleep 1
done
echo ""

################################################################################
# Vérification finale
################################################################################

echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}              VÉRIFICATION DES SERVICES${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"

# Fonction de vérification
check_service() {
    local name=$1
    local url=$2
    local expected=$3
    
    echo -n "→ $name... "
    if curl -s "$url" 2>/dev/null | grep -q "$expected"; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ ERREUR${NC}"
        return 1
    fi
}

check_service "Loki      " "http://localhost:3100/ready" "ready"
check_service "Grafana   " "http://localhost:3000/api/health" "ok"
check_service "Alertmgr  " "http://localhost:9093/-/healthy" "Healthy"
check_service "SNMP Notif" "http://localhost:9464/health" "ok"
check_service "Trap View " "http://localhost:8888/health" "OK"

# Vérifier les règles Loki
echo -n "→ Règles Loki... "
RULES_COUNT=$(curl -s http://localhost:3100/loki/api/v1/rules 2>/dev/null | grep -o '"name":"[^"]*"' | wc -l)
if [ "$RULES_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ $RULES_COUNT groupes chargés${NC}"
else
    echo -e "${YELLOW}⚠ Règles en cours de chargement${NC}"
fi

################################################################################
# Informations finales
################################################################################

echo -e "\n${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              DÉPLOIEMENT TERMINÉ AVEC SUCCÈS !                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}🌐 INTERFACES WEB :${NC}"
echo -e "  ${GREEN}•${NC} Grafana:        ${YELLOW}http://localhost:3000${NC} (admin/admin)"
echo -e "  ${GREEN}•${NC} Alertmanager:   ${YELLOW}http://localhost:9093${NC}"
echo -e "  ${GREEN}•${NC} Trap Viewer:    ${YELLOW}http://localhost:8888${NC}"
echo -e "  ${GREEN}•${NC} Nginx Demo:     ${YELLOW}http://localhost:8080${NC}"

echo -e "\n${CYAN}🔍 API ENDPOINTS :${NC}"
echo -e "  ${GREEN}•${NC} Loki API:       ${YELLOW}http://localhost:3100${NC}"
echo -e "  ${GREEN}•${NC} Loki Rules:     ${YELLOW}http://localhost:3100/loki/api/v1/rules${NC}"
echo -e "  ${GREEN}•${NC} Alloy:          ${YELLOW}http://localhost:12345${NC}"

echo -e "\n${CYAN}📊 DASHBOARDS GRAFANA :${NC}"
echo -e "  ${GREEN}•${NC} Monitoring:     ${YELLOW}http://localhost:3000/d/monitoring-stack${NC}"
echo -e "  ${GREEN}•${NC} Alertes SNMP:   ${YELLOW}http://localhost:3000/d/alertes-snmp${NC}"

echo -e "\n${CYAN}🧪 TEST RAPIDE :${NC}"
echo -e "  ${YELLOW}# Générer une erreur (trap envoyé en ~30 secondes):${NC}"
echo -e "  ${GREEN}sudo docker compose exec -T nginx-demo sh -c \"echo 'ERROR: test' >> /var/log/nginx/error.log\"${NC}"
echo -e "\n  ${YELLOW}# Attendre 45 secondes puis voir l'alerte:${NC}"
echo -e "  ${GREEN}curl -s http://localhost:9093/api/v2/alerts | jq${NC}"
echo -e "\n  ${YELLOW}# Voir les traps:${NC}"
echo -e "  ${GREEN}sudo docker compose logs snmptrapd | grep TRAP${NC}"

echo -e "\n${CYAN}📝 COMMANDES UTILES :${NC}"
echo -e "  ${GREEN}sudo docker compose ps${NC}           - État des services"
echo -e "  ${GREEN}sudo docker compose logs -f${NC}      - Voir tous les logs"
echo -e "  ${GREEN}sudo docker compose restart${NC}      - Redémarrer"
echo -e "  ${GREEN}sudo docker compose down${NC}         - Arrêter"

echo -e "\n${CYAN}📁 FICHIERS CRÉÉS :${NC}"
echo -e "  ${GREEN}•${NC} Installation:    ${YELLOW}$INSTALL_DIR${NC}"
echo -e "  ${GREEN}•${NC} Règles alertes:  ${YELLOW}$INSTALL_DIR/loki/rules/fake/rules.yml${NC}"
echo -e "  ${GREEN}•${NC} Config Loki:     ${YELLOW}$INSTALL_DIR/loki/loki-config.yml${NC}"
echo -e "  ${GREEN}•${NC} Config Alertmgr: ${YELLOW}$INSTALL_DIR/alertmanager/alertmanager.yml${NC}"

echo -e "\n${YELLOW}💡 PROCHAINES ÉTAPES :${NC}"
echo -e "  1. Ouvrir Grafana: ${CYAN}http://localhost:3000${NC}"
echo -e "  2. Se connecter avec: ${CYAN}admin / admin${NC}"
echo -e "  3. Tester une alerte avec la commande ci-dessus"
echo -e "  4. Voir les résultats dans Alertmanager et Trap Viewer"

echo -e "\n${GREEN}✅ Tout est prêt !${NC}\n"
