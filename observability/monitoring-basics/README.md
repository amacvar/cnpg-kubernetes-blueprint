# Monitoring CloudNativePG: The Basics

First article in a series building from single-cluster fundamentals up to
the full stack — fleet aggregation across clusters, object- and
query-level dashboards, and log collection with a tamper-evident audit
trail. This one stays deliberately narrow: one cluster, what CNPG already
gives you, and the one thing that recently changed in how you wire it up.

> Want to try this yourself? See [`PLAYBOOK.md`](PLAYBOOK.md) for the
> deploy steps.

## 🧠 What CNPG Exposes Natively

There's no sidecar to add and no exporter to deploy separately. Every
PostgreSQL instance the operator manages already runs its own Prometheus
exporter, built into the instance manager itself — HTTP or HTTPS, on port
9187, named `metrics`.

That exporter ships with a predefined set of metrics (installed by default
in a `ConfigMap` named `cnpg-default-monitoring`), plus a mechanism for
adding your own queries via additional ConfigMaps or Secrets. The queries
themselves run under real constraints, not just "trust the exporter":

- Each one is atomic — one read-only transaction per query.
- They execute as `cnpg_metrics_exporter`, a member of the built-in
  `pg_monitor` role, over peer authentication on the pod-local Unix
  socket — not a network connection, not a stored password.
- Because `session_user` is never a superuser here, the scrape session
  can't escalate via `RESET ROLE`/`RESET SESSION AUTHORIZATION`. Don't
  grant `cnpg_metrics_exporter` anything beyond `pg_monitor` and whatever
  table-level grants your own custom queries need — any extra membership
  flows into the scrape session through inheritance and quietly weakens
  this guarantee.

So the starting point isn't "how do I get metrics out of Postgres" —
CNPG already answers that. The starting point is "how do I get something
scraping port 9187 in the first place."

## Deploying kube-prometheus-stack

This part isn't CNPG-specific, so we won't dwell on it: the Prometheus
Operator (CRDs + controller) and Grafana, via the
`prometheus-community/kube-prometheus-stack` Helm chart. One cluster, one
namespace, defaults are fine to start. See `PLAYBOOK.md` for the actual
commands.

## ⚠️ The `PodMonitor` Change You Need to Know About

`PodMonitor` itself isn't new — CNPG has supported it since early
releases. What's changed is *who creates it*.

`.spec.monitoring.enablePodMonitor` on the `Cluster` used to auto-generate
a `PodMonitor` for you. That field is now deprecated — has been since CNPG
1.28 — and the CRD reference says so directly:

> "Deprecated: This feature will be removed in an upcoming release. If you
> need this functionality, you can create a PodMonitor manually."

Same story landed for the `Pooler` (pgbouncer) specifically in 1.30 — its
`enablePodMonitor` was still plain and undeprecated in 1.29, and picked up
the identical deprecation notice in 1.30. Two different timelines, same
direction: CNPG is handing PodMonitor ownership back to you rather than
managing it on your behalf, "to ensure you have complete ownership of your
monitoring configuration" (their words, not ours) instead of a Cluster
field silently reconciling something you might have hand-edited.

The replacement is small — this is the whole manifest, straight from
CNPG's own documentation:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: cluster-example
spec:
  selector:
    matchLabels:
      cnpg.io/cluster: cluster-example
  podMetricsEndpoints:
  - port: metrics
```

`cnpg.io/cluster` is the label every instance pod already carries, and
`metrics` is the exporter port name from the section above — no numeric
port, no extra config. If you're already using
`.spec.monitoring.tls.enabled` (new in 1.30), the manual `PodMonitor`
needs `scheme: https` and a `tlsConfig` pointing at the cluster's CA — see
`PLAYBOOK.md` if that applies to you.

## Verifying, Then the Payoff

Once the `PodMonitor` exists and Prometheus has picked it up, the fastest
sanity check is querying `cnpg_collector_up` for your cluster — if it's
`1`, the exporter is being scraped and everything above worked. From
there, CNPG's community Grafana dashboard is the actual payoff: point it
at this same Prometheus and you get replication status, backup age, WAL
metrics and connection usage without writing a single panel yourself.

*This is the floor the rest of the series builds on — fleet-wide
aggregation across clusters, per-object and per-query dashboards, and
eventually the log-collection pipeline, all assume this basic scrape path
already exists and works.*
