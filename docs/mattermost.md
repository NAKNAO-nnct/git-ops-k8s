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

The script generates two independent 256-bit passwords in memory and sends the Secret through `kubectl` standard input without printing or writing either value. It refuses to overwrite an existing Secret; run it once before the database starts. Keep the Secret out of Git. PostgreSQL initializes an empty volume and allows SCRAM-authenticated connections from the K3s pod CIDR. A NetworkPolicy further restricts network ingress to PostgreSQL to Mattermost-labeled pods in the `mattermost` namespace; other namespaces need an explicit policy change to connect. Before Mattermost starts, its init container uses the secret-backed PostgreSQL superuser to idempotently create or update the dedicated, non-superuser `mattermost` role and database.

In Argo CD, manually sync the `mattermost` Application. Automatic sync and pruning are intentionally disabled.

## Ingress and Cloudflare Tunnel

The Mattermost Application includes Traefik Ingress routes for `chat.wantan.men` and `chat.ingress.misosiru.uk`, with separate certificates from the `letsencrypt-cloudflare` ClusterIssuer. The wildcard Cloudflare DNS record `*.ingress.misosiru.uk` points to the Traefik VIP `172.26.27.240`, so the new hostname is for direct LAN access. It bypasses Cloudflare Tunnel and Access; Mattermost authentication is still required. The canonical `MM_SERVICESETTINGS_SITEURL` remains `https://chat.wantan.men`.

During initial setup, keep the Cloudflare Tunnel route direct to Mattermost until the Ingress, certificate, and LAN route have been verified. After validation, change the route to the shared Traefik service. The current route is:

- Hostname: `chat.wantan.men`
- Service: `http://traefik.traefik.svc.cluster.local:80`

Cloudflare terminates public HTTPS; the Tunnel connects to Traefik over in-cluster HTTP, while LAN clients can use HTTPS through the LoadBalancer. Do not enable an HTTP-to-HTTPS redirect at Traefik for this origin unless the Tunnel is also configured to connect to HTTPS.

For `chat.wantan.men`, Cloudflare Access is an additional login gate before Mattermost. Users and native clients must satisfy the existing Access policy as well as Mattermost authentication. The LAN-only `chat.ingress.misosiru.uk` alias does not pass through Cloudflare Access.

## Verification

```powershell
kubectl -n mattermost rollout status statefulset/postgres --timeout=10m
kubectl -n mattermost rollout status deployment/mattermost --timeout=10m
kubectl -n mattermost get pvc,pods,services
kubectl -n mattermost get networkpolicy postgres-ingress
```

Confirm both PVCs are `Bound` at 10 GiB, the Mattermost pod is Ready, `https://chat.wantan.men` displays Mattermost after Cloudflare Access authentication, and `https://chat.ingress.misosiru.uk` works from the LAN with a trusted certificate. The first Mattermost account should be created by an intended administrator; review the account-creation setting after initial setup.
