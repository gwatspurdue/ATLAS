import json
import logging
import os
import sys
import requests

# Configuration: request timeout (seconds) and log level come from env variables
REQUEST_TIMEOUT = float(os.environ.get("ORCH_REQUEST_TIMEOUT", "5"))
LOG_LEVEL = os.environ.get("ORCH_LOGLEVEL", "INFO").upper()

# Configure logger to write to stdout (so logs appear immediately even when redirected)
logger = logging.getLogger("orchestrator")
if not logger.handlers:
    handler = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(fmt='%(asctime)s %(levelname)s: %(message)s', datefmt='%H:%M:%S')
    handler.setFormatter(formatter)
    logger.addHandler(handler)
logger.setLevel(getattr(logging, LOG_LEVEL, logging.INFO))

# Shared requests session
session = requests.Session()

class Container:
    def __init__(self, name, port):
        self.name = name
        self.port = port

    def __repr__(self):
        return f"Container(name={self.name}, port={self.port})"

def populate_containers(json_data):
    """
    Populates a list of Container instances from JSON data.

    Args:
        json_data (dict): A mapping of container name -> port.
    """
    containers = []
    for item in json_data:
        containers.append(Container(name=item, port=json_data[item]))
    return containers

def check_containers(timeout=REQUEST_TIMEOUT):
    """
    Checks each container's health status with a configurable timeout.
    """
    # TODO: add check for all endpoints, some containers need new endpoints for this
    for container in containers:
        try:
            logger.info(f"Checking {container.name} on port {container.port}")
            response = session.get(f"http://localhost:{container.port}/health", timeout=timeout)
            try:
                status = response.json().get("status")
            except ValueError:
                logger.warning(f"Invalid JSON from {container.name} (port {container.port})")
                status = None

            if status == "healthy":
                logger.info(f"{container.name} is healthy.")
            else:
                logger.warning(f"{container.name} is not healthy. Status code: {response.status_code}")
        except requests.exceptions.RequestException as e:
            logger.error(f"Error checking {container.name}: {e}")

def smiles_all_containers(smiles, timeout=REQUEST_TIMEOUT):
    """
    Sends SMILES data to all containers for processing with a timeout on POSTs.

    Args:
        smiles (str): The SMILES string to be processed.
    """
    results = {}
    for container in containers:
        try:
            logger.info(f"Posting SMILES to {container.name} (port {container.port})")
            response = session.post(f"http://localhost:{container.port}/smi", json={"smiles": smiles}, timeout=timeout)
            if response.status_code == 200:
                try:
                    results[container.name] = response.json()
                except ValueError:
                    results[container.name] = f"Invalid JSON response: {response.text}"
            else:
                results[container.name] = f"Error: Status code {response.status_code}"
        except requests.exceptions.RequestException as e:
            results[container.name] = f"Error: {e}"
    return results


if __name__ == "__main__":
    logger.info("Starting orchestrator")
    with open('container_ports.json', 'r') as file:
        data = json.load(file)
    containers = populate_containers(data)
    for container in containers:
        logger.info(f"{container} found on port {container.port}")

    check_containers()
    
    logger.info("Sending test SMILES to all containers...")
    test_smiles = "C1=CC=CC=C1"  # Example SMILES for benzene
    results = smiles_all_containers(test_smiles)
    for container_name, result in results.items():
        logger.info(f"Results from {container_name}: {result}")
    logger.info("Orchestrator run complete")