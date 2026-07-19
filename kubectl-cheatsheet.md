# Kubernetes Cheat Sheet zur Node-Überwachung

Eine Sammlung nützlicher `kubectl`-Befehle zur Überwachung und Untersuchung von Node-Ressourcen, Kapazitäten und der Verteilung von Workloads über Namespaces hinweg.

## Alle Node-Ressourcen abrufen
```bash
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU:.status.capacity.cpu,\
MEMORY:.status.capacity.memory,\
STORAGE:.status.capacity.ephemeral-storage \
| column -t

```

## Alle Nodes nach Namespace und Ressourcenzuteilung abrufen
```bash
#!/usr/bin/env bash

# Tabellenkopf
printf "%-10s %-15s %-15s %-15s %-15s %-15s\n" \
  "NODE" "NAMESPACE" "CPU_REQUESTS" "CPU_LIMITS" "MEM_REQUESTS" "MEM_LIMITS"

kubectl get pods -A -o json \
  | jq -r '
      .items[]
      | . as $pod
      | $pod.spec.containers[]
      | {
          node: $pod.spec.nodeName,
          ns: $pod.metadata.namespace,
          cpu_req: (.resources.requests.cpu // "-"),
          cpu_lim: (.resources.limits.cpu // "-"),
          mem_req: (.resources.requests.memory // "-"),
          mem_lim: (.resources.limits.memory // "-")
        }
      | "\(.node) \(.ns) \(.cpu_req) \(.cpu_lim) \(.mem_req) \(.mem_lim)"
    ' \
  | while read -r node ns cpu_req cpu_lim mem_req mem_lim; do
      printf "%-10s %-15s %-15s %-15s %-15s %-15s\n" \
        "$node" "$ns" "$cpu_req" "$cpu_lim" "$mem_req" "$mem_lim"
    done \
  | sort

```

## Alle Pods pro Node abrufen
```bash
#!/usr/bin/env bash

# Tabellenkopf
printf "%-15s %-20s %-40s\n" "NODE" "NAMESPACE" "POD"

kubectl get pods -A -o json \
  | jq -r '
      .items[]
      | {
          node: .spec.nodeName,
          ns: .metadata.namespace,
          pod: .metadata.name
        }
      | "\(.node) \(.ns) \(.pod)"
    ' \
  | while read -r node ns pod; do
      printf "%-15s %-20s %-40s\n" "$node" "$ns" "$pod"
    done \
  | sort

```

## Weitere nützliche kubectl-Befehle

Eine Auswahl an `kubectl`-Befehlen, die beim Debugging und bei der Cluster-Analyse hilfreich sein könnten.

### Debugging mit Ephemeral Containern
Fügt einem laufenden Pod einen temporären Debug-Container hinzu — ideal, wenn das Image selbst keine Shell enthält (z. B. distroless-Images):
```bash
kubectl debug -it POD_NAME --image=busybox --target=CONTAINER_NAME
```

### Node-Debugging
Startet einen privilegierten Debug-Pod direkt auf einem Node, um z. B. das Dateisystem oder Netzwerk des Hosts zu untersuchen:
```bash
kubectl debug node/NODE_NAME -it --image=busybox
```

### Erklärung von Ressourcenfeldern (rekursiv)
Zeigt die komplette Feldstruktur einer Ressource inkl. aller verschachtelten Felder — sehr hilfreich beim Schreiben von YAML-Manifesten:
```bash
kubectl explain pod.spec --recursive
```

### Events sortiert und gefiltert anzeigen
Events chronologisch sortieren bzw. auf ein bestimmtes Objekt eingrenzen:
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl get events --field-selector involvedObject.name=POD_NAME
```

### Änderungen vor dem Apply anzeigen (Diff)
Zeigt den Unterschied zwischen dem aktuell laufenden Zustand und einer lokalen Manifest-Datei, bevor `apply` ausgeführt wird:
```bash
kubectl diff -f deployment.yaml
```

### Berechtigungen prüfen (RBAC)
Prüft, ob der aktuelle (oder ein anderer) Benutzer eine bestimmte Aktion ausführen darf:
```bash
kubectl auth can-i delete pods --namespace=production
kubectl auth can-i list secrets --as=system:serviceaccount:default:my-sa
kubectl auth can-i --list
```

### Restart-Zähler aller Container abrufen
Zeigt, wie oft Container in einem Pod neu gestartet wurden — nützlich zur schnellen Fehlersuche bei CrashLoopBackOff:
```bash
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}'
```

### Ressourcenverbrauch sortiert anzeigen
Pods bzw. Nodes nach CPU- oder Speicherverbrauch sortiert auflisten (benötigt metrics-server):
```bash
kubectl top pods --all-namespaces --sort-by=cpu
kubectl top nodes --sort-by=memory
```

### Rollout-Historie und Rollback
Historie eines Deployments einsehen und bei Bedarf auf eine vorherige Revision zurückrollen:
```bash
kubectl rollout history deployment/my-app
kubectl rollout undo deployment/my-app --to-revision=2
```

### Auf einen Zustand warten
Blockiert, bis eine Bedingung erfüllt ist — praktisch in Skripten/Pipelines statt Polling per Schleife:
```bash
kubectl wait --for=condition=Ready pod -l app=my-app --timeout=120s
```

### Direkten API-Zugriff nutzen (--raw)
Ruft Rohdaten direkt von der Kubernetes-API ab, z. B. Metriken oder Healthz-Endpunkte:
```bash
kubectl get --raw /apis/metrics.k8s.io/v1beta1/nodes
kubectl get --raw /healthz?verbose
```

### Dateien zwischen Pod und lokalem Rechner kopieren
```bash
kubectl cp POD_NAME:/pfad/in/container ./lokaler-pfad
```

### Pods nach Node filtern (Feld-Selektor)
Alternative zum vorherigen Skript, direkt über die API gefiltert statt per `jq`:
```bash
kubectl get pods -A --field-selector spec.nodeName=NODE_NAME
```

### Erhöhte Log-Ausgabe für Fehlersuche
Zeigt detaillierte HTTP-Requests/-Responses zwischen `kubectl` und dem API-Server (Werte von 6–9 sind am ausführlichsten):
```bash
kubectl get pods -v=8
```

### Schnell zwischen Kontexten/Namespaces wechseln
```bash
kubectl config use-context CONTEXT_NAME
kubectl config set-context --current --namespace=my-namespace
```

### Hilfreiche Zusatztools (nicht Teil von kubectl selbst)
- **[k9s](https://k9scli.io/)** – Terminal-UI zur interaktiven Cluster-Navigation
