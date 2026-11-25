# Argo CD bootstrap

この repository は Argo CD の control plane を導入する手順のみを用意しています。tenant workload や自動同期対象の Application は含みません。K3s cluster と kubeconfig が利用可能になってから実行してください。

## Install

まず `kubectl config current-context` と `kubectl get nodes` で対象 cluster を確認し、全 node が `Ready` であることを確認します。Argo CD の公式 install manifest は release `v3.6.1` に固定しています。

```sh
kubectl apply -f bootstrap/argocd/namespace.yaml
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.6.1/manifests/install.yaml
kubectl -n argocd rollout status deployment/argocd-server --timeout=10m
kubectl -n argocd get pods
```

Server-side apply is required because the ApplicationSet CRD exceeds the client-side apply annotation limit. `--force-conflicts` also permits migration if a previous client-side apply partially created resources.

## Access

初期セットアップ時は port-forward でアクセスできます。

```sh
kubectl -n argocd port-forward service/argocd-server 8080:443
```

ブラウザーで `https://127.0.0.1:8080` を開きます。初期 `admin` password は `argocd-initial-admin-secret` にあります。取得・変更後の認証情報は安全な secret manager 等に保存し、Git やログに残さないでください。

LAN からは `argocd.ingress.misosiru.uk` を Traefik の VIP `172.26.27.240` に向けてアクセスできます。Cloudflare の `*.ingress.misosiru.uk` は DNS-only の A レコードとして VIP を指し、Ingress は `letsencrypt-cloudflare` で証明書を発行して Argo CD の HTTPS service に接続します。Cloudflare Access は経由しないため、LAN 内からのアクセスにも Argo CD の認証が必要です。`argocd-internal-ingress` Application は `bootstrap/argocd/applications/argocd-internal-ingress.yaml` から登録して同期します。

Cloudflare Tunnel 用の Argo CD `Application` は [Cloudflare Tunnel 手順](cloudflare-tunnel.md)に従って登録します。Ingress / 証明書基盤の追加手順は[こちら](ingress.md)です。その他のアプリケーションを追加する際は、repository URL、branch、project、destination namespace、同期・prune 方針を確認した `Application` を別途作成します。初期状態ではアプリを自動同期・削除しません。

## GitHub SSO

組織所有の GitHub OAuth App を作成し、以下を設定します。Wildcard URI と Device Flow は不要です。

- Homepage URL: `https://argocd.wantan.men`
- Authorization callback URL: `https://argocd.wantan.men/api/dex/callback`

Client secret は Git に保存せず、PowerShell の secure prompt から Secret として登録します。その後、GitHub connector の base config を適用します。

```powershell
.\bootstrap\argocd\set-github-sso-secret.ps1
kubectl apply -f bootstrap/argocd/github-sso-config.yaml
.\bootstrap\argocd\set-github-sso-admin-team.ps1
```

`Yamada-Factory` の組織メンバーは read-only、入力したチームのメンバーは Argo CD admin になります。チーム slug は public repository に含めず、secure prompt から `argocd-rbac-cm` に設定します。初回ログイン時には GitHub の OAuth 許可が必要です。組織の OAuth app policy によっては、別途 OAuth App の承認も必要になります。この構成は既存のローカル `admin` アカウントを無効化しません。復旧用として残し、初期 password は安全な場所に保存してください。

Client secret をローテーションする場合は GitHub で新しい secret を生成し、secure prompt から Secret を更新します。Argo CD の公開 URL や callback URL を変える場合は、GitHub OAuth App と `argocd-cm` の両方を更新してください。

Ingress ホスト名は追加ホストであり、canonical URL と OAuth callback は引き続き `argocd.wantan.men` です。`argocd.ingress.misosiru.uk` から GitHub SSO を開始しても canonical host にリダイレクトされるため、このホスト名を維持したまま利用する場合はローカル `admin` アカウントを使用してください。

## GitOps configuration

Repository、`AppProject`、`Application` は Git 上の manifest を正として管理し、UI は状態確認や一時的な操作に使うことを推奨します。Cloudflare Tunnel Application は公開 repository の `main` branch を参照するため、repository credentials は不要です。Private repository の認証情報を平文の manifest に含めず、SOPS や External Secrets 等の secret 管理方法を決めてから登録してください。
