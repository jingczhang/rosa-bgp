# Open Issues and Solutions

## Table of Contents

- [1. Overview](#1-overview)
- [2. Open Issues and Solutions](#2-open-issues-and-solutions)

---

## 1. Overview

The [rosa-bgp PoC](https://github.com/msemanrh/rosa-bgp) establishes L3 direct routing between OpenShift (ROSA HCP) Pod networks and AWS VPC networks. It uses BGP via AWS VPC Route Server so that KubeVirt VMs receive routable Pod IPs — no NAT, no tunnels.

The overall solution has two layers. There are a few potential issues in the first layer.

```
┌──────────────────────────────────────────────────────────────────────┐
│  AWS Infrastructure (Terraform)                                      │
│                                                                      │
│  VPC1 (ROSA) ─── TGW ─── VPC2 (External)                             │
│  ├── 3 private + 3 public subnets per VPC                            │
│  ├── ROSA HCP cluster + machine pools (bgp_router=true)              │
│  ├── VPC Route Server + 6 endpoints (2 per AZ)                       │
│  ├── Route Server peers (one per router node)                        │
│  ├── Disable src/dst check on bgp_router nodes                       │
│  └── NAT GW, IGW, TGW attachments, route propagation                 │
│                                                                      │
│  Terraform outputs: RS endpoint IPs, RS ASN, local BGP ASN           │
└──────────────────────────────────┬───────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│  In-Cluster (shell scripts and oc apply steps)                       │
└──────────────────────────────────────────────────────────────────────┘
```

## 2. Open Issues and Solutions

### Node replacement breaks BGP and data plane
Two things break when a ROSA worker node is replaced and gets a new private IP:

1. **Route Server peer configuration becomes stale.** Each `aws_vpc_route_server_peer` is configured with the worker node's private IP at apply time. When a node is replaced, the new node gets a different IP, but the Route Server still expects BGP from the old IP. The new node cannot establish a BGP session because no peer entry exists for its address.
2. **`SourceDestCheck` reverts to enabled.** The `disable_src_dst_check.sh` script runs once via `null_resource` with no triggers. The new node's ENI defaults to `SourceDestCheck=true` and silently drops all CUDN pod traffic.

**Solution:**
Both are fixed by running `terraform apply` immediately after a node replacement event (upgrade, spot termination, scaling).

For **stale peers**, the `data.external` lookup re-discovers the new node's private IP and Terraform updates the `aws_vpc_route_server_peer` resources accordingly.

For **src/dst check**, the `null_resource` uses `triggers` tied to the router node IPs — when any IP changes, Terraform recreates the resource and re-runs the script. The script previously hardcoded `AWS_REGION="eu-central-1"`, which would silently skip instances when deploying to a different region. This has been fixed: `var.aws_region` is now passed as a command-line argument to the script.

> **Important:** Between the node replacement and `terraform apply`, BGP peering is down for that AZ and CUDN traffic through the replaced node is dropped. Run `terraform apply` as soon as possible after any node change event.

The same `terraform apply` also covers **adding a new node** to an existing pool — `data.external` picks up the new instance and both the Route Server peer and src/dst check are applied automatically.

### BFD is not working
The PoC falls back to `bgp-keepalive` for peer liveness detection because BFD was not validated with AWS VPC Route Server. The peering is single-hop (RS endpoints and worker nodes are in the same subnet) and security groups (`rosa_rfc1918_sg` and `rosa_allow_from_all_sg`) are wide open, so the most likely explanation is that AWS VPC Route Server version used does not support BFD on its endpoints.

With default BGP keepalive (60s interval, 180s hold time), peer failure detection takes up to 3 minutes. BFD detects failures in subsecond to low-second range (typical: 300ms x 3 = ~1s). In practice, the impact of the slower BGP-only detection depends on application tolerance — TCP retransmissions and application-level retries may absorb a few minutes of path loss without user-visible outage, making this a reliability improvement rather than a hard requirement for most workloads.
