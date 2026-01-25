## Nutzung
Tekton Scripts für ArgoCD App Definitionen

# 1. Setup ausführen (einmalig)
cd tekton/argocd
export DOCKER_USER=dein_username
export DOCKER_TOKEN=dein_token
export DOCKER_EMAIL=deine_email
./setup.sh

# 2. Apps bauen
./build.sh --list          # Zeigt alle verfügbaren Apps
./build.sh caweb           # Baut einzelne App
./build.sh --all           # Baut alle Apps
IMAGE_TAG=v1.0.0 ./build.sh tester   # Mit spezifischem Tag