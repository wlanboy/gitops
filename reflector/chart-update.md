# Plan: Helm Chart um extraVolumes / extraEnv erweitern

### 1. `values.yaml` — Defaults ergänzen

```yaml
extraVolumeMounts: []
extraVolumes: []
extraEnv: []
```

---

### 2. `templates/deployment.yaml` — volumeMounts einbinden

Im Container-Block, nach den bestehenden `volumeMounts`:

```yaml
volumeMounts:
  # ... bestehende mounts ...
  {{- with .Values.extraVolumeMounts }}
  {{- toYaml . | nindent 12 }}
  {{- end }}
```

---

### 3. `templates/deployment.yaml` — volumes einbinden

Auf Pod-Ebene, nach den bestehenden `volumes`:

```yaml
volumes:
  # ... bestehende volumes ...
  {{- with .Values.extraVolumes }}
  {{- toYaml . | nindent 8 }}
  {{- end }}
```

---

### 4. `templates/deployment.yaml` — env einbinden

Im Container-Block, nach den bestehenden `env`-Einträgen:

```yaml
env:
  # ... bestehende env vars ...
  {{- with .Values.extraEnv }}
  {{- toYaml . | nindent 12 }}
  {{- end }}
```

---

### Einrückung — Orientierung

```
spec:                        # Pod spec
  volumes:                   # indent 8
    ...
  containers:
    - name: ...
      env:                   # indent 12
        ...
      volumeMounts:          # indent 12
        ...
```

Der `nindent`-Wert hängt vom jeweiligen Chart ab — das ist die einzige Stelle, die von Chart zu Chart abweichen kann.
