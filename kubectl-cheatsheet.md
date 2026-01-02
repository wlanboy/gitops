# Kubernetes cheat sheet for node oversight

## get all node ressources
```bash
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU:.status.capacity.cpu,\
MEMORY:.status.capacity.memory,\
STORAGE:.status.capacity.ephemeral-storage \
| column -t

```

#ä get all nodes by namespaces and ressouce allocation
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

