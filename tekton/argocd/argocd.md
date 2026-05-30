# Tekton Scripts für ArgoCD App Definitionen

Dieses Verzeichnis enthält Shell-Skripte, um Tekton-Pipelines für ArgoCD-verwaltete Anwendungen aufzusetzen und zu bauen. Das `setup.sh`-Skript konfiguriert einmalig die Docker-Credentials, während `build.sh` das Bauen einzelner oder aller Apps übernimmt.

## Erklärung

- **setup.sh** — Richtet die Kubernetes-Secrets für die Docker-Registry ein. Muss nur einmal pro Cluster ausgeführt werden.
- **build.sh** — Startet eine Tekton-Pipeline für eine oder mehrere Apps. Der Image-Tag kann per Umgebungsvariable `IMAGE_TAG` gesetzt werden (Standard: `latest`).

## Nutzung

### 1. Setup ausführen (einmalig)
```bash
cd tekton/argocd
export DOCKER_USER=dein_username
export DOCKER_TOKEN=dein_token
export DOCKER_EMAIL=deine_email
./setup.sh
```

### 2. Apps bauen
```bash
./build.sh --list                    # Zeigt alle verfügbaren Apps
./build.sh caweb                     # Baut einzelne App
./build.sh --all                     # Baut alle Apps
IMAGE_TAG=v1.0.0 ./build.sh tester  # Mit spezifischem Tag
```