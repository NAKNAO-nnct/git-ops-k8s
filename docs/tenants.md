# テナントの実験手順

以下は例であり、実行する前に `kubectl config current-context` が**専用の実験用クラスタ**であることを確認してください。アプリの公開、管理パスワード、既存データの扱いはご自身の環境に合わせてください。テスト後の namespace 削除は PVC を含むリソースを削除する可能性があります。

## 共通準備

- `ceph-rbd` は既存 Ceph に接続された RBD CSI の StorageClass として別途作成します。Kubernetes 内に Ceph を新設する定義はありません。CSI の認証情報は専用に払い出します。
- CNI による NetworkPolicy 強制と DNS ラベル `k8s-app=kube-dns` を確認します。環境が異なれば共通 policy を修正してください。
- `kubectl create namespace tenant-X` で対象 namespace を先に作った後、下記 Secret を安全に作成します。後で生成済み manifest の Namespace を適用するとラベルも設定されます。キーは `kubectl create secret generic NAME -n NAMESPACE --from-file=KEY=秘密ファイル` で指定できます。秘密ファイルは Git の対象外の安全な場所に置き、シェル履歴に値を残さないでください。

| namespace | Secret 名 | 必要なキー |
|---|---|---|
| tenant-a | `immich-db` | `password` |
| tenant-c | `mysql-credentials` | `password`, `root-password` |
| tenant-c | `nextcloud-admin` | `username`, `password` |
| tenant-d | `mysql-credentials` | `password`, `root-password` |

上記の Secret 値は PostgreSQL / MySQL の初期化時に使います。**後で Secret だけ変更しても DB の既存パスワードは変更されません。** DB 側も安全にローテーションしてください。MySQL は永続ボリュームが既に初期化されている場合、初期 DB / ユーザーも再作成しません。

## A: Immich / S3 直接マウント — 必ず使い捨てデータで

S3 は POSIX ファイルシステムではありません。採用例の [csi-s3 / GeeseFS](https://github.com/yandex-cloud/k8s-csi-s3) 自身も、マウント方式や接続先ごとに POSIX 互換性・整合性が異なると説明しています。Immich は起動時にファイルの作成・読取・上書きを検査します（[公式資料](https://docs.immich.app/administration/system-integrity/)）。rename、上書き、キャッシュ、一貫性、権限、マウント切断、並列操作、削除等の互換性を本サンプルは保証しません。**本物の写真や既存バケットでは絶対に試さず**、独立した使い捨てバケットを使ってください。Immich の mount check を無効にしないでください。

1. CSI driver `ru.yandex.s3.csi` と GeeseFS をその driver の公式手順で実験クラスタにインストールし、K3s・OS・endpoint との互換性と privileged driver のリスクを確認します。実際に利用できる chart/version は自身で固定・検証してください。CSI は namespace 内ではなくノード側で S3 にアクセスするため、Pod の NetworkPolicy が S3 資格情報や通信を隔離するわけではありません。
2. 専用 S3 資格情報を、driver の指定に従い `kube-system/csi-s3-secret` として作成します。`accessKeyID`, `secretAccessKey`, `endpoint`、必要なら `region` を含みます。TLS とバケット単位の最小権限を使います。
3. [S3 PV の TypeScript 定義](../cdk8s/src/resources/immich-s3-pv.ts) の `volumeHandle` を `使い捨てバケット名/専用prefix` に変更し、[README の手順](../README.md#cdk8s-の生成と動作検証)で再生成します。PV は `Retain` に設定済みで、この例の PVC に固定して紐付きます。**PV の 10Gi は S3 の実容量制限ではありません**。ディレクトリとファイルの `0777/0666` は実験用で、本番向けの権限設定ではありません。
4. tenant-a の namespace / Secret を作成し、以下を実行します。

```powershell
kubectl apply -f kubernetes\dist\immich-s3-pv
kubectl apply -f kubernetes\dist\tenant-a
kubectl -n tenant-a get pods,pvc
kubectl -n tenant-a logs deployment/immich
kubectl -n tenant-a port-forward service/immich 2283:2283
```

ローカル `http://127.0.0.1:2283` で使い捨て写真のアップロード・表示・更新・削除、再起動、mount 障害、復元を検証します。ML はモデル取得のための外向き HTTPS が必要です。S3 のバージョニングと DB / S3 双方の別系統バックアップ・リストア試験なしに重要データを扱わないでください。

## B: Minecraft

公式 EULA に同意した場合だけ `EULA=TRUE` のまま適用します。起動時にサーバーやライブラリをダウンロードするため外向き HTTPS が必要です。

```powershell
kubectl apply -f kubernetes\dist\tenant-b
kubectl -n tenant-b get pods,pvc
kubectl -n tenant-b port-forward service/minecraft 25565:25565
```

同じ PC の Minecraft クライアントから `127.0.0.1:25565` で接続します。ネットワーク公開には TCP 対応 LoadBalancer / ルーターとアクセス制御が別途必要です。Web 用 Ingress は Minecraft の TCP 接続の代わりにはなりません。

## C: Nextcloud

Secret を作成し `kubectl apply -f kubernetes\dist\tenant-c` で適用します。`kubectl -n tenant-c port-forward service/nextcloud 8080:80` でローカル確認します。運用には trusted domains、HTTPS、cron、メール、キャッシュ、アップグレードやバックアップを別途設定します。

## D: Web + MySQL + Redis

`applications/tenant-d` でイメージをビルドし、プライベート registry に push します。[tenant-d.ts](../cdk8s/src/resources/tenant-d.ts) の `example.invalid/tenant-d-web:0.1.0` を検証したイメージに変更して再生成し、Secret 作成後に `kubectl apply -f kubernetes\dist\tenant-d`。`kubectl -n tenant-d port-forward service/web 8081:8080` のあと `/` と `/health` を確認します。DB や Redis が利用できない場合 `/health` は 503 を返します。Redis は永続化されません。

## 外部 DB VM

`kubernetes/dist/tenant-{a,c,d}-external-db` は、それぞれの内蔵 DB を除外して VM に接続する生成済みの雛形です。対応する `cdk8s/src/resources/tenant-*-external-db.ts` の DNS 名・IP を変更して再生成してください。DNS・IP・ルート・DB・Secret は別途用意します。内部 DB 版と外部 DB 版は同時に適用・同期しないでください。適用前に [network.md](network.md) を確認してください。

## 削除

バックアップの取得と復元、PVC の reclaim policy、S3 の保存方針を確認し、DB や写真の保持について明示的に合意してから削除します。namespace を消しても外部 VM、S3、`Retain` ボリュームは自動で片付かない場合があります。
