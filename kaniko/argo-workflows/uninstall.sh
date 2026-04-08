#!/bin/bash
set -euo pipefail

NS="argo-workflows"

ALL=false
if [[ "${1:-}" == "--all" ]]; then
  ALL=true
fi

ask() {
  local question="$1"
  if $ALL; then return 0; fi
  read -r -p "$question [j/N] " answer
  [[ "$answer" =~ ^[jJyY]$ ]]
}

echo "=== Argo Workflows Deinstallation (Namespace: $NS) ==="
if $ALL; then echo "(--all: alle Komponenten werden ohne Rückfrage gelöscht)"; fi
echo ""

# 1. Laufende Workflows löschen
if ask "Alle laufenden Workflows im Namespace '$NS' löschen?"; then
  kubectl delete workflows --all -n "$NS" --ignore-not-found
  echo "-> Workflows gelöscht."
fi

# 2. WorkflowTemplate löschen
if ask "WorkflowTemplate 'kaniko-build' löschen?"; then
  kubectl delete workflowtemplate kaniko-build -n "$NS" --ignore-not-found
  echo "-> WorkflowTemplate gelöscht."
fi

# 3. EventSource + Sensor löschen
if ask "EventSource 'github-webhook' und Sensor 'github-sensor' löschen?"; then
  kubectl delete eventsource github-webhook -n "$NS" --ignore-not-found
  kubectl delete sensor github-sensor -n "$NS" --ignore-not-found
  echo "-> EventSource und Sensor gelöscht."
fi

# 4. Secrets löschen
if ask "Secret 'dockerhub-creds' löschen?"; then
  kubectl delete secret dockerhub-creds -n "$NS" --ignore-not-found
  echo "-> dockerhub-creds gelöscht."
fi

if ask "Secret 'github-creds' löschen?"; then
  kubectl delete secret github-creds -n "$NS" --ignore-not-found
  echo "-> github-creds gelöscht."
fi

# 5. buildkitd löschen
if ask "Deployment 'buildkitd' löschen?"; then
  kubectl delete deployment buildkitd -n "$NS" --ignore-not-found
  kubectl delete service buildkitd -n "$NS" --ignore-not-found
  echo "-> buildkitd gelöscht."
fi

# 6. local-registry löschen
if ask "Deployment 'local-registry' löschen?"; then
  kubectl delete deployment local-registry -n "$NS" --ignore-not-found
  kubectl delete service local-registry -n "$NS" --ignore-not-found
  echo "-> local-registry gelöscht."
fi

# 7. Argo Events deinstallieren
if ask "Argo Events (Namespace 'argo-events' + Manifeste) deinstallieren?"; then
  kubectl delete -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml --ignore-not-found || true
  kubectl delete -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml --ignore-not-found || true
  kubectl delete namespace argo-events --ignore-not-found
  echo "-> Argo Events deinstalliert."
fi

# 8. Argo Workflows deinstallieren
if ask "Argo Workflows (quick-start-minimal) deinstallieren?"; then
  kubectl delete -n "$NS" -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.5/quick-start-minimal.yaml --ignore-not-found || true
  echo "-> Argo Workflows deinstalliert."
fi

# 9. Namespace löschen
if ask "Namespace '$NS' löschen? (löscht alle verbleibenden Ressourcen)"; then
  kubectl delete namespace "$NS" --ignore-not-found
  echo "-> Namespace '$NS' gelöscht."
fi

echo ""
echo "=== Deinstallation abgeschlossen ==="
