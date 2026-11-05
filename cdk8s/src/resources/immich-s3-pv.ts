import type { PersistentVolume, Resource } from '../types';

export const resources: Resource[] = [
  {
    "apiVersion": "v1",
    "kind": "PersistentVolume",
    "metadata": {
      "name": "tenant-a-s3-experiment"
    },
    "spec": {
      "storageClassName": "",
      "persistentVolumeReclaimPolicy": "Retain",
      "capacity": {
        "storage": "10Gi"
      },
      "accessModes": [
        "ReadWriteMany"
      ],
      "claimRef": {
        "namespace": "tenant-a",
        "name": "immich-media"
      },
      "csi": {
        "driver": "ru.yandex.s3.csi",
        "volumeHandle": "REPLACE_WITH_DISPOSABLE_BUCKET/immich",
        "nodePublishSecretRef": {
          "name": "csi-s3-secret",
          "namespace": "kube-system"
        },
        "nodeStageSecretRef": {
          "name": "csi-s3-secret",
          "namespace": "kube-system"
        },
        "controllerPublishSecretRef": {
          "name": "csi-s3-secret",
          "namespace": "kube-system"
        },
        "volumeAttributes": {
          "capacity": "10Gi",
          "mounter": "geesefs",
          "options": "--memory-limit 1000 --dir-mode 0777 --file-mode 0666"
        }
      }
    }
  } satisfies PersistentVolume,
];
