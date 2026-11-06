# Proxmox VM / Cloud-init

OpenTofu 1.6 以上または Terraform と `bpg/proxmox` provider を使用します。サンプルは仮想 NIC 1本の VM を作成し、Cloud-init でユーザー・SSH 公開鍵・IPv4 を指定します。**K3s、DB、qemu-guest-agent のインストールは行いません**。

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

`vms` に専用 DB VM を追加する例もあります。bridge を実在する tenant 用 VNet に変更し、ルートと Firewall を先に用意します。Terraform は DB ソフト・アカウント・バックアップを作成しません。[外部 DB 接続](network.md)を参照してください。

Terraform state には構成情報が入るため、アクセス制御・暗号化・バックアップを行い、Git には保存しないでください。ノード配置・HA・テンプレートアクセスなどは現環境に合わせた検証が必要です。

参考：[bpg provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)・[K3s HA](https://docs.k3s.io/datastore/ha-embedded)。

## 使い捨て K3s 2ノード検証

`infrastructure/proxmox/k3s-lab/` は独立した OpenTofu root です。K3s server 1台（2 vCPU / 4 GiB）と worker 1台（2 vCPU / 2 GiB）を作成し、worker の join まで試します。各 VM は 20 GiB のブートディスクを使い、K3s バージョンを固定します。この構成は HA ではなく、既存の汎用 VM 定義やクラスタ設定には触れません。

ブートディスクは選択した Proxmox datastore（既存 Ceph RBD pool など）に置けますが、**これは Kubernetes の Ceph CSI/PVC 設定ではありません**。K3s はデフォルトの Flannel を使います。この検証は node join の疎通確認までで、NetworkPolicy の強制やテナント workload は対象外です。

plan 前に次を確認してください。

- 選択した bridge で DHCP が利用でき、VM 2台のアドレスを安定して予約できること。worker は QEMU guest agent が報告した server の IP へ join します。`network_ipv4_cidr` はその bridge の CIDR に設定します。
- Ubuntu cloud-init template の boot disk が `virtio0` であること、Cloud-init drive があり、対象ノードから clone できること。
- snippet 用の共有 datastore で `snippets` content type が有効であること。snippet には一時 join token が含まれます。
- 未使用 VM ID と、CPU・メモリ・Ceph 容量がある対象 Proxmox node を選ぶこと。example の値はすべて置き換えてください。

`terraform.tfvars.example` を `terraform.tfvars` にコピーして環境値を設定し、最小権限の Proxmox token は provider が読む `PROXMOX_VE_API_TOKEN` 環境変数で渡します。snippet のアップロードには Proxmox node への SSH も使うため、`ssh_username` で指定したアカウントに対応する秘密鍵を `ssh_private_key_path` で指定してください（既定値は `~/.ssh/id_ed25519`）。provider は API endpoint の DNS suffix を使って node 名に FQDN を割り当てます。各 FQDN が実行環境から名前解決でき、SSH 接続できることを確認してください。OpenTofu state には生成した join token が入るため、state は非公開で保管し、Git に追加しないでください。

```powershell
cd infrastructure\proxmox\k3s-lab
Copy-Item terraform.tfvars.example terraform.tfvars
tofu init
tofu fmt -check
tofu validate
tofu plan
```

`plan` は state refresh のため Proxmox API へ接続することがありますが、VM は作成しません。plan の VM ID・配置先・ディスク・ネットワークを確認し、別途明示的に承認するまで apply しないでください。apply は VM を作成・起動し、destroy は VM と K3s の node data を削除します。

起動後、server の DHCP IP に SSH 接続し、`sudo cat /etc/rancher/k3s/k3s.yaml` で kubeconfig を取得します。kubeconfig の `server` アドレスを到達可能な IP に直し、ファイルを Git 管理外に保管してください。`kubectl get nodes -o wide` で server と worker の Ready を確認します。
