#!/bin/bash

# Script d'import de tous les dashboards dans Grafana
# À exécuter dans monitoring-stack-complete/

echo "📊 IMPORT DES DASHBOARDS DANS GRAFANA"
echo "═══════════════════════════════════════════════════════════"
echo ""

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Vérifier que Grafana est accessible
echo -n "Vérification de Grafana... "
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ ÉCHEC${NC}"
    echo ""
    echo "Grafana n'est pas accessible. Vérifiez qu'il est démarré:"
    echo "  sudo docker compose ps grafana"
    exit 1
fi

echo ""

# Liste des dashboards à importer
dashboards=(
    "dashboard-monitoring.json:Monitoring Stack - Logs & Alertes"
    "dashboard-alertes-snmp.json:Alertes & Traps SNMP"
)

# Copier les dashboards s'ils ne sont pas déjà là
for dash in "${dashboards[@]}"; do
    filename=$(echo "$dash" | cut -d: -f1)
    if [ ! -f "$filename" ]; then
        echo "Copie de $filename..."
        cp ../$filename . 2>/dev/null
    fi
done

echo "═══════════════════════════════════════════════════════════"
echo ""

# Compteurs
success_count=0
fail_count=0

# Importer chaque dashboard
for dash in "${dashboards[@]}"; do
    filename=$(echo "$dash" | cut -d: -f1)
    title=$(echo "$dash" | cut -d: -f2)
    
    echo -e "${BLUE}📊 Import de: $title${NC}"
    echo "   Fichier: $filename"
    
    if [ ! -f "$filename" ]; then
        echo -e "   ${RED}✗ Fichier introuvable${NC}"
        ((fail_count++))
        echo ""
        continue
    fi
    
    RESPONSE=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -u admin:admin \
      -d @$filename \
      http://localhost:3000/api/dashboards/db)
    
    if echo "$RESPONSE" | grep -q "success"; then
        DASHBOARD_URL=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('url',''))" 2>/dev/null)
        echo -e "   ${GREEN}✓ Importé avec succès${NC}"
        echo "   URL: http://localhost:3000${DASHBOARD_URL}"
        ((success_count++))
    else
        echo -e "   ${RED}✗ Échec de l'import${NC}"
        ERROR_MSG=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('message','Erreur inconnue'))" 2>/dev/null)
        echo "   Erreur: $ERROR_MSG"
        ((fail_count++))
    fi
    echo ""
done

echo "═══════════════════════════════════════════════════════════"
echo "📊 RÉSUMÉ"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "Dashboards importés avec succès: ${GREEN}$success_count${NC}"
echo -e "Dashboards en échec: ${RED}$fail_count${NC}"
echo ""

if [ $success_count -gt 0 ]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "🌐 ACCÉDER AUX DASHBOARDS"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "  http://localhost:3000"
    echo ""
    echo "  Login: admin"
    echo "  Password: admin"
    echo ""
    echo "Puis:"
    echo "  1. Cliquer sur le menu ☰ (en haut à gauche)"
    echo "  2. Aller dans 'Dashboards'"
    echo "  3. Vous verrez vos nouveaux dashboards"
    echo ""
fi

echo "═══════════════════════════════════════════════════════════"
echo "📋 CONTENU DES DASHBOARDS"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}1. Monitoring Stack - Logs & Alertes${NC}"
echo "   • Vue d'ensemble des logs"
echo "   • Statistiques en temps réel"
echo "   • Taux d'erreurs"
echo "   • Distribution par conteneur"
echo "   • Logs récents et logs d'erreur"
echo ""
echo -e "${BLUE}2. Alertes & Traps SNMP${NC}"
echo "   • Alertes CRITICAL et WARNING actives"
echo "   • Redémarrages de conteneurs"
echo "   • Logs Alertmanager"
echo "   • Logs SNMP Notifier"
echo "   • Logs SNMPtrapd (traps reçus)"
echo "   • Alertes récentes par sévérité"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎨 PERSONNALISATION"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Vous pouvez modifier les dashboards directement dans Grafana:"
echo "  1. Ouvrir un dashboard"
echo "  2. Cliquer sur l'icône ⚙️ (Settings) en haut à droite"
echo "  3. Cliquer sur 'Edit' sur un panel"
echo "  4. Modifier la requête LogQL"
echo "  5. Sauvegarder"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🔄 RÉIMPORTER UN DASHBOARD"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Si vous voulez réimporter (écraser) un dashboard:"
echo "  ./import-all-dashboards.sh"
echo ""
echo "Le paramètre 'overwrite: true' dans le JSON écrase automatiquement"
echo ""
echo "═══════════════════════════════════════════════════════════"
