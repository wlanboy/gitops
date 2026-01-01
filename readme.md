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

## 📦 Deployment der einzelnen Applikationen
Jede App besteht aus zwei Schritten:
- Namespace anlegen
- ArgoCD‑App‑Definition anwenden

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

kubectl apply -f namespaces/namespace-simpleservice.yaml
kubectl apply -f apps/app-simpleservice.yaml
```

# 🧰 ArgoCD CLI – Verwaltung der Apps
Die ArgoCD‑CLI ermöglicht es, Apps zu synchronisieren, ihren Status abzufragen oder Fehler zu analysieren.

## 🔐 Login
# argocli
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
```
app get zeigt den aktuellen Status, z. B.:
- OutOfSync
- Healthy / Degraded
- Sync‑History

# 🛠️ Troubleshooting
Dieser Abschnitt hilft dir, häufige Probleme beim Arbeiten mit ArgoCD, Kubernetes und Git‑Repos schnell zu identifizieren und zu beheben.

## 🔑 1. ArgoCD kann das Git‑Repository nicht lesen
Symptome:
- App bleibt im Status Missing oder OutOfSync
- Fehlermeldung: authentication required oder repository not accessible

Mögliche Ursachen & Lösungen:
- GitHub‑Token fehlt oder ist ungültig → Stelle sicher, dass $GITHUB_TOKEN korrekt gesetzt ist und repo‑Zugriff hat.
- envsubst wurde nicht ausgeführt → Prüfe, ob die Repository‑YAML wirklich die Credentials enthält.
- Private Repos ohne Credentials → ArgoCD benötigt zwingend ein Token, wenn das Repo privat ist.

## 📦 2. ArgoCD kann nicht in den Namespace deployen
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

## 🔁 3. App bleibt im Status OutOfSync
Symptome:
- ArgoCD zeigt Unterschiede zwischen Live‑State und Git‑State
- Sync schlägt immer wieder fehl

Typische Ursachen:
- Kubernetes erzeugt Felder automatisch, z. B.: metadata.annotations
- status‑Felder → Diese sollten in .spec.ignoreDifferences ignoriert werden.
- Manuelles Editieren von Ressourcen im Cluster → Änderungen werden von ArgoCD überschrieben oder führen zu Drift.
- Fehlende CRDs → Wenn eine App CRDs benötigt, müssen diese vorher installiert sein.

## 🌐 4. ArgoCD kann den Cluster nicht erreichen
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

## 🧹 5. Alte Ressourcen werden nicht gelöscht
Symptome:
- Ressourcen bleiben bestehen, obwohl sie im Git gelöscht wurden

Lösungen:
- Prüfe, ob prune: true in der App‑Definition gesetzt ist.
- Falls selfHeal: true fehlt, ArgoCD korrigiert Drift nicht automatisch.
