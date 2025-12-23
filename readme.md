# init argocd apps
```bash
export GITHUB_USERNAME="user_name"
export GITHUB_TOKEN="ghp_XXXXXX"

envsubst < repo-wlanboy.yaml | kubectl apply -f -

kubectl apply -f cluster-gmk.yaml

kubectl apply -f projects/wlanboy-project.yaml

kubectl apply -f namespaces/namespace-wlanboy.yaml
kubectl apply -f apps/app-wlanboy.yaml

kubectl apply -f namespaces/namespace-tester.yaml
kubectl apply -f apps/app-tester.yaml

kubectl apply -f namespaces/namespace-eureka.yaml
kubectl apply -f apps/app-eureka.yaml

kubectl apply -f namespaces/namespace-mirror.yaml
kubectl apply -f apps/app-mirror.yaml

kubectl apply -f namespaces/namespace-javahttpclient.yaml
kubectl apply -f apps/app-javahttpclient.yaml

kubectl apply -f namespaces/namespace-webshell.yaml
kubectl apply -f apps/app-webshell.yaml
```

# argocli
```bash
read -s ARGO_PW
argocd login argocd.gmk.lan --grpc-web \
  --username admin \
  --password "$ARGO_PW"

argocd app get wlanboy
argocd app sync wlanboy

argocd app get tester
argocd app sync tester

argocd app get eureka
argocd app sync eureka

argocd app get mirror
argocd app sync mirrir

argocd app get javahttpclient
argocd app sync javahttpclient

argocd app get webshell
argocd app sync webshell
```