# Grafana Cloud Kubernetes Monitoring

The `grafana-cloud` Argo CD Application installs Grafana Kubernetes Monitoring chart `4.6.2` in the `monitoring` namespace and registers its Alloy collector with Grafana Cloud Fleet Management. It uses a small, clustered per-node DaemonSet with the service-discovery preset; it does not enable privileged, host-network, or host-filesystem presets.

The Grafana Kubernetes Monitoring backend and its alert/recording rules are already activated. Keep the Grafana plan on Free; no plan upgrade is required to deploy the collector. The stack has reported that its Free Metrics limit is reached, so installing the collector does not guarantee that additional metrics will be accepted or visible.

## Create credentials

Create a Grafana Cloud access policy token for the Fleet Management integration with the scopes `metrics:read` and `set:alloy-data-write`. Do not use a general-purpose token or commit the token to Git.

From a trusted workstation with `kubectl` configured for this cluster, run:

```powershell
.\bootstrap\grafana-cloud\set-credentials.ps1
```

The script displays the active Kubernetes context, prompts for the token using a secure prompt, creates the `monitoring` namespace if needed, and creates `grafana-cloud-credentials`. It refuses to overwrite an existing Secret. The Secret contains the Fleet Management instance ID as `username` and the access policy token as `password`; neither value is written to a file.

## Register and sync

Register the Application:

```powershell
kubectl apply -f bootstrap/argocd/applications/grafana-cloud.yaml
```

Then manually sync `grafana-cloud` in Argo CD. Automatic sync and pruning are intentionally disabled.

## Verify

```powershell
kubectl -n monitoring get pods
```

Confirm the Alloy pods are Ready and the cluster appears as `proxmox-k3s` in Grafana Cloud Fleet Management. Once metrics are accepted, use the Kubernetes Monitoring dashboards and select that cluster.
