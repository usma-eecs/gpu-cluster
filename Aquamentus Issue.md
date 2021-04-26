# CNI Plug-in Issue on Aquamentus

When adding Aquamentus (one of our GPU machines) as a node, we were having issue with the container networking. After trying several things, what finally worked was commenting out **KUBELET_KUBEADM_ARGS** in **/var/lib/kubelet/kubeadm-flag.env** and then restarting the kubelet service.