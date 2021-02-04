# K8s Cluster using Rancher and RKE

## Set up the VM

As we will need to create several similar nodes for the cluster to host our K8s cluster,  we set up the first node to use as a template. This node has 8 GB of RAM, 4 cores, and 32 GB of storage. We utilized Ubuntu 20.04 Server for this node and connected the NIC to our cluster internal network.

### Add an Account

We need to add a non-root (non-"ubuntu") user account to the VM. 

```{bash}
sudo adduser manager
sudo usermod -aG sudo manager

#Logout of the "ubuntu" user account and log into the "manager" account
sudo deluser ubuntu
```

### Install Docker

As of the writing of this guide, the latest version of Docker on Ubuntu 20.04 supported by RKE is 19.03. So after installing a few pre-reqs, we installed that version on our VM. 

```{bash}
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
   
sudo apt-get update

sudo apt-get install docker-ce=5:19.03.14~3-0~ubuntu-focal \
    docker-ce-cli=5:19.03.14~3-0~ubuntu-focal \
    containerd.io

#Need to add user to docker group
sudo /usr/sbin/usermod -aG docker manager
```

## Clone VMs

We decided to create a cluster with 3 Control Plane/ETCD nodes and 3 workers nodes. As such, we will clone our first VM five times and then execute a few steps on each of the nodes.

### Change the hostname

We rename the VM to **rke1-X** in **`/etc/hostname`**. Note: This change won't take effect until a reboot.

### Create a SSH Key

```{bash}
ssh-keygen
```

### Copy Keys Across Hosts

```{bash}
ssh-copy-id manager@rke1-X.cluster.lan
```

### Updates to Services VM

Using **ip a** we need to find the MAC address of this VM so we can add a static IP reservation to our DHCP server. We add this reservation in **`/etc/dhcp/dhcpd.conf`**:

```{yaml}
host rke1-1 {
    hardware ethernet 00:00:00:00:00:00;
    fixed-address 192.168.1.21
}
```

We'll have to add another DNS reservation for the additional RKE1 node we decided to add in **`/etc/bind/db.cluster.lan`**:

```{yaml}
rke1-6.cluster.lan.   IN      A       192.168.1.26
```

## Create Cluster on Rancher

Once all six VMs are up and running, we log into the Rancher UI and create a new cluster from "Existing nodes". There isn't too much to discuss here because we can basically leave the defaults and scroll to the bottom to see the docker command to run on the node to bring it into the cluster. We just need to ensure we select the correct roles we want to assign to each node using the checkboxes in Rancher.

Once the docker command is run on the node, it's just a matter of waiting for the node to download the necessary images and join the cluster.