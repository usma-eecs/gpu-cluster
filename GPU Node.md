## Prereqs:
Source: https://github.com/NVIDIA/k8s-device-plugin#upgrading-kubernetes-with-the-device-plugin

This guide assumes that you have Docker and the proper Nvidia drivers installed on your machine.

### Install Nvidia-Docker2

```{bash}
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update && sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker
```

Next you will need to ensure that **"nvidia"** is your default runtime for container. You're **/etc/docker/daemon.json** file should look like this:

```{json}
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
```

### Test the Installation

The command below will start a container to run the **nvidia-smi** command. The output should match what you get if you run **nvidia-smi** directly on the host.

```{bash}
sudo docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## Cluster Prep
**Note:** There are two paths from here depending on whether you want to be able to share the GPUs between user pods.

### Dedicated GPUs
If there are already GPU Nodes in your cluster than this is likely already complete but I'll include it here just in case. 

To automatically identify nodes with GPUs, Nvidia uses a "K8S Device Plugin" pod that is scheduled on each node (daemonset). We add this daemonset using a Helm chart. First we must add this Helm chart to Rancher's list of repositories in the **Cluster Explorer** under the **Apps & Marketplace** option ("Cluster Explorer" dropdown on the top left corner of the screen). We want to go to "Chart Repositories" and click the "Create" button. The link to include is: https://nvidia.github.io/k8s-device-plugin

The one change we want to make to *YAML* before deploying this chart is **failOnInitError** to **false** so our installation doesn't fail because some nodes don't have GPUs.

Once this daemonset is installed, it should automatically propagate to nodes added later.

### GPU Sharing

Here is a link to a conversation about this may provide some additional options in the future: https://github.com/NVIDIA/k8s-device-plugin/issues/169

I tried to "copy /dev" technique with no success. The *Deepomatic* technique worked so that's what I'll discuss here.

Instead of using the official Nvidia "K8S Device Plugin", we are going to use **kubectl** to deploy an altered version of this plugin to the cluster.

```{bash}
kubectl create -f https://raw.githubusercontent.com/Deepomatic/shared-gpu-nvidia-k8s-device-plugin/v1.10/deepomatic-shared-gpu-nvidia-device-plugin.yml
```

This will deploy a daemonset across the cluster that will allow the GPU sharing. Each GPU node will appear to have 100 GPUs available for use.

You can ensure that pods are scheduled on GPUs nodes by adding *deepomatic.com/shared-gpu: '1'* to the resource requirement in your deployment yamls.

## Add Node in Rancher
This should should be pretty self-explanatory as Rancher provides you with the *Docker* command to run to add a node.

## Check the Availability of GPUs
Run the command below to check to ensure nodes are properly reporting GPUs.

```{bash}
kubectl get nodes -o=custom-columns=NAME:.metadata.name,GPUs:.status.capacity.'deepomatic\.com/shared-gpu'
```
## Troubleshooting
The only issue I had when figuring out the order of operations here was caused by **nvidia** not being the default runtime. You can test this by running a container and *inspecting* it to find the default runtime.

```{bash}
docker run busybox:latest

#Find the name of the container that you just ran
docker ps -a

#Find the default runtime
docker inspect CONT_NAME | grep Runtime
```