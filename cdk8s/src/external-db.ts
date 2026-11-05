import type { Deployment, Resource } from './types';

export interface ExternalDbConfig {
  dbDeployment: string;
  dbService: string;
  dbClaim: string;
  appDeployment: string;
  container: string;
  envName: string;
  host: string;
}

export function withExternalDb(
  resources: Resource[],
  additions: Resource[],
  config: ExternalDbConfig,
): Resource[] {
  const removed = new Set([
    `Deployment/${config.dbDeployment}`,
    `Service/${config.dbService}`,
    `PersistentVolumeClaim/${config.dbClaim}`,
  ]);
  const seen = new Set<string>();
  const remaining = resources.filter((resource) => {
    const key = `${resource.kind}/${resource.metadata?.name}`;
    if (!removed.has(key)) return true;
    seen.add(key);
    return false;
  });
  if (seen.size !== removed.size) {
    throw new Error(`Could not find all local database resources: ${[...removed].join(', ')}`);
  }

  let patched = false;
  const result = remaining.map((resource): Resource => {
    if (resource.kind !== 'Deployment' || resource.metadata?.name !== config.appDeployment) {
      return resource;
    }
    const podSpec = resource.spec?.template.spec;
    if (!resource.spec || !podSpec) throw new Error(`Missing pod spec for ${config.appDeployment}`);
    const container = podSpec.containers.find((item) => item.name === config.container);
    if (!container?.env?.some((item) => item.name === config.envName)) {
      throw new Error(`Missing ${config.envName} in ${config.appDeployment}/${config.container}`);
    }
    const updated: Deployment = {
      ...resource,
      spec: {
        ...resource.spec,
        template: {
          ...resource.spec.template,
          spec: {
            ...podSpec,
            containers: podSpec.containers.map((item) => item.name !== config.container ? item : {
              ...item,
              env: item.env?.map((env) => env.name !== config.envName ? env : {
                ...env,
                value: config.host,
              }),
            }),
          },
        },
      },
    };
    patched = true;
    return updated;
  });
  if (!patched) throw new Error(`Could not find deployment ${config.appDeployment}`);
  return [...result, ...additions];
}
