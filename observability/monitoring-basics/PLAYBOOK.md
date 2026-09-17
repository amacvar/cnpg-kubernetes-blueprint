# Monitoring Basics: Deploy & Verify

## Prerequisites

- A Kubernetes cluster with the CNPG operator already installed.
- Helm.

## Step 1: Deploy kube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values kube-prometheus-values.yaml
```

## Step 2: Deploy the cluster

```bash
kubectl apply -f pg-cluster.yaml
kubectl cnpg status pg-cluster -n default
```

## Step 3: Deploy the PodMonitor

```bash
kubectl apply -f podmonitor.yaml
```

```bash
kubectl get podmonitor pg-cluster -n default
```

## Step 4: Verify the scrape is actually working

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Then, in another shell:

```bash
curl -s 'http://localhost:9090/api/v1/query?query=cnpg_collector_up' | python3 -m json.tool
```

You want to see one result per instance, each with value `1`. If the
result set is empty, don't go looking for a Postgres-side problem first —
check `kube-prometheus-values.yaml` actually got applied
(`podMonitorSelectorNilUsesHelmValues: false`). An unscraped PodMonitor
produces no error anywhere; it just silently isn't there.

## Step 5: Import the community dashboard

CNPG's own per-cluster Grafana dashboard lives in a dedicated repository,
not a numbered grafana.com import ID:

```bash
curl -sLO https://raw.githubusercontent.com/cloudnative-pg/grafana-dashboards/main/charts/cluster/grafana-dashboard.json
```

In Grafana: **Dashboards → New → Import**, upload
`grafana-dashboard.json`, point it at your Prometheus datasource. You
should immediately see replication status, backup age, WAL metrics and
connection usage for `pg-cluster`.
