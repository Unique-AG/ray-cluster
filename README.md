# ray-cluster
Unique Ray Cluster

## Ansible

We use Ansible to prepare the cluster. 

### Pre-requisites
- An existing `management_user_ssh_keys`-owner (which has been applied to the target) must add your public ssh key to the `cluster_vars.management_user_ssh_keys` list in their respective `ansible/values.yaml` and at least run the `ssh` role once.
- Must have ansible and potentially 1password-cli installed on your machine.

### Playing Ansible

1. Create a `ansible/values.yaml` file with the appropriate values for your cluster.

2. Create a `ansible/inventories/ray_cluster/hosts.yaml` file with the appropriate values for your cluster.

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
 ansible-playbook playbooks/provisioning.yaml --extra-vars "@values.yaml" --tags "cluster,ssh,kubernetes,charts,apps"
 ```

## Application Deployments

All application resources are deployed via ArgoCD. The ansible role `apps` will create an ArgoCD application for each app defined in the `values.yaml` file.
Some apps, that contain multiple services, use a ArgoCD ApplicationSet to deploy each service and required resource (e.g. the `10-document-chat` app).

### Helm

Individual services are packaged into Helm charts and deployed via ArgoCD. The Helm charts are stored in the `helm` directory and are packaged and pushed to the OCI registry with the `helm/publish.sh` script.

## License
This repository is intended primarily for research, development, testing, and the collection and dissemination of knowledge.

The Ray Research project by UNIQUE is source-disclosed, rather than open source, in order to encourage collaboration and innovation, as well as to provide transparency and insight into the internal mechanisms of UNIQUE. 

Please note that this software is licensed under the _UNIQUE Custom Proprietary License 1.0_. For detailed terms and conditions, refer to the [LICENSE](LICENSE.md) file.
