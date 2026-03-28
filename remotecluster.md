# Add remote cluster

Dieses Dokument beschreibt, wie ein entfernter Kubernetes-Cluster zu ArgoCD hinzugefügt wird. ArgoCD benötigt dafür einen dedizierten ServiceAccount mit den nötigen Berechtigungen sowie die Zugangsdaten (Token und CA-Zertifikat) des Ziel-Clusters.

## serviceaccount and token

Auf dem **Ziel-Cluster** (remote cluster) ausführen:

```bash
# Namespace für den ArgoCD-Manager anlegen (idempotent durch --dry-run + apply)
kubectl create namespace argocd-manager --dry-run=client -o yaml | kubectl apply -f -

# ServiceAccount anlegen, unter dem ArgoCD auf dem Ziel-Cluster agiert
kubectl -n argocd-manager create serviceaccount argocd-manager

# ClusterRoleBinding: gibt dem ServiceAccount cluster-admin Rechte,
# damit ArgoCD alle Ressourcen verwalten kann
kubectl create clusterrolebinding argocd-manager-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=argocd-manager:argocd-manager

# Das automatisch erstellte Secret des ServiceAccounts ermitteln
SECRET=$(kubectl -n argocd-manager get sa argocd-manager -o jsonpath="{.secrets[0].name}")

# Bearer-Token aus dem Secret extrahieren (base64-dekodiert)
CLUSTER_TOKEN=$(kubectl -n argocd-manager get secret $SECRET -o jsonpath="{.data.token}" | base64 -d)

# CA-Zertifikat des Ziel-Clusters extrahieren (base64-kodiert, wird so im Secret gespeichert)
CLUSTER_CA=$(kubectl -n argocd-manager get secret $SECRET -o jsonpath="{.data['ca\.crt']}")

# API-Server-URL des Ziel-Clusters (kubectl cluster-info zum Ermitteln)
#kubectl cluster-info
CLUSTER_API="https://192.168.178.83:6443"

# Frei wählbarer Name für den Cluster in ArgoCD
CLUSTER_NAME="p400"
```

## add cluster to argocd

Auf dem **ArgoCD-Cluster** ausführen. Die zuvor gesetzten Umgebungsvariablen (`CLUSTER_TOKEN`, `CLUSTER_CA`, `CLUSTER_API`, `CLUSTER_NAME`) werden benötigt.

```bash
# Template mit den Cluster-Zugangsdaten befüllen und als Cluster-Secret speichern
envsubst < cluster-template.yaml.tpl > cluster-${CLUSTER_NAME}.yaml

# Cluster-Secret in ArgoCD registrieren (im argocd Namespace)
kubectl apply -f cluster-p400.yaml
```

Das resultierende Secret enthält die Verbindungsdaten und wird von ArgoCD als bekannter Ziel-Cluster erkannt.
