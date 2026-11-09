# Proxmox VM / Cloud-init

## 永続 K3s HA クラスタ

`infrastructure/proxmox/k3s-cluster/` は、3 台の Proxmox ホストそれぞれに K3s server 1 台と worker 1 台を作成します。server は 2 vCPU / 4 GiB、worker は 8 vCPU / 16 GiB です。server は `NoSchedule` taint を持ち、アプリの配置先は worker に限定します。Ubuntu 26.04 Cloud Image から VM を作成し、K3s の 3 server embedded-etcd 構成と kube-vip による API VIP を設定します。

- `vmbr1` を通常通信・外部通信・Kubernetes API VIP 用に使い、デフォルトゲートウェイを設定します。
- `vmbr0` を Ceph 用 NIC に使います。この NIC にデフォルトゲートウェイは設定しません。
- 例にある IP は文書用の予約アドレスです。実環境の値は Gitignore 対象の `terraform.tfvars` にだけ保存し、適用前に Proxmox の稼働 VM IP、Cloud-init 固定 IP、その他の手動割当との重複を確認して予約してください。DHCP/IPAM がなければ読み取り専用インベントリだけで未使用を保証することはできません。
- VM の OS / コンテナイメージ用ディスクは Ceph RBD 上に作成します。アプリの永続データは別途 Ceph CSI / StorageClass を構成して保存します。Ceph CSI、CNI の NetworkPolicy 強制、Ingress、バックアップはこの root の対象外です。テナント workload を載せる前にこれらを準備・検証してください。

```powershell
cd infrastructure\proxmox\k3s-cluster
Copy-Item terraform.tfvars.example terraform.tfvars
# terraform.tfvars の SSH 公開鍵と IP 候補を確認・修正する。
terraform init
terraform validate
terraform plan
```

`terraform.tfvars` と Terraform state は Git に含めません。`plan` を確認するだけで VM は作成されません。VM 作成の `apply` は、IP の重複確認・Proxmox 権限確認・plan 差分確認後に別途明示的に実行してください。

適用後、Cloud-init が完了するまで待ち、bootstrap server で `sudo k3s kubectl get nodes -o wide` を実行して 3 server / 3 worker が `Ready` であることと、API VIP 経由の接続を確認します。Terraform は QEMU Guest Agent の IP 取得まで待ちますが、K3s の join 完了までは待ちません。kubeconfig は bootstrap server の `/etc/rancher/k3s/k3s.yaml` にあります。CNI の NetworkPolicy 強制と Ceph CSI が整うまではテナント workload を適用しないでください。

Argo CD の導入は [Argo CD bootstrap 手順](argocd.md)を参照してください。

OpenTofu 1.6 以上または Terraform と `bpg/proxmox` provider を使用します。サンプルは仮想 NIC 1本の VM を作成し、Cloud-init でユーザー・SSH 公開鍵・IPv4 を指定します。**Kubernetes、DB、qemu-guest-agent のインストールは行いません**。

## 準備

1. Proxmox に cloud-init 対応の Ubuntu cloud image template を作成し、`qemu-guest-agent` を有効化しておきます。template の boot disk は `scsi0`、Cloud-init は provider が扱える構成にします。
2. template を対象ノードから clone できること、datastore が利用可能であることを確認します。物理ノードごとに1 VM を配置できるよう ID と空き容量を決めます。サンプルの ID・IP を実環境にそのまま使わないでください。
3. API 用の専用ユーザーと必要な最小権限の API token を用意し、HTTPS の証明書を実行端末で信頼します。provider は `PROXMOX_VE_API_TOKEN` などの環境変数を利用できます。認証情報を tfvars や Git に書かないでください。template には clone 権限を、作成先の `/vms/<vmid>` には VM の割り当て・構成権限を設定します。privilege separation を有効にした token では、必要な ACL をユーザーと token の両方に設定してください。必要な権限の詳細は provider の資料を参照します。
4. `terraform.tfvars.example` を `terraform.tfvars` にコピーし、endpoint、公開鍵、template、ノード、bridge、storage、IP を設定します。`terraform.tfvars` は Git の対象外です。DHCP を使う場合はアドレス予約を行い、固定 IP と DNS を確認します。

```powershell
cd infrastructure\proxmox
Copy-Item terraform.tfvars.example terraform.tfvars
# terraform.tfvars を編集。認証トークンは環境変数で設定。
tofu init
tofu validate
tofu plan
```

`plan` を十分確認し、影響範囲に合意できた場合のみ人が `tofu apply` します。初期化後、VM ごとに SSH、IP、qemu-guest-agent、移行、時刻同期を確認してください。既存 VM は自動 import されません。

`infrastructure/proxmox/` は Cloud-init 対応 template から汎用 VM を作成する root です。永続 K3s cluster の6台は専用 root `infrastructure/proxmox/k3s-cluster/` で管理します。

Terraform state には構成情報が入るため、アクセス制御・暗号化・バックアップを行い、Git には保存しないでください。ノード配置・HA・テンプレートアクセスなどは現環境に合わせた検証が必要です。

参考：[bpg provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)。
