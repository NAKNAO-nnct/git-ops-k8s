# Ceph CSI の導入

この repository には、upstream Ceph-CSI Operator を使って RBD と CephFS CSI を構成する manifest と手順があります。Ceph pool / filesystem の作成は自動化対象外で、実 credentials / MON address は含めません。CephX user の作成例は後述します。CSI chart は upstream で非推奨になったため、Ceph-CSI Operator `v1.1.0` の all-in-one manifest を使います。

## 前提

- K3s cluster が起動し、全 node が `Ready`。
- 使用する Ceph version が Ceph-CSI release の対応範囲にあること。
- node から `vmbr0` 経由で Ceph MON の TCP 3300（または v1 protocol の 6789）、OSD の TCP 6800-7300 に到達できること。
- 専用の RBD pool があること。CephFS を使う場合は filesystem と active MDS があり、CSI 用 subvolume group を作成できること。
- RBD / CephFS それぞれの least-privilege CephX user を作成すること。`client.admin` は使わないでください。[Ceph-CSI capabilities](https://github.com/ceph/ceph-csi/blob/v3.18.1/docs/capabilities.md)を参照してください。
- 以下の Kubernetes API 操作に cluster-admin 権限があること。CSI node plugin は privileged component として動作します。

Ceph-CSI Operator `v1.1.0` は Kubernetes 1.32 以降をサポートします。all-in-one manifest が Operator と CRD を作成し、`Driver` resource が RBD / CephFS driver を有効にします。

Ceph 管理端末で作成する CephX user の権限は、実際の pool / filesystem / subvolume group に合わせます。以下は upstream の capabilities を使った例です。値を置き換えて実行し、key の表示を抑止してから、`ceph auth get-key` で取得した key を安全に Kubernetes 作業端末へ転送してください。

```sh
set -e
RBD_POOL=REPLACE_WITH_RBD_POOL
FS_NAME=REPLACE_WITH_CEPHFS_NAME
SUBVOL_GROUP=csi
umask 077

ceph auth get-or-create --key-type=aes client.csi-rbd \
  mgr "profile rbd pool=${RBD_POOL}" \
  osd "profile rbd pool=${RBD_POOL}" \
  mon "profile rbd" >/dev/null
rbd_key=$(ceph auth get-key client.csi-rbd) && printf '%s' "$rbd_key" > /secure/path/csi-rbd.key

ceph auth get-or-create --key-type=aes client.csi-cephfs \
  mgr 'allow rw' \
  osd "allow rwx tag cephfs metadata=${FS_NAME}, allow rw tag cephfs data=${FS_NAME}" \
  mds "allow r fsname=${FS_NAME} path=/volumes, allow rws fsname=${FS_NAME} path=/volumes/${SUBVOL_GROUP}" \
  mon "allow r fsname=${FS_NAME}" >/dev/null
cephfs_key=$(ceph auth get-key client.csi-cephfs) && printf '%s' "$cephfs_key" > /secure/path/csi-cephfs.key
```

## Operator と driver の導入

適用前に context と cluster を確認します。

```sh
kubectl config current-context
kubectl get nodes
```

```sh
kubectl apply -f https://raw.githubusercontent.com/ceph/ceph-csi-operator/v1.1.0/deploy/all-in-one/install.yaml
kubectl -n ceph-csi-operator-system rollout status deployment/ceph-csi-operator-controller-manager --timeout=5m
kubectl apply -f bootstrap/ceph-csi/drivers.yaml
kubectl -n ceph-csi-operator-system get pods
```

## Ceph 接続と StorageClass

cluster 固有の設定と credentials は Gitignore 対象の root `secrets/` 配下に置きます。

```sh
mkdir -p secrets/ceph-csi
cp bootstrap/ceph-csi/examples/ceph-connection.yaml.example secrets/ceph-csi/ceph-connection.yaml
cp bootstrap/ceph-csi/examples/client-profile.yaml.example secrets/ceph-csi/client-profile.yaml
cp bootstrap/ceph-csi/examples/storageclass-rbd.yaml.example secrets/ceph-csi/storageclass-rbd.yaml
cp bootstrap/ceph-csi/examples/storageclass-cephfs.yaml.example secrets/ceph-csi/storageclass-cephfs.yaml
```

ローカルコピーを編集します。

- `ceph-connection.yaml` に、Ceph network から到達できる MON endpoint を設定します。
- StorageClass の RBD pool 名と CephFS filesystem 名を実値に置換します。placeholder のまま適用しないでください。
- `ClientProfile` 名の `homelab-ceph` と StorageClass の `clusterID` は一致させます。変更する場合は両方を変更してください。
- CephFS の `subVolumeGroup` は `csi` です。存在しない場合は Ceph 側で先に作成します。

CephX key file はキーだけを含む内容にし、秘密値をコマンド引数や Git に書きません。上記で作成した key file を安全に `secrets/ceph-csi/rbd.key` と `secrets/ceph-csi/cephfs.key` へ転送します。Secret の `userID` には `client.` prefix を付けません。

```sh
kubectl -n ceph-csi-operator-system create secret generic csi-rbd-secret \
  --from-literal=userID=csi-rbd \
  --from-file=userKey=secrets/ceph-csi/rbd.key \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n ceph-csi-operator-system create secret generic csi-cephfs-secret \
  --from-literal=userID=csi-cephfs \
  --from-file=userKey=secrets/ceph-csi/cephfs.key \
  --dry-run=client -o yaml | kubectl apply -f -
```

接続、profile、StorageClass を適用します。

```sh
kubectl apply -f secrets/ceph-csi/ceph-connection.yaml
kubectl apply -f secrets/ceph-csi/client-profile.yaml
kubectl apply -f secrets/ceph-csi/storageclass-rbd.yaml
kubectl apply -f secrets/ceph-csi/storageclass-cephfs.yaml
kubectl get storageclass ceph-rbd cephfs
kubectl get csidriver
```

アプリケーションは PVC で `ceph-rbd`（通常 `ReadWriteOnce`）または `cephfs`（`ReadWriteMany`）を指定します。PVC の要求容量は論理容量であり、物理容量の予約ではありません。Ceph pool を監視し、実際の PVC provision / mount をテストしてから workload を載せてください。両 StorageClass は `Retain` なので、PVC 削除だけでは Ceph 上のデータは自動削除されません。

CSI はアプリの永続データを Ceph に置きますが、worker の 32 GiB boot disk は引き続き OS、containerd image、ログ、`emptyDir` などに使われます。node の ephemeral storage が不足しないよう `nodefs` / image 使用量を監視してください。また、StorageClass や共有 CephX user だけでは tenant 間の強いデータ境界にならないため、実運用で分離が必要なら pool / filesystem / CephX user と Kubernetes の権限を合わせて設計します。

更新前に upstream の [Operator quick start](https://ceph.github.io/ceph-csi-operator/quick-start/) と [installation guide](https://ceph.github.io/ceph-csi-operator/installation/) を確認してください。
