# Kaniko Build Jobs

Minimales Setup für Docker Image Builds mit Kaniko in Kubernetes.

## Dateien

```
kaniko/
├── namespace.yaml            # Namespace
├── secret.yaml               # Docker Hub Credentials (Template)
├── github-secret.yaml        # GitHub Credentials (für private Repos)
├── job-caweb.yaml            # Beispiel Build Job
├── trigger-service.yaml      # Webhook Service für Auto-Trigger
└── argocd-notifications-cm.yaml  # ArgoCD Notifications Config
```

## Setup

### 1. Namespace erstellen
```bash
kubectl apply -f namespace.yaml
```

### 2. Secrets erstellen

**Docker Hub:**
```bash
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=wlanboy \
  --docker-password=DEIN_DOCKERHUB_TOKEN \
  -n kaniko
```

**GitHub (für private Repos):**
```bash
kubectl create secret generic github-creds \
  --from-literal=.git-credentials='https://USERNAME:GITHUB_TOKEN@github.com' \
  -n kaniko
```

### 3. Manueller Build
```bash
kubectl apply -f job-caweb.yaml
kubectl logs -f job/kaniko-caweb -n kaniko
```

## Automatischer Trigger bei ArgoCD Sync

### 1. Trigger Service deployen
```bash
kubectl apply -f trigger-service.yaml
```

### 2. ArgoCD Notifications konfigurieren
```bash
kubectl apply -f argocd-notifications-cm.yaml
```

### 3. App für Notifications annotieren
```bash
kubectl annotate application caweb \
  notifications.argoproj.io/subscribe.on-sync-succeeded.kaniko-webhook="" \
  -n argocd
```

## Ablauf

```
Git Push → ArgoCD Sync → Notification → Webhook → Kaniko Job → Docker Hub
```

## Neuen Build manuell triggern

```bash
# Job löschen und neu erstellen
kubectl delete job kaniko-caweb -n kaniko --ignore-not-found
kubectl apply -f job-caweb.yaml
```

## Debugging

```bash
# Job Status
kubectl get jobs -n kaniko

# Build Logs
kubectl logs -f job/kaniko-caweb -n kaniko

# Trigger Service Logs
kubectl logs -f deployment/kaniko-trigger -n kaniko
```
