# Ingress and certificate infrastructure

K3s' bundled Traefik and ServiceLB are disabled. This setup installs Traefik as the Ingress controller, MetalLB for a single L2 LoadBalancer VIP on `vmbr1` (`172.26.27.0/24`), and cert-manager for DNS-01 certificates through Cloudflare.

The three Helm charts are pinned to Traefik `42.4.3`, MetalLB `0.16.2`, and cert-manager `v1.21.3`. Traefik `42.4.3` is selected instead of the newly published `43.0.0` chart because `43.0.0` includes CRD changes and a Traefik version support break. MetalLB's FRR-K8s subchart is disabled; only L2 announcements are needed.

## Address reservation

One VIP is enough for the shared Traefik service, regardless of the number of Ingresses or hostnames. The user confirmed that `172.26.27.240`-`172.26.27.245` are available; this configuration uses only `172.26.27.240/32` so other addresses are not allocated automatically. The L2 advertisement is restricted to `eth0`, the K3s VM interface on `vmbr1`.

The Traefik Service is `LoadBalancer` and receives the single reserved VIP from this pool.

## Install order

These Applications are intentionally manual-sync:

1. Apply and sync MetalLB:

   ```powershell
   kubectl apply -f bootstrap/argocd/applications/metallb.yaml
   argocd app sync metallb --sync-option CreateNamespace=true
   ```

2. After MetalLB's CRDs and controller are ready, apply and sync its address configuration:

   ```powershell
   kubectl apply -f bootstrap/argocd/applications/metallb-config.yaml
   argocd app sync metallb-config
   ```

3. Apply and sync Traefik:

   ```powershell
   kubectl apply -f bootstrap/argocd/applications/traefik.yaml
   argocd app sync traefik --sync-option CreateNamespace=true
   ```

4. Apply and sync cert-manager. Wait for all cert-manager deployments and webhook to become ready:

   ```powershell
   kubectl apply -f bootstrap/argocd/applications/cert-manager.yaml
   argocd app sync cert-manager --sync-option CreateNamespace=true
   ```

5. Create a Cloudflare API token with `Zone:Read` and `DNS:Edit` access limited to `wantan.men`, `misosiru.uk`, and `yamada-factory.uk`. Then run:

   ```powershell
   .\bootstrap\cert-manager\set-cloudflare-api-token.ps1
   ```

   The script reads the token securely and sends the Secret to `kubectl` over standard input. It does not write the token to Git or a file and refuses to replace an existing Secret.

   Cloudflare tokens expire after the configured lifetime (this token is set to one year). Record the expiration date shown in Cloudflare and rotate the token before it expires. The setup script intentionally refuses to overwrite an existing Secret, so use the approved secret-rotation procedure when replacing it.
6. Apply and sync the ClusterIssuer configuration:

   ```powershell
   kubectl apply -f bootstrap/argocd/applications/cert-manager-config.yaml
   argocd app sync cert-manager-config --sync-option CreateNamespace=true
   ```

7. Sync the existing Mattermost Application to add its `chat.wantan.men` and `chat.ingress.misosiru.uk` Ingress routes and request production certificates:

   ```powershell
   argocd app sync mattermost
   ```

For a DNS-01 dry run, temporarily use the `letsencrypt-cloudflare-staging` ClusterIssuer on a test Certificate or Ingress before requesting a production certificate. The ACME email is omitted because it is optional; configure a monitored contact address if expiry notifications are desired.

The Cloudflare solver covers zones managed by the Cloudflare token. Sakura Cloud DNS delegation and its `ingress.internal.*` names are not configured here. The Cloudflare wildcard `*.ingress.misosiru.uk` is DNS-only and points to the private Traefik VIP `172.26.27.240`; `chat.ingress.misosiru.uk` is therefore a direct LAN route, not a public Cloudflare Tunnel route. During initial setup, keep the public Cloudflare Tunnel route pointed directly at Mattermost until the Ingress, certificate, and LoadBalancer path are verified. After verification, set its origin to `http://traefik.traefik.svc.cluster.local:80`; the existing public `chat.wantan.men` route uses this Traefik origin.

## Verify

```powershell
kubectl -n metallb-system get pods
kubectl -n traefik get pods,service
kubectl -n cert-manager get pods
kubectl get clusterissuer
kubectl -n mattermost get ingress,certificate
```

Confirm the ClusterIssuers are `Ready`, the certificate is `Ready`, the Traefik Service has the reserved VIP, and an HTTPS request from `172.26.27.0/24` reaches Mattermost. The same hostname must resolve to the VIP on the LAN for direct LoadBalancer access; public DNS remains on the Cloudflare Tunnel.
