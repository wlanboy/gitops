#!/bin/bash
set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# App-Definitionen: name|repo-url|image-name
declare -A APPS
APPS=(
    ["caweb"]="https://github.com/wlanboy/caweb.git|wlanboy/caweb"
    ["tester"]="https://github.com/wlanboy/httptester.git|wlanboy/httptester"
    ["eureka"]="https://github.com/wlanboy/eurekaclientjava.git|wlanboy/eurekaclientjava"
    ["mirror"]="https://github.com/wlanboy/MirrorService.git|wlanboy/mirrorservice"
    ["javahttpclient"]="https://github.com/wlanboy/JavaHttpClient.git|wlanboy/javahttpclient"
    ["kubeevent"]="https://github.com/wlanboy/kubeevent.git|wlanboy/kubeevent"
    ["kubeeventjava"]="https://github.com/wlanboy/kubeeventjava.git|wlanboy/kubeeventjava"
    ["randomfail"]="https://github.com/wlanboy/randomfail.git|wlanboy/randomfail"
    ["simpleservice"]="https://github.com/wlanboy/SimpleService.git|wlanboy/simpleservice"
    ["webpyshell"]="https://github.com/wlanboy/webpyshell.git|wlanboy/webpyshell"
    ["webshell"]="https://github.com/wlanboy/webpyshell.git|wlanboy/webshell"
    ["wlanboy"]="https://github.com/wlanboy/wlanboy.github.io.git|wlanboy/wlanboy"
)

IMAGE_TAG="${IMAGE_TAG:-latest}"

usage() {
    echo -e "${GREEN}Tekton Build Script${NC}"
    echo ""
    echo "Usage: $0 <app-name|--all|--list>"
    echo ""
    echo "Optionen:"
    echo "  <app-name>    Einzelne App bauen"
    echo "  --all         Alle Apps bauen"
    echo "  --list        Verfügbare Apps auflisten"
    echo ""
    echo "Umgebungsvariablen:"
    echo "  IMAGE_TAG     Docker Image Tag (default: latest)"
    echo ""
    echo "Beispiele:"
    echo "  $0 caweb"
    echo "  $0 --all"
    echo "  IMAGE_TAG=v1.0.0 $0 tester"
}

list_apps() {
    echo -e "${GREEN}Verfügbare Apps:${NC}"
    echo ""
    printf "%-18s %-45s %s\n" "APP" "REPOSITORY" "IMAGE"
    printf "%-18s %-45s %s\n" "---" "----------" "-----"
    for app in "${!APPS[@]}"; do
        IFS='|' read -r repo image <<< "${APPS[$app]}"
        printf "%-18s %-45s %s\n" "$app" "$repo" "$image"
    done | sort
}

build_app() {
    local app_name=$1

    if [ -z "${APPS[$app_name]}" ]; then
        echo -e "${RED}Fehler: App '$app_name' nicht gefunden.${NC}"
        echo "Nutze '$0 --list' für verfügbare Apps."
        exit 1
    fi

    IFS='|' read -r repo_url image_name <<< "${APPS[$app_name]}"

    echo -e "${BLUE}Building: $app_name${NC}"
    echo "  Repository: $repo_url"
    echo "  Image:      $image_name:$IMAGE_TAG"

    # PipelineRun erstellen
    cat <<EOF | kubectl create -f -
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: build-${app_name}-
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: docker-build-pipeline
  serviceAccountName: tekton-build-sa
  params:
    - name: repo-url
      value: ${repo_url}
    - name: image-name
      value: ${image_name}
    - name: image-tag
      value: ${IMAGE_TAG}
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
EOF

    echo -e "${GREEN}PipelineRun für $app_name gestartet.${NC}"
}

build_all() {
    echo -e "${GREEN}Baue alle Apps...${NC}"
    echo ""
    for app in "${!APPS[@]}"; do
        build_app "$app"
        echo ""
    done
    echo -e "${GREEN}Alle PipelineRuns gestartet!${NC}"
    echo ""
    echo "Status prüfen mit:"
    echo "  kubectl get pipelineruns -n tekton-pipelines"
}

# Main
case "${1:-}" in
    --help|-h)
        usage
        ;;
    --list|-l)
        list_apps
        ;;
    --all|-a)
        build_all
        ;;
    "")
        usage
        exit 1
        ;;
    *)
        build_app "$1"
        ;;
esac
