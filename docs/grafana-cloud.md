# Grafana Cloud Kubernetes Monitoring

The `grafana-cloud` Argo CD Application installs Grafana Kubernetes Monitoring chart `4.6.2` in the `monitoring` namespace and registers its Alloy collector with Grafana Cloud Fleet Management. It enables cluster metrics (kube-state-metrics, kubelet, and cAdvisor), Linux host metrics, OpenCost, Kepler energy metrics, cluster events, selected infrastructure pod logs, and a restricted Kubernetes manifest-change feed. Kubernetes metrics and logs are sent through the Grafana Cloud OTLP destination.

The Grafana Kubernetes Monitoring backend and its alert/recording rules are already activated. Keep the Grafana plan on Free; no plan upgrade is required to deploy the collector. The stack has reported that its Free Metrics limit is reached, so new metric series may be rejected and status checks may remain Offline until the limit allows ingestion again. Windows Exporter is intentionally not deployed because all six Kubernetes nodes are Linux.

Pod logs are limited to `cert-manager`, `kube-system`, `metallb-system`, `monitoring`, and `traefik`; application logs, including Mattermost, are not forwarded. The filesystem-log-reader preset mounts node `/var/log` for container log collection. Kubernetes manifest collection is experimental and uses an allowlist that excludes Secret and ConfigMap resources. It also excludes the `argocd`, `cilium-secrets`, `kube-system`, `mattermost`, and `monitoring` namespaces and does not send full manifest payloads.

Kepler runs as a privileged DaemonSet to access host energy data. OpenCost uses the existing `grafana-cloud-credentials` Secret to query Grafana Cloud Prometheus; on-premises cost values require a suitable pricing model to be meaningful.

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

## OTLP receiver

The Alloy collector accepts OTLP/gRPC and OTLP/HTTP and forwards metrics, logs, and traces to the Grafana Cloud OTLP gateway. The existing access-policy token is referenced through the `grafana-cloud-credentials` Secret and is not stored in Git. Host-info metrics are disabled to avoid adding more series while the Free Metrics limit is reached.

The LAN endpoint is `https://collector.otlp.ingress.misosiru.uk` on port 443. Traefik terminates TLS using cert-manager and allows source addresses only from `172.26.27.0/24`; Cloudflare Tunnel is not used. Configure an OpenTelemetry client with:

```text
OTEL_EXPORTER_OTLP_ENDPOINT=https://collector.otlp.ingress.misosiru.uk
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

For OTLP/gRPC, use the same endpoint and set `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`.

Pods inside the cluster can use the internal Service directly:

```text
OTEL_EXPORTER_OTLP_ENDPOINT=http://grafana-cloud-alloy-otlp.monitoring.svc.cluster.local:4318
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
```

For in-cluster gRPC, use port `4317` and `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`. The internal receiver is plaintext and does not authenticate individual workloads; any pod able to reach the Service can submit telemetry.

After syncing `grafana-cloud` first and then `grafana-cloud-otlp`, verify the receiver Service, IngressRoute, and certificate:

```powershell
kubectl -n monitoring get service grafana-cloud-alloy-otlp
kubectl -n monitoring get ingressroute,middleware,certificate
```
