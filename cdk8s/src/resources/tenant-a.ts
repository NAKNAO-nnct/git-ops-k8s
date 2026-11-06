import type { Deployment, NetworkPolicy, PersistentVolumeClaim, Service, Resource } from '../types';

export const resources: Resource[] = [
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "immich",
      "namespace": "tenant-a"
    },
    "spec": {
      "ports": [
        {
          "port": 2283,
          "targetPort": 2283
        }
      ],
      "selector": {
        "app": "immich"
      }
    }
  } satisfies Service,
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "immich-ml",
      "namespace": "tenant-a"
    },
    "spec": {
      "ports": [
        {
          "port": 3003,
          "targetPort": 3003
        }
      ],
      "selector": {
        "app": "immich-ml"
      }
    }
  } satisfies Service,
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "postgres",
      "namespace": "tenant-a"
    },
    "spec": {
      "ports": [
        {
          "port": 5432,
          "targetPort": 5432
        }
      ],
      "selector": {
        "app": "postgres"
      }
    }
  } satisfies Service,
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "redis",
      "namespace": "tenant-a"
    },
    "spec": {
      "ports": [
        {
          "port": 6379,
          "targetPort": 6379
        }
      ],
      "selector": {
        "app": "redis"
      }
    }
  } satisfies Service,
  {
    "apiVersion": "v1",
    "kind": "PersistentVolumeClaim",
    "metadata": {
      "name": "immich-media",
      "namespace": "tenant-a"
    },
    "spec": {
      "accessModes": [
        "ReadWriteOnce"
      ],
      "resources": {
        "requests": {
          "storage": "10Gi"
        }
      },
      "storageClassName": "ceph-rbd"
    }
  } satisfies PersistentVolumeClaim,
  {
    "apiVersion": "v1",
    "kind": "PersistentVolumeClaim",
    "metadata": {
      "name": "immich-ml-cache",
      "namespace": "tenant-a"
    },
    "spec": {
      "accessModes": [
        "ReadWriteOnce"
      ],
      "resources": {
        "requests": {
          "storage": "10Gi"
        }
      },
      "storageClassName": "ceph-rbd"
    }
  } satisfies PersistentVolumeClaim,
  {
    "apiVersion": "v1",
    "kind": "PersistentVolumeClaim",
    "metadata": {
      "name": "immich-postgres",
      "namespace": "tenant-a"
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
      "name": "immich",
      "namespace": "tenant-a"
    },
    "spec": {
      "replicas": 1,
      "selector": {
        "matchLabels": {
          "app": "immich"
        }
      },
      "strategy": {
        "type": "Recreate"
      },
      "template": {
        "metadata": {
          "labels": {
            "app": "immich"
          }
        },
        "spec": {
          "containers": [
            {
              "env": [
                {
                  "name": "DB_HOSTNAME",
                  "value": "postgres"
                },
                {
                  "name": "DB_USERNAME",
                  "value": "immich"
                },
                {
                  "name": "DB_DATABASE_NAME",
                  "value": "immich"
                },
                {
                  "name": "DB_PASSWORD",
                  "valueFrom": {
                    "secretKeyRef": {
                      "key": "password",
                      "name": "immich-db"
                    }
                  }
                },
                {
                  "name": "REDIS_HOSTNAME",
                  "value": "redis"
                },
                {
                  "name": "IMMICH_MACHINE_LEARNING_URL",
                  "value": "http://immich-ml:3003"
                }
              ],
              "image": "ghcr.io/immich-app/immich-server:v3.3.6",
              "name": "immich",
              "ports": [
                {
                  "containerPort": 2283
                }
              ],
              "volumeMounts": [
                {
                  "mountPath": "/data",
                  "name": "media"
                }
              ]
            }
          ],
          "volumes": [
            {
              "name": "media",
              "persistentVolumeClaim": {
                "claimName": "immich-media"
              }
            }
          ]
        }
      }
    }
  } satisfies Deployment,
  {
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
      "name": "immich-ml",
      "namespace": "tenant-a"
    },
    "spec": {
      "replicas": 1,
      "selector": {
        "matchLabels": {
          "app": "immich-ml"
        }
      },
      "strategy": {
        "type": "Recreate"
      },
      "template": {
        "metadata": {
          "labels": {
            "app": "immich-ml"
          }
        },
        "spec": {
          "containers": [
            {
              "image": "ghcr.io/immich-app/immich-machine-learning:v3.3.6",
              "name": "ml",
              "ports": [
                {
                  "containerPort": 3003
                }
              ],
              "volumeMounts": [
                {
                  "mountPath": "/cache",
                  "name": "cache"
                }
              ]
            }
          ],
          "volumes": [
            {
              "name": "cache",
              "persistentVolumeClaim": {
                "claimName": "immich-ml-cache"
              }
            }
          ]
        }
      }
    }
  } satisfies Deployment,
  {
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
      "name": "postgres",
      "namespace": "tenant-a"
    },
    "spec": {
      "replicas": 1,
      "selector": {
        "matchLabels": {
          "app": "postgres"
        }
      },
      "strategy": {
        "type": "Recreate"
      },
      "template": {
        "metadata": {
          "labels": {
            "app": "postgres"
          }
        },
        "spec": {
          "containers": [
            {
              "env": [
                {
                  "name": "POSTGRES_USER",
                  "value": "immich"
                },
                {
                  "name": "POSTGRES_DB",
                  "value": "immich"
                },
                {
                  "name": "POSTGRES_INITDB_ARGS",
                  "value": "--data-checksums"
                },
                {
                  "name": "PGDATA",
                  "value": "/var/lib/postgresql/data/pgdata"
                },
                {
                  "name": "POSTGRES_PASSWORD",
                  "valueFrom": {
                    "secretKeyRef": {
                      "key": "password",
                      "name": "immich-db"
                    }
                  }
                }
              ],
              "image": "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23",
              "name": "postgres",
              "ports": [
                {
                  "containerPort": 5432
                }
              ],
              "volumeMounts": [
                {
                  "mountPath": "/var/lib/postgresql/data",
                  "name": "data"
                }
              ]
            }
          ],
          "volumes": [
            {
              "name": "data",
              "persistentVolumeClaim": {
                "claimName": "immich-postgres"
              }
            }
          ]
        }
      }
    }
  } satisfies Deployment,
  {
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
      "name": "redis",
      "namespace": "tenant-a"
    },
    "spec": {
      "selector": {
        "matchLabels": {
          "app": "redis"
        }
      },
      "template": {
        "metadata": {
          "labels": {
            "app": "redis"
          }
        },
        "spec": {
          "containers": [
            {
              "image": "docker.io/valkey/valkey:9@sha256:c123e3715db63d06d4ad6964884037aa0d5d4d703939b9929954112889708e1d",
              "name": "redis",
              "ports": [
                {
                  "containerPort": 6379
                }
              ]
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
      "name": "immich-http",
      "namespace": "tenant-a"
    },
    "spec": {
      "ingress": [
        {
          "from": [
            {
              "namespaceSelector": {
                "matchLabels": {
                  "kubernetes.io/metadata.name": "ingress-system"
                }
              }
            }
          ],
          "ports": [
            {
              "port": 2283,
              "protocol": "TCP"
            }
          ]
        }
      ],
      "podSelector": {
        "matchLabels": {
          "app": "immich"
        }
      },
      "policyTypes": [
        "Ingress"
      ]
    }
  } satisfies NetworkPolicy,
  {
    "apiVersion": "networking.k8s.io/v1",
    "kind": "NetworkPolicy",
    "metadata": {
      "name": "ml-downloads",
      "namespace": "tenant-a"
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
      "podSelector": {
        "matchLabels": {
          "app": "immich-ml"
        }
      },
      "policyTypes": [
        "Egress"
      ]
    }
  } satisfies NetworkPolicy,
];
