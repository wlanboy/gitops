# ArgoCD CLI Cheat Sheet

Eine Sammlung nützlicher `argocd`-Befehle zur Verwaltung von Applications, Projects und Clustern über die CLI.

## Login & Kontext

### Login am ArgoCD-Server
```bash
argocd login ARGOCD_SERVER --username admin --password PASSWORD
argocd login ARGOCD_SERVER --sso
```

### Aktuellen Kontext anzeigen / wechseln
```bash
argocd context
argocd context ARGOCD_SERVER
```

### Initiales Admin-Passwort auslesen (frisch installierter Cluster)
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

---

## Applications

### Alle Applications auflisten
```bash
argocd app list
```

### Details einer Application anzeigen
```bash
argocd app get APP_NAME
```

### Application anlegen
```bash
argocd app create APP_NAME \
  --repo https://github.com/ORG/REPO.git \
  --path PATH_IM_REPO \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace TARGET_NAMESPACE
```

### Manuelles Sync auslösen
```bash
argocd app sync APP_NAME
argocd app sync APP_NAME --prune
argocd app sync APP_NAME --force
```

### Diff zwischen Live-State und Git anzeigen
```bash
argocd app diff APP_NAME
```

### Application-Historie und Rollback
```bash
argocd app history APP_NAME
argocd app rollback APP_NAME REVISION_ID
```

### Auf Sync/Health-Status warten
Blockiert, bis die Application synchronisiert und healthy ist — praktisch in CI/CD-Pipelines statt Polling per Schleife:
```bash
argocd app wait APP_NAME --sync --health
argocd app wait APP_NAME --timeout 300
```

### Application löschen
```bash
argocd app delete APP_NAME
argocd app delete APP_NAME --cascade=false
```

### Ressourcen einer Application anzeigen
```bash
argocd app resources APP_NAME
```

### Logs eines Pods über eine Application abrufen
```bash
argocd app logs APP_NAME --container CONTAINER_NAME --follow
```

### Auto-Sync konfigurieren
```bash
argocd app set APP_NAME --sync-policy automated
argocd app set APP_NAME --auto-prune --self-heal
```

### Nicht verwaltete/abweichende Ressourcen finden
```bash
argocd app diff APP_NAME --local PFAD_ZU_MANIFESTEN
```

---

## Projects

### Alle Projects auflisten
```bash
argocd proj list
```

### Details eines Projects anzeigen
```bash
argocd proj get PROJECT_NAME
```

### Erlaubte Destinations/Repos eines Projects einsehen
```bash
argocd proj allow-cluster-resource PROJECT_NAME GROUP KIND
argocd proj add-source PROJECT_NAME https://github.com/ORG/REPO.git
```

---

## Cluster & Repositories

### Verbundene Cluster auflisten
```bash
argocd cluster list
```

### Neuen Cluster hinzufügen (aus aktuellem kubeconfig-Kontext)
```bash
argocd cluster add KUBECONFIG_CONTEXT_NAME
```

### Verbundene Repositories auflisten
```bash
argocd repo list
```

### Neues Repository hinzufügen
```bash
argocd repo add https://github.com/ORG/REPO.git --username USER --password TOKEN
```

---

## Accounts & RBAC

### Aktuellen Benutzer anzeigen
```bash
argocd account get-user-info
```

### Passwort ändern
```bash
argocd account update-password
```

### Berechtigungen prüfen
```bash
argocd account can-i sync applications APP_NAME
argocd account can-i '*' '*' '*'
```

---

## Nützliche Flags

### Ausgabe als JSON/YAML
```bash
argocd app get APP_NAME -o json
argocd app get APP_NAME -o yaml
```

### Grpc-Web für Umgebungen hinter restriktiven Proxies
```bash
argocd login ARGOCD_SERVER --grpc-web
```

### Insecure-Verbindung (self-signed Zertifikate)
```bash
argocd login ARGOCD_SERVER --insecure
```

### Erhöhte Log-Ausgabe für Fehlersuche
```bash
argocd app sync APP_NAME --loglevel debug
```

### Hilfreiche Zusatztools (nicht Teil der argocd-CLI selbst)
- **[argocd-autopilot](https://argocd-autopilot.readthedocs.io/)** – Bootstrapping von GitOps-Repos nach ArgoCD-Best-Practices

