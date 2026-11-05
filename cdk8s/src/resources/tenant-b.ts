import type { Deployment, NetworkPolicy, PersistentVolumeClaim, Service, Resource } from '../types';

export const resources: Resource[] = [
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "minecraft",
      "namespace": "tenant-b"
    },
    "spec": {
      "ports": [
        {
          "port": 25565,
          "protocol": "TCP",
          "targetPort": 25565
        }
      ],
      "selector": {
        "app": "minecraft"
      },
      "type": "ClusterIP"
    }
  } satisfies Service,
  {
    "apiVersion": "v1",
    "kind": "PersistentVolumeClaim",
    "metadata": {
      "name": "minecraft-data",
      "namespace": "tenant-b"
    },
    "spec": {
      "accessModes": [
        "ReadWriteOnce"
      ],
      "resources": {
        "requests": {
          "storage": "20Gi"
        }
      },
      "storageClassName": "ceph-rbd"
    }
  } satisfies PersistentVolumeClaim,
  {
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
      "name": "minecraft",
      "namespace": "tenant-b"
    },
    "spec": {
      "selector": {
        "matchLabels": {
          "app": "minecraft"
        }
      },
      "strategy": {
        "type": "Recreate"
      },
      "template": {
        "metadata": {
          "labels": {
            "app": "minecraft"
          }
        },
        "spec": {
          "containers": [
            {
              "env": [
                {
                  "name": "EULA",
                  "value": "TRUE"
                },
                {
                  "name": "VERSION",
                  "value": "1.21.4"
                },
                {
                  "name": "TYPE",
                  "value": "VANILLA"
                },
                {
                  "name": "MEMORY",
                  "value": "2G"
                }
              ],
              "image": "itzg/minecraft-server:java21",
              "name": "minecraft",
              "ports": [
                {
                  "containerPort": 25565
                }
              ],
              "volumeMounts": [
                {
                  "mountPath": "/data",
                  "name": "data"
                }
              ]
            }
          ],
          "volumes": [
            {
              "name": "data",
              "persistentVolumeClaim": {
                "claimName": "minecraft-data"
              }
            }
          ]
        }
      }
    }
  } satisfies Deployment,
  {
    "apiVersion": "networking.k8s.io/v1",
    "kind": "NetworkPolicy",
    "metadata": {
      "name": "minecraft-network",
      "namespace": "tenant-b"
    },
    "spec": {
      "egress": [
        {
          "ports": [
            {
              "port": 443,
              "protocol": "TCP"
            }
          ],
          "to": [
            {
              "ipBlock": {
                "cidr": "0.0.0.0/0",
                "except": [
                  "10.0.0.0/8",
                  "172.16.0.0/12",
                  "192.168.0.0/16",
                  "169.254.0.0/16",
                  "127.0.0.0/8"
                ]
              }
            }
          ]
        }
      ],
      "ingress": [
        {
          "ports": [
            {
              "port": 25565,
              "protocol": "TCP"
            }
          ]
        }
      ],
      "podSelector": {
        "matchLabels": {
          "app": "minecraft"
        }
      },
      "policyTypes": [
        "Ingress",
        "Egress"
      ]
    }
  } satisfies NetworkPolicy,
];
