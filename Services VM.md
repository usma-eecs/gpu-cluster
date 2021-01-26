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

## DNS Server

The next thing to install will be the DNS server that will serve the devices on the "cluster internal" network. We'll use **bind** for this purpose.

```{bash}
sudo apt install -y bind9
```

We need to go into /etc/default/named and change an options line to OPTIONS="-u bind -4" to set in IPv4-only mode.

The following lines should be added inside the existing options block inside /etc/bind/named.conf.options:

```{bash}
#Listen on localhost and the IP address for our cluster internal
listen-on port 53 { 127.0.0.1; 192.168.1.1; };

#Allow queries from the same
allow-query { localhost; 192.168.1.0/24; };

recursion yes;

#These are two of the upstream DNS servers of EECSNet
#Found using "systemd-resolve --status"
forwarders {
       10.19.89.201;
       10.19.89.202;
};
```

Next we need to set up a zone for this DNS server to manage. We can add this zone to /etc/bind/named.conf.local by adding this block:

```{bash}
zone "rancher.lan" {
  type master;
  file "/etc/bind/db.cluster.lan";
};
```

To go along with this zone definition, we'll have to create the file at **/etc/bind/db.cluster.lan" with these contents:

```{bash}
; Time-to-live for DNS record cache
$TTL    86400
; Defines the origin hostname for our zone
$ORIGIN cluster.lan.


; Start of Authority (SOA) Record
; Defines the various timing elements for this zone
@       IN      SOA     services.cluster.lan. admin.cluster.lan. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                          86400 )       ; Negative Cache TTL

; Define the DNS server
        IN      NS      services

; A records
; Point a domain to an IP address
rancher.cluster.lan.    IN     A      192.168.1.1
services.cluster.lan.   IN     A      192.168.1.1

rancher-1.cluster.lan.        IN      A       192.168.1.11
rancher-2.cluster.lan.        IN      A       192.168.1.12
rancher-3.cluster.lan.        IN      A       192.168.1.13

rke1-1.cluster.lan.   IN      A       192.168.1.21
rke1-2.cluster.lan.   IN      A       192.168.1.22
rke1-3.cluster.lan.   IN      A       192.168.1.23
rke1-4.cluster.lan.   IN      A       192.168.1.24
rke1-5.cluster.lan.   IN      A       192.168.1.25
```

Next we open up the firewall to allow DNS traffic and start the DNS server. We also need to direct our external NIC to use the localhost as a DNS server.

```{bash}
sudo firewall-cmd --permanent --zone=internal --add-port=53/udp
sudo firewall-cmd --reload

sudo systemctl enable named
sudo systemctl start named
```

### DHCP Server

Next we will install a DHCP server for the cluster machines.

```{bash}
sudo apt install -y isc-dhcp-server
```

We then specify what interface to listen on for the DHCP server. This is done by setting the correct interface (**ens192** in this case) in /etc/default/isc-dhcp-server as well as uncommenting the lines pointing to the DHCP configuration and PID for IPv4.

The next step is to add the configuration and static records to **/etc/default/dhcpd.conf**:

```{bash}
option domain-name "cluster.lan";
option domain-name-servers services.cluster.lan;

default-lease-time 600;
max-lease-time 7200;

ddns-update-style none;

authoritative;

subnet 192.168.1.0 netmask 255.255.255.0 {
option routers 192.168.1.1;
option subnet-mask 255.255.255.0;
option domain-name "cluster.lan";
option domain-name-servers 192.168.1.1;
#Keep this range far away from our static reservations
range 192.168.1.100 192.168.1.199;
}

#Add these for all your clients
host rancher-1 {
 hardware ethernet 00:00:00:00:00:00;
 fixed-address 192.168.1.10;
}
```

We'll have to come back here to update these records once the MAC addresses are assigned for the VMs we create for the clusters.

Now we have to add the DHCP service to the firewall and start the DHCP service.

```{bash}
sudo firewall-cmd --permanent --zone=internal --add-service=dhcp
sudo firewall-cmd --reload

sudo systemctl enable isc-dhcp-server
sudo systemctl start isc-dhcp-server
```

## Loadbalancer

We are going to install **haproxy** as a loadbalancer for all our services.

```{bash}
sudo apt install -y haproxy
```

Replace the contents of /etc/haproxy/haproxy.cfg with what is below:

```{bash}
global
    maxconn     20000
    log         /dev/log local0 info
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    user        haproxy
    group       haproxy
    daemon

    stats socket /var/lib/haproxy/stats

defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          300s
    timeout server          300s
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 20000

#The HAProxy "Stats" page
#Available at port 9000
listen stats
    bind :9000
    mode http
    stats enable
    stats uri /

#Define services as needed
#This service load balances the Rancher Web UI
frontend rancher_http_fe
    bind :80
    default_backend rancher_http_be
    mode tcp
    option tcplog

backend rancher_http_be
    balance source
    mode tcp
    server rancher-1 192.168.1.10:80 check
    server rancher-2 192.168.1.11:80 check
    server rancher-3 192.168.1.12:80 check
```

Finally we open the firewall and start the service:

```{bash}
sudo firewall-cmd --permanent --zone=external --add-port=9000/tcp
sudo firewall-cmd --permanent --zone=external --add-port=80/tcp
sudo firewall-cmd --permanent --zone=external --add-service=http
sudo firewall-cmd --reload

sudo systemctl enable haproxy
sudo systemctl start haproxy
```