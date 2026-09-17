# Observability

A series on monitoring CloudNativePG, building from single-cluster basics
up to the full multi-cluster stack (fleet aggregation, object-level and
query-level dashboards, log collection with a tamper-evident audit trail).

- [`monitoring-basics/`](monitoring-basics/README.md) —
  what CNPG exposes natively, deploying kube-prometheus-stack, and wiring
  up a `PodMonitor` by hand now that automatic creation is deprecated.
