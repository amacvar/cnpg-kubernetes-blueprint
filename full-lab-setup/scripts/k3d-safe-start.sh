#!/bin/bash
# Start all k3d clusters on this Docker host, working around a real k3d/k3s
# bug: containers on the shared "multi-cluster-net" bridge don't keep stable
# IPs across a stop/start (Docker's IPAM can hand out a different address),
# but a k3s agent caches the server's IP on disk after it first joins
# (/var/lib/rancher/k3s/agent/etc/k3s-agent-load-balancer.json) and only
# re-resolves DNS if that cached address stops answering entirely. In a
# multi-cluster lab, several k3s servers share the same network and port
# 6443 — so a stale cached IP can land on a *different* cluster's server,
# which still answers TCP fine (just rejects the credentials), so k3s never
# falls back to DNS. Symptom: a node stuck looping "not authorized" that
# looks like a token/cert problem but isn't. Root-caused and reproduced
# 2026-09-19 — see project-cnpg-blueprint-lab memory for the full writeup.
#
# Use this instead of a plain `k3d cluster start --all` any time the
# clusters were stopped (e.g. before a host reboot) and are now being
# started back up.
#
# This script only clears that specific stale-cache symptom. It does NOT
# handle the separate "invalid IP" Docker network-endpoint corruption seen
# on the same class of bug (fix there is `docker network disconnect` +
# `connect` on the affected container) — that one has been rarer and needs
# a human to notice `docker inspect` reporting `invalid IP`.
set -euo pipefail

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
