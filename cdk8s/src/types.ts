import type { Deployment } from 'kubernetes-types/apps/v1';
import type {
  Namespace,
  PersistentVolume,
  PersistentVolumeClaim,
  Service,
  ServiceAccount,
} from 'kubernetes-types/core/v1';
import type { NetworkPolicy } from 'kubernetes-types/networking/v1';
import type { ClusterRole, ClusterRoleBinding } from 'kubernetes-types/rbac/v1';

export type {
  ClusterRole,
  ClusterRoleBinding,
  Deployment,
  Namespace,
  NetworkPolicy,
  PersistentVolume,
  PersistentVolumeClaim,
  Service,
  ServiceAccount,
};

export type Resource =
  | ClusterRole
  | ClusterRoleBinding
  | Deployment
  | Namespace
  | NetworkPolicy
  | PersistentVolume
  | PersistentVolumeClaim
  | Service
  | ServiceAccount;
