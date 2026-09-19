# Kubernetes minor-version upgrade notes

This is a safe operational runbook for upgrading a kubeadm-managed control plane from one Kubernetes minor release to the next.

> Important: this is a runbook, not a standalone automation script. The original draft mixed shell commands with pasted certificate output, which should not be executed as shell commands.

## 1. Update the Kubernetes apt repository

Open the repository file:

```bash
sudo nano /etc/apt/sources.list.d/kubernetes.list
```

Update the URL from the current release to the next minor version. For example:

```bash
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /
```

becomes:

```bash
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /
```

Then refresh package metadata:

```bash
sudo apt update
sudo apt-cache madison kubeadm
```

## 2. Upgrade kubeadm

```bash
sudo apt-mark unhold kubeadm && \
sudo apt-get update && sudo apt-get install -y kubeadm='1.35.0-1.1' && \
sudo apt-mark hold kubeadm
kubeadm version

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.35.0
kubeadm version
```

## 3. Upgrade kubelet and kubectl

Replace the patch version as needed for the latest available package in the 1.35 release line:

```bash
sudo apt-mark unhold kubelet kubectl && \
sudo apt-get update && sudo apt-get install -y kubelet='1.35.0-1.1' kubectl='1.35.0-1.1' && \
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

## 4. Review certificate SANs (informational only)

The original draft included certificate subject-alt-name output for /etc/kubernetes/pki/etcd/server.crt. That content is not a command and should be treated as inspection output only.

Example format:

```text
DNS:controlplane
DNS:kubernetes
DNS:kubernetes.default
DNS:kubernetes.default.svc
DNS:kubernetes.default.svc.cluster.local
IP Address:172.20.0.1
IP Address:10.244.243.223
```

## Recommendation

- Keep this as a documentation note instead of a shell script.
- Run the command blocks on the control plane node only.
- Do not execute the pasted certificate output as commands.
- If you want automation, convert the commands into a proper script with error checks and a safe rollback plan.
