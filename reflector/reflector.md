# Reflector — Kubernetes Secret & ConfigMap Spiegelung

## Was ist Reflector?

[Reflector](https://github.com/emberstack/kubernetes-reflector) ist ein Kubernetes-Controller von Emberstack, der Secrets und ConfigMaps automatisch zwischen Namespaces synchronisiert ("spiegelt").

Das Problem ohne Reflector: Kubernetes isoliert Secrets hart nach Namespace. Eine Java-Anwendung in Namespace `eureka` kann ein Secret aus Namespace `default` nicht direkt lesen. Ohne Reflector muss man das Secret manuell in jeden Ziel-Namespace kopieren — und bei jeder Änderung erneut.

Reflector löst das durch Annotationen am Quell-Secret: Der Controller erkennt die Annotationen und hält die Kopien in den Ziel-Namespaces automatisch aktuell.

---

## Vorteile

| Ohne Reflector | Mit Reflector |
| --- | --- |
| Secret manuell in jeden Namespace kopieren | Einmalig im Quell-Namespace anlegen |
| Bei Änderung (z. B. neues Zertifikat) alle Kopien manuell updaten | Änderung am Quell-Secret → alle Kopien werden automatisch aktualisiert |
| Fehleranfällig, schlecht skalierbar | Konsistent, auditierbar, automatisiert |
| Kein zentrales Lifecycle-Management | Quell-Secret ist Single Source of Truth |

Besonders wertvoll für:

- TLS-Zertifikate und Truststores, die von vielen Services genutzt werden
- Wildcard-Zertifikate, die in mehrere Ingress-Namespaces müssen
- Datenbankpasswörter oder API-Keys, die mehrere Teams brauchen

---

## Schritt-für-Schritt: Truststore in Java-Anwendungen einbinden

Ziel: Ein `gmk-truststore.p12` aus einem Kubernetes-Secret als Datei in den Java-Container mounten und die JVM darauf zeigen lassen.

### Schritt 1 — Reflector installieren

```bash
helm repo add emberstack https://emberstack.github.io/helm-charts
helm repo update
helm upgrade --install reflector emberstack/reflector \
  --namespace kube-system \
  --wait
```

Überprüfen:

```bash
kubectl get pods -n kube-system | grep reflector
```

---

### Schritt 2 — Truststore-Secret im Quell-Namespace anlegen

```bash
kubectl create secret generic gmk-truststore \
  --from-file=gmk-truststore.p12 \
  --namespace default \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

### Schritt 3 — Reflector-Annotationen setzen

Die Annotationen steuern, wohin gespiegelt wird:

```bash
kubectl annotate secret gmk-truststore \
  --namespace default \
  --overwrite \
  reflector.v1.k8s.emberstack.com/reflection-allowed="true" \
  reflector.v1.k8s.emberstack.com/reflection-auto-enabled="true" \
  reflector.v1.k8s.emberstack.com/reflection-auto-namespaces="eureka,javahttpclient,kubeeventjava,simpleservice,mirror"
```

Alternativ direkt im Secret-Manifest:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: gmk-truststore
  namespace: default
  annotations:
    reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
    reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "eureka,javahttpclient"
type: Opaque
data:
  gmk-truststore.p12: <base64-encoded-inhalt>
```

Spiegelung prüfen:

```bash
kubectl get secrets --all-namespaces | grep gmk-truststore
```

---

### Schritt 4 — Helm Chart: extraVolumes und extraVolumeMounts konfigurieren

Das gespiegelte Secret wird als Volume in den Pod eingebunden. In der `values.yaml` des jeweiligen Helm-Releases:

```yaml
extraVolumes:
  - name: truststore
    secret:
      secretName: gmk-truststore

extraVolumeMounts:
  - name: truststore
    mountPath: /etc/ssl/truststore
    readOnly: true

extraEnv:
  - name: JAVAX_NET_SSL_TRUSTSTORE
    value: /etc/ssl/truststore/gmk-truststore.p12
  - name: JAVAX_NET_SSL_TRUSTSTORE_TYPE
    value: PKCS12
  - name: JAVAX_NET_SSL_TRUSTSTORE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: gmk-truststore-password
        key: password
```

> `mountPath` ist frei wählbar — `/etc/ssl/truststore` ist eine gute Konvention für Read-only-Zertifikate.

---

### Schritt 5 — JVM-Argumente in der Anwendung setzen

#### Option A: Über Umgebungsvariablen (empfohlen für Helm)

Die `JAVAX_NET_SSL_*`-Variablen aus Schritt 4 werden von der JVM automatisch ausgewertet, wenn `System.setProperty` im Code aufgerufen wird. Sicherer ist die direkte JVM-Übergabe via `JAVA_TOOL_OPTIONS`:

```yaml
extraEnv:
  - name: JAVA_TOOL_OPTIONS
    value: >-
      -Djavax.net.ssl.trustStore=/etc/ssl/truststore/gmk-truststore.p12
      -Djavax.net.ssl.trustStoreType=PKCS12
      -Djavax.net.ssl.trustStorePassword=changeit
```

`JAVA_TOOL_OPTIONS` wird von der JVM vor allen anderen Optionen gelesen — kein Code-Eingriff nötig.

#### Option B: In `entrypoint.sh` (für eigene Docker-Images)

```bash
exec java \
  -Dspring.aot.enabled=true \
  -Djavax.net.ssl.trustStore=/etc/ssl/truststore/gmk-truststore.p12 \
  -Djavax.net.ssl.trustStoreType=PKCS12 \
  -Djavax.net.ssl.trustStorePassword=changeit \
  org.springframework.boot.loader.launch.JarLauncher
```

---

### Schritt 6 — Deployment-Template anpassen (falls kein extraVolumes-Support)

Falls das verwendete Helm-Chart `extraVolumes` noch nicht unterstützt, muss das `deployment.yaml`-Template erweitert werden (siehe [chart-update.md](chart-update.md)).

Kurzfassung der drei Stellen:

```yaml
# Pod-Ebene (indent 8)
volumes:
  {{- with .Values.extraVolumes }}
  {{- toYaml . | nindent 8 }}
  {{- end }}

# Container-Ebene (indent 12)
volumeMounts:
  {{- with .Values.extraVolumeMounts }}
  {{- toYaml . | nindent 12 }}
  {{- end }}

env:
  {{- with .Values.extraEnv }}
  {{- toYaml . | nindent 12 }}
  {{- end }}
```

---

## Zusammenfassung: Datenfluss

```text
default/gmk-truststore (Secret)
  │
  │  Reflector spiegelt automatisch
  ▼
eureka/gmk-truststore (Secret-Kopie)
javahttpclient/gmk-truststore
kubeeventjava/gmk-truststore
  │
  │  extraVolumes: secret → Volume
  ▼
Pod: /etc/ssl/truststore/gmk-truststore.p12
  │
  │  JAVA_TOOL_OPTIONS / -Djavax.net.ssl.trustStore
  ▼
JVM nutzt Truststore für ausgehende TLS-Verbindungen
```
