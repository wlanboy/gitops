# Kaniko Build Jobs

Minimales Setup für Docker Image Builds mit Kaniko in Kubernetes.

> ⚠️ **Kaniko ist seit 2025-06-03 archiviert** (GoogleContainerTools/kaniko wird nicht mehr gepflegt, `gcr.io/kaniko-project/executor` bekommt keine Updates/CVE-Fixes mehr). Chainguard pflegt einen Fork, das Image ist aber nur kostenpflichtig über einen eigenen Chainguard-Account (`cgr.dev/ORGANIZATION/kaniko`) verfügbar. Für neue Projekte siehe die Alternative [../buildah/buildah.md](../buildah/buildah.md) (Buildah, frei & aktiv gepflegt). Dieses Verzeichnis dient nur noch als Referenz für Bestandssetups.

## Setup

### 1. Namespace erstellen

```bash
kubectl apply -f namespace.yaml
```

### 2. Secrets erstellen

**Docker Hub:**

```bash
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=wlanboy \
  --docker-password=DEIN_DOCKERHUB_TOKEN \
  -n kaniko
```

**GitHub (für private Repos):**

```bash
kubectl create secret generic github-creds \
  --from-literal=.git-credentials='https://USERNAME:GITHUB_TOKEN@github.com' \
  -n kaniko
```

### 3. Manueller Build

```bash
kubectl apply -f job-caweb.yaml
kubectl logs -f job/kaniko-caweb -n kaniko
```

## Automatischer Trigger bei ArgoCD Sync

### 1. Trigger Service deployen

```bash
kubectl apply -f trigger-service.yaml
```

### 2. ArgoCD Notifications konfigurieren

```bash
kubectl apply -f argocd-notifications-cm.yaml
```

### 3. App für Notifications annotieren

```bash
kubectl annotate application caweb \
  notifications.argoproj.io/subscribe.on-sync-succeeded.kaniko-webhook="" \
  -n argocd
```

## Ablauf

```txt
Git Push → ArgoCD Sync → Notification → Webhook → Kaniko Job → Docker Hub
```

### Was dabei im Detail passiert

1. **Git Push** – Code wird auf `main` gepusht.
2. **ArgoCD Sync** – ArgoCD erkennt die Änderung und synct die Application erfolgreich (`Succeeded`).
3. **Notification** – `argocd-notifications-cm.yaml` definiert dafür einen Trigger:
   ```yaml
   trigger.on-sync-succeeded: |
     - when: app.status.operationState.phase in ['Succeeded']
       send: [trigger-kaniko-build]
   ```
   Das zugehörige Template baut daraus einen JSON-Body mit App-Namen, Repo-URL und Revision aus den ArgoCD-Metadaten (`{{.app.metadata.name}}`, `{{.app.spec.source.repoURL}}`, `{{.app.status.sync.revision}}`).
4. **Webhook** – ArgoCD schickt diesen JSON-Body per POST an
   `http://kaniko-trigger.kaniko.svc.cluster.local:8080/build` (definiert in `service.webhook.kaniko-webhook`).
   Empfänger ist der `kaniko-trigger` Service aus `trigger-service.yaml`. Dahinter läuft **kein** vollwertiger HTTP-Server, sondern ein simples Shell-Skript, das mit `nc -l -p 8080` in einer Endlosschleife lauscht, die Request-Zeilen einliest und mit `jq` `app` und `repo` aus dem Body extrahiert.
5. **Kaniko Job** – Das Skript löscht einen eventuell vorhandenen alten Job (`kubectl delete job kaniko-$APP`) und erzeugt per `kubectl apply -f -` einen neuen `Job` – strukturell identisch zu `job-caweb.yaml`, nur mit `$APP`/`$REPO` als Platzhalter statt fest codierten Werten. Damit der Pod das darf, besitzt er über `ServiceAccount` + `Role` + `RoleBinding` (ebenfalls in `trigger-service.yaml`) die Rechte, Jobs im Namespace `kaniko` zu erstellen/löschen.
6. **Docker Hub** – Der neue Kaniko-Job baut das Image aus dem Git-Context und pusht es nach `wlanboy/$APP:latest`.

> **Hinweis:** Der Webhook-Server basiert auf `nc` in einer Shell-Schleife – ohne Auth, ohne TLS, ohne robustes HTTP-Parsing. Das reicht für ein internes, vertrauenswürdiges Cluster-Netz, ist aber kein produktionsreifer Webhook-Empfänger.

## Neuen Build manuell triggern

```bash
# Job löschen und neu erstellen
kubectl delete job kaniko-caweb -n kaniko --ignore-not-found
kubectl apply -f job-caweb.yaml
```

## Debugging

```bash
# Job Status
kubectl get jobs -n kaniko

# Build Logs
kubectl logs -f job/kaniko-caweb -n kaniko

# Trigger Service Logs
kubectl logs -f deployment/kaniko-trigger -n kaniko
```
