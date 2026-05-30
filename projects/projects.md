# ArgoCD AppProject — wlanboy

Ein ArgoCD `AppProject` bündelt mehrere Anwendungen unter einem gemeinsamen Sicherheits- und Zugriffsdach: Es legt fest, welche Git-Repositories als Quellen erlaubt sind, auf welche Cluster und Namespaces deployed werden darf, und welche Kubernetes-Ressourcentypen zulässig sind.

## Was ist ein AppProject?

ArgoCD gruppiert Anwendungen in Projekte (`AppProject`). Ein Projekt ist kein Namespace, sondern eine **Zugriffskontrolle**: Es verhindert, dass eine Anwendung versehentlich (oder absichtlich) aus einem fremden Repository deployed oder in einen nicht autorisierten Namespace geschrieben wird.

Ohne explizites Projekt landen alle Apps im `default`-Projekt, das keinerlei Einschränkungen hat — in Produktionsumgebungen ein Sicherheitsrisiko.

---

## Das `wlanboy`-Projekt

Die Konfiguration liegt in [wlanboy-project.yaml](wlanboy-project.yaml) und definiert drei Hauptbereiche:

### 1. Erlaubte Quell-Repositories (`sourceRepos`)

Nur Git-Repositories aus diesem Whitelist dürfen als Quelle für Deployments verwendet werden:

| Repository | Anwendung |
| --- | --- |
| `wlanboy.github.io` | Statische Website |
| `httptester` | HTTP-Tester |
| `eurekaclientjava` | Eureka Service Discovery Client |
| `MirrorService` | Mirror-Service |
| `JavaHttpClient` | Java HTTP Client |
| `Webshell` / `webpyshell` | Web-Shells (Java & Python) |
| `kubeevent` / `kubeeventjava` | Kubernetes Event-Listener |
| `SimpleService` | Einfacher Dummy-Service |
| `randomfail` | Chaos-Test-Service |
| `caweb` | CA-Web-Service |

### 2. Erlaubte Deployment-Ziele (`destinations`)

Alle Anwendungen deployen auf den Cluster `gmk`, jeweils in ihren eigenen Namespace:

`wlanboy`, `tester`, `eureka`, `mirror`, `javahttpclient`, `webshell`, `webpyshell`, `kubeevent`, `kubeeventjava`, `randomfail`, `simpleservice`, `caweb`, `istio-ingress`

Die Namespace-Trennung stellt sicher, dass Services isoliert laufen und Secrets nicht namespace-übergreifend versehentlich zugreifbar sind (→ dafür ist [Reflector](../reflector/reflector.md) zuständig).

### 3. Erlaubte Cluster-Ressourcen (`clusterResourceWhitelist`)

Cluster-weite Ressourcen (außerhalb eines Namespace) sind standardmäßig gesperrt. Explizit erlaubt sind:

- `ClusterRole` — Berechtigungen cluster-weit definieren
- `ClusterRoleBinding` — Berechtigungen cluster-weit zuweisen

Alle anderen Cluster-Ressourcentypen (z. B. `Namespace`, `PersistentVolume`) bleiben für dieses Projekt gesperrt.

---

## Zusammenfassung: Sicherheitsmodell

```text
Git-Repository (aus sourceRepos)
  │
  │  ArgoCD synct
  ▼
AppProject "wlanboy" prüft:
  ├── Ist das Repo erlaubt?        → sourceRepos-Whitelist
  ├── Ist der Namespace erlaubt?   → destinations-Whitelist
  └── Ist der Ressourcentyp OK?    → clusterResourceWhitelist
  │
  ▼
Deployment auf Cluster "gmk"
```
