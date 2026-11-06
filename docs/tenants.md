# テナントの実験手順

以下は例であり、実行する前に `kubectl config current-context` が**専用の実験用クラスタ**であることを確認してください。アプリの公開、管理パスワード、既存データの扱いはご自身の環境に合わせてください。テスト後の namespace 削除は PVC を含むリソースを削除する可能性があります。

## 共通準備

- `ceph-rbd` は既存 Ceph に接続された RBD CSI の StorageClass として別途作成します。Kubernetes 内に Ceph を新設する定義はありません。CSI は専用 CephX ユーザーを使い、`client.admin` は使わないでください。K3s node から Ceph MON の TCP 3300/6789 と OSD の TCP 6800-7300 へ到達できる必要があります。
- CNI による NetworkPolicy 強制と DNS ラベル `k8s-app=kube-dns` を確認します。環境が異なれば共通 policy を修正してください。
- `kubectl create namespace tenant-X` で対象 namespace を先に作った後、下記 Secret を安全に作成します。後で生成済み manifest の Namespace を適用するとラベルも設定されます。キーは `kubectl create secret generic NAME -n NAMESPACE --from-file=KEY=秘密ファイル` で指定できます。秘密ファイルは Git の対象外の安全な場所に置き、シェル履歴に値を残さないでください。

| namespace | Secret 名 | 必要なキー |
|---|---|---|
| tenant-a | `immich-db` | `password` |
| tenant-c | `mysql-credentials` | `password`, `root-password` |
| tenant-c | `nextcloud-admin` | `username`, `password` |
| tenant-d | `mysql-credentials` | `password`, `root-password` |

上記の Secret 値は PostgreSQL / MySQL の初期化時に使います。**後で Secret だけ変更しても DB の既存パスワードは変更されません。** DB 側も安全にローテーションしてください。MySQL は永続ボリュームが既に初期化されている場合、初期 DB / ユーザーも再作成しません。

## A: Immich / Ceph RBD

Immich のメディア、PostgreSQL、ML キャッシュは `ceph-rbd` StorageClass の RBD PVC を使います。Ceph CSI RBD driver と `ceph-rbd` StorageClass は別途用意してください（[Ceph CSI の公式手順](https://github.com/ceph/ceph-csi/tree/devel/charts/ceph-csi-rbd)）。Ceph の cluster ID、MON アドレス、RBD pool、専用 CephX ユーザーを設定し、StorageClass の reclaim policy は実験中 `Retain` を推奨します。RBD は単一 node mount の `ReadWriteOnce` です。この定義は Immich を 1 replica で動かします。

1. K3s node から Ceph MON/OSD へのルーティングと firewall を確認します。標準ポートは MON TCP 3300/6789、OSD TCP 6800-7300 です。
2. `tenant-a` namespace と `immich-db` Secret を作成します。DB password は安全な場所で生成し、Git やシェル履歴に残さないでください。
3. 生成済み manifest を適用して状態を確認します。

```powershell
kubectl apply -f kubernetes\dist\tenant-a
kubectl -n tenant-a get pods,pvc
kubectl -n tenant-a logs deployment/immich
kubectl -n tenant-a port-forward service/immich 2283:2283
```

ローカル `http://127.0.0.1:2283` で動作を確認します。ML はモデル取得のための外向き HTTPS が必要です。Ceph RBD と `Retain` はバックアップではありません。重要なデータを扱う前に、Ceph とは別系統の DB / メディアバックアップと復元試験を用意してください。

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

バックアップの取得と復元、PVC の reclaim policy、Ceph RBD の保存方針を確認し、DB や写真の保持について明示的に合意してから削除します。namespace を消しても外部 VM や `Retain` ボリュームは自動で片付かない場合があります。
