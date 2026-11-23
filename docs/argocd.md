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

外部公開は設定せず、まず port-forward でアクセスします。

```sh
kubectl -n argocd port-forward service/argocd-server 8080:443
```

ブラウザーで `https://127.0.0.1:8080` を開きます。初期 `admin` password は `argocd-initial-admin-secret` にあります。取得・変更後の認証情報は安全な secret manager 等に保存し、Git やログに残さないでください。

実際のアプリケーションを追加する際は、repository URL、branch、project、destination namespace、同期・prune 方針を確認した Argo CD `Application` を別途作成します。初期状態ではアプリを自動同期・削除しません。

## GitOps configuration

Repository、`AppProject`、`Application` は Git 上の manifest を正として管理し、UI は状態確認や一時的な操作に使うことを推奨します。Private repository の認証情報を平文の manifest に含めず、SOPS や External Secrets 等の secret 管理方法を決めてから登録してください。repository URL、branch、manifest path、認証方式が決まるまでは repository を登録しません。
