# RKE2 Cluster to Host Rancher

## Motivation
RancherD is a pretty interesting tool and we had some success with it when our Rancher cluster was behind the **Services** machine but when we moved all machines directly onto the network we began to have some issues. In order to try to address these issues, we moved to installing Rancher directly on an RKE2 cluster.

config.yaml
write-kubeconfig-mode: "0644"
token: my-shared-secret
tls-san:
  - rancher-1.k8s.eecs.net
  - k8s.eecs.net
cluster-cidr:
  - 192.168.0.0/24
service-cidr:
  - 192.168.10.0/24
cluster-dns:
  - 192.168.10.10

-Make RKE2 directory and put config in it

curl -sfL https://get.rke2.io | sudo sh -

Wait

export KUBECONFIG=/etc/rancher/rke2/rke2.yaml

kubectl get nodes

autocomplete
source <(kubectl completion bash)

### Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

### Add Rancher Repo
From: https://rancher.com/docs/rancher/v2.x/en/installation/install-rancher-on-k8s/
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
kubectl create namespace cattle-system

### Use Rancher Cert

kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.4/cert-manager.crds.yaml

kubectl create namespace cert-manager

helm repo add jetstack https://charts.jetstack.io

helm repo update

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.0.4

helm install rancher rancher-stable/rancher   --namespace cattle-system   --set hostname=rancher-1.k8s.eecs.net

### Check status
kubectl -n cattle-system rollout status deploy/rancher