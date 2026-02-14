# Ingress Controller (AWS Load Balancer Controller)

This project uses an ALB-based Ingress on EKS via AWS Load Balancer Controller.

## 1) Install the controller (when EKS exists)

Add the repo:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
```

Create the service account (IRSA annotation goes here):

```bash
kubectl -n kube-system create serviceaccount aws-load-balancer-controller --dry-run=client -o yaml | kubectl apply -f -
kubectl -n kube-system annotate serviceaccount aws-load-balancer-controller \
  eks.amazonaws.com/role-arn="REPLACE_WITH_IAM_ROLE_ARN"
```

Install:

```bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f helm/addons/aws-load-balancer-controller/values.yaml
```

Verify:

```bash
kubectl -n kube-system get deploy aws-load-balancer-controller
kubectl -n kube-system get pods -l app.kubernetes.io/name=aws-load-balancer-controller
```

## 2) Mattermost Ingress

Ingress is defined in `helm/mattermost/templates/45-ingress.yaml` and enabled in:

- `helm/mattermost/values.prod.yaml` (`ingress.enabled: true`)

For production, set:

- `ingress.host`
- TLS via cert-manager (later layer)
