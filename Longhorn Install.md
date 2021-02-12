# Distributed Block Storage with Longhorn

## Set up worker nodes

In order to completely segregate the distributed block storage from the storage on each node, we will add an additional 32 GB hard disk to each worker node in our RKE cluster (rke1-4, rke1-5, rke1-6). Once this hard disk is added (and following a node reboot), we will need to add a partition to this disk, format the partition, and add the partition to the **fstab**.

### Partitioning
We will use **fdisk** to make the partition.

```{bash}
sudo fdisk /dev/sdb
```
Once in the **fdisk** command prompt, **n** will create a new partition and all the defaults will work for our purposes. Once we've answered all the prompts, **w** will write the changes to the disk.

### Formatting the Partition
We will use **mkfs** to format our partition to ext4.

```{bash}
sudo mkfs.ext4 /dev/sdb1
```
Once again, all the defaults will be fine for our purposes.

### Adding the Mount Point
Longhorn will look for the disks at **`/var/lib/longhorn`** so we need to make that directory as well as adding our new partition to the **fstab**.

```{bash}
sudo mkdir /var/lib/longhorn

#Get the UUID of /dev/sdb1
sudo blkid
```
Copy the UUID to the clipboard to make adding it **`/etc/fstab`** easier. The following line should be added at the end of this file:
```{bash}
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx /var/lib/longhorn ext4 defaults 0 0
```
We can test our **fstab** addition using **`sudo mount -a`** and if there are no issues a reboot will be the real test.

## Install Longhorn

### Add Node Label
We will want to add the following label to our three worker nodes:
```{bash}
node.longhorn.io/create-default-disk=true
```
We will use the **Cluster Manager** interface's **Nodes** tab to do this.

### Add Project
Longhorn is a Rancher App and is very easy to install using the **Cluster Explorer** interface in Rancher. The first step, however, is to add a **Storage** project on our RKE cluster for proper service segmentation. This is very easy to do using the default **Cluster Manager** interface.

### Add Longhorn App
Once we have added the new project, we can switch to the **Cluster Explorer** interface and find Longhorn in the **Apps** section (button near the top of the page). Most of the default settings are acceptable for what we need except for one setting we will use to ensure Longhorn only creates storage on nodes we want it to. Under the *Longhorn Default Settings* tab, we will check the *Customize Default Settings* box to gain access to several more settings. Once here, we will check the box next to *Create Default Disk on Labeled Nodes*. This will use the label we added earlier to our worker nodes. Once we make this change, we can proceed with the install. 

### Set up Ingress
As a temporary means of gaining access to the Longhorn Web UI, we will need to set up an **Ingress** in the **Cluster Manager** interface. If we go to the **Storage** project and then the *Load Balancing* tab, we can add an ingress. For temporary purposes, we will just allow Rancher to automatically generate a **xip.io** hostname and ensure the **Target Backend** is the **longhorn-frontend** on port **80**.  
*Note:* You may have to click the **`+ Service`** button to get the **longhorn-frontend** option to appear in the *Target* drop-down.

Once this ingress is initialized, the URL provided will permit access to the Longhorn Web UI for any device on the **cluster.lan** network.