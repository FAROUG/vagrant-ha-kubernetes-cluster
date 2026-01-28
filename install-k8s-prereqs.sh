#!/bin/bash
echo "======================================================"
echo "Running COMMON setup script for all nodes..."
echo "This is where you would install Docker, disable swap, etc."
echo "Universal configuration applied." > /etc/k8s_common_status.txt
echo "======================================================"

REQUIRED_USER="vagrant"
CURRENT_USER=$(id -u -n)
KUBERNETES_VERSION=v1.28
# REQUIRED_USER="vagrant"
# CURRENT_USER=$(id -u -n)

echo "Script is running with the user: $CURRENT_USER"

# Update system
sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Disable swap (Kubernetes requirement)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
sudo sed -i '/\sswap\s/s/^/#/' /etc/fstab

# Enable required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set system parameters
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

# Install container runtime (containerd is recommended)
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y containerd net-tools

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo mkdir -p /etc/cni/net.d
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Kubernetes repo
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates gnupg curl gpg lsb-release
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Install kubeadm, kubelet, kubectl
sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# Update the sandbox (pause) image version
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.9"|g' /etc/containerd/config.toml || true

# Enable SystemdCgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml || true

# Create the systemd override properly
sudo mkdir -p /etc/systemd/system/containerd.service.d
sudo tee /etc/systemd/system/containerd.service.d/override.conf > /dev/null <<EOF
[Service]
# Ensure the containerd socket permissions are handled correctly by the service
SupplementaryGroups=containerd
ExecStartPost=/usr/bin/chown root:containerd /run/containerd/containerd.sock

# Enhance security by protecting critical system directories
ProtectSystem=full

# Prevents the service from writing to user home directories
ProtectHome=true

# Isolate temporary files from the rest of the system
PrivateTmp=true

# Prevent privilege escalation
NoNewPrivileges=true

# Restart the service on failure for better reliability
Restart=on-failure

# Wait 10 seconds before attempting a restart
RestartSec=10

# Increase the file descriptor limit for I/O-heavy workloads
LimitNOFILE=1048576
EOF


# Create a proper config file that define the runtime endpoint
sudo tee /etc/crictl.yaml > /dev/null <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Create a containerd group and grant access
sudo groupadd containerd
sudo chown root:containerd /run/containerd/containerd.sock
sudo chmod 660 /run/containerd/containerd.sock
#!/bin/bash

if [ "$CURRENT_USER" != "$REQUIRED_USER" ]; then
    echo "Error: This script must be run as the user $REQUIRED_USER."
    echo "Current user is $CURRENT_USER."
    sudo usermod -aG containerd $REQUIRED_USER
    # exit 1
fi

# The rest of your script goes here
echo "Script is running with the correct user: $CURRENT_USER"
sudo chgrp containerd /run/containerd/containerd.sock

# Reload and restart systemd 
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart containerd
sudo systemctl restart kubelet.service


newgrp containerd

ls -ltrh /run/containerd/containerd.sock
crictl version

# Ensure the bash-completion package is installed system-wide
sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y bash-completion


echo "--- COMMON: Prereqs done ---"