# init argocd apps
```bash
export GITHUB_USERNAME="dein-user"
export GITHUB_TOKEN="ghp_XXXXXX"

envsubst < repo-wlanboy.yaml | kubectl apply -f -

kubectl apply -f cluster-gmk.yaml

kubectl apply -f namespaces/namespace-wlanboy.yaml
kubectl apply -f apps/wlanboy.yaml
```

