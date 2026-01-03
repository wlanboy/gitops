apiVersion: v1
kind: Secret
metadata:
  name: cluster-${CLUSTER_NAME}
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
stringData:
  name: ${CLUSTER_NAME}
  server: ${CLUSTER_API}
  config: |
    {
      "bearerToken": "${CLUSTER_TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${CLUSTER_CA}"
      }
    }
