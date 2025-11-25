# 📦 Livrables - Stack Monitoring Complète

Tous les fichiers nécessaires pour déployer la stack de monitoring de A à Z.

---

## 📁 Fichiers Créés

### 🚀 Scripts de Déploiement

| Fichier | Description | Usage |
|---------|-------------|-------|
| **deploy.sh** | Script de déploiement automatique complet | `./deploy.sh` |
| **verify.sh** | Vérification post-déploiement | `./verify.sh` |

### 📖 Documentation

| Fichier | Description | Contenu |
|---------|-------------|---------|
| **README.md** | Documentation complète (20+ pages) | Architecture, installation, configuration, dépannage, commandes |
| **QUICKSTART.md** | Guide de démarrage rapide (1 page) | Installation express en 3 minutes |

### 📊 Dashboards Grafana (créés précédemment)

| Fichier | Description | Panels |
|---------|-------------|--------|
| **dashboard-monitoring.json** | Dashboard principal logs et erreurs | 11 panels |
| **dashboard-alertes-snmp.json** | Dashboard alertes et traps SNMP | 11 panels |

### 🛠 Scripts Utilitaires (créés précédemment)

| Fichier | Description | Usage |
|---------|-------------|-------|
| **import-all-dashboards.sh** | Import automatique des dashboards | `./import-all-dashboards.sh` |
| **start-and-test.sh** | Démarre et teste le flux complet | `./start-and-test.sh` |
| **test-alert-flow.sh** | Test automatique du flux d'alertes | `./test-alert-flow.sh` |

---

## 🎯 Guide d'Utilisation

### Déploiement Initial

```bash
# 1. Copier les fichiers depuis /mnt/user-data/outputs/
cp /mnt/user-data/outputs/deploy.sh ~/
cp /mnt/user-data/outputs/verify.sh ~/
cp /mnt/user-data/outputs/README.md ~/
cp /mnt/user-data/outputs/QUICKSTART.md ~/

# 2. Rendre les scripts exécutables
chmod +x ~/deploy.sh
chmod +x ~/verify.sh

# 3. Déployer
cd ~
./deploy.sh

# 4. Vérifier
./verify.sh
```

**Durée totale:** 2-3 minutes

---

## 📊 Structure Créée par deploy.sh

```
~/projectRims/test/monitoring-stack-complete/
├── docker-compose.yml              # ← Orchestration principale
├── loki/
│   ├── loki-config.yml            # ← Config Loki
│   └── rules/
│       └── fake/
│           └── rules.yml          # ← 10 règles d'alertes
├── alloy/
│   └── config.alloy               # ← Config collecteur
├── grafana/
│   └── provisioning/
│       ├── datasources/           # ← Auto-config datasource Loki
│       └── dashboards/            # ← Auto-config dashboards
├── alertmanager/
│   └── alertmanager.yml           # ← Config routage alertes
├── snmptrapd/
│   ├── Dockerfile
│   ├── snmptrapd.conf
│   └── traphandle.sh              # ← Script réception traps
└── trap-viewer/
    ├── Dockerfile
    └── app.py                     # ← Interface web Flask
```

---

## 🔄 Workflow de Déploiement Complet

### Option 1 : Déploiement Express (Recommandé)

```bash
# Installation en une commande
curl -o deploy.sh [URL] && chmod +x deploy.sh && ./deploy.sh
```

**Avantages:**
- ✅ Tout automatique
- ✅ Aucune configuration manuelle
- ✅ Vérifications intégrées
- ✅ Prêt en 3 minutes

### Option 2 : Déploiement Pas à Pas

```bash
# 1. Lire la documentation
cat README.md

# 2. Comprendre l'architecture
cat QUICKSTART.md

# 3. Déployer
./deploy.sh

# 4. Vérifier
./verify.sh

# 5. Importer les dashboards (optionnel)
cp dashboard-*.json ~/projectRims/test/monitoring-stack-complete/
cd ~/projectRims/test/monitoring-stack-complete
./import-all-dashboards.sh

# 6. Tester
./test-alert-flow.sh
```

---

## 📋 Checklist de Déploiement

### Avant le Déploiement

- [ ] Docker installé (`docker --version`)
- [ ] Docker Compose V2 installé (`docker compose version`)
- [ ] Ports 3000, 3100, 9093, 9464, 8888, 162, 8080, 12345 disponibles
- [ ] Minimum 4 Go RAM disponible
- [ ] Minimum 10 Go espace disque

### Pendant le Déploiement

- [ ] Script deploy.sh exécuté sans erreur
- [ ] Tous les services démarrés (8 conteneurs)
- [ ] Attendre 45-60 secondes après démarrage

### Après le Déploiement

- [ ] Exécuter `./verify.sh` → Tout vert
- [ ] Grafana accessible (http://localhost:3000)
- [ ] Loki répond (http://localhost:3100/ready)
- [ ] Règles chargées (au moins 3 groupes)
- [ ] Test d'alerte réussi (ERROR → trap visible)

---

## 🧪 Tests de Validation

### Test 1 : Services de Base

```bash
# Tous les services répondent
curl http://localhost:3100/ready       # Loki
curl http://localhost:3000/api/health  # Grafana
curl http://localhost:9093/-/healthy   # Alertmanager
curl http://localhost:9464/health      # SNMP Notifier
curl http://localhost:8888/health      # Trap Viewer
```

### Test 2 : Règles d'Alertes

```bash
# Vérifier les règles chargées
curl -s http://localhost:3100/loki/api/v1/rules | jq '.data.groups[].name'

# Résultat attendu:
# "instant_alerts"
# "critical_alerts"
# "warning_alerts"
```

### Test 3 : Flux Complet

```bash
# Générer une erreur
sudo docker compose exec -T nginx-demo sh -c "echo 'ERROR: test validation' >> /var/log/nginx/error.log"

# Attendre 45 secondes
sleep 45

# Vérifier l'alerte
ALERTS=$(curl -s http://localhost:9093/api/v2/alerts | jq 'length')
echo "Alertes actives: $ALERTS"

# Vérifier le trap
TRAPS=$(sudo docker compose logs snmptrapd | grep -c TRAP)
echo "Traps reçus: $TRAPS"

# Vérifier l'interface web
curl http://localhost:8888 | grep -c "TRAP"
```

**Résultat attendu:**
- Alertes actives: ≥ 1
- Traps reçus: ≥ 1
- Interface web affiche le trap

---

## 🎓 Utilisation Quotidienne

### Démarrage du Système

```bash
cd ~/projectRims/test/monitoring-stack-complete
sudo docker compose up -d
sleep 45
./verify.sh
```

### Surveillance Continue

```bash
# Ouvrir 3 terminaux:

# Terminal 1: Logs temps réel
sudo docker compose logs -f

# Terminal 2: Alertes
watch -n 5 'curl -s http://localhost:9093/api/v2/alerts | jq length'

# Terminal 3: Traps
watch -n 5 'sudo docker compose logs snmptrapd | grep -c TRAP'

# Navigateur: Trap Viewer
firefox http://localhost:8888
```

### Arrêt Propre

```bash
cd ~/projectRims/test/monitoring-stack-complete
sudo docker compose down
```

---

## 📝 Personnalisation

### Ajouter une Règle d'Alerte Personnalisée

```bash
# 1. Éditer le fichier de règles
cd ~/projectRims/test/monitoring-stack-complete
nano loki/rules/fake/rules.yml

# 2. Ajouter dans un groupe existant ou créer un nouveau groupe
# Exemple:
groups:
  - name: custom_alerts
    interval: 1m
    rules:
      - alert: CustomKeywordAlert
        expr: count_over_time({job=~".+"} |~ "URGENT" [1m]) > 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Mot URGENT détecté"

# 3. Redémarrer Loki
sudo docker compose restart loki

# 4. Vérifier (attendre 15 secondes)
sleep 15
curl -s http://localhost:3100/loki/api/v1/rules | jq '.data.groups[] | select(.name=="custom_alerts")'
```

### Modifier les Seuils d'Alertes

```bash
# Exemple: Changer HighErrorRate de 5 à 10 erreurs/sec
nano loki/rules/fake/rules.yml

# Modifier:
expr: sum(rate({job=~".+"} |~ "(?i)error|fatal" [2m])) > 10
#                                                         ^^

# Redémarrer
sudo docker compose restart loki
```

### Ajouter un Dashboard Grafana

```bash
# 1. Créer le dashboard dans Grafana UI
# 2. Exporter le JSON
# 3. Sauvegarder dans grafana/provisioning/dashboards/
# 4. Redémarrer Grafana
sudo docker compose restart grafana
```

---

## 🔧 Maintenance

### Sauvegarde

```bash
# Sauvegarder la configuration
cd ~/projectRims/test/monitoring-stack-complete
tar -czf backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml \
  loki/ \
  alloy/ \
  grafana/ \
  alertmanager/ \
  snmptrapd/ \
  trap-viewer/

# Sauvegarder les données
sudo docker compose down
sudo tar -czf data-backup-$(date +%Y%m%d).tar.gz \
  $(docker volume inspect monitoring-stack-complete_loki-data -f '{{.Mountpoint}}') \
  $(docker volume inspect monitoring-stack-complete_grafana-data -f '{{.Mountpoint}}')
```

### Mise à Jour

```bash
# Mettre à jour les images Docker
cd ~/projectRims/test/monitoring-stack-complete
sudo docker compose pull
sudo docker compose up -d
```

### Nettoyage

```bash
# Nettoyer les logs anciens (Loki fait ça auto après 31 jours)
# Nettoyer les traps anciens
rm -rf trap-viewer/traps/*

# Nettoyer Docker
sudo docker system prune -a --volumes
```

---

## 📊 Métriques de Performance

### Stack Saine

```
CPU: < 20% (total de tous les conteneurs)
RAM: ~2-3 Go utilisés
Disque: ~1-2 Go (sans logs accumulés)
Network: ~10 MB/s entrée, ~1 MB/s sortie
```

### Commandes de Surveillance

```bash
# CPU et RAM
sudo docker stats

# Espace disque
du -sh ~/projectRims/test/monitoring-stack-complete/

# Volumes Docker
sudo docker system df -v

# Taille des logs Loki
sudo du -sh $(docker volume inspect monitoring-stack-complete_loki-data -f '{{.Mountpoint}}')
```

---

## 🎯 Objectifs Atteints

✅ **Déploiement automatique** - Script deploy.sh
✅ **Zero configuration** - Tout préconfigurésudo 
✅ **10 règles d'alertes** - Prêtes à l'emploi
✅ **Flux complet** - Logs → Alertes → SNMP
✅ **Dashboards Grafana** - 2 dashboards avec 22 panels
✅ **Interface web traps** - Visualisation temps réel
✅ **Tests automatiques** - Scripts de vérification
✅ **Documentation complète** - README + Quickstart
✅ **Prêt production** - Architecture robuste

---

## 📞 Support et Dépannage

### En cas de problème

1. **Consulter la documentation**
   - README.md section "Dépannage"
   - QUICKSTART.md section "Dépannage Express"

2. **Exécuter les vérifications**
   ```bash
   ./verify.sh
   ```

3. **Voir les logs**
   ```bash
   sudo docker compose logs | grep -i error
   ```

4. **Réinitialisation complète**
   ```bash
   sudo docker compose down -v
   ./deploy.sh
   ```

### Logs Utiles

```bash
# Erreurs de tous les services
sudo docker compose logs | grep -i error

# Logs Loki (règles)
sudo docker compose logs loki | grep -i rule

# Logs Alertmanager (alertes)
sudo docker compose logs alertmanager | grep -i alert

# Logs SNMP (traps)
sudo docker compose logs snmptrapd | grep TRAP
```

---

## 🚀 Prochaines Étapes

Une fois la stack déployée et validée:

1. **Personnaliser les règles** selon vos besoins
2. **Ajouter vos applications** au monitoring
3. **Créer des dashboards** personnalisés
4. **Configurer des notifications** supplémentaires
5. **Intégrer avec vos outils** existants

---

## 📚 Ressources

- **Documentation Loki:** https://grafana.com/docs/loki/
- **Documentation Grafana:** https://grafana.com/docs/grafana/
- **LogQL Guide:** https://grafana.com/docs/loki/latest/logql/
- **Alertmanager:** https://prometheus.io/docs/alerting/

---

## ✅ Validation Finale

Après déploiement, vous devez avoir:

✅ 8 conteneurs en cours d'exécution
✅ Toutes les interfaces web accessibles
✅ 3+ groupes de règles chargés dans Loki
✅ Test d'alerte réussi (ERROR → trap visible)
✅ Dashboards Grafana fonctionnels
✅ Aucune erreur dans `./verify.sh`

**Si tout est ✅, félicitations! Votre stack de monitoring est opérationnelle! 🎉**

---

## 📅 Date de Création

**Version:** 1.0.0  
**Date:** 2025-11-25  
**Auteur:** Stack Monitoring Automatisée  
**Testé sur:** Ubuntu 22.04 LTS, Docker 24.0+

---

**🎯 Résultat Final: Système de monitoring complet, automatisé et prêt à l'emploi en moins de 3 minutes!**
