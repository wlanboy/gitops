# Tekton CLI (tkn) Cheat Sheet

Eine Sammlung nützlicher `tkn`-Befehle zur Verwaltung von Pipelines, Tasks und Runs über die CLI.

## Pipelines

### Alle Pipelines auflisten
```bash
tkn pipeline list
```

### Details einer Pipeline anzeigen
```bash
tkn pipeline describe PIPELINE_NAME
```

### Pipeline manuell starten
```bash
tkn pipeline start PIPELINE_NAME
tkn pipeline start PIPELINE_NAME --showlog
```

### Pipeline mit Parametern und Workspace starten
```bash
tkn pipeline start PIPELINE_NAME \
  -p PARAM_NAME=WERT \
  -w name=WORKSPACE_NAME,claimName=PVC_NAME \
  --showlog
```

### Pipeline löschen
```bash
tkn pipeline delete PIPELINE_NAME
```

---

## PipelineRuns

### Alle PipelineRuns auflisten
```bash
tkn pipelinerun list
```

### Details eines PipelineRuns anzeigen
```bash
tkn pipelinerun describe PIPELINERUN_NAME
```

### Logs eines PipelineRuns live verfolgen
```bash
tkn pipelinerun logs PIPELINERUN_NAME --follow
```

### Letzten PipelineRun einer Pipeline anzeigen
```bash
tkn pipelinerun logs --last -f
```

### PipelineRun abbrechen
```bash
tkn pipelinerun cancel PIPELINERUN_NAME
```

### Alte PipelineRuns aufräumen
Löscht abgeschlossene Runs, um den Cluster sauber zu halten — praktisch nach Debugging-Sessions oder in CI-Cleanup-Jobs:
```bash
tkn pipelinerun delete --keep 5
tkn pipelinerun delete -p PIPELINE_NAME --keep 5
```

---

## Tasks

### Alle Tasks auflisten
```bash
tkn task list
```

### Details einer Task anzeigen
```bash
tkn task describe TASK_NAME
```

### Task manuell starten
```bash
tkn task start TASK_NAME --showlog
```

### ClusterTasks auflisten
```bash
tkn clustertask list
```

---

## TaskRuns

### Alle TaskRuns auflisten
```bash
tkn taskrun list
```

### Logs eines TaskRuns anzeigen
```bash
tkn taskrun logs TASKRUN_NAME --follow
```

### Alte TaskRuns aufräumen
```bash
tkn taskrun delete --keep 5
```

---

## Trigger

### EventListener auflisten
```bash
tkn eventlistener list
```

### Logs eines EventListeners anzeigen
```bash
tkn eventlistener logs EVENTLISTENER_NAME
```

### TriggerTemplates und TriggerBindings auflisten
```bash
tkn triggertemplate list
tkn triggerbinding list
```

---

## Hub (Tekton Catalog)

### Nach Tasks/Pipelines im Tekton Hub suchen
```bash
tkn hub search TASK_NAME
```

### Task direkt aus dem Hub installieren
```bash
tkn hub install task TASK_NAME
```

---

## Nützliche Flags

### Ausgabe als JSON/YAML
```bash
tkn pipelinerun describe PIPELINERUN_NAME -o json
tkn pipeline describe PIPELINE_NAME -o yaml
```

### Namespace explizit angeben
```bash
tkn pipeline list -n my-namespace
```

### Alle Namespaces durchsuchen
```bash
tkn pipelinerun list -A
```

### PipelineRun aus YAML-Datei starten (dry-run/preview vor apply)
```bash
tkn pipeline start PIPELINE_NAME --dry-run -o yaml
```

### Ergebnisse (Results) eines abgeschlossenen Runs anzeigen
```bash
tkn pipelinerun describe PIPELINERUN_NAME | grep -A 20 "Results"
```

### Hilfreiche Zusatztools (nicht Teil von tkn selbst)
- **[Tekton Dashboard](https://tekton.dev/docs/dashboard/)** – Web-UI zur Visualisierung von Pipelines und Runs
- **[Tekton Hub](https://hub.tekton.dev/)** – Katalog wiederverwendbarer Tasks und Pipelines
