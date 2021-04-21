# SSL Certificate Secret

We have a SSL Certificate signed by the EECSNet CA and we need to add a Kubernetes secret to every namespace that will need access.

```{bash}
kubectl create secret tls -n rook-ceph k8s.eecs.net --cert=tls.crt --key=tls.key
```