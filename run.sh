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

echo "[+] Starting ADMET platform"

# Create logs and pid directories
mkdir -p logs
mkdir -p pids

# Ensure a placeholder log exists so tail glob has at least one file
touch logs/.placeholder.log

# Start live log viewer so Python output (and other logs) appear on the terminal
# and also append to the log files. PID is recorded so it can be stopped later.
echo "[+] Starting live log viewer (tail -F logs/orchestrator.log)"
tail -n +1 -F logs/orchestrator.log 2>/dev/null | sed -u 's/^/[LOG] /' &
logviewer_pid=$!
echo "$logviewer_pid" > "pids/logviewer.pid"
echo "[+] Recorded log viewer PID $logviewer_pid in pids/logviewer.pid"

# Ensure the live viewer is cleaned up when this script exits
cleanup() {
  if [ -f "pids/logviewer.pid" ]; then
    lvpid=$(cat "pids/logviewer.pid" || true)
    if [ -n "${lvpid:-}" ]; then
      kill "$lvpid" || true
      rm -f "pids/logviewer.pid"
    fi
  fi
}
trap cleanup EXIT

# Load port configuration
PORTS=$(python3 assign_ports.py --dir "$CONTAINER_DIR" 2>&1 | grep -v "^\[" | grep -v "^✓" | grep -v "^✗")

# Start model containers
echo "[+] Starting model containers"

for container in "$CONTAINER_DIR"/*.sif; do
  # skip if no matching files
  [ -e "$container" ] || continue

  container_name=$(basename "$container" .sif)
  port=$(echo "$PORTS" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('$container_name', ''))")
  
  echo "[+] Starting container: $container on port $port"
  singularity run --containall --cleanenv --env PORT="$port" "$container" > "logs/${container_name}.log" 2>&1 &
  pid=$!
  echo "$pid" > "pids/${container_name}.pid"
  echo "[+] Recorded PID $pid for $container_name in pids/${container_name}.pid"
done

echo "[+] All containers are starting..."

# Wait for containers to signal healthy via their /health endpoints (no arbitrary sleep)
WAIT_TIMEOUT="${WAIT_TIMEOUT:-120}"   # seconds per container
WAIT_INTERVAL="${WAIT_INTERVAL:-2}"    # seconds between checks

if [ ! -f container_ports.json ]; then
  echo "container_ports.json not found!"
  exit 1
fi

wait_for() {
  name="$1"
  port="$2"
  timeout="$3"
  interval="$4"
  elapsed=0
  while [ "$elapsed" -lt "$timeout" ]; do
    # Query the health endpoint and parse the JSON "status" field
    status=$(curl -sS "http://localhost:${port}/health" 2>/dev/null | python3 -c 'import sys, json
data = sys.stdin.read()
if not data:
    print("")
else:
    try:
        print(json.loads(data).get("status", ""))
    except Exception:
        print("")')
    if [ "${status}" = "healthy" ]; then
      echo "[+] ${name} is healthy (port ${port})."
      return 0
    fi
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done
  echo "[-] Timeout waiting for ${name} (port ${port}) after ${timeout}s"
  return 1
}

failed=0
# Read container names and ports from container_ports.json
while IFS=$' ' read -r name port; do
  if ! wait_for "$name" "$port" "$WAIT_TIMEOUT" "$WAIT_INTERVAL"; then
    failed=1
  fi
done < <(python3 - <<PY
import json
with open('container_ports.json') as f:
    data = json.load(f)
for k, v in data.items():
    print(k, v)
PY
)

if [ "$failed" -ne 0 ]; then
  echo "[-] Some containers failed to become healthy. See logs/ for details. Exiting."
  exit 1
fi

echo "[+] All containers healthy."

# Start orchestrator
echo "[+] Starting orchestrator"

python3 orchestrator.py > "logs/orchestrator.log" 2>&1 &
orch_pid=$!
echo "$orch_pid" > "pids/orchestrator.pid"
echo "[+] Recorded orchestrator PID $orch_pid in pids/orchestrator.pid"

# Wait for orchestrator so the script remains running
wait "$orch_pid"
sleep 1