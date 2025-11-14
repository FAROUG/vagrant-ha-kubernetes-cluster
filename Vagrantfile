# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|

  # === CONFIGURATION VARIABLES (Modify these only) ===
  NUM_MASTERS = 2  # Best practice for HA is 3 or 5 masters
  NUM_WORKERS = 2  # Number of worker/data nodes
  IP_SUBNET_BASE = "192.168.1" # !! Match your Wi-Fi network subnet !!

  BASE_BOX = "bento/ubuntu-22.04" # e.g., "ubuntu/focal64"
  BRIDGE_INTERFACE = "en0: Wi-Fi" # Your specific Wi-Fi adapter

  # New variables for dynamic IP ranges:
  MASTER_START_IP  = 101 # Masters will be .101, .102, .103...
  WORKER_START_IP  = 121 # Workers will be .121, .122...
  LB_IP            = "192.168.1.100" # The stable Virtual IP for the API
  VM_NETWORK       = "public_network"
  # ====================================================


  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = BASE_BOX

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  #  config.vm.network "public_network",
  # use_dhcp_assigned_default_route: true

  # Define a subnet base for your static IPs.
  # !! IMPORTANT: Change "192.168.1" to match your actual Wi-Fi network subnet !!
  # E.g., if your router is 10.0.0.1, use "10.0.0"
    # --- 1. Dynamically Generate Host Entries (Ruby Logic) ---
  # This builds a single string with all IP/Hostname pairs needed

  # --- Add the Load Balancer Machine Definition ---
  # --- Ruby Logic to build the dynamic server list for HAProxy ---
  haproxy_servers = ""
  (0...NUM_MASTERS).each do |i|
    # Server line format: server k8s-master-1 192.168.1.101:6443 check inter 10s
    hostname = "k8s-master-#{i + 1}"
    ip_address = "#{IP_SUBNET_BASE}.#{MASTER_START_IP + i}"
    haproxy_servers += "    server #{hostname} #{ip_address}:6443 check inter 10s\n"
  end
  # --- End of dynamic server list generation ---
  

  # --- Generate Host Entries for /etc/hosts ---
  hosts_entries = ""
  all_hostnames = [] # Array to store all hostnames for deletion logic

  # Add the Load Balancer entry FIRST
  hosts_entries += "#{LB_IP} k8s-lb\n"
  all_hostnames << "k8s-lb"


  # Master IPs (101, 102, ...)
  # Loop from 0 up to (but not including) NUM_MASTERS
  (0...NUM_MASTERS).each do |i| 
    ip = "#{IP_SUBNET_BASE}.#{MASTER_START_IP + i}"
    # Hostnames should start at index 1: (0 + 1)
    hostname = "k8s-master-#{i + 1}" 
    hosts_entries += "#{ip} #{hostname}\n"
    all_hostnames << hostname
  end

  # Worker IPs (121, 122, ...)
  # Loop from 0 up to (but not including) NUM_WORKERS
  (0...NUM_WORKERS).each do |i|
    ip = "#{IP_SUBNET_BASE}.#{WORKER_START_IP + i}"
    # Hostnames should start at index 1: (0 + 1)
    hostname = "k8s-worker-#{i + 1}"
    hosts_entries += "#{ip} #{hostname}\n"
    all_hostnames << hostname
  end

  # Convert the Ruby array of hostnames into a space-separated string for the shell script
  managed_hostnames_str = all_hostnames.join(" ")

  # --- 2. Function to configure a node ---
  auto_configure_node = proc do |node, name, ip_suffix|
    node.vm.hostname = name
    node.vm.network VM_NETWORK,
      bridge: BRIDGE_INTERFACE,
      ip: "#{IP_SUBNET_BASE}.#{ip_suffix}"

    # === Universal Provisioner: Update /etc/hosts ===
    # We pass the dynamically generated string using Ruby interpolation (`#{hosts_entries}`)
    node.vm.provision "shell", run: "once", inline: <<-SHELL
      echo "Updating /etc/hosts on \$HOSTNAME..."

      # Define all hostnames we are managing in a shell variable
      MANAGED_HOSTNAMES="#{managed_hostnames_str}"

      # 1. Remove existing incorrect entries for managed hostnames (e.g., 127.0.2.1 k8s-master-1)
      for name_to_remove in \$MANAGED_HOSTNAMES; do
        sudo sed -i "/\\s\$name_to_remove\$/d" /etc/hosts
      done

      # 2. Remove the default vagrant entry (127.0.1.1 vagrant) if it exists
      sudo sed -i '/127\.0\.1\.1.*vagrant/d' /etc/hosts

      # 3. Append the correct entries generated in the Vagrantfile (192.168.1.x)
      cat <<EOF | sudo tee -a /etc/hosts > /dev/null
#{hosts_entries}
EOF

      # 4. Final de-duplication and cleanup
      sudo awk '!a[\$0]++' /etc/hosts > /tmp/hosts && sudo mv /tmp/hosts /etc/hosts

      echo "Hosts file updated successfully:"
      cat /etc/hosts
    SHELL
    # End of inline script

    
    # === Common K8s Prerequisites Script (Runs on ALL nodes) ===
    node.vm.provision "shell", path: "install-k8s-prereqs.sh", run: "once"

    # Conditional Provisioning based on node type
    if name.start_with?("k8s-master-1")
      node.vm.provision "shell", path: "init-cluster.sh" , run: "once"
    elsif name.start_with?("k8s-master") # <-- This targets the others
      node.vm.provision "shell", path: "join-manager.sh" , run: "once"
    elsif name.start_with?("k8s-worker")
      # Note: Worker nodes need the master's IP (e.g., .101) to join the cluster
      node.vm.provision "shell", path: "join-worker.sh" , run: "once"
    end
  end

  #   # --- Add the Load Balancer Machine Definition (updated with inline script) ---
  # config.vm.define "k8s-lb" do |lb|
  #   lb.vm.hostname = "k8s-lb"
  #   lb.vm.network VM_NETWORK,
  #     bridge: BRIDGE_INTERFACE,
  #     ip: LB_IP

  # Load Balancer Definition (uses the proc + extra inline script for HAProxy)
  config.vm.define "k8s-lb" do |lb|
    # auto_configure_node = proc do |node, name, LB_IP| # Accepts the full IP here
    lb.vm.hostname = "k8s-lb"
    lb.vm.network VM_NETWORK,
      bridge: BRIDGE_INTERFACE,
      ip: LB_IP

    # Provision the load balancer using an inline script and Ruby variables
    lb.vm.provision "shell", run: "once", inline: <<-SHELL
      echo "--- LB: Setting up HAProxy Dynamically ---"
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -y

      # Dynamically find the latest available version in the current repo
      # This command extracts the version string from apt-cache output
      HAPROXY_VERSION=$(apt-cache madison haproxy | awk '{print $3}' | head -n 1)

      # Install the exact version and automatically accept dependencies
      if [ -z "$HAPROXY_VERSION" ]; then
          echo "ERROR: Could not determine HAProxy version. Installing default."
          sudo DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy
      else
          echo "Installing HAProxy version: $HAPROXY_VERSION"
          sudo DEBIAN_FRONTEND=noninteractive apt-get install -y haproxy="$HAPROXY_VERSION"
          sudo apt-mark hold haproxy
      fi

      # Create HAProxy config file using dynamic server list
      cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg > /dev/null
global
    log /dev/log    local0
    chroot /var/lib/haproxy
    daemon

defaults
    log     global
    mode    tcp
    # option  httplog
    timeout connect 10s
    timeout client 30s
    timeout server 30s

# Frontend for Kubernetes API (VIP:6443)
frontend kubernetes-api
    bind *:6443
    mode tcp
    default_backend kubernetes-masters

# Backend for Kubernetes API
backend kubernetes-masters
    mode tcp
    balance roundrobin
    # REMOVED: 'option tcpchk' which caused the error
#{haproxy_servers}
EOF
      sudo haproxy -c -f /etc/haproxy/haproxy.cfg
      sudo systemctl restart haproxy
      echo "--- LB: HAProxy configuration complete using dynamic list ---"
    SHELL
  end

  # --- Master Node Definitions (Starting IP index 101) ---
  (1..NUM_MASTERS).each do |i|
    hostname = "k8s-master-#{i}"
    # Assign IPs starting from 192.168.1.101, 102, 103...
    ip_suffix = 100 + i 
    config.vm.define hostname do |node|
      auto_configure_node.call(node, hostname, ip_suffix)
    end
  end

  # --- Worker Node Definitions (Starting IP index 121) ---
  (1..NUM_WORKERS).each do |i|
    hostname = "k8s-worker-#{i}"
    # Assign IPs starting from 192.168.1.121, 122...
    ip_suffix = 120 + i
    config.vm.define hostname do |node|
      auto_configure_node.call(node, hostname, ip_suffix)
    end
  end
  # # Loop through the nodes and configure each one
  # nodes.each do |hostname, ip|
  #   config.vm.define hostname do |node|
  #     node.vm.hostname = hostname
      
  #     # Use a public (bridged) network
  #     # The 'bridge' parameter ensures it uses your specific Wi-Fi interface
  #     node.vm.network "public_network",
  #       bridge: "en0: Wi-Fi",
  #       ip: ip

        
  #       # === NODE-SPECIFIC CONFIGURATION ===
  #     # --- Conditional Provisioning (Run based on hostname) ---
  #     if hostname == "k8s-master"
  #       node.vm.provision "shell", path: "init-cluster.sh", run: "always"
  #     else
  #       # Pass the master IP to the join script
  #       node.vm.provision "shell", path: "join-worker.sh", args: nodes["k8s-master"], run: "always"
  #     end
  #   end
  # end
      
  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.

  # Ensure the shared folder exists on the host machine
  if !Dir.exist?("cluster_data")
    Dir.mkdir("cluster_data")
  end
  # Configure shared folder for all VMs (default mount point is /vagrant on the guest)
  # This makes the 'cluster_data' folder on your Mac accessible in every VM as /vagrant/cluster_data
  config.vm.synced_folder "cluster_data", "/vagrant/cluster_data"

  # Disable the default share of the current code directory. Doing this
  # provides improved isolation between the vagrant box and your host
  # by making sure your Vagrantfile isn't accessible to the vagrant box.
  # If you use this you may want to enable additional shared subfolders as
  # shown above.
  # config.vm.synced_folder ".", "/vagrant", disabled: true

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
  # This is a comment
end
