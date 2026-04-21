# Proposal: VMPodIP Route Advertisement

## Problem

When advertising UDN pod networks via BGP on AWS (ROSA), traffic for the entire CUDN subnet (`10.100.0.0/16`) routes through a **single worker node** due to AWS VPC route table limitations (one next-hop per prefix). This creates:

- **Throughput bottleneck** — all external ingress funnels through one node
- **Double-hop latency** — traffic hits the active worker, then Geneve-tunnels to the actual destination node
- **Poor scaling** — adding workers doesn't improve inbound capacity

On-premise deployments don't have this problem because physical routers support ECMP.

## Proposed Solution

Add a new `VMPodIP` advertisement type to `RouteAdvertisements`. OVN-Kubernetes would advertise individual VM pod IPs as `/32` routes, each pointing to the node where the VM runs.

### User-Facing API

```yaml
apiVersion: k8s.ovn.org/v1
kind: RouteAdvertisements
metadata:
  name: advertise-vm-ips
spec:
  nodeSelector: {}
  frrConfigurationSelector: {}
  networkSelectors:
    - networkSelectionType: ClusterUserDefinedNetworks
      clusterUserDefinedNetworkSelector:
        networkSelector:
          matchLabels:
            advertise: "true"
  advertisements:
    - "VMPodIP"
```

### Behavior

| Current (PodNetwork) | Proposed (VMPodIP) |
|---|---|
| Advertises `10.100.0.0/16` | Advertises `10.100.0.5/32`, `10.100.0.9/32`, ... |
| Single next-hop (one worker) | Per-VM next-hop (distributed across workers) |
| Traffic → active worker → Geneve → destination | Traffic → destination node directly |
| All VMs share one ingress path | Each VM has its own ingress path |

### Why This Works

1. **VPC route tables support multiple `/32` entries** — each VM IP is a different prefix, so each gets its own next-hop. No ECMP needed.

2. **VM IPs are stable** — UDN with `lifecycle: Persistent` ensures IPs survive restarts. No route churn.

3. **Live migration handled** — OVN-Kubernetes already tracks KubeVirt live migration. On migration: withdraw `/32` from source node, advertise from target node.

4. **Scales within AWS limits** — 5 Route Servers × 100 routes/FIB = 500 VMs with direct routing. Sufficient for most deployments.

## Implementation

OVN-Kubernetes already has the building blocks:

| Capability | Existing Code |
|---|---|
| Detect VM pods | `kubevirt.IsPodOwnedByVirtualMachine()` |
| Get pod IPs per node | Pod annotation handling |
| Write `/32` prefixes to FRRConfiguration | EgressIP advertisement logic |
| Handle IP migration between nodes | EgressIP + KubeVirt live migration support |

Changes needed:

1. Add `VMPodIP` to `AdvertisementType` enum in `types.go`
2. Add gathering logic in `routeadvertisements/controller.go`:
   - For selected CUDNs, find pods owned by VirtualMachines
   - Group by node
   - Write `/32` prefixes to each node's FRRConfiguration
3. Reconcile on pod create/delete/migration events

No changes to frr-k8s — it just sees additional prefixes.

## Scope

- **In scope**: KubeVirt VMs on Layer2 UDNs with persistent IPs
- **Out of scope**: Regular pods (ephemeral IPs cause route churn), Layer3 UDNs, non-KubeVirt workloads
