# Minimal EKS (Kuberentes on AWS) using EKS Auto Mode?

## What is this?

Quickly bootstrap an AWS EKS cluster:

- With EFS (to support `ReadWriteMany`) storage support
- It takes about 25mins to run, from a completely empty new account with zero added resources
  - Assumes you have ran [aws-nuke](https://aws-nuke.ekristen.dev/quick-start/) on the target account
    and/or have a completely new account
- Ingress setup


### Ingress notes

For L7 (layer 7) traffic (e.g.HTTP/HTTPS) within your EKS cluster, you need an Ingress

By the end of reading/running this you should be able to load the web address (`http` not `https`)
of your deployment (service) in a web browser and view the application running in the related
pod(s) container(s).

Note: For Ingress, it might take longer than you expect for the AWS DNS to assign IPs
to your application load balancer address, use `dig <address>` to verify/wait until IPs are assigned
which can take a minute or two.

### [What's EKS auto mode?](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)

aka How to I get a web app (e.g. nginx) hosted on EKS?

> EKS Auto Mode creates a load balancer when you create an Ingress Kubernetes objects and configures it to route traffic to your cluster workload. ([src](https://docs.aws.amazon.com/eks/latest/userguide/auto-configure-alb.html)

See: https://docs.aws.amazon.com/eks/latest/userguide/auto-configure-alb.html and follow the steps,

## Usage

### 1. Read `bootstrap-eks.sh`

Read `bootstrap-eks.sh` so you have a general understanding.

### 2. Authenticate your terminal (aws cli)

Either with SSO, or exporting access keys, get aws cli working with your target (empty) account.

### 3. From the root of this repo, run ``bootstrap-eks.sh`

Using bash- yes bash, not zsh, not something else.

```bash
./bootstrap-eks.sh
# Wait and watch
```

### 4. Enjoy the cluster

Deploy kubernetes resources to your cluster just like you would any other Kubernetes compliant provider.

### 5. Delete the cluster- don't leave it running!

Use aws nuke to remove the resources. See also `eksctl delete cluster --name test-eks`

### How do I delete it all? (This is costing me money, help delete it now!)

```shell
# There's no confirmation when deleting, make sure you know you want to delete
# your EKS cluster and you have the correct name!
# eksctl delete cluster --name test-eks
```


## Test / debug Dynamic Storage provisioning

```
kubectl apply -f pod-dynamic-provisioning.yaml
# wait
kubectl exec efs-app-dynamic-provisioning -- bash -c "cat data/out"
# Exec into pod and verify data/user id permissions:
kubectl exec -it efs-app-dynamic-provisioning -- bash
```

Example storage troubleshoot session:

```
[root@efs-app-dynamic-provisioning /]# id
uid=0(root) gid=0(root) groups=0(root)
[root@efs-app-dynamic-provisioning /]# pwd
/
[root@efs-app-dynamic-provisioning /]# touch test
[root@efs-app-dynamic-provisioning /]# ls -l test
-rw-r--r--. 1 root root 0 Sep 23 21:14 test
[root@efs-app-dynamic-provisioning /]# pwd
/
[root@efs-app-dynamic-provisioning /]# touch /data/test
[root@efs-app-dynamic-provisioning /]# ls -l /data/test
-rw-r--r--. 1 50003 50003 0 Sep 23 21:14 /data/test
```
