# Argo Workflows + Kaniko

Kubernetes-native Build Pipelines mit Argo Workflows und Kaniko.

## Dateien

```
argo-workflows/
├── namespace.yaml          # Namespace
├── install.yaml            # Installation Hinweise
├── secrets.yaml            # Docker Hub + GitHub Secrets
├── workflow-template.yaml  # Wiederverwendbares Build Template
├── workflow-caweb.yaml     # Beispiel Workflow für caweb
└── sensor-github.yaml      # Optional: GitHub Webhook Trigger
```

## Installation

### 1. Namespace
```bash
kubectl apply -f namespace.yaml
```

### 2. Argo Workflows installieren
```bash
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.5/quick-start-minimal.yaml
```

### 3. Secrets erstellen
```bash
# Docker Hub
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=wlanboy \
  --docker-password=DEIN_TOKEN \
  -n argo

# GitHub (optional, für private Repos)
kubectl create secret generic github-creds \
  --from-literal=token=GITHUB_TOKEN \
  -n argo
```

### 4. Workflow Template deployen
```bash
kubectl apply -f workflow-template.yaml
```

## Build starten

### Manuell via kubectl
```bash
kubectl create -f workflow-caweb.yaml
```

### Mit argo CLI
```bash
# CLI installieren: https://github.com/argoproj/argo-workflows/releases
argo submit workflow-caweb.yaml -n argo --watch
```

### Mit Parametern
```bash
argo submit -n argo --from workflowtemplate/kaniko-build \
  -p repo=https://github.com/wlanboy/mirror.git \
  -p image=wlanboy/mirror \
  -p tag=v1.0.0
```

## Status prüfen

```bash
# Alle Workflows
argo list -n argo

# Logs eines Workflows
argo logs -n argo @latest

# UI öffnen (Port-Forward)
kubectl port-forward svc/argo-server -n argo 2746:2746
# Dann: https://localhost:2746
```

## Optional: GitHub Webhook Trigger

Für automatische Builds bei Git Push:

### 1. Argo Events installieren
```bash
kubectl create namespace argo-events
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml
```

### 2. EventSource + Sensor deployen
```bash
kubectl apply -f sensor-github.yaml
```

### 3. Webhook in GitHub konfigurieren
- URL: `https://dein-cluster/push`
- Content-Type: `application/json`
- Events: `push`

## Workflow für neue App erstellen

Kopiere `workflow-caweb.yaml` und passe die Parameter an:
- `repo`: Git Repository URL
- `image`: Docker Hub Image Name
- `tag`: Image Tag
- `branch`: Git Branch
