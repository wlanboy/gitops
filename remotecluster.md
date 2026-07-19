# Add remote cluster

Dieses Dokument beschreibt, wie ein entfernter Kubernetes-Cluster zu ArgoCD hinzugefügt wird. ArgoCD verwaltet Ziel-Cluster nicht über eine eigene Anmeldung, sondern über ein Kubernetes-Secret im `argocd`-Namespace, das die Zugangsdaten eines ServiceAccounts auf dem Ziel-Cluster enthält (Bearer-Token + CA-Zertifikat des API-Servers).

Der Ablauf läuft über zwei verschiedene Cluster-Kontexte – vorher mit `kubectl config get-contexts` prüfen, welcher Kontext gerade aktiv ist, und bei Bedarf mit `kubectl config use-context <name>` wechseln:

1. Auf dem **Ziel-Cluster**: ServiceAccount + Berechtigungen anlegen, Token und CA extrahieren.
2. Auf dem **ArgoCD-Cluster**: Aus diesen Daten ein Cluster-Secret bauen und anwenden.

## 1. ServiceAccount und Token (auf dem Ziel-Cluster)

```bash
# Namespace für den ArgoCD-Manager anlegen (idempotent durch --dry-run + apply)
kubectl create namespace argocd-manager --dry-run=client -o yaml | kubectl apply -f -

# ServiceAccount anlegen, unter dessen Identität ArgoCD auf dem Ziel-Cluster agiert
kubectl -n argocd-manager create serviceaccount argocd-manager

# ClusterRoleBinding: gibt dem ServiceAccount cluster-admin Rechte,
# damit ArgoCD beliebige Ressourcen deployen/verwalten kann.
# Für produktive Umgebungen ggf. durch eine restriktivere ClusterRole ersetzen,
# statt pauschal cluster-admin zu vergeben.
kubectl create clusterrolebinding argocd-manager-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=argocd-manager:argocd-manager

# API-Server-URL des Ziel-Clusters (mit "kubectl cluster-info" ermitteln)
CLUSTER_API="https://192.168.178.83:6443"

# Frei wählbarer Name für den Cluster in ArgoCD
CLUSTER_NAME="p400"
```

### Token besorgen

Ab Kubernetes 1.24 legt Kubernetes für ServiceAccounts **kein** Secret mehr automatisch an – `.secrets[]` ist dann leer und die frühere Methode über `kubectl get sa ... -o jsonpath="{.secrets[0].name}"` liefert kein Ergebnis. Vorher mit `kubectl version` prüfen, welcher Fall zutrifft:

**Kubernetes < 1.24** (automatisches Secret vorhanden):

```bash
SECRET=$(kubectl -n argocd-manager get sa argocd-manager -o jsonpath="{.secrets[0].name}")
CLUSTER_TOKEN=$(kubectl -n argocd-manager get secret "$SECRET" -o jsonpath="{.data.token}" | base64 -d)
CLUSTER_CA=$(kubectl -n argocd-manager get secret "$SECRET" -o jsonpath="{.data['ca\.crt']}")
```

**Kubernetes >= 1.24** (Secret muss manuell erzeugt werden, dauerhaft gültig statt ablaufend):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: argocd-manager
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
EOF

# Kurz warten, bis Kubernetes das Token in das Secret befüllt hat
CLUSTER_TOKEN=$(kubectl -n argocd-manager get secret argocd-manager-token -o jsonpath="{.data.token}" | base64 -d)
CLUSTER_CA=$(kubectl -n argocd-manager get secret argocd-manager-token -o jsonpath="{.data['ca\.crt']}")
```

`CLUSTER_TOKEN` wird base64-**dekodiert** (Klartext-Token für das JSON im Cluster-Secret), `CLUSTER_CA` bleibt base64-**kodiert**, da das Ziel-Feld `caData` im ArgoCD-Cluster-Secret ohnehin base64 erwartet.

## 2. Cluster in ArgoCD registrieren (auf dem ArgoCD-Cluster)

Die zuvor gesetzten Umgebungsvariablen (`CLUSTER_TOKEN`, `CLUSTER_CA`, `CLUSTER_API`, `CLUSTER_NAME`) werden hier benötigt – ggf. per `export` in die neue Shell-Session mitgeben oder das Skript am Stück in einer Session ausführen.

```bash
# Template (cluster.yaml.tpl) mit den Zugangsdaten befüllen und als Cluster-Secret ablegen
envsubst < cluster.yaml.tpl > cluster-${CLUSTER_NAME}.yaml

# Cluster-Secret in ArgoCD registrieren (Namespace "argocd" steht im Template selbst)
kubectl apply -f cluster-${CLUSTER_NAME}.yaml
```

ArgoCD erkennt das Secret anhand des Labels `argocd.argoproj.io/secret-type: cluster` (siehe [cluster.yaml.tpl](cluster.yaml.tpl)) automatisch als neuen Ziel-Cluster. Prüfen lässt sich das Ergebnis mit:

```bash
argocd cluster list
```
