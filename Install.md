## Installing Docker as the Cgroup Driver

*Needs to be completed on all nodes.*

**Source:** https://docs.docker.com/engine/install/debian/

*Note: The link above is for Debian but the instructions are very similar for other Linux flavors. The Docker website has similar guides for several other distros.*

```bash
sudo apt-get update

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io
```

## Installing kubeadm, kubelet, and kubectl

*Needs to be completed on all nodes.*

**Source:** https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

```bash
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

Because Docker is already installed, Kubernetes should autoselect that as the Cgroup driver.

## Turning off swap

*Needs to be completed on all nodes.*

```bash
sudo swapoff -a
```

You then need to edit the fstab to comment out the swap line so swap doesn't turn on restart.

## Starting Cluster

**Source:** https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/

The following command should be executed on the control-plane:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

Once this is complete it will prompt the user to execute the following commands to allow **kubectl** to work for non-root users.

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

The final line in the cluster startup will be a command that needs to be executed on each compute node in order to add them to the cluster. It will look something like this:

```bash
sudo kubeadm join --token <token> <control-plane-host>:<control-plane-port> --discovery-token-ca-cert-hash sha256:<hash>
```

Paste this line into each node (after completing the installation steps above) in order to add each node to the cluster.

## Installing Flannel as the Container Network Interface

*Only needed on control-plane node.*

**Sources**: https://appfleet.com/blog/configure-kubernetes-network-with-flannel/ and https://github.com/coreos/flannel

First we need to ensure that packets traversing a bridge are sent to the IP tables for processing.

```bash
echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee -a /etc/sysctl.conf
```

Then we can use the official install script to install Flannel.

```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

This should install Flannel and allow the **coredns** pods to come online.

## "Tainting" the Control Plane

**Source**: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/

*Note: This has not been done to our control plane as of 9 SEP 20 but will likely be done in the future.*

If you need to schedule pods on the control plane node than you must "taint" the control plane using this command:

```bash
kubectl taint nodes --all node-role.kubernetes.io/master-
```

This may be necessary if you want to give a pod the ability to schedule other pods as (unless you change that setting as well) only the control plane can schedule pods. 

### Add user to Docker group

*I believe this is only needed on the control plane.*

In order to pull images from Docker Hub (and do other Docker things), the current user (**eecs** in our case) needs to be in the "docker" user group.

```bash
sudo usermod -aG docker eecs
```
