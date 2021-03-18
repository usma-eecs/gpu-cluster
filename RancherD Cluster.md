# Rancher Cluster using RancherD

Rancher has recently released a new method of creating a highly-available Rancher cluster with a tool called RancherD. This appear to be a combination of a RKE cluster install and the Rancher install. We had originally planned to put Rancher on a K3S cluster (per the recommendation in the Rancher documentation) but it's clear that the recommendation has changed.

## Set up the VM

As we will need to create several similar nodes for the cluster to host the Rancher install,  we set up the first node to use as a template. This node has 8 GB of RAM, 4 cores, and 16 GB of storage. We utilized Ubuntu 20.04 Server for this node and connected the NIC to our cluster internal network.

### Add an Account

We need to add a non-root (non-"ubuntu") user account to the VM. 

```{bash}
sudo adduser manager
sudo usermod -aG sudo manager

#Logout of the "ubuntu" user account and log into the "manager" account
sudo deluser ubuntu
```

### Change the hostname

We rename the VM to **rancher-1** in **`/etc/hostname`**. Note: This change won't take effect until a reboot.

### Add MAC Address to DHCP

Using **ip a** we need to find the MAC address of this VM so we can add a static IP reservation to our DHCP server. We add this reservation in **`/etc/dhcp/dhcpd.conf`**:

```{yaml}
host rancher-1 {
    hardware ethernet 00:00:00:00:00:00;
    fixed-address 192.168.1.11
}
```

Following this we need to restart the DHCP server as well as the Rancher node so we can verify the hostname has changed and the IP reservation is correct.

## RancherD Setup

We followed the instructions from Rancher located here: https://rancher.com/docs/rancher/v2.x/en/installation/install-rancher-on-linux/

### Config YAML

We wrote a file at **`/etc/rancher/rke2/config.yaml`** consisting of:

```{yaml}
token: wouldnt-you-like-to-know
tls-san:
  - k8s.eecs.net
```

### Running the Installer

After verifying that the script doesn't do anything naughty, we run:

```{bash}
sudo -s
curl -sfL https://get.rancher.io | sh -
```
 This will install the **rancherd** binary and we can enable the service using:

 ```{bash}
sudo systemctl enable rancherd-server.service
sudo systemctl start rancherd-server.service
 ```

### KUBECONFIG Environmental Variable
We then set the **KUBECONFIG** variable so **kubectl** knows how to contact the cluster.

```{bash}
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml PATH=$PATH:/var/lib/rancher/rke2/bin
```

We can then check to ensure the cluster is up using:

```{bash}
kubectl get daemonset rancher -n cattle-system
kubectl get pod -n cattle-system
```

Note: I had to **chown** the **`/etc/rancher/rke2`** directory in order to get **kubectl** to function.

### Admin Password
Once the Rancher is running, we used the **rancherd reset-admin** to get the admin password for the web portal. You can also verify that your SAN was pulled correctly from your **config.yaml**. According to Rancher's documentation you should have *https://* in front of your SAN in the configuration file; however, we found that wasn't correct. This finding is supported by other RKE2 documentation from Rancher.

## HAProxy Modification
As RancherD uses HTTPS communication on port 8443, we went back to add a service to our HAProxy in **`/etc/haproxy/haproxy.cfg`**.

```{yaml}
frontend rancher_https_fe
    bind :8443
    default_backend rancher_https_be
    mode tcp
    option tcplog

backend rancher_https_be
    balance source
    mode tcp
    server rancher-1 192.168.1.11:8443 check
    server rancher-2 192.168.1.12:8443 check
    server rancher-3 192.168.1.13:8443 check
```

We also had to open the port on the firewall:
```{bash}
sudo firewall-cmd --permanent --zone=external --add-port=8443/tcp
sudo firewall-cmd --reload
```

## Additional Nodes
Running through the Rancher install documentation exactly can distract you from cloning your VM before starting the RancherD service. Ideally you do this because the second and third node need to join the first node as fellow members of the cluster. As we didn't clone the VM before starting the service, we had to use the **sudo rancherd-uninstall.sh** script to remove the seperate Rancher "cluster" spun up when **Rancher-2** was cloned. Following this, we added the necessary line to the **config.yaml** to point **Rancher-2** at the existing cluster when we went through the RancherD install step again.

#### **`/etc/rancher/rke2/config.yaml`**
```{yaml}
server https://rancher-1.cluster.lan:9345
token: wouldnt-you-like-to-know
tls-san:
  - k8s.eecs.net
```

## SSL Termination at Load Balancer
After initially standing up this cluster it because clear that, if we wanted to do any sort of domain-based routing for HTTPS services, we needed to have SSL termination at HAProxy (our external load balancer). To this end, there are a few things that have to be done to allow the use of our own SSL certificate that can be maintained by HAProxy. We opted to use a self-signed certificate as our system can't grab a Let's Encrypt but ideally we would use something like that. 

Assuming you've created your own certificate through one of the multiple of methods, you should have a **cert.pem** and **key.pem** file. We need to put these files in the **/etc/rancher/ssl** folder on the all nodes. Additionally, the directory **/var/lib/rancher/rke2/server/manifests** needs to be created on all nodes and the following file should be stored there:

#### **`/var/lib/rancher/rke2/server/manifests/values.yaml`**
```{yaml}
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rancher
  namespace: kube-system
spec:
  valuesContent: |
    publicCA: true
```
This file modifies the Helm deployment of RancherD and allows the use of a *public certificate authority (CA)*. 

The additional steps should be all that is necessary when standing up the RancherD Rancher cluster. Remember that the **cert.pem** and **key.pem** files also need to be on the load balancer machine (the *Services* VM in our case).


