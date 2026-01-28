#! /bin/bash

# Install the etcdctl client
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y etcd-client
sudo mkdir -p /backup
# Set environment variables for authentication using kubeadm certs
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379 
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key

# Get the etcdctl version
etcdctl version

# List cluster members
etcdctl member list \
 --write-out=table

# Get cluster health status
etcdctl endpoint health \
 --write-out=table

# Perform backup of the etcd
etcdctl \
 snapshot save /backup/snapshot.db

etcdctl \
 snapshot save /backup/snapshot-1.db


 etcdctl \
 snapshot save /opt/snapshot-pre-boot.db


# Get the etcd snapshot status
etcdctl \
 snapshot status /backup/snapshot.db \
 --write-out=table

etcdctl \
 snapshot status /opt/snapshot-pre-boot.db \
 --write-out=table

# Stop The API service (Kubeadm)
sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

# Stop The etcd service (Kubeadm)
sudo mv /etc/kubernetes/manifests/etcd.yaml /tmp/

# 3. Modify etcd.yaml to point to the new data directory AND set the initial-cluster-state to 'new'
# You correctly changed the data-dir, but the 'initial-cluster-state' must also be updated
sudo sed -i 's|--data-dir=/var/lib/etcd|--data-dir=/var/lib/etcd-from-backup|g' /etc/kubernetes/manifests/etcd.yaml
sudo sed -i 's|--data-dir=/var/lib/etcd|--data-dir=/var/lib/etcd-from-backup|g' /tmp/etcd.yaml
sudo sed -i '/- --initial-cluster-state=existing/a\    - --initial-cluster-state=new' /etc/kubernetes/manifests/etcd.yaml 


# Stop the kubelet on the first master
systemctl stop kubelet

# check the kubelet service status
systemctl status kubelet

# Restore a snapshot to a new data directory:
etcdctl snapshot restore /backup/snapshot-1.db \
  --data-dir /var/lib/etcd-from-backup

etcdctl snapshot restore /opt/snapshot-pre-boot.db \
  --data-dir /var/lib/etcd-from-backup

# Run The API service (Kubeadm)
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
# Run The etcd service (Kubeadm)
sudo mv /tmp/etcd.yaml /etc/kubernetes/manifests/etcd.yaml

# Start the kubelet on all the first master
systemctl daemon-reload
sudo systemctl start kubelet

# check the kubelet service status
systemctl status kubelet




# On k8s-master-2

# 1. Ensure services are stopped (from Phase 1)
# sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/
# sudo systemctl stop kubelet

# 2. Clean up old etcd data
sudo rm -rf /var/lib/etcd/* /etc/kubernetes/pki/etcd/*

# 3. Use kubeadm to re-initialize this node as a JOINING control plane member. 
# This requires the original `kubeadm join` command used to set up the cluster initially.
# It should look similar to this (you may need to get the exact command from your setup logs):
# This command runs the 'kubeadm' program and saves the single line of output
# into the shell variable named JOIN_COMMAND_WORKER.
K8S_SHARE_DIR="/vagrant/cluster_data"
echo "--- MASTER: Running kubeadm init and capturing join command ---"
JOIN_COMMAND_WORKER=$(sudo kubeadm token create --print-join-command)

# This writes the content of that variable to a file in the shared directory.
echo "sudo $JOIN_COMMAND_WORKER" > $K8S_SHARE_DIR/join_cmd_restored_worker.sh
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

JOIN_CMD_MASTER="sudo kubeadm join $API_SERVER_ENDPOINT --token $TOKEN --discovery-token-ca-cert-hash $CA_HASH --control-plane --certificate-key $CERT_KEY"
echo "$JOIN_CMD_MASTER" > $K8S_SHARE_DIR/join_cmd_restored_master.sh

chmod +x $K8S_SHARE_DIR/join_cmd_worker.sh $K8S_SHARE_DIR/join_cmd_restored_master.sh
echo "--- MASTER: Both join commands saved to shared folder and ready for use ---"


# sudo kubeadm join 192.168.1.100:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash> --control-plane 

# This command handles certificate syncing and etcd joining automatically.

# 4. Move the apiserver manifest back to restart services
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml




# Using etcdutl (File-based Backup)
# For offline file-level backup of the data directory:

etcdutl backup \
  --data-dir /var/lib/etcd \
  --backup-dir /backup/etcd-backup

#   This copies the etcd backend database and WAL files to the target location.


# Restoring ETCD
# Using etcdutl
# To restore a snapshot to a new data directory:

etcdutl snapshot restore /backup/etcd-snapshot.db \
  --data-dir /var/lib/etcd-restored

# To use a backup made with etcdutl backup, simply copy the backup contents back into /var/lib/etcd and restart etcd.

etcdutl snapshot restore # is used to restore a .db snapshot file.

etcdutl backup # performs a raw file-level copy of etcd’s data and WAL files without needing etcd to be running.








# etcd-2.yaml :
    location: /var/lib/etcd-from-second-backup
    restored: /backup/snapshot-2.db 
    pods :
        1. nginx-deployment-86dcfdf4c6
        2. nginx-deployment-1-86dcfdf4c6
        3. nginx-deployment-2-86dcfdf4c6
        4. nginx-deployment-3-86dcfdf4c6

        etcdctl snapshot restore /backup/snapshot-2.db \
  --data-dir /var/lib/etcd-from-second-backup


# etcd-1.yaml :
    location: /var/lib/etcd-from-backup
    restored: /backup/snapshot-1.db 
    pods :
        1. nginx-deployment-86dcfdf4c6
        2. nginx-deployment-1-86dcfdf4c6
        3. nginx-deployment-2-86dcfdf4c6


        etcdctl snapshot restore /backup/snapshot-1.db \
  --data-dir /var/lib/etcd-from-backup

# etcd.yaml :
    location: /var/lib/etcd
    restored: /backup/snapshot.db 
    pods :
        1. nginx-deployment-86dcfdf4c6
        2. nginx-deployment-1-86dcfdf4c6

        etcdctl snapshot restore /backup/snapshot.db \
  --data-dir /var/lib/etcd