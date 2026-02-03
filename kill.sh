#!/usr/bin/env bash
set -euo pipefail

# Check if container directory argument is provided
if [ $# -eq 0 ]; then
  echo "Usage: $0 <container_directory>"
  exit 1
fi

CONTAINER_DIR="$1"

# Check if container directory is not empty
if [ -z "$CONTAINER_DIR" ]; then
  echo "Container directory cannot be empty."
  exit 1
fi

echo "[+] Stopping ADMET platform"

# Confirm with the user
read -r -p "Are you sure you want to stop all containers and the orchestrator? [y/N] " response
case "$response" in
  [yY][eE][sS]|[yY]) ;;
  *) echo "Aborted."; exit 0 ;;
esac

# Ensure we have pid dir
mkdir -p pids

# Stop model containers
echo "[+] Stopping model containers"
found=false
for container in "$CONTAINER_DIR"/*.sif; do
  # skip if no matching files
  [ -e "$container" ] || continue

  container_name=$(basename "$container" .sif)
  pidfile="pids/${container_name}.pid"

  if [ -f "$pidfile" ]; then
    pids=$(tr '\n' ' ' < "$pidfile" || true)
  else
    # Find processes that reference this container file (singularity run ... <container>.sif)
    pids=$(pgrep -f "singularity .*${container_name}\.sif" || true)
  fi

  if [ -z "$pids" ]; then
    echo "[-] No running process found for $container_name"
    continue
  fi

  found=true
  echo "[+] Found process(es) for $container_name: $pids. Sending SIGTERM..."
  kill $pids || true

  # Wait up to 10 seconds for each pid to exit, then SIGKILL if necessary
  for pid in $pids; do
    for i in {1..10}; do
      if kill -0 "$pid" 2>/dev/null; then
        sleep 1
      else
        break
      fi
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo "[!] $pid did not exit, sending SIGKILL"
      kill -KILL "$pid" || true
    fi
  done

  # Remove pidfile if present
  [ -f "$pidfile" ] && rm -f "$pidfile"

done

if [ "$found" = false ]; then
  echo "[*] No container processes were found."
fi

# Stop orchestrator
echo "[+] Stopping orchestrator"
orch_pidfile="pids/orchestrator.pid"
if [ -f "$orch_pidfile" ]; then
  orch_pids=$(tr '\n' ' ' < "$orch_pidfile" || true)
else
  orch_pids=$(pgrep -f "orchestrator\.py" || true)
fi

if [ -z "$orch_pids" ]; then
  echo "[-] No orchestrator process found"
else
  echo "[+] Found orchestrator PID(s): $orch_pids. Sending SIGTERM..."
  kill $orch_pids || true

  for pid in $orch_pids; do
    for i in {1..10}; do
      if kill -0 "$pid" 2>/dev/null; then
        sleep 1
      else
        break
      fi
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo "[!] $pid did not exit, sending SIGKILL"
      kill -KILL "$pid" || true
    fi
  done

  [ -f "$orch_pidfile" ] && rm -f "$orch_pidfile"
fi

echo "[+] Done."
