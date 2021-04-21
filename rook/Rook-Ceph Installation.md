# Rook-Ceph Installation

This guide will cover the installation of the Ceph distributed storage on a cluster using Rook. 

Instructions taken from here: https://rook.github.io/docs/rook/v1.6/ceph-quickstart.html

### Explanation of Files:
*cluster.yaml, common.yaml, crds.yaml, operator.yaml*: Installation files defining various resources needed.  
*filesystem.yaml, storageclass.yaml*: Files defining the Ceph filesystem as well as adding the rook-ceph storageclass.  
*dashboard-ingress-https.yaml*: Establishes an ingress to access the Rook dashboard.  
*toolbox.yaml*: Deployment definition to faciliate testing and troubleshooting.  
*zap-disks.sh*: Script to remove all traces of filesystem from disks for storage overhaul.  

## Requirements:

It is assumed that this storage will be installed on a functioning Kubernetes cluster. Each node that is to host storage should have a second hard-disk mounted at **/dev/sdb**. This can be changed by modifying the appropriate fields in the configuration files. These disks should be unformatted.

## Installation of Resources:

```{bash}
kubectl apply -f crds.yaml -f common.yaml -f operator.yaml

# verify the rook-ceph-operator is in the `Running` state before proceeding
kubectl -n rook-ceph get pod
```

```{bash}
kubectl create -f cluster.yaml
```

```{bash}
kubectl apply -f filesystem.yaml -f storageclass.yaml
```

## Dashboard

The dashboard is turned on in *cluster.yaml* and therefore you will need to add an ingress to the dashboard. This, obviously, requires that you have an ingress controller installed. Also, if you don't have an SSL certificate you will need to make some changes to create this command.

```{bash}
kubectl apply -f dashboard-ingress-http.yaml
```

Default username is "admin" and use this command to get the password for the dashboard:

```{bash}
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo
```