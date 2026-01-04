# Add remote cluster

## serviceaccount and token
```bash
kubectl create namespace argocd-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl -n argocd-manager create serviceaccount argocd-manager
kubectl create clusterrolebinding argocd-manager-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=argocd-manager:argocd-manager
SECRET=$(kubectl -n argocd-manager get sa argocd-manager -o jsonpath="{.secrets[0].name}")
CLUSTER_TOKEN=$(kubectl -n argocd-manager get secret $SECRET -o jsonpath="{.data.token}" | base64 -d)
CLUSTER_CA=$(kubectl -n argocd-manager get secret $SECRET -o jsonpath="{.data['ca\.crt']}")

#kubectl cluster-info
CLUSTER_API="https://192.168.178.83:6443"
CLUSTER_NAME="p400"
```

## add cluster to argocd
```bash
envsubst < cluster-template.yaml.tpl > cluster-${CLUSTER_NAME}.yaml

kubectl apply -f cluster-p400.yaml
```