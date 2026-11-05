import { App, ApiObject, Chart } from 'cdk8s';
import path from 'node:path';
import { tenantResources } from './common';
import { withExternalDb, type ExternalDbConfig } from './external-db';
import type { Resource } from './types';
import { resources as tenantA } from './resources/tenant-a';
import { resources as tenantB } from './resources/tenant-b';
import { resources as tenantC } from './resources/tenant-c';
import { resources as tenantD } from './resources/tenant-d';
import { resources as externalA } from './resources/tenant-a-external-db';
import { resources as externalC } from './resources/tenant-c-external-db';
import { resources as externalD } from './resources/tenant-d-external-db';
import { resources as admin } from './resources/admin';
import { resources as immichS3 } from './resources/immich-s3-pv';

const tenants: Record<string, Resource[]> = {
  'tenant-a': tenantA,
  'tenant-b': tenantB,
  'tenant-c': tenantC,
  'tenant-d': tenantD,
};

const external: Record<string, { additions: Resource[]; config: ExternalDbConfig }> = {
  'tenant-a': {
    additions: externalA,
    config: {
      dbDeployment: 'postgres', dbService: 'postgres', dbClaim: 'immich-postgres',
      appDeployment: 'immich', container: 'immich', envName: 'DB_HOSTNAME', host: 'postgres-external',
    },
  },
  'tenant-c': {
    additions: externalC,
    config: {
      dbDeployment: 'mysql', dbService: 'mysql', dbClaim: 'mysql-data',
      appDeployment: 'nextcloud', container: 'nextcloud', envName: 'MYSQL_HOST', host: 'mysql-external',
    },
  },
  'tenant-d': {
    additions: externalD,
    config: {
      dbDeployment: 'mysql', dbService: 'mysql', dbClaim: 'mysql-data',
      appDeployment: 'web', container: 'web', envName: 'MYSQL_HOST', host: 'mysql-external',
    },
  },
};

function synthChart(outdir: string, name: string, resources: Resource[]): void {
  const app = new App({ outdir: path.join(outdir, name) });
  const chart = new Chart(app, 'manifest');
  for (const resource of resources) {
    const { apiVersion, kind, metadata } = resource;
    if (!apiVersion || !kind || !metadata?.name) {
      throw new Error(`Resource in ${name} is missing apiVersion, kind or metadata.name`);
    }
    new ApiObject(chart, `${kind}-${metadata.name}`, {
      ...resource,
      apiVersion,
      kind,
      metadata,
    });
  }
  app.synth();
}

function synthArgo(outdir: string): void {
  const app = new App({ outdir: path.join(outdir, 'argocd') });
  const chart = new Chart(app, 'manifest');
  new ApiObject(chart, 'application-set', {
    apiVersion: 'argoproj.io/v1alpha1',
    kind: 'ApplicationSet',
    metadata: { name: 'tenant-samples', namespace: 'argocd' },
    spec: {
      generators: [{
        list: {
          elements: Object.keys(tenants).map((name) => ({
            name,
            path: `kubernetes/dist/${name}`,
          })),
        },
      }],
      template: {
        metadata: { name: '{{name}}' },
        spec: {
          project: 'default',
          source: {
            repoURL: 'https://example.invalid/replace-with-your-repository.git',
            targetRevision: 'main',
            path: '{{path}}',
          },
          destination: {
            server: 'https://kubernetes.default.svc',
            namespace: '{{name}}',
          },
        },
      },
    },
  });
  app.synth();
}

export function synth(outdir: string): void {
  for (const [name, resources] of Object.entries(tenants)) {
    const all = [...tenantResources(name), ...resources];
    synthChart(outdir, name, all);
    const ext = external[name];
    if (ext) synthChart(outdir, `${name}-external-db`, withExternalDb(all, ext.additions, ext.config));
  }
  synthChart(outdir, 'admin', admin);
  synthChart(outdir, 'immich-s3-pv', immichS3);
  synthArgo(outdir);
}
