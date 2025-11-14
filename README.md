# 🧩 Highly Available Kubernetes Cluster using Vagrant & VirtualBox

This repository automates the provisioning of a **Highly Available Kubernetes (K8s) Cluster** using **Vagrant** and **VirtualBox**, designed for local development, testing, and learning.  
The setup dynamically provisions **multiple master and worker nodes**, all connected via a **bridged Wi-Fi network**, and includes an **HAProxy load balancer** to ensure control-plane high availability.

---

## 🌐 Architecture Overview

                                     ┌────────────────────────────┐
                                     │        Host Machine        │
                                     │   (Vagrant + VirtualBox)   │
                                     └────────────┬───────────────┘
                                                  │
                                                  ▼
                                         ┌───────────────────┐
                                         │    HAProxy (LB)   │
                                         │   192.168.1.100   │
                                         │ Routes API traffic│
                                         │   to all masters  │
                                         └────────┬──────────┘
                                                  │
                           ┌──────────────────────┼────────────────────────┐
                           ▼                      ▼                        ▼
                    ┌────────────────┐      ┌────────────────┐       ┌────────────┐
                    │   Master #1    │      │   Master #2    │  ...  │  Master #N │
                    │ 192.168.1.101  │      │ 192.168.1.102  │       │    ...     │
                    │ Runs etcd + API│      │ Runs etcd + API│       │    ...     │
                    └────────────────┘      └────────────────┘       └────────────┘
                            │                     │                       │
                            └──────────────┬──────┴───────────────────────┘
                                           │
                                           ▼
                            ┌────────────────────────────┐
                            │        Worker Nodes        │
                            │ (192.168.1.121, .122, …)   │
                            │ Run Pods & Deployments     │
                            └────────────────────────────┘
---

## ⚙️ Features

- 🧠 **Dynamic Scaling** — Control the number of masters and workers via variables in the `Vagrantfile`
- 🔁 **Highly Available Control Plane** — HAProxy load balancer distributes API requests to all masters
- 🛰️ **Bridged Wi-Fi Networking** — Each node is accessible on your local LAN (via `en0: Wi-Fi`)
- 🧩 **Automated Provisioning** — Each VM installs prerequisites, configures hosts, and joins the cluster automatically
- 📂 **Shared Folder Integration** — Join tokens and scripts are stored and shared through `/vagrant/cluster_data`
- 🧱 **Four Modular Shell Scripts:**
  1. `install-k8s-prereqs.sh` — Installs Docker, kubeadm, kubelet, configures hostnames and networking
  2. `init-cluster.sh` — Initializes the Kubernetes cluster on the first master node
  3. `join-manager.sh` — Joins additional masters to the control plane
  4. `join-worker.sh` — Joins worker nodes to the cluster

---

## 🧩 Vagrant Setup Details

### Main Variables in `Vagrantfile`
| Variable | Description | Example |
|-----------|--------------|----------|
| `NUM_MASTERS` | Number of master nodes | `2` |
| `NUM_WORKERS` | Number of worker nodes | `2` |
| `IP_SUBNET_BASE` | Subnet for the bridged network | `192.168.1` |
| `BRIDGE_INTERFACE` | Your Wi-Fi adapter name | `"en0: Wi-Fi"` |
| `MASTER_START_IP` | Starting IP for masters | `101` → creates `.101`, `.102`, etc. |
| `WORKER_START_IP` | Starting IP for workers | `121` → creates `.121`, `.122`, etc. |

### Default Network Example
| Node Type | Hostname | IP Address |
|------------|-----------|------------|
| Load Balancer | `k8s-lb` | `192.168.1.100` |
| Master 1 | `k8s-master-1` | `192.168.1.101` |
| Master 2 | `k8s-master-2` | `192.168.1.102` |
| Worker 1 | `k8s-worker-1` | `192.168.1.121` |
| Worker 2 | `k8s-worker-2` | `192.168.1.122` |

---

## 🚀 How to Use

### 1️⃣ Prerequisites
- [Vagrant](https://www.vagrantup.com/downloads)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- Unix/macOS terminal environment

### 2️⃣ Clone the Repository
```bash
git clone https://github.com/FAROUG/vagrant-ha-kubernetes-cluster.git
cd vagrant-ha-kubernetes-cluster
```
### 3️⃣ Adjust Configuration

``` Edit the Vagrantfile to set:
NUM_MASTERS = 3
NUM_WORKERS = 2
IP_SUBNET_BASE = "192.168.1"
BRIDGE_INTERFACE = "en0: Wi-Fi"
```

### 4️⃣ Bring Up the Cluster
```
vagrant up
```

#### This will automatically:

- Provision the load balancer

- Create and initialize the first master node

- Join additional masters

- Join worker nodes to the cluster

### 5️⃣ Verify Cluster Status

SSH into the first master node:
```
vagrant ssh k8s-master-1
```