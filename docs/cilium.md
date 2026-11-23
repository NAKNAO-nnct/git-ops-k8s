# Cilium bootstrap

The K3s configuration disables Flannel and K3s' built-in network policy controller. Install Cilium before deploying workloads. Nodes remain `NotReady` until a CNI is installed.

## Network design

- K3s node IPs, embedded-etcd traffic, the API VIP, and Cilium's VXLAN underlay use the internal Ceph network (`vmbr0`, `172.26.26.0/24`).
- The default route remains on `vmbr1` (`172.26.27.0/24`) for outbound traffic.
- The API VIP is internal-only (`172.26.26.206` in the proposed address plan). Do not expose TCP 6443 to the Internet.
- Allow UDP 8472 between K3s node IPs on `vmbr0`. Cilium uses VXLAN for cross-node pod traffic.
- K3s defaults to Pod CIDR `10.42.0.0/16` and Service CIDR `10.43.0.0/16`. Check for overlap with routed home and VPN networks before installation.

## Install

The pinned pair is K3s `v1.36.6+k3s1` (Kubernetes `v1.36.6`) and Cilium `1.20.5`. Cilium's compatibility table lists Kubernetes 1.36 as E2E tested. Recheck the [compatibility table](https://docs.cilium.io/en/stable/network/kubernetes/compatibility/) when upgrading either version.

Run the install on the initial K3s server, where the generated kubeconfig is available:

```sh
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
cilium install \
  --version 1.20.5 \
  --set k8sServiceHost=172.26.26.206 \
  --set k8sServicePort=6443 \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.42.0.0/16 \
  --set routingMode=tunnel \
  --set tunnelProtocol=vxlan \
  --set kubeProxyReplacement=false
```

K3s' generated kubeconfig uses `127.0.0.1`, which is not the API server address on worker nodes. Set `k8sServiceHost` to the internal API VIP so Cilium agents on every node can reach the control plane. If installing from another administrative host, copy the kubeconfig securely and set its API server endpoint to `https://172.26.26.206:6443`. Cilium's cluster pool is explicitly matched to K3s' default Pod CIDR (`10.42.0.0/16`). K3s' kube-proxy remains enabled. Do not deploy tenant workloads until Cilium reports ready and all six nodes are `Ready`.

```sh
cilium status --wait
kubectl get nodes -o wide
cilium connectivity test
```

Confirm that every node's `InternalIP` is on `172.26.26.0/24`, cross-node pod traffic uses the internal network, and pod egress uses the default route on `vmbr1`. See the [network isolation notes](network.md) before enabling tenant workloads.
