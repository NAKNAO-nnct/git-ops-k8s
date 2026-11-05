# ネットワークと DB VM

## Kubernetes 内 DB

各テナントの Pod と DB は同一 namespace 内に置き、`mysql`、`postgres`、`redis` の Service 名で接続します。共通ポリシーは namespace 間の ingress/egress を原則拒否し、同じ namespace と DNS を許可します。外部公開用ポートの例外は README の注意を参照してください。

```text
tenant-c namespace: Nextcloud → mysql:3306 → MySQL Pod → Ceph RBD
tenant-d namespace: Web → mysql:3306 / redis:6379
```

## DB を Proxmox VM に置く例

`kubernetes/overlays/tenant-c-external-db` は C の Kubernetes 内 MySQL を除き、`mysql-external` という ExternalName Service と、指定 DB IP への TCP/3306 の egress 許可を生成する**雛形**です。アプリは `MYSQL_HOST=mysql-external` に接続します。

A・D 用の overlay もあります。A の DB VM では、選択した Immich バージョンに対応する PostgreSQL 拡張・DB ユーザーを別途準備する必要があります。D の外部 DB は TCP/3306 で接続し、Redis は Kubernetes 内に残ります。各 overlay の DNS 名・IP はいずれも架空です。

```text
Nextcloud Pod
  → Cilium NetworkPolicy: DB VM の IP:3306 のみ許可
  → worker / 共通ネットワーク → ルーター・EVPN exit → DB VM
  ← 戻り経路（DB VM → worker が使う送信元 IP）
```

例の DNS 名 `tenant-c-db.example.invalid`、IP `172.28.103.10/32` は必ず環境に合わせます。DNS が返す IP と許可先の IP は一致させてください。VM の MySQL と DB/user/password を事前に作成し、namespace の `mysql-credentials` の `password` と一致させます。MySQL bind address、認証、TLS、DB 側 firewall を設定します。overlay は VM、DNS、経路、DB を作成しません。

**SNAT 有効だけでは外部→VNet の新規接続はできません。** DB subnet への経路、EVPN exit の L3 到達性、戻りルート、Firewall を実環境で設定してから、接続試験を行ってください。Proxmox のネットワーク設定はこのサンプルでは変更しません。

DB VM が見た送信元が Pod IP か worker IP かは CNI、SNAT、経路で変わります。単純な構成では複数テナントが同じ worker IP に見えることがあり、DB Firewall はその IP のみではテナントを区別できません。より強い境界にはテナント別 egress IP（例: Cilium Egress Gateway）と VM Firewall 等を組み合わせ、gateway IP の割り当て・ルート・SNAT・フェイルオーバーを設計してください。このリポジトリは egress gateway を**設定していません**。

テストは必ず実際の送信元を DB 側で観測し、tenant-c → DB C の成功、tenant-d → DB C の失敗、tenant-c → 別 DB の失敗、戻り経路と障害時の動作を確認します。Cilium は Pod 起動時の egress gateway ポリシー適用に遅延があり得るため、それだけを唯一の安全境界にしないでください。

すでに Kubernetes 内 MySQL を使っている状態で overlay に切り替えても、データ移行は行われません。バックアップ・移行・復元確認を先に行い、古い Deployment/PVC の削除を自動 prune に任せないでください。
