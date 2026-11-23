# Cilium bootstrap

The K3s configuration disables Flannel and K3s' built-in network policy controller. Install Cilium before deploying workloads. Nodes remain `NotReady` until a CNI is installed.

## Network design

- K3s node IPs, embedded-etcd traffic, the API VIP, and Cilium's VXLAN underlay use the internal Ceph network (`vmbr0`, `172.26.26.0/24`).
- The default route remains on `vmbr1` (`172.26.27.0/24`) for outbound traffic.
- The API VIP is internal-only (`172.26.26.206` in the proposed address plan). Do not expose TCP 6443 to the Internet.
- Allow UDP 8472 between K3s node IPs on `vmbr0`. Cilium uses VXLAN for cross-node pod traffic.
- K3s defaults to Pod CIDR `10.42.0.0/16` and Service CIDR `10.43.0.0/16`. Check for overlap with routed home and VPN networks before installation.

## Install

After applying the K3s VMs, set `CILIUM_VERSION` to a Cilium release compatible with the configured K3s/Kubernetes release. Confirm compatibility before installation; the K3s version is configured in `infrastructure/proxmox/k3s-cluster/variables.tf`.

Run the install on the initial K3s server, where the generated kubeconfig is available:

```sh
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
: "${CILIUM_VERSION:?Set a Cilium release compatible with the configured K3s version}"
cilium install \
  --version "$CILIUM_VERSION" \
  --set ipam.mode=kubernetes \
  --set routingMode=tunnel \
  --set tunnelProtocol=vxlan \
  --set kubeProxyReplacement=false
```

If installing from another administrative host, copy the kubeconfig securely and set its API server endpoint to `https://172.26.26.206:6443`. Kubernetes IPAM uses the Pod CIDRs assigned to nodes by K3s. K3s' kube-proxy remains enabled. Do not deploy tenant workloads until Cilium reports ready and all six nodes are `Ready`.

```sh
cilium status --wait
kubectl get nodes -o wide
cilium connectivity test
```

Confirm that every node's `InternalIP` is on `172.26.26.0/24`, cross-node pod traffic uses the internal network, and pod egress uses the default route on `vmbr1`. See the [network isolation notes](network.md) before enabling tenant workloads.
