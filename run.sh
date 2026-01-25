#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_DIR="$BASE_DIR/models"

echo "[+] Starting ADMET platform"

cleanup() {
  echo "[+] Shutting down..."
  kill 0
}
trap cleanup SIGINT SIGTERM EXIT

# Start model containers
echo "[+] Starting model containers"

apptainer exec \
  --containall \
  "$MODELS_DIR/tox.sif" \
  python server.py --port 9001 &

apptainer exec \
  --containall \
  "$MODELS_DIR/pk.sif" \
  python server.py --port 9002 &

apptainer exec \
  --containall \
  "$MODELS_DIR/solubility.sif" \
  python server.py --port 9003 &

sleep 3  # give them time to boot

# Start orchestrator
echo "[+] Starting orchestrator"

apptainer exec \
  --containall \
  orchestrator.sif \
  uvicorn orchestrator:app \
    --host 0.0.0.0 \
    --port 8080
