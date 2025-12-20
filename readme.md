# init argocd apps
```bash
export GITHUB_USERNAME="user_name"
export GITHUB_TOKEN="ghp_XXXXXX"

envsubst < repo-wlanboy.yaml | kubectl apply -f -

kubectl apply -f cluster-gmk.yaml

kubectl apply -f projects/wlanboy-project.yaml

kubectl apply -f namespaces/namespace-wlanboy.yaml
kubectl apply -f apps/app-wlanboy.yaml
```

