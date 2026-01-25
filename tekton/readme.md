# Tekton Builds

Tekton Pipelines für deine GitHub-Projekte und ArgoCD Apps einrichten.

**Voraussetzungen:** K3s Cluster, Istio, Cert-Manager und ArgoCD müssen laufen.

---

## 1. Tekton Installation per Helm

### Helm Repos hinzufügen

```bash
# Tekton Pipelines (Core)
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Warten bis Tekton ready ist
kubectl wait --for=condition=Ready pods --all -n tekton-pipelines --timeout=300s
```

### Tekton Dashboard (optional aber empfohlen)

```bash
helm repo add tekton https://tektoncd.github.io/dashboard
helm repo update

helm install tekton-dashboard tekton/tekton-dashboard \
  --namespace tekton-pipelines \
  --set service.type=ClusterIP
```

### Tekton Triggers (für Webhooks)

```bash
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply --filename https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml

# Warten bis ready
kubectl wait --for=condition=Ready pods --all -n tekton-pipelines --timeout=300s
```

---

## 2. Credentials einrichten

### Docker Hub Secret

```bash
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<DEIN_USER> \
  --docker-password=<DEIN_TOKEN> \
  --docker-email=<DEINE_EMAIL> \
  -n tekton-pipelines
```

### GitHub Secret (für private Repos)

```bash
kubectl create secret generic github-creds \
  --from-literal=username=<GITHUB_USER> \
  --from-literal=password=<GITHUB_PAT> \
  -n tekton-pipelines
```

### ServiceAccount mit Secrets

```yaml
# tekton-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-build-sa
  namespace: tekton-pipelines
secrets:
  - name: dockerhub-creds
  - name: github-creds
imagePullSecrets:
  - name: dockerhub-creds
```

```bash
kubectl apply -f tekton-serviceaccount.yaml
```

---

## 3. Tekton Tasks installieren

### Git-Clone Task (aus Tekton Hub)

```bash
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml -n tekton-pipelines
```

### Kaniko Build Task (für Docker Images ohne Docker Daemon)

```yaml
# task-kaniko.yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: kaniko-build
  namespace: tekton-pipelines
spec:
  params:
    - name: IMAGE
      description: Name des Docker Images (z.B. wlanboy/caweb:latest)
    - name: DOCKERFILE
      default: ./Dockerfile
    - name: CONTEXT
      default: .
  workspaces:
    - name: source
  results:
    - name: IMAGE_DIGEST
      description: Digest des gebauten Images
  steps:
    - name: build-and-push
      image: gcr.io/kaniko-project/executor:latest
      args:
        - --dockerfile=$(params.DOCKERFILE)
        - --context=$(workspaces.source.path)/$(params.CONTEXT)
        - --destination=$(params.IMAGE)
        - --digest-file=$(results.IMAGE_DIGEST.path)
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
  volumes:
    - name: docker-config
      secret:
        secretName: dockerhub-creds
        items:
          - key: .dockerconfigjson
            path: config.json
```

```bash
kubectl apply -f task-kaniko.yaml
```

---

## 4. Pipeline Definition

### Generische Build Pipeline

```yaml
# pipeline-docker-build.yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: docker-build-pipeline
  namespace: tekton-pipelines
spec:
  params:
    - name: repo-url
      type: string
      description: Git Repository URL
    - name: repo-revision
      type: string
      default: main
    - name: image-name
      type: string
      description: Docker Image Name (z.B. wlanboy/caweb)
    - name: image-tag
      type: string
      default: latest
    - name: dockerfile-path
      type: string
      default: ./Dockerfile
    - name: context-path
      type: string
      default: .
  workspaces:
    - name: shared-workspace
  tasks:
    - name: fetch-source
      taskRef:
        name: git-clone
      workspaces:
        - name: output
          workspace: shared-workspace
      params:
        - name: url
          value: $(params.repo-url)
        - name: revision
          value: $(params.repo-revision)
    - name: build-push
      taskRef:
        name: kaniko-build
      runAfter:
        - fetch-source
      workspaces:
        - name: source
          workspace: shared-workspace
      params:
        - name: IMAGE
          value: $(params.image-name):$(params.image-tag)
        - name: DOCKERFILE
          value: $(params.dockerfile-path)
        - name: CONTEXT
          value: $(params.context-path)
```

```bash
kubectl apply -f pipeline-docker-build.yaml
```

---

## 5. PipelineRuns für deine Apps

### Beispiel: caweb bauen

```yaml
# pipelinerun-caweb.yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: build-caweb-
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: docker-build-pipeline
  serviceAccountName: tekton-build-sa
  params:
    - name: repo-url
      value: https://github.com/wlanboy/caweb.git
    - name: image-name
      value: wlanboy/caweb
    - name: image-tag
      value: latest
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
```

```bash
kubectl create -f pipelinerun-caweb.yaml
```

### Beispiel: tester bauen

```yaml
# pipelinerun-tester.yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: build-tester-
  namespace: tekton-pipelines
spec:
  pipelineRef:
    name: docker-build-pipeline
  serviceAccountName: tekton-build-sa
  params:
    - name: repo-url
      value: https://github.com/wlanboy/httptester.git
    - name: image-name
      value: wlanboy/tester
    - name: image-tag
      value: latest
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 1Gi
```

---

## 6. Alle Apps auf einen Blick

| App | GitHub Repo | Docker Image |
|-----|-------------|--------------|
| caweb | wlanboy/caweb | wlanboy/caweb |
| tester | wlanboy/httptester | wlanboy/httptester |
| eureka | wlanboy/eurekaclientjava | wlanboy/eurekaclientjava |
| mirror | wlanboy/MirrorService | wlanboy/mirrorservice |
| wlanboy | wlanboy/wlanboy.github.io | wlanboy/wlanboy |
| webshell | wlanboy/webpyshell | wlanboy/webshell |
| webpyshell | wlanboy/webpyshell | wlanboy/webpyshell |
| kubeevent | wlanboy/kubeevent | wlanboy/kubeevent |
| kubeeventjava | wlanboy/kubeeventjava | wlanboy/kubeeventjava |
| randomfail | wlanboy/randomfail | wlanboy/randomfail |
| simpleservice | wlanboy/SimpleService | wlanboy/simpleservice |
| javahttpclient | wlanboy/JavaHttpClient | wlanboy/javahttpclient |

---

## 7. Nützliche Befehle

```bash
# Pipeline Runs anzeigen
kubectl get pipelineruns -n tekton-pipelines

# Logs eines PipelineRuns anschauen
kubectl logs -n tekton-pipelines -l tekton.dev/pipelineRun=<NAME> --all-containers

# Tekton CLI installieren (tkn)
# Dann einfacher:
tkn pipelinerun list -n tekton-pipelines
tkn pipelinerun logs -n tekton-pipelines <NAME> -f

# Dashboard Port-Forward
kubectl port-forward svc/tekton-dashboard -n tekton-pipelines 9097:9097
# Dann: http://localhost:9097
```

---

## 8. Istio Gateway und TLS Certificate

Das Tekton Dashboard wird über Istio mit TLS-Zertifikat von cert-manager erreichbar gemacht.

### Certificate (im istio-ingress Namespace)

```yaml
# certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tekton-dashboard-tls
  namespace: istio-ingress
spec:
  secretName: tekton-dashboard-tls
  issuerRef:
    name: local-ca-issuer
    kind: ClusterIssuer
  dnsNames:
    - tekton.gkmc.lan
  privateKey:
    rotationPolicy: Always
```

### Gateway und VirtualService

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: tekton-gateway
  namespace: tekton-pipelines
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https
        protocol: HTTPS
      hosts:
        - tekton.gkmc.lan
      tls:
        mode: SIMPLE
        credentialName: tekton-dashboard-tls
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - tekton.gkmc.lan
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: tekton-dashboard
  namespace: tekton-pipelines
spec:
  hosts:
    - tekton.gkmc.lan
  gateways:
    - tekton-gateway
  http:
    - match:
        - uri:
            prefix: /
      route:
        - destination:
            host: tekton-dashboard
            port:
              number: 9097
```

```bash
kubectl apply -f certificate.yaml
kubectl apply -f gateway.yaml
```

Das Dashboard ist dann erreichbar unter: **https://tekton.gkmc.lan**

---

## 9. Webhook Trigger (optional)

Für automatische Builds bei Git Push:

```yaml
# trigger-template.yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: docker-build-trigger-template
  namespace: tekton-pipelines
spec:
  params:
    - name: gitrevision
    - name: gitrepositoryurl
    - name: imagename
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: triggered-build-
      spec:
        pipelineRef:
          name: docker-build-pipeline
        serviceAccountName: tekton-build-sa
        params:
          - name: repo-url
            value: $(tt.params.gitrepositoryurl)
          - name: repo-revision
            value: $(tt.params.gitrevision)
          - name: image-name
            value: $(tt.params.imagename)
        workspaces:
          - name: shared-workspace
            volumeClaimTemplate:
              spec:
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: 1Gi
```

---

## Schnellstart-Zusammenfassung

```bash
# 1. Tekton installieren
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
kubectl wait --for=condition=Ready pods --all -n tekton-pipelines --timeout=300s

# 2. Triggers installieren
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml

# 3. Docker Hub Credentials
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=DEIN_USER \
  --docker-password=DEIN_TOKEN \
  --docker-email=DEINE_EMAIL \
  -n tekton-pipelines

# 4. Tasks und Pipeline anwenden
kubectl apply -f tekton-serviceaccount.yaml
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml -n tekton-pipelines
kubectl apply -f task-kaniko.yaml
kubectl apply -f pipeline-docker-build.yaml

# 5. Istio Gateway und TLS
kubectl apply -f certificate.yaml
kubectl apply -f gateway.yaml

# 6. Build starten
kubectl create -f pipelinerun-caweb.yaml

# Dashboard: https://tekton.gkmc.lan
```

---

## Automatisiertes Setup

Alternativ kannst du das Setup-Script im `argocd/` Unterordner verwenden:

```bash
cd tekton/argocd
export DOCKER_USER=dein_username
export DOCKER_TOKEN=dein_token
export DOCKER_EMAIL=deine_email
./setup.sh

# Apps bauen
./build.sh --list          # Zeigt alle Apps
./build.sh caweb           # Baut einzelne App
./build.sh --all           # Baut alle Apps
```
