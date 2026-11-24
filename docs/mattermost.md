# Mattermost sample deployment

This repository deploys the official Mattermost Team Edition container directly on Kubernetes; it does not use the Enterprise-only operator. The sample uses the official `mattermost-team-edition` v12.1.0 image and PostgreSQL 17.

## Storage and credentials

The PostgreSQL StatefulSet uses a 10 GiB `ceph-rbd` volume. Mattermost's local file storage uses a separate 10 GiB `ceph-rbd` PVC mounted at `/mattermost/data`. Both claims use the `Retain` reclaim policy inherited from the StorageClass, so deleting a claim does not delete its Ceph data.

Create the namespace and database Secret before syncing the Argo CD application:

```powershell
kubectl create namespace mattermost --dry-run=client -o yaml | kubectl apply -f -
.\bootstrap\mattermost\set-db-secret.ps1
kubectl apply -f bootstrap/argocd/applications/mattermost.yaml
```

The script generates two independent 256-bit passwords in memory and sends the Secret through `kubectl` standard input without printing or writing either value. It refuses to overwrite an existing Secret; run it once before the database starts. Keep the Secret out of Git. The PostgreSQL init script uses the superuser only to create a dedicated, non-superuser `mattermost` role and database; initialization scripts run only when the database volume is empty.

In Argo CD, manually sync the `mattermost` Application. Automatic sync and pruning are intentionally disabled.

## Cloudflare Tunnel

The public hostname reuses the existing Cloudflare Tunnel and the current `*.wantan.men` Cloudflare Access policy. Add this public-hostname route to the remote-managed tunnel:

- Hostname: `chat.wantan.men`
- Service: `http://mattermost.mattermost.svc.cluster.local:8065`

No public Kubernetes Service, NodePort, LoadBalancer, or inbound firewall rule is needed. Cloudflare terminates public HTTPS; the Tunnel connects to the in-cluster HTTP service. Mattermost is configured with `https://chat.wantan.men` as its Site URL.

Cloudflare Access is an additional login gate before Mattermost. Users and native clients must satisfy the existing Access policy as well as Mattermost authentication.

## Verification

```powershell
kubectl -n mattermost rollout status statefulset/postgres --timeout=10m
kubectl -n mattermost rollout status deployment/mattermost --timeout=10m
kubectl -n mattermost get pvc,pods,services
```

Confirm both PVCs are `Bound` at 10 GiB, the Mattermost pod is Ready, and `https://chat.wantan.men` displays Mattermost after Cloudflare Access authentication. The first Mattermost account should be created by an intended administrator; review the account-creation setting after initial setup.
