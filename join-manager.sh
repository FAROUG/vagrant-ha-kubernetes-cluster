#!/bin/bash
echo "======================================================"
echo "Running MANAGER NODE setup script..."
echo "This is where you would install the K8s Manager services (kubeadm join)"
echo "Node-specific configuration applied." > /etc/k8s_manager_node_status.txt
echo "======================================================"
echo "--- SECONDARY MASTER: Waiting for the control plane join command ---"

# Define the reuired user and the current user
REQUIRED_USER="vagrant"
CURRENT_USER=$(id -u -n)
K8S_SHARE_DIR="/vagrant/cluster_data"

# Wait for the master join command file to appear
TIMEOUT=300
while [ ! -f $K8S_SHARE_DIR/join_cmd_master.sh ] && [ $TIMEOUT -gt 0 ]; do
  sleep 5
  TIMEOUT=$((TIMEOUT - 5))
done

if [ -f $K8S_SHARE_DIR/join_cmd_master.sh ]; then
  echo "--- SECONDARY MASTER: Control Plane join command found. Executing now ---"
  # Execute the command found in the file
  sh $K8S_SHARE_DIR/join_cmd_master.sh 
  echo "--- SECONDARY MASTER: Kubeadm join executed ---"
else
  echo "--- SECONDARY MASTER: Timeout waiting for master join command! Cluster join failed. ---"
  exit 1
fi

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
kubectl get pods -A -o wide
# --- End of commands running as the vagrant user ---
EOF


# The rest of your script goes here (runs as the original user, root in your case)
echo "Script is running with the correct user: $CURRENT_USER"
echo "Ran MANAGER NODE setup script"