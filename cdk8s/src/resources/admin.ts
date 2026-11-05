import type { ClusterRole, ClusterRoleBinding, Deployment, Namespace, NetworkPolicy, Service, ServiceAccount, Resource } from '../types';

export const resources: Resource[] = [
  {
    "apiVersion": "v1",
    "kind": "Namespace",
    "metadata": {
      "name": "platform-admin"
    }
  } satisfies Namespace,
  {
    "apiVersion": "v1",
    "kind": "ServiceAccount",
    "metadata": {
      "name": "tenant-admin",
      "namespace": "platform-admin"
    }
  } satisfies ServiceAccount,
  {
    "apiVersion": "rbac.authorization.k8s.io/v1",
    "kind": "ClusterRole",
    "metadata": {
      "name": "tenant-admin"
    },
    "rules": [
      {
        "apiGroups": [
          ""
        ],
        "resources": [
          "namespaces"
        ],
        "verbs": [
          "get",
          "list",
          "create",
          "delete"
        ]
      },
      {
        "apiGroups": [
          "networking.k8s.io"
        ],
        "resources": [
          "networkpolicies"
        ],
        "verbs": [
          "create"
        ]
      }
    ]
  } satisfies ClusterRole,
  {
    "apiVersion": "rbac.authorization.k8s.io/v1",
    "kind": "ClusterRoleBinding",
    "metadata": {
      "name": "tenant-admin"
    },
    "roleRef": {
      "apiGroup": "rbac.authorization.k8s.io",
      "kind": "ClusterRole",
      "name": "tenant-admin"
    },
    "subjects": [
      {
        "kind": "ServiceAccount",
        "name": "tenant-admin",
        "namespace": "platform-admin"
      }
    ]
  } satisfies ClusterRoleBinding,
  {
    "apiVersion": "apps/v1",
    "kind": "Deployment",
    "metadata": {
      "name": "tenant-admin",
      "namespace": "platform-admin"
    },
    "spec": {
      "replicas": 1,
      "selector": {
        "matchLabels": {
          "app": "tenant-admin"
        }
      },
      "template": {
        "metadata": {
          "labels": {
            "app": "tenant-admin"
          }
        },
        "spec": {
          "serviceAccountName": "tenant-admin",
          "containers": [
            {
              "name": "admin",
              "image": "example.invalid/tenant-admin:0.1.0",
              "ports": [
                {
                  "containerPort": 8000
                }
              ],
              "env": [
                {
                  "name": "APP_ENV",
                  "value": "production"
                },
                {
                  "name": "APP_DEBUG",
                  "value": "false"
                },
                {
                  "name": "SESSION_DRIVER",
                  "value": "file"
                },
                {
                  "name": "CACHE_STORE",
                  "value": "file"
                },
                {
                  "name": "PLATFORM_WRITES_ENABLED",
                  "value": "false"
                },
                {
                  "name": "APP_KEY",
                  "valueFrom": {
                    "secretKeyRef": {
                      "name": "tenant-admin-auth",
                      "key": "app-key"
                    }
                  }
                },
                {
                  "name": "PLATFORM_ADMIN_USER",
                  "valueFrom": {
                    "secretKeyRef": {
                      "name": "tenant-admin-auth",
                      "key": "username"
                    }
                  }
                },
                {
                  "name": "PLATFORM_ADMIN_PASSWORD_HASH",
                  "valueFrom": {
                    "secretKeyRef": {
                      "name": "tenant-admin-auth",
                      "key": "password-hash"
                    }
                  }
                }
              ],
              "readinessProbe": {
                "httpGet": {
                  "path": "/up",
                  "port": 8000
                }
              }
            }
          ]
        }
      }
    }
  } satisfies Deployment,
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "tenant-admin",
      "namespace": "platform-admin"
    },
    "spec": {
      "selector": {
        "app": "tenant-admin"
      },
      "ports": [
        {
          "port": 8000,
          "targetPort": 8000
        }
      ]
    }
  } satisfies Service,
  {
    "apiVersion": "networking.k8s.io/v1",
    "kind": "NetworkPolicy",
    "metadata": {
      "name": "deny-inbound",
      "namespace": "platform-admin"
    },
    "spec": {
      "podSelector": {},
      "policyTypes": [
        "Ingress"
      ]
    }
  } satisfies NetworkPolicy,
];
