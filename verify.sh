#!/bin/bash

################################################################################
# Script de Vérification Post-Déploiement
# Vérifie que tous les services fonctionnent correctement
################################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Vérification Post-Déploiement                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}\n"

ERRORS=0
WARNINGS=0

# Fonction de vérification
check() {
    local name=$1
    local command=$2
    local expected=$3
    
    echo -n "→ $name... "
    if eval "$command" 2>/dev/null | grep -q "$expected"; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ ERREUR${NC}"
        ((ERRORS++))
        return 1
    fi
}

check_warning() {
    local name=$1
    local command=$2
    local expected=$3
    
    echo -n "→ $name... "
    if eval "$command" 2>/dev/null | grep -q "$expected"; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ WARNING${NC}"
        ((WARNINGS++))
        return 1
    fi
}

################################################################################
# 1. Services Docker
################################################################################

echo -e "${CYAN}[1/6] Services Docker${NC}"

check "Docker démarré    " "sudo docker info" "Server Version"
check "Compose installé " "docker compose version" "Docker Compose"

RUNNING=$(sudo docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)
echo -n "→ Conteneurs actifs... "
if [ "$RUNNING" -ge 7 ]; then
    echo -e "${GREEN}✓ $RUNNING/8${NC}"
else
    echo -e "${RED}✗ $RUNNING/8${NC}"
    ((ERRORS++))
fi

################################################################################
# 2. Services HTTP
################################################################################

echo -e "\n${CYAN}[2/6] Services HTTP${NC}"

check "Loki            " "curl -s http://localhost:3100/ready" "ready"
check "Grafana         " "curl -s http://localhost:3000/api/health" "ok"
check "Alertmanager    " "curl -s http://localhost:9093/-/healthy" "Healthy"
check "SNMP Notifier   " "curl -s http://localhost:9464/health" "ok"
check "Trap Viewer     " "curl -s http://localhost:8888/health" "OK"

################################################################################
# 3. Règles Loki
################################################################################

echo -e "\n${CYAN}[3/6] Règles d'Alertes Loki${NC}"

RULES_RESPONSE=$(curl -s http://localhost:3100/loki/api/v1/rules 2>/dev/null)
GROUPS_COUNT=$(echo "$RULES_RESPONSE" | grep -o '"name":"[^"]*"' | wc -l)

echo -n "→ Groupes de règles... "
if [ "$GROUPS_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ $GROUPS_COUNT groupes${NC}"
    echo "$RULES_RESPONSE" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g' | while read group; do
        echo -e "    ${GREEN}•${NC} $group"
    done
else
    echo -e "${YELLOW}⚠ Aucun groupe (règles en cours de chargement?)${NC}"
    ((WARNINGS++))
fi

################################################################################
# 4. Alertes Actives
################################################################################

echo -e "\n${CYAN}[4/6] Alertes Actives${NC}"

ALERTS_COUNT=$(curl -s http://localhost:9093/api/v2/alerts 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
echo -e "→ Alertes actives: ${CYAN}$ALERTS_COUNT${NC}"

if [ "$ALERTS_COUNT" -gt 0 ]; then
    curl -s http://localhost:9093/api/v2/alerts | jq -r '.[] | "  • \(.labels.alertname) [\(.status.state)]"' 2>/dev/null
fi

################################################################################
# 5. Traps SNMP
################################################################################

echo -e "\n${CYAN}[5/6] Traps SNMP${NC}"

TRAP_COUNT=$(sudo docker compose logs snmptrapd 2>/dev/null | grep -c "TRAP" || echo "0")
echo -e "→ Traps reçus au total: ${CYAN}$TRAP_COUNT${NC}"

if [ "$TRAP_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Système de traps fonctionnel${NC}"
    echo "  Derniers traps:"
    sudo docker compose logs snmptrapd 2>/dev/null | grep "TRAP" | tail -3 | sed 's/^/    /'
else
    echo -e "${YELLOW}⚠ Aucun trap reçu (normal si aucune alerte générée)${NC}"
fi

################################################################################
# 6. Collecte de Logs
################################################################################

echo -e "\n${CYAN}[6/6] Collecte de Logs${NC}"

# Vérifier qu'Alloy envoie des logs
ALLOY_LOGS=$(sudo docker compose logs alloy 2>/dev/null | grep -c "pushed" || echo "0")
echo -n "→ Alloy collecte des logs... "
if [ "$ALLOY_LOGS" -gt 0 ]; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}⚠ Aucune activité détectée${NC}"
    ((WARNINGS++))
fi

# Vérifier que Loki reçoit des logs
echo -n "→ Loki reçoit des logs... "
LOG_COUNT=$(curl -s 'http://localhost:3100/loki/api/v1/query?query=sum(count_over_time({job=~".+"}[1m]))' 2>/dev/null | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
if [ "$LOG_COUNT" != "0" ] && [ "$LOG_COUNT" != "null" ]; then
    echo -e "${GREEN}✓ $LOG_COUNT logs/minute${NC}"
else
    echo -e "${YELLOW}⚠ Aucun log détecté${NC}"
    ((WARNINGS++))
fi

################################################################################
# Résumé
################################################################################

echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}║               ✅ TOUS LES TESTS RÉUSSIS !                      ║${NC}"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}║           ⚠  TESTS RÉUSSIS AVEC WARNINGS                       ║${NC}"
else
    echo -e "${RED}║              ❌ CERTAINS TESTS ONT ÉCHOUÉ                       ║${NC}"
fi
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Résumé:${NC}"
if [ "$ERRORS" -eq 0 ]; then
    echo -e "  ${GREEN}✓ Erreurs: $ERRORS${NC}"
else
    echo -e "  ${RED}✗ Erreurs: $ERRORS${NC}"
fi

if [ "$WARNINGS" -eq 0 ]; then
    echo -e "  ${GREEN}✓ Warnings: $WARNINGS${NC}"
else
    echo -e "  ${YELLOW}⚠ Warnings: $WARNINGS${NC}"
fi

################################################################################
# Informations Utiles
################################################################################

echo -e "\n${CYAN}🌐 Interfaces Web:${NC}"
echo -e "  ${GREEN}•${NC} Grafana:      ${YELLOW}http://localhost:3000${NC} (admin/admin)"
echo -e "  ${GREEN}•${NC} Alertmanager: ${YELLOW}http://localhost:9093${NC}"
echo -e "  ${GREEN}•${NC} Trap Viewer:  ${YELLOW}http://localhost:8888${NC}"

echo -e "\n${CYAN}🧪 Test Rapide:${NC}"
echo -e "  ${GREEN}# Générer une alerte:${NC}"
echo -e "  ${YELLOW}sudo docker compose exec -T nginx-demo sh -c \"echo 'ERROR: test' >> /var/log/nginx/error.log\"${NC}"
echo -e "\n  ${GREEN}# Attendre 45 secondes puis vérifier:${NC}"
echo -e "  ${YELLOW}curl -s http://localhost:9093/api/v2/alerts | jq${NC}"
echo -e "  ${YELLOW}sudo docker compose logs snmptrapd | grep TRAP | tail -5${NC}"

if [ "$ERRORS" -gt 0 ]; then
    echo -e "\n${RED}⚠ Des erreurs ont été détectées. Consultez le README.md section Dépannage${NC}"
    echo -e "${RED}  ou exécutez: sudo docker compose logs -f${NC}"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "\n${YELLOW}⚠ Quelques warnings détectés, mais le système est fonctionnel${NC}"
    exit 0
else
    echo -e "\n${GREEN}✅ Tout est parfaitement opérationnel !${NC}"
    exit 0
fi
