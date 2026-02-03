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

sleep 75  # give them time to boot (adjust as necessary)

# Start orchestrator
echo "[+] Starting orchestrator"

python3 orchestrator.py > "logs/orchestrator.log" 2>&1 &
orch_pid=$!
echo "$orch_pid" > "pids/orchestrator.pid"
echo "[+] Recorded orchestrator PID $orch_pid in pids/orchestrator.pid"

# Wait for orchestrator so the script remains running
wait "$orch_pid"