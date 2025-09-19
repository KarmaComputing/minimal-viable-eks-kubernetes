# Minimal EKS (Kuberentes on AWS) using EKS Auto Mode?

[What's EKS auto mode?](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
aka How to I get a web app (e.g. nginx) hosted on EKS?

Assumption: You already have a boostrapped eks cluster using automode (see `bootstrap-eks.sh`), and can successfully `kubectl get pods` to it.

tldr: For L7 (layer 7) traffic (e.g.HTTP/HTTPS) within your EKS cluster, you need an Ingress

Read `bootstrap-eks.sh`.

> EKS Auto Mode creates a load balancer when you create an Ingress Kubernetes objects and configures it to route traffic to your cluster workload. ([src](https://docs.aws.amazon.com/eks/latest/userguide/auto-configure-alb.html)

See: https://docs.aws.amazon.com/eks/latest/userguide/auto-configure-alb.html
