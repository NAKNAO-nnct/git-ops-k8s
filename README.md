# Proxmox + Kubernetes マルチテナント実験

Proxmox 上の VM に Kubernetes を構築し、テナントごとのアプリ・DB を試すための**実験用サンプル**です。既存の Proxmox、SDN、Swarm、Ceph、S3 の設定は変更しません。実環境にデプロイする操作も自動実行しません。

> **本番投入不可。** Kubernetes、CSI、S3、実際の DB を使った結合試験は未実施です。単一レプリカの DB、バックアップ、TLS、監視、認証連携、障害復旧、S3 の互換性検証などが必要です。特に Immich の S3 マウントには写真データの破損・喪失リスクがあります。

## 収録内容

| テナント | アプリ | DB / 他 | 永続ストレージ |
|---|---|---|---|
| A | Immich | 専用 PostgreSQL + Valkey + ML | メディアは S3 互換バケットを直接マウントする**実験用** PV、DB は Ceph RBD |
| B | Minecraft Java | — | Ceph RBD |
| C | Nextcloud | 専用 MySQL | Ceph RBD。別途 DB VM 接続の overlay あり |
| D | 自作 Web のサンプル | 専用 MySQL + Redis | MySQL は Ceph RBD。Redis は揮発性 |

```text
infrastructure/proxmox/    OpenTofu VM + Cloud-init の例
kubernetes/base/          全テナント共通 NetworkPolicy
kubernetes/tenants/       A〜D の Kustomize 定義
kubernetes/overlays/      A・C・D の外部 DB VM 接続例
kubernetes/storage/       Immich の S3 直接マウント用 PV の例
kubernetes/platform/      Laravel 管理画面のデプロイ例
applications/tenant-d/    DB / Redis を利用する Web サンプル
admin/                    Laravel 管理画面
tests/                    マニフェスト検証
```

## 前提と順序

1. 実験用クラスタ、リストア可能なバックアップ、重複しない IP/VM ID と容量を用意します。**既存クラスタをそのまま試験台にしないでください。**
2. [VM 作成手順](docs/proxmox.md)で cloud-init 対応 VM を用意します。例は K3s node 3台と、任意の DB VM を作れます。OS の初期アカウント・SSH 公開鍵・IP のみ設定し、K3s・MySQL・SDN は自動インストールしません。
3. 3ノードへの K3s 等のインストール、etcd の quorum と API の固定入口、NetworkPolicy を強制できる CNI、既存 Ceph 用 CSI と `ceph-rbd` StorageClass は別途準備します。**K3s のデフォルト Flannel 単体では、このリポジトリの NetworkPolicy を強制できません。** Cilium の CNI 併用手順と MTU は構築する K3s/Cilium の公式資料に従ってください。
4. [テナント構築手順](docs/tenants.md)に従い、Secret・テスト用バケット・CSI を準備し、対象テナントを適用します。placeholder を実値に変更する前に必ず内容を確認してください。
5. [Laravel 管理画面](docs/admin.md)を構築します。管理画面は現時点で namespace と基本 NetworkPolicy の直接作成・削除のみ対応し、**アプリ・DB・VM の自動作成や Git への書き戻しには対応していません**。

各ノードの NIC は共通ネットワーク接続でよく、テナントごとに NIC は不要です。Namespace、NetworkPolicy、Pod Security、RBAC を別途正しく設定しても、共有カーネルを使うため、互いに信頼しない利用者の完全な隔離にはなりません。

## 動作検証

```powershell
python -m pip install -r tests\requirements.txt
python -m unittest discover -s tests -v
```

`kubectl kustomize` が必要です。これらは**オフラインの構造検査**であり、イメージ取得、実デプロイ、ネットワークの遮断やストレージの正常性は証明しません。Laravel のテストは `admin` で `composer install` 後に `php artisan test` です。

## セキュリティと運用上の重要事項

- PV の `Retain` はバックアップではありません。S3 のバージョニング、別系統バックアップ、DB を含む復元試験が必要です。
- HTTP/TCP のアプリ用ポートはサンプルでは全送信元に対して ingress を許可しています。Service は ClusterIP ですが、これ自体はテナント分離ではありません。公開前に送信元、ingress controller、外部 Firewall を絞り、正負両方の疎通テストを行ってください。
- 名前空間間の隔離には CNI のポリシー強制、テナントへの Kubernetes 権限制限、特権 Pod / hostNetwork / hostPath 等の禁止が必要です。NetworkPolicy は同じ namespace の Pod 間は全許可します。
- DNS や API など共有基盤を保護し、CNI のポリシー・SNAT 挙動、Pod CIDR、IPv6、ノードからのアクセスを実環境で確認してください。`ipBlock` による IPv4 の除外は全てのネットワークや CNI の挙動を網羅しません。
- NetworkPolicy は合算されます。テナントに自分のポリシーの変更権限を与えると、許可を追加され得ます。アプリにも特権を与えないでください。
- Image tag や `example.invalid` はサンプルです。検証した digest、イメージ更新、署名、脆弱性管理を別途実施します。
- Secret はリポジトリに保存しません。Secret の保管・暗号化・RBAC・ローテーション・ログ管理は別途設計してください。
- `kubectl apply` と Laravel の直接操作は GitOps の自動同期ではありません。両方で同一 namespace を管理すると競合するので、管理元を分けます。
