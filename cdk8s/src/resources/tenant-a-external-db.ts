import type { NetworkPolicy, Service, Resource } from '../types';

export const resources: Resource[] = [
  {
    "apiVersion": "v1",
    "kind": "Service",
    "metadata": {
      "name": "postgres-external",
      "namespace": "tenant-a"
    },
    "spec": {
      "externalName": "tenant-a-db.example.invalid",
      "type": "ExternalName"
    }
  } satisfies Service,
  {
    "apiVersion": "networking.k8s.io/v1",
    "kind": "NetworkPolicy",
    "metadata": {
      "name": "allow-external-postgres",
      "namespace": "tenant-a"
    },
    "spec": {
      "egress": [
        {
          "ports": [
            {
              "port": 5432,
              "protocol": "TCP"
            }
          ],
          "to": [
            {
              "ipBlock": {
                "cidr": "172.28.101.10/32"
              }
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
        "Egress"
      ]
    }
  } satisfies NetworkPolicy,
];
