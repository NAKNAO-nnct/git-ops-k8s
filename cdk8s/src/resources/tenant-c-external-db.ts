import type { NetworkPolicy, Service, Resource } from '../types';

export const resources: Resource[] = [
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "mysql-external",
      "namespace": "tenant-c"
    },
    "spec": {
      "externalName": "tenant-c-db.example.invalid",
      "type": "ExternalName"
    }
  } satisfies Service,
  {
    "apiVersion": "networking.k8s.io/v1",
    "kind": "NetworkPolicy",
    "metadata": {
      "name": "allow-external-mysql",
      "namespace": "tenant-c"
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
                "cidr": "172.28.103.10/32"
              }
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
        "Egress"
      ]
    }
  } satisfies NetworkPolicy,
];
