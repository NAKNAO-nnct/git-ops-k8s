# Network and workload isolation

この repository は現在 tenant workload や DB 接続のサンプルを含みません。実アプリケーションを追加する際は、次の境界を個別に設計・検証してください。

## K3s node networks and Cilium

- `vmbr0` (`172.26.26.0/24`) は Ceph とノード間の内部通信に使います。K3s node IP、embedded etcd、Cilium VXLAN tunnel、API VIP はこのネットワークを通します。
- `vmbr1` (`172.26.27.0/24`) はデフォルトゲートウェイを持ち、外向き通信に使います。Ceph NIC にはデフォルトゲートウェイを設定しません。
- Cilium tunnel mode はノード間で UDP 8472 を必要とします。Ceph MON / OSD への接続とともに、ファイアウォールで必要な送信元・宛先だけ許可してください。
- Kubernetes API VIP は内部ネットワーク上の管理用 endpoint です。管理端末からの TCP 6443 のみ許可し、WAN へ公開しません。
- Pod の外向き通信が `vmbr1` から出ること、Cilium の masquerade 後に意図した送信元 IP になることを実環境で確認してください。

## Kubernetes network policies

- Namespace ごとの default-deny と必要最小限の ingress/egress policy を使います。NetworkPolicy は CNI が enforcement して初めて機能します。
- DNS、Kubernetes API、monitoring、ingress など共有 service への必要な通信を明示的に許可します。
- 同じ namespace 内の Pod 間通信もポリシー設計の対象です。複数 policy は合算され、利用者に policy 変更権限を与えると追加許可され得ます。
- Node、Pod、Service の CIDR、IPv6、CNI の routing / SNAT の挙動を確認し、許可・拒否の両方を実環境でテストします。

## Kubernetes workload to an external database

外部 DB への接続を追加する場合は、CNI policy だけでなく DB 側 firewall、DNS、往復経路、TLS、認証も設定します。SNAT 後に DB が観測する送信元は CNI と routing によって異なり、worker IP だけでは workload や namespace を区別できない場合があります。

より強い境界として egress gateway を利用する場合は、送信元 IP の予約、route、SNAT、failover と policy の適用タイミングを検証してください。NetworkPolicy のみを唯一の安全境界にしないでください。

## Ceph storage

Ceph CSI Operator、RBD / CephFS driver、StorageClass の導入手順は[こちら](ceph-csi.md)です。CephX は必要最小限の専用ユーザーを使い、node から MON / OSD への routing と firewall を確認してください。PV の `Retain` は backup の代わりではありません。Ceph 外の backup と restore test を用意します。
