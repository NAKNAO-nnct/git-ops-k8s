import type { Namespace, NetworkPolicy, Resource } from './types';

export function tenantResources(tenant: string): Resource[] {
  const namespace = {
    apiVersion: 'v1',
    kind: 'Namespace',
    metadata: {
      name: tenant,
      labels: { 'platform.example/tenant': tenant },
    },
  } satisfies Namespace;

  const defaultDeny = {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'NetworkPolicy',
    metadata: { name: 'default-deny', namespace: tenant },
    spec: { podSelector: {}, policyTypes: ['Ingress', 'Egress'] },
  } satisfies NetworkPolicy;

  const tenantAndDns = {
    apiVersion: 'networking.k8s.io/v1',
    kind: 'NetworkPolicy',
    metadata: { name: 'same-tenant-and-dns', namespace: tenant },
    spec: {
      podSelector: {},
      policyTypes: ['Ingress', 'Egress'],
      ingress: [{ from: [{ podSelector: {} }] }],
      egress: [
        { to: [{ podSelector: {} }] },
        {
          to: [{
            namespaceSelector: { matchLabels: { 'kubernetes.io/metadata.name': 'kube-system' } },
            podSelector: { matchLabels: { 'k8s-app': 'kube-dns' } },
          }],
          ports: [{ protocol: 'UDP', port: 53 }, { protocol: 'TCP', port: 53 }],
        },
      ],
    },
  } satisfies NetworkPolicy;

  return [namespace, defaultDeny, tenantAndDns];
}
