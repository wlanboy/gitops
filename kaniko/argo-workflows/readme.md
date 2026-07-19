# Argo Workflows + Kaniko

Kubernetes-native Build Pipelines mit Argo Workflows und Kaniko.

## Dateien

```
argo-workflows/
├── namespace.yaml          # Namespace
├── install.yaml            # Installation Hinweise
├── secrets.yaml            # Docker Hub + GitHub Secrets
├── workflow-template.yaml  # Wiederverwendbares Build Template
├── workflow-caweb.yaml     # Beispiel Workflow für caweb
└── sensor-github.yaml      # Optional: GitHub Webhook Trigger
```

## Installation

### 1. Namespace
```bash
kubectl apply -f namespace.yaml
```

### 2. Argo Workflows installieren
```bash
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/download/v3.5.5/quick-start-minimal.yaml
```

### 3. Secrets erstellen
```bash
# Docker Hub
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=wlanboy \
  --docker-password=DEIN_TOKEN \
  -n argo

# GitHub (optional, für private Repos)
kubectl create secret generic github-creds \
  --from-literal=token=GITHUB_TOKEN \
  -n argo
```

### 4. Workflow Template deployen
```bash
kubectl apply -f workflow-template.yaml
```

## Build starten

### Manuell via kubectl
```bash
kubectl create -f workflow-caweb.yaml
```

### Mit argo CLI
```bash
# CLI installieren: https://github.com/argoproj/argo-workflows/releases
argo submit workflow-caweb.yaml -n argo --watch
```

### Mit Parametern
```bash
argo submit -n argo --from workflowtemplate/kaniko-build \
  -p repo=https://github.com/wlanboy/mirror.git \
  -p image=wlanboy/mirror \
  -p tag=v1.0.0
```

## Status prüfen

```bash
# Alle Workflows
argo list -n argo

# Logs eines Workflows
argo logs -n argo @latest

# UI öffnen (Port-Forward)
kubectl port-forward svc/argo-server -n argo 2746:2746
# Dann: https://localhost:2746
```

## Wie der Build-Workflow funktioniert

`workflow-template.yaml` definiert eine `WorkflowTemplate` namens `kaniko-build` mit zwei Schritten, die sich einen gemeinsamen Speicher (`volumeClaimTemplates: workspace`, ein PVC) teilen:

1. **`git-clone`** – ein `alpine/git`-Container klont das Repo (`{{workflow.parameters.repo}}`, Branch `{{workflow.parameters.branch}}`) nach `/workspace/source`.
2. **`kaniko`** – der Kaniko-Executor baut aus genau diesem Verzeichnis (`--context=/workspace/source`) das Image und pusht es nach `{{image}}:{{tag}}`.

Der Grund für zwei getrennte Schritte statt Kanikos eingebautem `git://`-Context (wie in der Kubernetes-Job-Variante): Argo Workflows kann so pro Schritt Logs/Status einzeln anzeigen, und der Clone-Schritt kann bei Bedarf leicht getauscht/erweitert werden (z. B. um private Repos mit Token-Auth), ohne den Kaniko-Schritt anzufassen.

`workflow-caweb.yaml` ist ein fertiger `Workflow`, der diese Template mit konkreten Parametern für `caweb` referenziert (`workflowTemplateRef`) – das ist das Pendant zu `job-caweb.yaml` in der Kubernetes-Job-Variante. Für eine neue App brauchst du **keine** neue Template-Definition, sondern nur einen neuen kleinen `Workflow` (oder einen `argo submit --from workflowtemplate/...` Aufruf) mit anderen `-p repo=... -p image=...`-Werten.

## Optional: GitHub Webhook Trigger

Für automatische Builds bei Git Push:

### 1. Argo Events installieren
```bash
kubectl create namespace argo-events
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml
```

### 2. EventSource + Sensor deployen
```bash
kubectl apply -f sensor-github.yaml
```

### 3. Webhook in GitHub konfigurieren
- URL: `https://dein-cluster/push`
- Content-Type: `application/json`
- Events: `push`

### Was dabei im Detail passiert

`sensor-github.yaml` enthält zwei Ressourcen, die zusammenspielen:

1. **`EventSource` (`github-webhook`)** – öffnet einen echten HTTP-Endpunkt (`/push` auf Port `12000`) und registriert sich selbst als GitHub-Webhook für das Repo `wlanboy/caweb` (über `apiToken` aus dem Secret `github-creds`). Anders als beim `nc`-Skript der Kubernetes-Job-Variante übernimmt hier Argo Events das komplette HTTP-Handling, die GitHub-Webhook-Registrierung und die Signaturprüfung.
2. **`Sensor` (`github-sensor`)** – "hängt" (`dependencies`) am Event `caweb` dieser EventSource. Trifft ein Push-Event ein, führt der Trigger `trigger-kaniko` eine `k8s create`-Operation aus: Es wird ein neuer `Workflow` erzeugt (`generateName: build-caweb-`), der per `workflowTemplateRef` auf `kaniko-build` verweist – also exakt die oben beschriebene Template mit `git-clone` + `kaniko`.
3. **Dynamischer Tag** – der Block `parameters` am Ende ersetzt den vierten Parameter (`spec.arguments.parameters.3.value`, also `tag`) durch `body.after` aus der Event-Payload – das ist die neue Commit-SHA aus dem GitHub-Push-Payload. Dadurch bekommt jedes gebaute Image automatisch die SHA des auslösenden Commits als Tag, statt eines festen `latest`.

Im Vergleich zur Kubernetes-Job-Variante (ArgoCD-Notification → selbstgebauter `nc`-Webhook) ist das robuster: kein selbstgeschriebener HTTP-Parser, Auth über GitHub-Token, und der Trigger reagiert direkt auf den Push (nicht erst nach einem ArgoCD-Sync).

## Workflow für neue App erstellen

Kopiere `workflow-caweb.yaml` und passe die Parameter an:
- `repo`: Git Repository URL
- `image`: Docker Hub Image Name
- `tag`: Image Tag
- `branch`: Git Branch

## Deinstallation

```bash
# Interaktiv – für jede Komponente einzeln bestätigen
./uninstall.sh

# Alles ohne Rückfrage löschen
./uninstall.sh --all
```

Reihenfolge der entfernten Komponenten:
1. Laufende Workflows
2. WorkflowTemplate `kaniko-build`
3. EventSource `github-webhook` + Sensor `github-sensor`
4. Secrets `dockerhub-creds` und `github-creds`
5. Argo Events (Namespace `argo-events`)
6. Argo Workflows (quick-start-minimal)
7. Namespace `argo`
