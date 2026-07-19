# Buildah Build Jobs

Minimales Setup für Docker Image Builds mit Buildah in Kubernetes — Alternative zu [../kaniko/kaniko.md](../kaniko/kaniko.md), da Kaniko seit 2025-06-03 archiviert und unmaintained ist. Buildah (containers-Projekt, Red Hat) ist frei nutzbar und aktiv gepflegt.

## Dateien

```
buildah/
├── namespace.yaml            # Namespace
├── secret.yaml               # Docker Hub Credentials (Template, gleiches Format wie Kaniko)
├── github-secret.yaml        # GitHub Credentials (für private Repos)
├── job-caweb.yaml            # Beispiel Build Job (git-clone Init-Container + buildah bud/push)
├── job-caweb-local.yaml      # Wie job-caweb.yaml, aber SKIP_PUSH=true und ohne docker-config-Secret (nur lokal bauen)
├── job-caweb-registry-local.yaml  # Wie job-caweb.yaml, aber Push an lokale In-Cluster-Registry (TLS_VERIFY=false, ohne docker-config-Secret)
```

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
  -n buildah
```

Buildah liest dasselbe `config.json`-Format über `--authfile` — kein separates Secret-Format nötig.

**GitHub (für private Repos):**

```bash
kubectl create secret generic github-creds \
  --from-literal=username=USERNAME \
  --from-literal=token=DEIN_GITHUB_TOKEN \
  -n buildah
```

Für private Repos die Clone-URL im Init-Container um `https://$(GIT_USER):$(GIT_TOKEN)@github.com/...` erweitern und die Secret-Keys per `env.valueFrom.secretKeyRef` einspeisen (nicht per Datei-Mount wie bei Kaniko — vermeidet den unzuverlässigen `credential.helper`-Umweg).

### 3. Manueller Build

```bash
kubectl apply -f job-caweb.yaml
kubectl logs -f job/buildah-caweb -n buildah
```

## Parameter: Push steuern / lokale Registry

Der `buildah`-Container in `job-caweb.yaml` unterstützt drei Env-Variablen zur Steuerung des Push-Verhaltens:

| Variable | Default | Zweck |
|----------|---------|-------|
| `REGISTRY` | `docker.io/wlanboy` | Ziel-Registry-Prefix, z. B. `registry.registry.svc.cluster.local:5000` |
| `SKIP_PUSH` | `false` | Bei `true` wird nur gebaut, kein `buildah push` |
| `TLS_VERIFY` | `true` | Bei `false` wird `--tls-verify=false` gesetzt (für lokale Registries ohne TLS) |

Beispiel: nur lokal bauen, kein Push:

```yaml
env:
  - name: SKIP_PUSH
    value: "true"
```

Beispiel: Push an lokale In-Cluster-Registry ohne TLS:

```yaml
env:
  - name: REGISTRY
    value: "registry.registry.svc.cluster.local:5000"
  - name: TLS_VERIFY
    value: "false"
```

### Fertige Variante: nur lokal bauen

`job-caweb-local.yaml` ist eine eigenständige Job-Variante mit `SKIP_PUSH=true` fest vorkonfiguriert. Sie benötigt kein `docker-config`-Secret, da kein Push erfolgt:

```bash
kubectl apply -f job-caweb-local.yaml
kubectl logs -f job/buildah-caweb-local -n buildah
```

### Fertige Variante: Push an lokale In-Cluster-Registry

`job-caweb-registry-local.yaml` pusht statt zu Docker Hub an eine lokale Registry (`REGISTRY=registry.registry.svc.cluster.local:5000`, `TLS_VERIFY=false`). Da In-Cluster-Registries meist ohne Auth laufen, wird kein `docker-config`-Secret gemountet. Adresse der Registry bei Bedarf im `REGISTRY`-Env-Wert anpassen:

```bash
kubectl apply -f job-caweb-registry-local.yaml
kubectl logs -f job/buildah-caweb-registry-local -n buildah
```

## Ablauf

```txt
Git Push → ArgoCD Sync → Notification → Webhook → Buildah Job (git-clone + bud + push) → Docker Hub
```

## Neuen Build manuell triggern

```bash
# Job löschen und neu erstellen
kubectl delete job buildah-caweb -n buildah --ignore-not-found
kubectl apply -f job-caweb.yaml
```

## Debugging

```bash
# Job Status
kubectl get jobs -n buildah

# Build Logs
kubectl logs -f job/buildah-caweb -n buildah

# Trigger Service Logs
kubectl logs -f deployment/buildah-trigger -n buildah
```

## Hinweis: privilegierter Container

Anders als Kaniko führt Buildah `RUN`-Schritte über einen echten Container-Runtime-Layer aus. Das minimale Job-Setup hier läuft dafür mit `securityContext.privileged: true` (vergleichbar mit Docker-in-Docker). Falls die Namespace-übergreifende Pod Security Admission das blockiert, den `buildah`-Namespace mit dem `privileged`-Level labeln:

```bash
kubectl label namespace buildah pod-security.kubernetes.io/enforce=privileged
```

Für einen echten rootless-Betrieb (ohne `privileged`) sind zusätzliche Cluster-Konfiguration (User-Namespaces, `/dev/fuse`, passender Storage-Treiber) nötig — für dieses minimale Beispiel-Setup bewusst nicht abgebildet.
