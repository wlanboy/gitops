# 📘 ArgoCD Deployment – Erweiterte Dokumentation

Dieses Dokument beschreibt die Initialisierung und Verwaltung verschiedener ArgoCD‑Applikationen innerhalb eines Kubernetes‑Clusters. 
Es führt Schritt für Schritt durch die Einrichtung der benötigten Projekte, Namespaces und Applikationen sowie die Nutzung der ArgoCD‑CLI.

## 🚀 Initialisierung der ArgoCD‑Apps

In diesem Abschnitt werden alle benötigten Ressourcen im Kubernetes‑Cluster angelegt. Dazu gehören:

- Git‑Repository‑Definitionen
- Cluster‑Konfigurationen
- ArgoCD‑Projekte
- Namespaces
- ArgoCD‑Applikationen

## 🔧 Voraussetzungen

Bevor du startest, benötigst du:

- Zugriff auf den Kubernetes‑Cluster (kubectl konfiguriert)
- Ein GitHub‑Repository mit deinen App‑Manifests
- Ein gültiges GitHub‑Token für den Zugriff auf private Repositories
- ArgoCD ist bereits im Cluster installiert

## 📝 Schritt‑für‑Schritt‑Initialisierung

```bash
export GITHUB_USERNAME="user_name"
export GITHUB_TOKEN="ghp_XXXXXX"

envsubst < repo-wlanboy.yaml | kubectl apply -f -
```

➡️ Legt das Git‑Repository in ArgoCD an, sodass ArgoCD später die App‑Manifeste daraus beziehen kann.

```bash
kubectl apply -f cluster-gmk.yaml
```

➡️ Registriert den Ziel‑Cluster (falls mehrere Cluster genutzt werden).
ArgoCD weiß dadurch, wohin es die Anwendungen deployen soll.

```bash
kubectl apply -f projects/wlanboy-project.yaml
```

➡️ Erstellt ein ArgoCD‑Projekt, das als logische Gruppierung für mehrere Apps dient.
Projekte definieren u. a.:

- erlaubte Git‑Repos
- erlaubte Ziel‑Cluster
- erlaubte Namespaces und Ressourcen

## 🔁 Reflector – Secret-Spiegelung in Java-App-Namespaces

Reflector ist ein Helm-basiertes Tool, das Kubernetes Secrets automatisch in mehrere Namespaces spiegelt.
Es wird **nicht** über ArgoCD verwaltet, sondern direkt via Helm in `kube-system` installiert.

### Installation & Einrichtung

```bash
cd reflector/
bash reflector.sh
```
### Status prüfen

```bash
kubectl get secrets --all-namespaces | grep gmk-truststore
```

### `apps/` vs. `apps-trust/`

Für die Java-Apps, deren Namespaces oben per `reflection-auto-namespaces` mit dem `gmk-truststore`-Secret versorgt werden gibt es zwei Varianten der ArgoCD-App-Definition:

- **`apps/app-<name>.yaml`** – Standard-Manifest ohne Truststore-Mount.
- **`apps-trust/app-<name>.yaml`** – identisches Manifest, zusätzlich mit `extraVolumes`/`extraVolumeMounts` für `/opt/trust` und `JAVA_TOOL_OPTIONS`, das den JVM-Truststore auf das gespiegelte `gmk-truststore`-Secret zeigen lässt.

Welche Variante man deployt, hängt davon ab, ob die jeweilige App TLS-Verbindungen gegen den internen CA-Truststore verifizieren muss:

## 📦 Deployment der einzelnen Applikationen

Jede App besteht aus zwei Schritten:

- Namespace anlegen
- ArgoCD‑App‑Definition anwenden (aus `apps/`, bzw. `apps-trust/` für Apps mit Truststore-Bedarf – siehe oben)

```bash
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

kubectl apply -f namespaces/namespace-webpyshell.yaml
kubectl apply -f apps/app-webpyshell.yaml

kubectl apply -f namespaces/namespace-kubeevent.yaml
kubectl apply -f apps/app-kubeevent.yaml

kubectl apply -f namespaces/namespace-kubeeventjava.yaml
kubectl apply -f apps/app-kubeeventjava.yaml

kubectl apply -f namespaces/namespace-simpleservice.yaml
kubectl apply -f apps/app-simpleservice.yaml

kubectl apply -f namespaces/namespace-randomfail.yaml
kubectl apply -f apps/app-randomfail.yaml

kubectl apply -f namespaces/namespace-caweb.yaml
kubectl create secret generic ca-secret -n caweb \
  --from-file=ca.pem=/local-ca/ca.pem --from-file=ca.key=/local-ca/ca.key
kubectl apply -f apps/app-caweb.yaml
```

## 🏗️ Image Builds im Cluster

Für den Bau von Docker-Images innerhalb des Clusters (getriggert nach ArgoCD-Sync) gibt es zwei Ansätze:

- **[kaniko/kaniko.md](kaniko/kaniko.md)** – ursprüngliches Setup. Kaniko ist seit 2025-06-03 archiviert und unmaintained.
- **[buildah/buildah.md](buildah/buildah.md)** – aktueller Ersatz für Kaniko, aktiv gepflegt (containers-Projekt, Red Hat). Enthält Varianten für Push zu Docker Hub, reinen lokalen Build ohne Push sowie Push an eine lokale In-Cluster-Registry.

## 🧰 ArgoCD CLI – Verwaltung der Apps

Die ArgoCD‑CLI ermöglicht es, Apps zu synchronisieren, ihren Status abzufragen oder Fehler zu analysieren.

## 🔐 Login

### argocli

```bash
read -s ARGO_PW
argocd login argocd.gmk.lan --grpc-web \
  --username admin \
  --password "$ARGO_PW"
```

➡️ Meldet dich an der ArgoCD‑API an.  
--grpc-web wird benötigt, wenn ArgoCD hinter einem Ingress läuft.

## 🔄 App‑Status prüfen & synchronisieren

Für jede App:

```bash
argocd app get wlanboy
argocd app sync wlanboy

argocd app get tester
argocd app sync tester

argocd app get eureka
argocd app sync eureka

argocd app get mirror
argocd app sync mirror

argocd app get javahttpclient
argocd app sync javahttpclient

argocd app get webshell
argocd app sync webshell

argocd app get webpyshell
argocd app sync webpyshell

argocd app get simpleservice
argocd app sync simpleservice

argocd app get kubeevent
argocd app sync kubeevent

argocd app get randomfail
argocd app sync randomfail

argocd app get kubeeventjava
argocd app sync kubeeventjava

argocd app get caweb
argocd app sync caweb
```

app get zeigt den aktuellen Status, z. B.:

- OutOfSync
- Healthy / Degraded
- Sync‑History

## 🛠️ Troubleshooting

Dieser Abschnitt hilft dir, häufige Probleme beim Arbeiten mit ArgoCD, Kubernetes und Git‑Repos schnell zu identifizieren und zu beheben.

### 🔑 1. ArgoCD kann das Git‑Repository nicht lesen

Symptome:

- App bleibt im Status Missing oder OutOfSync
- Fehlermeldung: authentication required oder repository not accessible

Mögliche Ursachen & Lösungen:

- GitHub‑Token fehlt oder ist ungültig → Stelle sicher, dass $GITHUB_TOKEN korrekt gesetzt ist und repo‑Zugriff hat.
- envsubst wurde nicht ausgeführt → Prüfe, ob die Repository‑YAML wirklich die Credentials enthält.
- Private Repos ohne Credentials → ArgoCD benötigt zwingend ein Token, wenn das Repo privat ist.

### 📦 2. ArgoCD kann nicht in den Namespace deployen

Symptome:

- App zeigt PermissionDenied
- Events: namespace not found

Lösungen:

- Prüfe, ob der Namespace existiert:

```bash
kubectl get ns
```

- Stelle sicher, dass der Namespace vor der App‑Definition angewendet wurde.
- Falls RBAC genutzt wird: → ServiceAccount von ArgoCD benötigt Rechte für den Namespace.

### 🔁 3. App bleibt im Status OutOfSync

Symptome:

- ArgoCD zeigt Unterschiede zwischen Live‑State und Git‑State
- Sync schlägt immer wieder fehl

Typische Ursachen:

- Kubernetes erzeugt Felder automatisch, z. B.: metadata.annotations
- status‑Felder → Diese sollten in .spec.ignoreDifferences ignoriert werden.
- Manuelles Editieren von Ressourcen im Cluster → Änderungen werden von ArgoCD überschrieben oder führen zu Drift.
- Fehlende CRDs → Wenn eine App CRDs benötigt, müssen diese vorher installiert sein.

### 🌐 4. ArgoCD kann den Cluster nicht erreichen

Symptome:

- cluster unreachable
- permission denied
- no such host

Lösungen:

- Prüfe, ob der Cluster korrekt registriert wurde:

```bash
argocd cluster list
```

- Stelle sicher, dass der ArgoCD‑Server Zugriff auf den Kubernetes‑API‑Server hat.

- Wenn du mehrere Cluster nutzt:
  → Kubeconfig und Cluster‑Ressource müssen zusammenpassen.

### 🧹 5. Alte Ressourcen werden nicht gelöscht

Symptome:

- Ressourcen bleiben bestehen, obwohl sie im Git gelöscht wurden

Lösungen:

- Prüfe, ob prune: true in der App‑Definition gesetzt ist.
- Falls selfHeal: true fehlt, ArgoCD korrigiert Drift nicht automatisch.
