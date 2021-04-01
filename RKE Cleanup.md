Here is a script that cleans up the RKE deployment on a node. Reboot after use!

```{bash}
#!/bin/bash
docker rm -f $(docker ps -qa)
docker volume rm $(docker volume ls -q)
cleanupdirs="/var/lib/etcd /etc/kubernetes /etc/cni /opt/cni /var/run/calico /opt/rke /var/lib/cni /run/secrets/kubernetes.io /var/lib/rancher /var/lib/kubelet /var/lib/docker"
for dir in $cleanupdirs; do
        echo "Removing $dir"
        rm -rf $dir
done
```
