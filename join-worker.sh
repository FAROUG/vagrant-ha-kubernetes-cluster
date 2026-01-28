#!/bin/bash
echo "======================================================"
echo "Running WORKER NODE setup script..."
echo "This is where you would install the K8s Worker services (kubeadm join)"
echo "Node-specific configuration applied." > /etc/k8s_node_status.txt
echo "======================================================"
echo "--- WORKER: Waiting for the master to initialize and generate join command ---"
echo "--- WORKER: Waiting for the worker join command ---"

# Define the reuired user and the current user
REQUIRED_USER="vagrant"
CURRENT_USER=$(id -u -n)
K8S_SHARE_DIR="/vagrant/cluster_data"

# Wait up to 300 seconds for the join command file to appear
TIMEOUT=300
while [ ! -f $K8S_SHARE_DIR/join_cmd_worker.sh ] && [ $TIMEOUT -gt 0 ]; do
  sleep 5
  TIMEOUT=$((TIMEOUT - 5))
done
if [ -f $K8S_SHARE_DIR/join_cmd_worker.sh ]; then
    echo "--- WORKER: Join command found. Executing now ---"
    # Execute the command sourced from the master script
    # In a real setup, you use 'sudo sh /vagrant/cluster_data/join_cmd_worker.sh'
      sh $K8S_SHARE_DIR/join_cmd_worker.sh 
    echo "--- WORKER: Kubeadm join command executed ---"
else
    echo "--- WORKER: Timeout waiting for master join command! Cluster join failed. ---"
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

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Ran WORKER NODE setup script"