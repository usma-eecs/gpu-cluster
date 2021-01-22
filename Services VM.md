# Services VM

The first machine to be established will be the "services" VM that will function as single point of ingress into the Rancher Cluster (and later clusters). This VM will serve as the load balancer, DHCP server, and DNS server for the VLAN that all of the cluster machines are on. 

For this machine, we will use Ubuntu 20.04 Desktop as a template was easily available and it will provide us a desktop environment to monitor various resources inside the cluster VLAN. This machine has 4 cores, 8GB of RAM, and 64GB of storage. This VM also has two NICs, one for each of the networks it straddles.

## Firewalld

While Ubuntu 20.04 comes loaded with **iptables**, I prefer to use **firewalld** for the ease of zone configuration. The first step will be to install this and establish our connection zones on the NICs.  

```{bash}
sudo apt install firewalld

#Before establshing the zones, I needed to change the connection names in nmtui-edit
sudo nmcli connection modify ens160 connection.zone external
sudo nmcli connection modify ens192 connection.zone internal

sudo firewall-cmd --get-active-zones
```
In order to allow clients on the internal network to communicate with outside (to grab images and other tasks), we turn on masquerading on both interfaces and check to ensure that IP forwarding is turned on.

```{bash}
sudo firewall-cmd --zone=external --add-masquerade --permanent
sudo firewall-cmd --zone=internal --add-masquerade --permanent

sudo sysctl -w net.ipv4.ip_forward=1

#Should print '1' to screen
cat /proc/sys/net/ipv4/ip_forwarding
```