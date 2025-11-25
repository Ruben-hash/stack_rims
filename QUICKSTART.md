# ⚡ Démarrage Rapide - Stack Monitoring

Déploiement complet en **3 minutes** !

---

## 🚀 Installation Express

```bash
# 1. Télécharger et déployer (TOUT AUTOMATIQUE)
curl -o deploy.sh https://votreserveur.com/deploy.sh
chmod +x deploy.sh
./deploy.sh

# ⏳ Attendre 2-3 minutes... ☕

# 2. Vérifier que tout fonctionne
chmod +x verify.sh
./verify.sh

# 3. C'est prêt ! 🎉
```

---

## 🌐 Accès Interfaces

| Service | URL | Login |
|---------|-----|-------|
| **Grafana** | http://localhost:3000 | admin / admin |
| **Alertmanager** | http://localhost:9093 | - |
| **Trap Viewer** | http://localhost:8888 | - |

---

## 🧪 Test en 1 Minute

```bash
# Générer une erreur
sudo docker compose exec -T nginx-demo sh -c "echo 'ERROR: test alerte' >> /var/log/nginx/error.log"

# Attendre 45 secondes
sleep 45

# Voir l'alerte
curl -s http://localhost:9093/api/v2/alerts | jq

# Voir le trap SNMP
sudo docker compose logs snmptrapd | grep TRAP | tail -3

# Interface web
firefox http://localhost:8888
```

**✅ Résultat attendu:** Alerte visible dans Alertmanager + Trap SNMP affiché

---

## 📊 Architecture Simple

```
Application → Logs → Alloy → Loki → Alertmanager → SNMP → Traps
                              ↓
                           Grafana (visualisation)
```

---

## 💻 Commandes Essentielles

```bash
# État des services
sudo docker compose ps

# Voir les logs en temps réel
sudo docker compose logs -f

# Redémarrer tout
sudo docker compose restart

# Arrêter
sudo docker compose down

# Voir les alertes actives
curl -s http://localhost:9093/api/v2/alerts | jq

# Voir les règles Loki
curl -s http://localhost:3100/loki/api/v1/rules | jq '.data.groups[].name'

# Compter les traps SNMP reçus
sudo docker compose logs snmptrapd | grep -c TRAP
```

---

## 🚨 10 Règles d'Alertes Préconfigurées

### Alertes Instantanées (30 secondes)
- ✅ **InstantError** - Détecte "error" dans logs
- ✅ **InstantCritical** - Détecte "critical" dans logs

### Alertes Critiques (1-2 minutes)
- ✅ **HighErrorRate** - Plus de 5 erreurs/sec
- ✅ **ServiceDown** - Service arrêté
- ✅ **ContainerRestarting** - Redémarrages fréquents

### Alertes Warning (3-5 minutes)
- ✅ **HighWarningRate** - Trop de warnings
- ✅ **HighLogVolume** - Volume de logs élevé
- ... et 3 autres !

---

## 🔧 Dépannage Express

### Problème : Service ne démarre pas
```bash
sudo docker compose logs [service]
sudo docker compose restart [service]
```

### Problème : Aucune alerte
```bash
# Vérifier les règles
curl -s http://localhost:3100/loki/api/v1/rules | jq

# Recharger
sudo docker compose restart loki
```

### Problème : Pas de traps SNMP
```bash
# Vérifier la chaîne complète
curl http://localhost:3100/ready        # Loki OK?
curl http://localhost:9093/-/healthy    # Alertmanager OK?
curl http://localhost:9464/health       # SNMP Notifier OK?
sudo docker compose logs snmptrapd      # Traps reçus?
```

### Réinitialisation totale
```bash
sudo docker compose down -v
./deploy.sh  # Redéployer
```

---

## 📝 Personnalisation Rapide

### Ajouter une règle d'alerte

```bash
# Éditer le fichier
nano loki/rules/fake/rules.yml

# Ajouter votre règle
- alert: MonAlerte
  expr: count_over_time({job=~".+"} |~ "MON_MOT_CLE" [1m]) > 0
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "Mon alerte personnalisée"

# Redémarrer Loki
sudo docker compose restart loki
```

### Changer le mot de passe Grafana

```bash
# Dans docker-compose.yml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=nouveau_mdp

# Redémarrer
sudo docker compose restart grafana
```

---

## 📚 Documentation Complète

Consultez **README.md** pour :
- Architecture détaillée
- Configuration avancée
- Tous les cas d'usage
- Dépannage complet
- Exemples de requêtes LogQL

---

## ✅ Checklist Post-Installation

- [ ] Tous les services démarrés (`sudo docker compose ps`)
- [ ] Loki répond (`curl http://localhost:3100/ready`)
- [ ] Règles chargées (`curl http://localhost:3100/loki/api/v1/rules`)
- [ ] Grafana accessible (`http://localhost:3000`)
- [ ] Test d'alerte réussi (générer ERROR → voir trap)

---

## 🎯 Flux d'une Alerte

```
T+0s   → ERROR écrit dans les logs
T+15s  → Loki évalue les règles → Alerte PENDING
T+30s  → Condition persiste → Alerte FIRING
T+35s  → Loki envoie à Alertmanager
T+40s  → Alertmanager envoie webhook à SNMP Notifier
T+45s  → SNMP Notifier envoie trap à SNMPtrapd
T+50s  → Trap visible sur http://localhost:8888
```

**⏱ Délai total:** ~30-50 secondes pour les alertes instantanées

---

## 💡 Conseils Pro

1. **Surveillance continue:** Laissez Trap Viewer ouvert (refresh auto 10s)
2. **Logs en temps réel:** `sudo docker compose logs -f | grep -i error`
3. **Dashboards Grafana:** Utilisez les 2 dashboards préconfigurés
4. **Requêtes LogQL:** Explorez les logs dans Grafana → Explore
5. **Alertmanager:** Surveillez http://localhost:9093 pour les alertes

---

## 📞 Support Rapide

**Problème courant #1:** "Règles pas chargées"
```bash
sudo docker compose restart loki
sleep 15
curl -s http://localhost:3100/loki/api/v1/rules | jq
```

**Problème courant #2:** "Pas de logs dans Grafana"
```bash
# Vérifier le datasource
curl -s -u admin:admin http://localhost:3000/api/datasources | jq
# Générer des logs
for i in {1..10}; do sudo docker compose exec -T nginx-demo sh -c "echo 'Test $i'"; done
```

**Problème courant #3:** "Services s'arrêtent"
```bash
# Voir les erreurs
sudo docker compose logs | grep -i error
# Recréer
sudo docker compose up -d --force-recreate
```

---

## 🎉 C'est Tout !

Vous avez maintenant :
- ✅ Collecte automatique de logs
- ✅ 10 règles d'alertes actives
- ✅ Notifications SNMP fonctionnelles
- ✅ Dashboards Grafana configurés
- ✅ Interface web pour visualiser les traps

**Temps total:** 3 minutes  
**Configuration:** 0 minute (tout automatique)  
**Prêt à l'emploi:** Oui ✅

---

**Questions? → Consultez README.md**  
**Problème? → Exécutez verify.sh**  
**Tout va bien? → Profitez ! 🚀**
