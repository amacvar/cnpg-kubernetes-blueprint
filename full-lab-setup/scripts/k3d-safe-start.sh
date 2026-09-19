#!/bin/bash
echo "Starting all k3d clusters..."
k3d cluster start --all

echo "Clearing stale load-balancer cache on every agent and restarting it..."
while read -r c; do
  docker exec "$c" rm -f /var/lib/rancher/k3s/agent/etc/k3s-agent-load-balancer.json 2>/dev/null || true
  docker restart "$c" >/dev/null
  echo "  restarted $c"
done < <(docker ps --filter "label=k3d.role=agent" --format '{{.Names}}')

echo "Waiting for nodes to settle..."
sleep 10

while read -r ctx; do
  echo "== $ctx =="
  kubectl --context "$ctx" get nodes
done < <(kubectl config get-contexts -o name | grep '^k3d-')
