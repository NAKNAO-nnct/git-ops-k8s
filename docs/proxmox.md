# Proxmox VM / Cloud-init

OpenTofu 1.6 以上または Terraform と `bpg/proxmox` provider を使用します。サンプルは仮想 NIC 1本の VM を作成し、Cloud-init でユーザー・SSH 公開鍵・IPv4 を指定します。**K3s、DB、qemu-guest-agent のインストールは行いません**。

## 準備

1. Proxmox に cloud-init 対応の Ubuntu cloud image template を作成し、`qemu-guest-agent` を有効化しておきます。template の boot disk は `scsi0`、Cloud-init は provider が扱える構成にします。
2. template を対象ノードから clone できること、datastore が利用可能であることを確認します。物理ノードごとに1 VM を配置できるよう ID と空き容量を決めます。サンプルの ID・IP を実環境にそのまま使わないでください。
3. API 用の専用ユーザーと必要な最小権限の API token を用意し、HTTPS の証明書を実行端末で信頼します。provider は `PROXMOX_VE_API_TOKEN` などの環境変数を利用できます。認証情報を tfvars や Git に書かないでください。API token と template clone に必要な権限は provider の資料を参照します。
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
