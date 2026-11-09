# Proxmox K3s platform

3 台の Proxmox host 上に HA K3s cluster を構築し、Argo CD を GitOps の control plane として導入するための IaC と bootstrap 手順です。サンプル tenant workload と Laravel 管理アプリケーションは含めません。

## 構成

```text
infrastructure/proxmox/k3s-cluster/  3 K3s server + 3 worker VMs
infrastructure/proxmox/             generic Cloud-init VM root
bootstrap/argocd/                     Argo CD namespace bootstrap
docs/                                 Proxmox、network、Argo CD 手順
bootstrap/ceph-csi/                   Ceph CSI operator and driver resources
```

各 Proxmox host に server 1 台（2 vCPU / 4 GiB / 40 GiB disk）と worker 1 台（8 vCPU / 16 GiB / 32 GiB disk）を作成します。VM boot disk は Ceph RBD 上です。server は embedded etcd と kube-vip API VIP を使い、Ubuntu 26.04 LTS Cloud Image から起動します。VM 作成前に [Proxmox 手順](docs/proxmox.md)を確認してください。

## 構築順序

1. VM の IP、VMID、Proxmox 権限と Ceph datastore を確認します。
2. `infrastructure/proxmox/k3s-cluster/` で `terraform init`、`validate`、`plan` を実行し、差分を確認してから明示的に `apply` します。
3. 3 server と 3 worker が `Ready` になることを確認し、CNI / NetworkPolicy enforcement を準備します。
4. [Ceph CSI の導入手順](docs/ceph-csi.md)に従い、RBD / CephFS CSI と StorageClass を構成・検証します。
5. [Argo CD の導入手順](docs/argocd.md)に従って Argo CD を bootstrap します。
6. 実際に運用するアプリケーションを決めた後、Git repository と Argo CD Application を追加します。サンプル workload は現在含まれていません。

## 運用上の注意

- Terraform state には認証・構成情報が含まれます。Git に保存せず、アクセス制御・暗号化・バックアップを設定してください。
- IPAM がない場合、Proxmox inventory だけでは手動設定された IP との重複を保証できません。適用前に確認・予約してください。
- Namespace / NetworkPolicy は CNI が enforcement して初めて有効です。共有 kernel 上の Kubernetes は相互に信頼しない利用者を完全には隔離しません。
- Ingress、バックアップ、監視、テナント向け RBAC はこの repository の bootstrap 対象外です。[network and isolation notes](docs/network.md)を確認してください。
