# ray-cluster
Unique Ray Cluster

## Ansible

We use Ansible to prepare the cluster. 

1. Create a `values.yaml` file with the appropriate values for your cluster.

2. Create a `hosts.yaml` file with the appropriate values for your cluster.

3. Run the playbook from the `ansible` directory with:

```bash
ansible-playbook playbooks/provisioning.yaml --extra-vars "@values.yaml"
```

The provisioning playbook has several tags that you can use to run specific tasks:

- `cluster`: Upgrade the apt-packages, setup and harden SSH, provision management user.
- `kubernetes`: Provision the Kubernetes cluster with k3s.
- `charts`: Provision the Helm charts. You can define a list of roles to install in the `values.yaml` file.
- `apps`: Setup ArgoCD applications so they can be deployed on the cluster via ArgoCD.

To run a specific task, use the `--tags` option:

```bash
ansible-playbook playbooks/provisioning.yaml --extra-vars "@values.yaml" --tags "cluster,kubernetes,charts,apps"
```