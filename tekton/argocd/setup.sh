#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Tekton Build Pipeline Setup ===${NC}"

# Docker Hub Credentials prüfen
if [ -z "$DOCKER_USER" ] || [ -z "$DOCKER_TOKEN" ] || [ -z "$DOCKER_EMAIL" ]; then
    echo -e "${YELLOW}Bitte Docker Hub Credentials als Umgebungsvariablen setzen:${NC}"
    echo "  export DOCKER_USER=dein_username"
    echo "  export DOCKER_TOKEN=dein_token"
    echo "  export DOCKER_EMAIL=deine_email"
    echo ""
    read -p "Möchtest du die Credentials jetzt eingeben? (j/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Jj]$ ]]; then
        read -p "Docker Username: " DOCKER_USER
        read -s -p "Docker Token/Passwort: " DOCKER_TOKEN
        echo
        read -p "Docker Email: " DOCKER_EMAIL
    else
        echo -e "${RED}Abbruch. Bitte Credentials setzen und erneut starten.${NC}"
        exit 1
    fi
fi

# 1. Tekton Pipelines installieren
echo -e "\n${GREEN}[1/7] Tekton Pipelines installieren...${NC}"
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
echo "Warte auf Tekton Pipelines..."
kubectl wait --for=condition=Ready pods --all -n tekton-pipelines --timeout=300s

# 2. Tekton Triggers installieren
echo -e "\n${GREEN}[2/7] Tekton Triggers installieren...${NC}"
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
echo "Warte auf Tekton Triggers..."
sleep 10
kubectl wait --for=condition=Ready pods --all -n tekton-pipelines --timeout=300s

# 3. Docker Hub Secret erstellen
echo -e "\n${GREEN}[3/7] Docker Hub Credentials einrichten...${NC}"
kubectl delete secret dockerhub-creds -n tekton-pipelines 2>/dev/null || true
kubectl create secret docker-registry dockerhub-creds \
    --docker-server=https://index.docker.io/v1/ \
    --docker-username="$DOCKER_USER" \
    --docker-password="$DOCKER_TOKEN" \
    --docker-email="$DOCKER_EMAIL" \
    -n tekton-pipelines

# 4. ServiceAccount erstellen
echo -e "\n${GREEN}[4/7] ServiceAccount erstellen...${NC}"
kubectl apply -f "$SCRIPT_DIR/serviceaccount.yaml"

# 5. Tasks installieren
echo -e "\n${GREEN}[5/7] Tasks installieren...${NC}"
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml -n tekton-pipelines
kubectl apply -f "$SCRIPT_DIR/task-kaniko.yaml"

# 6. Pipeline installieren
echo -e "\n${GREEN}[6/7] Pipeline installieren...${NC}"
kubectl apply -f "$SCRIPT_DIR/pipeline.yaml"

# 7. Istio Gateway und Certificate
echo -e "\n${GREEN}[7/7] Istio Gateway und TLS Certificate einrichten...${NC}"
kubectl apply -f "$SCRIPT_DIR/certificate.yaml"
kubectl apply -f "$SCRIPT_DIR/gateway.yaml"

echo -e "\n${GREEN}=== Setup abgeschlossen! ===${NC}"
echo ""
echo -e "${GREEN}Tekton Dashboard erreichbar unter:${NC}"
echo "  https://tekton.gkmc.lan"
echo ""
echo "Nutze jetzt './build.sh <app>' um eine App zu bauen, z.B.:"
echo "  ./build.sh caweb"
echo "  ./build.sh tester"
echo "  ./build.sh --all"
echo ""
echo "Status prüfen mit:"
echo "  kubectl get pipelineruns -n tekton-pipelines"
echo "  kubectl get certificate -n istio-ingress"
