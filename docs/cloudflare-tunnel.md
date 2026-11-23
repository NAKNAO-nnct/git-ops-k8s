# Argo CD Cloudflare Tunnel

Cloudflared runs inside Kubernetes and creates an outbound-only Cloudflare Tunnel for `argocd.wantan.men`. The public origin is Argo CD's ClusterIP service; no NodePort, LoadBalancer, or inbound firewall rule is required.

## Cloudflare Zero Trust

1. Create a remotely-managed Cloudflare Tunnel and name it `k3s-argocd`.
2. In the tunnel's public hostnames, add `argocd.wantan.men` with service `https://argocd-server.argocd.svc.cluster.local:443`.
3. Enable **No TLS Verify** for that origin. Argo CD's default in-cluster certificate is self-signed; this setting applies only to the cloudflared-to-Argo CD connection. Public browser traffic still uses HTTPS at Cloudflare.
4. Create an exact-hostname self-hosted Access application for `argocd.wantan.men`. Give it a restrictive Allow policy for the intended administrators, with no Bypass policy. The exact hostname is more specific than `*.wantan.men`; Cloudflare documents that the more-specific application path takes precedence and does not inherit the wildcard application's policies.
5. Select the intended identity provider and an appropriately short session duration for this administrative application. Do not enable instant authentication unless intentionally desired.

If another Access application uses a wildcard hostname, verify that the exact-hostname application is selected and that no Bypass policy grants unintended access. Use Cloudflare's Access policy tester and test the hostname from both an allowed and an unauthenticated session. Require MFA through Cloudflare Access or the selected identity provider where available; account-wide authentication settings must be reviewed separately.

## Kubernetes and Argo CD

The GitHub repository is public, so Argo CD does not need repository credentials. The Application source is pinned to `main` and `bootstrap/cloudflared`; it does not enable automatic sync or pruning.

After creating the tunnel, keep its token out of Git and shell command history:

```powershell
kubectl create namespace cloudflare-tunnel --dry-run=client -o yaml | kubectl apply -f -
.\bootstrap\cloudflared\set-tunnel-token.ps1
```

Paste the tunnel token into the secure prompt. The script sends a Secret manifest through `kubectl` standard input and does not write the token to a file. Then register the Argo CD Application:

```powershell
kubectl apply -f bootstrap/argocd/applications/cloudflare-tunnel.yaml
```

Sync the `cloudflare-tunnel` Application in Argo CD. It creates two cloudflared replicas with host spreading and references the manually-created `cloudflared` Secret. The token must be recreated in the cluster if the tunnel is rotated; it is deliberately not managed by Argo CD.

## Verification

```powershell
kubectl -n cloudflare-tunnel rollout status deployment/cloudflared
kubectl -n cloudflare-tunnel get pods
```

Confirm both replicas are Ready, the tunnel shows healthy connectors in Cloudflare Zero Trust, and `https://argocd.wantan.men` requires the intended Access policy before displaying Argo CD.
