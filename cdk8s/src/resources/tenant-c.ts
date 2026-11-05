import type { Deployment, NetworkPolicy, PersistentVolumeClaim, Service, Resource } from '../types';

export const resources: Resource[] = [
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "mysql",
      "namespace": "tenant-c"
    },
    "spec": {
      "ports": [
        {
          "port": 3306,
          "targetPort": 3306
        }
      ],
      "selector": {
        "app": "mysql"
      }
    }
  } satisfies Service,
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "nextcloud",
      "namespace": "tenant-c"
    },
    "spec": {
      "ports": [
        {
          "port": 80,
          "targetPort": 80
        }
      ],
      "selector": {
        "app": "nextcloud"
      }
    }
  } satisfies Service,
  {
    "apiVersion": "v1",
    "kind": "PersistentVolumeClaim",
    "metadata": {
      "name": "mysql-data",
      "namespace": "tenant-c"
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
    "apiVersion": "v1",
    "kind": "PersistentVolumeClaim",
    "metadata": {
      "name": "nextcloud-data",
      "namespace": "tenant-c"
    },
    "spec": {
      "accessModes": [
        "ReadWriteOnce"
      ],
      "resources": {
        "requests": {
          "storage": "30Gi"
        }
      },
      "storageClassName": "ceph-rbd"
    }
  } satisfies PersistentVolumeClaim,
  {
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
      "name": "mysql",
      "namespace": "tenant-c"
    },
    "spec": {
      "replicas": 1,
      "selector": {
        "matchLabels": {
          "app": "mysql"
        }
      },
      "strategy": {
        "type": "Recreate"
      },
      "template": {
        "metadata": {
          "labels": {
            "app": "mysql"
          }
        },
        "spec": {
          "containers": [
            {
              "args": [
                "--transaction-isolation=READ-COMMITTED"
              ],
              "env": [
                {
                  "name": "MYSQL_DATABASE",
                  "value": "nextcloud"
                },
                {
                  "name": "MYSQL_USER",
                  "value": "nextcloud"
                },
                {
                  "name": "MYSQL_PASSWORD",
                  "valueFrom": {
                    "secretKeyRef": {
                      "key": "password",
                      "name": "mysql-credentials"
                    }
                  }
                },
                {
                  "name": "MYSQL_ROOT_PASSWORD",
                  "valueFrom": {
                    "secretKeyRef": {
                      "key": "root-password",
                      "name": "mysql-credentials"
                    }
                  }
                }
              ],
              "image": "mysql:8.4",
              "name": "mysql",
              "ports": [
                {
                  "containerPort": 3306
                }
              ],
              "volumeMounts": [
                {
                  "mountPath": "/var/lib/mysql",
                  "name": "data"
                }
              ]
            }
          ],
          "volumes": [
            {
              "name": "data",
              "persistentVolumeClaim": {
                "claimName": "mysql-data"
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
      "name": "nextcloud",
      "namespace": "tenant-c"
    },
    "spec": {
      "replicas": 1,
      "selector": {
        "matchLabels": {
          "app": "nextcloud"
        }
      },
      "strategy": {
        "type": "Recreate"
      },
      "template": {
        "metadata": {
          "labels": {
            "app": "nextcloud"
          }
        },
        "spec": {
          "containers": [
            {
              "env": [
                {
                  "name": "MYSQL_HOST",
                  "value": "mysql"
                },
                {
                  "name": "MYSQL_DATABASE",
                  "value": "nextcloud"
                },
                {
                  "name": "MYSQL_USER",
                  "value": "nextcloud"
                },
                {
                  "name": "MYSQL_PASSWORD",
                  "valueFrom": {
                    "secretKeyRef": {
                      "key": "password",
                      "name": "mysql-credentials"
                    }
                  }
                },
                {
                  "name": "NEXTCLOUD_ADMIN_USER",
                  "valueFrom": {
                    "secretKeyRef": {
                      "key": "username",
                      "name": "nextcloud-admin"
                    }
                  }
                },
                {
                  "name": "NEXTCLOUD_ADMIN_PASSWORD",
                  "valueFrom": {
                    "secretKeyRef": {
                      "key": "password",
                      "name": "nextcloud-admin"
                    }
                  }
                }
              ],
              "image": "nextcloud:31-apache",
              "name": "nextcloud",
              "ports": [
                {
                  "containerPort": 80
                }
              ],
              "volumeMounts": [
                {
                  "mountPath": "/var/www/html",
                  "name": "data"
                }
              ]
            }
          ],
          "volumes": [
            {
              "name": "data",
              "persistentVolumeClaim": {
                "claimName": "nextcloud-data"
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
      "name": "nextcloud-http",
      "namespace": "tenant-c"
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
              "port": 80,
              "protocol": "TCP"
            }
          ]
        }
      ],
      "podSelector": {
        "matchLabels": {
          "app": "nextcloud"
        }
      },
      "policyTypes": [
        "Ingress"
      ]
    }
  } satisfies NetworkPolicy,
];
