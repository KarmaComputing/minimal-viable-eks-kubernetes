#!/bin/bash

set -exuo pipefail

export AWS_REGION=eu-west-2


echo Creating eks cluster. Creation takes about 20 minutes... wowee
echo 'You can watch its creation progress at https://eu-west-2.console.aws.amazon.com/cloudformation/'
echo 'eventually the cluster will be visible in console at https://eu-west-2.console.aws.amazon.com/eks/clusters?region=eu-west-2'
eksctl create cluster --name=test-eks --enable-auto-mode

echo 
echo 'You should now configure your cli to use aws (ACCESS_TOKEN or sso etc)'
echo 'Then, if you can now `kubectl get nodes`, your EKS cluster is good.'
echo
echo 'Now to setup ingress, read https://docs.aws.amazon.com/eks/latest/userguide/auto-configure-alb.html'


