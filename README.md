# Minimal EKS (Kuberentes on AWS) using EKS Auto Mode?

> By the end of reading this you should be able to load the web address (`http` not `https`)
of your deployment (service) in a web browser and view the application running in the related
pod(s) container(s). Note: It might take longer than you expect for the AWS DNS to assign IPs
to your application load balancer address, use `dig <address>` to verify/wait until IPs are assigned
which can take a minute or two.

[What's EKS auto mode?](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
aka How to I get a web app (e.g. nginx) hosted on EKS?

Assumption: You already have a boostrapped eks cluster using automode (see `bootstrap-eks.sh`), and can successfully `kubectl get pods` to it.

tldr: For L7 (layer 7) traffic (e.g.HTTP/HTTPS) within your EKS cluster, you need an Ingress

Read `bootstrap-eks.sh`.

> EKS Auto Mode creates a load balancer when you create an Ingress Kubernetes objects and configures it to route traffic to your cluster workload. ([src](https://docs.aws.amazon.com/eks/latest/userguide/auto-configure-alb.html)

See: https://docs.aws.amazon.com/eks/latest/userguide/auto-configure-alb.html and follow the steps,

# How do I delete it all? (This is costing me money, help delete it now!)

```
# There's no confirmation when deleting, make sure you know you want to delete
# your EKS cluster and you have the correct name!
# eksctl delete cluster --name test-eks
```
