import type { NetworkPolicy, Service, Resource } from '../types';

export const resources: Resource[] = [
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "mysql-external",
      "namespace": "tenant-d"
    },
    "spec": {
      "externalName": "tenant-d-db.example.invalid",
      "type": "ExternalName"
    }
  } satisfies Service,
  {
    "apiVersion": "networking.k8s.io/v1",
    "kind": "NetworkPolicy",
    "metadata": {
      "name": "allow-external-mysql",
      "namespace": "tenant-d"
    },
    "spec": {
      "egress": [
        {
          "ports": [
            {
              "port": 3306,
              "protocol": "TCP"
            }
          ],
          "to": [
            {
              "ipBlock": {
                "cidr": "172.28.104.10/32"
              }
            }
          ]
        }
      ],
      "podSelector": {
        "matchLabels": {
          "app": "web"
        }
      },
      "policyTypes": [
        "Egress"
      ]
    }
  } satisfies NetworkPolicy,
];
