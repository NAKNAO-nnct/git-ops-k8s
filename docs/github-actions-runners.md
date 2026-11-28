# GitHub Actions self-hosted runners

The `arc-runner-slim`, `arc-runner-medium`, and `arc-runner-large` Applications install organization-level ephemeral runners for `Yamada-Factory` with Actions Runner Controller (ARC) `0.15.1`. Jobs select a profile with `runs-on: slim`, `runs-on: medium`, or `runs-on: large`.

Each runner uses Docker-in-Docker. The runner workspace and Docker image layers share one ephemeral Ceph RBD volume per Pod. Runner and Docker container images, containerd's image cache, logs, and small `emptyDir` volumes still use worker-local storage:

| Scale set | Runner Pod resources | Ceph volume |
| --- | ---: | ---: |
| `slim` | 1 CPU / 2 GiB | 10 GiB |
| `medium` | 4 CPU / 4 GiB | 20 GiB |
| `large` | 16 CPU / 16 GiB | 50 GiB |

`minRunners` is zero, so no idle runner Pods are kept. `maxRunners` is intentionally unset; ARC may create a runner for each queued job. This avoids an explicit concurrency cap, but a burst of jobs can still create many Pods and Ceph PVCs. The PVC requests are logical capacity, not a physical reservation. Monitor the Ceph pool and Kubernetes node capacity.

The `large` scale set is defined but cannot run on the current workers (8 CPU and about 15.6 GiB allocatable each). Its jobs remain queued until a worker has at least 16 CPU and 16 GiB allocatable. The ephemeral StorageClass uses `WaitForFirstConsumer`, so an unschedulable runner does not provision its RBD volume before a suitable worker is available.

## GitHub App and Secret

The organization-owned GitHub App needs only:

- Organization `Self-hosted runners`: Read and write.
- Repository `Metadata`: Read-only.

Create a Kubernetes Secret in `arc-runners`; do not commit the downloaded private key or put it in Helm values:

```powershell
kubectl create namespace arc-runners --dry-run=client -o yaml | kubectl apply -f -
kubectl -n arc-runners create secret generic arc-github-app `
  --from-literal=github_app_id='<APP_ID>' `
  --from-literal=github_app_installation_id='<INSTALLATION_ID>' `
  --from-file=github_app_private_key='<PATH_TO_DOWNLOADED_PRIVATE_KEY>' `
  --dry-run=client -o yaml | kubectl apply -f -
```

The Secret is consumed by the runner scale-set charts. Kubernetes Secrets are not encrypted merely by base64 encoding; restrict cluster API access and enable encryption at rest for the cluster's Secret data.

## Install

Applications do not auto-sync. Apply and sync the CRDs first, then the controller and StorageClass. Create the GitHub App Secret before installing the three scale sets:

```powershell
kubectl apply -f bootstrap/argocd/applications/arc-crds.yaml
argocd app sync arc-crds --sync-option CreateNamespace=true --sync-option ServerSideApply=true
argocd app wait arc-crds --sync --health --timeout 5m

kubectl apply -f bootstrap/argocd/applications/arc-controller.yaml
argocd app sync arc-controller --sync-option CreateNamespace=true
kubectl -n arc-systems rollout status deployment/arc-gha-rs-controller --timeout=5m

kubectl apply -f bootstrap/argocd/applications/arc-runner-storage.yaml
argocd app sync arc-runner-storage --sync-option CreateNamespace=true

kubectl apply -f bootstrap/argocd/applications/arc-runner-slim.yaml
kubectl apply -f bootstrap/argocd/applications/arc-runner-medium.yaml
kubectl apply -f bootstrap/argocd/applications/arc-runner-large.yaml
argocd app sync arc-runner-slim --sync-option CreateNamespace=true
argocd app sync arc-runner-medium --sync-option CreateNamespace=true
argocd app sync arc-runner-large --sync-option CreateNamespace=true
```

Use the Argo CD UI to sync if the `argocd` CLI is unavailable; include the `ServerSideApply=true` sync option when syncing `arc-crds`. The runner Applications reference the `arc-github-app` Secret and the controller ServiceAccount in `arc-systems`.

The upstream ARC CRDs exceed the client-side apply annotation limit, so `arc-crds` manages them separately with Server-Side Apply. The Helm controller Application skips its bundled CRDs.

## Security

Docker-in-Docker runs a privileged container. Treat jobs on these runners as trusted code: do not route untrusted fork pull requests or other untrusted workflows to them. A compromised job can affect its worker node; use dedicated workers and appropriate repository/workflow controls when practical.

## Verify cleanup

After a test job, confirm its runner Pod and ephemeral PVC are gone. The `ceph-rbd-ephemeral` StorageClass uses `reclaimPolicy: Delete`, so deletion of the PVC also removes its dynamically provisioned RBD image.

```powershell
kubectl -n arc-runners get pods,pvc
kubectl get storageclass ceph-rbd-ephemeral
```
