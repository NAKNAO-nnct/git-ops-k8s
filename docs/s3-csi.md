# S3 CSI driver

The `s3-csi` Argo CD Application installs the [Yandex Cloud S3 CSI driver](https://github.com/yandex-cloud/k8s-csi-s3) chart `0.43.7`, using GeeseFS as its FUSE mounter. The driver supports S3-compatible endpoints, including Ceph RGW, once an endpoint, bucket, and credentials are configured.

## Install

Confirm the current Kubernetes context before applying the Argo CD Application:

```powershell
kubectl config current-context
kubectl apply -f bootstrap/argocd/applications/s3-csi.yaml
```

Then manually sync the `s3-csi` Application in Argo CD. Automatic sync is intentionally disabled, consistent with the other applications.

The chart's built-in Secret and StorageClass are disabled. No S3 endpoint or credentials are currently configured, and the chart's default StorageClass uses a `Delete` reclaim policy. Configure a dedicated Secret and StorageClass for the actual S3 provider before creating S3-backed PVCs; keep credentials out of Git and scope them to only the required bucket. Use a `Retain` reclaim policy when deleting a PVC must not delete its objects.

## Security and usage notes

The CSI node plugin requires a privileged container, `SYS_ADMIN`, `/dev/fuse`, host mount propagation, and access to the node's systemd control socket. It is installed in `kube-system` and runs on schedulable worker nodes; only trusted workloads should be allowed to use the driver.

S3 is object storage, not a fully POSIX filesystem. Prefer an application's native S3 support when available, and do not use an S3 mount for database files or workloads that depend on filesystem locking, atomic rename, or concurrent write semantics.

## Verify

After syncing the Application, confirm the node plugin and controller are ready:

```powershell
kubectl get csidriver ru.yandex.s3.csi
kubectl -n kube-system rollout status daemonset/csi-s3 --timeout=5m
kubectl -n kube-system rollout status statefulset/csi-s3-provisioner --timeout=5m
```

A PVC mount can only be tested after configuring an S3 endpoint, bucket, Secret, and StorageClass.
