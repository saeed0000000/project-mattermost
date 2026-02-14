# Observability Layer (Prometheus + Grafana + Alertmanager + Loki + Promtail)

This folder prepares Layer 4 for your project.

## Prerequisites

- EKS cluster is up and reachable (`kubectl get nodes` works).
- EBS CSI driver is active (for `gp3` PVCs).
- Helm is installed.

## 1) Add Helm repositories

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

## 2) Create namespaces

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -
```

## 3) Install Prometheus stack

```bash
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f helm/observability/kube-prometheus-stack.values.yaml
```

## 4) Install Loki

```bash
helm upgrade --install loki grafana/loki \
  -n logging \
  -f helm/observability/loki.values.yaml
```

## 5) Install Promtail

```bash
helm upgrade --install promtail grafana/promtail \
  -n logging \
  -f helm/observability/promtail.values.yaml
```

## 6) Verify

```bash
kubectl -n monitoring get pods
kubectl -n logging get pods
kubectl -n monitoring get pvc
kubectl -n logging get pvc
```

## 7) Access Grafana locally

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
```

Open: http://localhost:3000

Default credentials from values:

- user: `admin`
- password: `change-me-before-install`

Change this password in `helm/observability/kube-prometheus-stack.values.yaml` before production usage.
