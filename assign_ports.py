import json
import socket
import sys
import argparse
from pathlib import Path

START_PORT = 18000
OUTPUT_FILE = "container_ports.json"
CONTAINERS_DIR = "containers"

def discover_containers():
    """Discover all .sif files in the containers directory."""
    containers_path = Path(CONTAINERS_DIR)
    if not containers_path.exists():
        raise RuntimeError(f"Containers directory not found: {CONTAINERS_DIR}")
    
    sif_files = list(containers_path.glob("*.sif"))
    if not sif_files:
        raise RuntimeError(f"No .sif files found in {CONTAINERS_DIR}")
    
    return {sif_file.stem: None for sif_file in sif_files}

def find_available_port(start_port=8000, max_attempts=100):
    """Find an available port starting from start_port."""
    for port in range(start_port, start_port + max_attempts):
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.bind(("localhost", port))
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                return port
        except OSError:
            continue
    raise RuntimeError(f"Could not find available port in range {start_port}-{start_port + max_attempts}")


def assign_ports():
    """Assign available ports to each container."""
    containers = discover_containers()
    port_config = {}
    current_port = START_PORT

    for container_name in containers.keys():
        try:
            available_port = find_available_port(current_port)
            port_config[container_name] = available_port
            print(f"✓ {container_name}: {available_port}", file=sys.stderr)
            current_port = available_port + 1
        except RuntimeError as e:
            print(f"✗ Error assigning port to {container_name}: {e}", file=sys.stderr)
            return None

    return port_config


def save_ports(port_config):
    """Save port configuration to JSON file."""
    with open(OUTPUT_FILE, "w") as f:
        json.dump(port_config, f, indent=2)
    print(f"[+] Port configuration saved to {OUTPUT_FILE}", file=sys.stderr)


def load_ports():
    """Load port configuration from JSON file."""
    if Path(OUTPUT_FILE).exists():
        with open(OUTPUT_FILE, "r") as f:
            return json.load(f)
    return None


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Assign ports to containerized models.")
    parser.add_argument("--dir", type=str, default="containers", help="Directory containing container .sif files.")

    args = parser.parse_args()
    CONTAINERS_DIR = args.dir
    print("[+] Assigning ports to containers...", file=sys.stderr)
    port_config = assign_ports()

    if port_config:
        save_ports(port_config)
        print(json.dumps(port_config, indent=2))
    else:
        print("[!] Failed to assign ports", file=sys.stderr)
        sys.exit(1)