#!/bin/bash
echo "======================================================"
echo "Running MASTER setup script..."
echo "This is where you would install K8s Control Plane (kubeadm init)"
echo "Master-specific configuration applied." > /etc/k8s_master_status.txt
echo "======================================================"

# Define the interface name
INTERFACE="enp0s8"
ENDPOINT_IP="192.168.1.100:6443" # The LB IP

# Define the reuired user and the current user
REQUIRED_USER="vagrant"
CURRENT_USER=$(id -u -n)
K8S_SHARE_DIR="/vagrant/cluster_data"

# Command to get only the IPv4 address for the specified interface
PRIVATE_IP=$(ip -4 addr show "$INTERFACE" | awk '/inet / {print $2}' | cut -d/ -f1)

if [ -n "$PRIVATE_IP" ]; then
    echo "The IP address for $INTERFACE is: $PRIVATE_IP"
else
    echo "Could not find an IPv4 address for interface $INTERFACE."
fi

echo "--- MASTER-1: Initializing Kubernetes Cluster ---"
sudo kubeadm init  --control-plane-endpoint=$ENDPOINT_IP --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$PRIVATE_IP --v=5

# Run the user-specific script as the 'vagrant' user
    # Note: Indent the EOF block commands ONLY if you want to use a 'tab', not spaces,
    # with the '<<-EOF' syntax. We will use no indentation within the block here for simplicity.
sudo -u "$REQUIRED_USER" /bin/bash <<EOF
# --- Commands running as the vagrant user ---
echo "Now running commands as user: \$(whoami)"
# Use the vagrant user's home directory path explicitly if needed, or rely on the environment switch
mkdir -p /home/\$(whoami)/.kube
mkdir -p $K8S_SHARE_DIR
# Use 'cp' without sudo, assuming the original script runner (root) has permission to read /etc/kubernetes/admin.conf
sudo cp -i /etc/kubernetes/admin.conf /home/\$(whoami)/.kube/config
# Change ownership of the copied file to the vagrant user (already the current user inside the EOF block)
sudo chown \$(id -u):\$(id -g) /home/\$(whoami)/.kube/config
# Set KUBECONFIG environment variable for commands within this block
export KUBECONFIG=/home/\$(whoami)/.kube/config
# Run kubectl commands
# Install Pod Network Add-on (Flannel)
# kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
# Install Pod Network Add-on (Calico)
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl get pods -A -o wide

# Local-path-provisioner - Installation
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.32/deploy/local-path-storage.yaml

# --- End of commands running as the vagrant user ---
EOF



# This command runs the 'kubeadm' program and saves the single line of output
# into the shell variable named JOIN_COMMAND_WORKER.
echo "--- MASTER: Running kubeadm init and capturing join command ---"
JOIN_COMMAND_WORKER=$(sudo kubeadm token create --print-join-command)

# This writes the content of that variable to a file in the shared directory.
echo "sudo $JOIN_COMMAND_WORKER" > $K8S_SHARE_DIR/join_cmd_worker.sh
echo "--- MASTER: Kubeadm join command saved to shared folder ---"


# This command executes the upload and captures the output
UPLOAD_OUTPUT=$(sudo kubeadm init phase upload-certs --upload-certs)

# Use 'echo' to pass the output to grep, and find the line that matches exactly 64 hex characters
CERT_KEY=$(echo "$UPLOAD_OUTPUT" | grep -oP '^[a-f0-9]{64}$')

# Capture the required certificate key for HA masters
# Check if the key was captured successfully
if [ -z "$CERT_KEY" ]; then
    echo "ERROR: Failed to capture the certificate key. Check kubeadm output."
    echo "$UPLOAD_OUTPUT" # Display the full output for debugging
    exit 1
fi

echo "Captured Cert Key: $CERT_KEY" 

# Create a fresh token for the control plane join command
TOKEN=$(sudo kubeadm token create)

# Manually construct the full control plane join command
API_SERVER_ENDPOINT=$(echo $JOIN_COMMAND_WORKER | awk '{print $3}')
CA_HASH=$(echo $JOIN_COMMAND_WORKER | grep -oP '(?=sha256:).*')

JOIN_CMD_MASTER="sudo kubeadm join $API_SERVER_ENDPOINT --token $TOKEN --discovery-token-ca-cert-hash $CA_HASH --control-plane --certificate-key $CERT_KEY --apiserver-advertise-address PRIVATEIP"
echo "$JOIN_CMD_MASTER" > $K8S_SHARE_DIR/join_cmd_master.sh

chmod +x $K8S_SHARE_DIR/join_cmd_worker.sh $K8S_SHARE_DIR/join_cmd_master.sh
echo "--- MASTER: Both join commands saved to shared folder and ready for use ---"

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# The rest of your script goes here (runs as the original user, root in your case)
echo "Script is running with the correct user: $CURRENT_USER"


# Helm package manager Installation
sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
sudo ./get_helm.sh
sudo helm version


# a. Installing Gateway API with NGINX
# What this does:
# Installs the NGINX Gateway Controller, along with the Gateway API Custom Resource Definitions (CRDs) and related resources.


# 1. Install Standard Channel
# kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/standard-install.yaml
# or
# kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v1.5.1" | kubectl apply -f -

# 2. Install Experimental Channel
# kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/experimental-install.yaml
# or 
# kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.1/deploy/crds.yaml
# 3. Deploy NGINX Gateway Fabric into a Kubernetes cluster using Helm package manager
# helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway
# or 
# kubectl apply -f https://raw.githubusercontent.com/nginx/nginx-gateway-fabric/v1.6.1/deploy/nodeport/deploy.yaml

# 4. Verify the Deployment
# kubectl get pods -n nginx-gateway
# 5. View the nginx-gateway service
# kubectl get svc -n nginx-gateway nginx-gateway -o yaml

# 6. Update the nginx-gateway service to expose ports 30080 for HTTP and 30081 for HTTPS
# kubectl patch svc nginx-gateway -n nginx-gateway --type='json' -p='[
#   {"op": "replace", "path": "/spec/ports/0/nodePort", "value": 30080},
#   {"op": "replace", "path": "/spec/ports/1/nodePort", "value": 30081}
# ]'



# b. GatewayClass Definition


# sudo ETCDCTL_API=3 etcdctl snapshot save snapshot.db --cacert=/etc/kubernetes/pki/etcd/ca.crt  --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key --endpoints=https://127.0.0.1:2379