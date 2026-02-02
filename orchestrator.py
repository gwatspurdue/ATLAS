import json
import requests

class Container:
    def __init__(self, name, port):
        self.name = name
        self.port = port

    def __repr__(self):
        return f"Container(name={self.name}, port={self.port})"

def populate_containers(json_data):
    """
    Populates a list of container dictionaries from JSON data.

    Args:
        json_data (str): A JSON string representing a list of containers and ports.
    """
    containers = []
    for item in json_data:
        containers.append(Container(name=item, port=json_data[item]))
    return containers

def check_containers():
    """
    Checks each of the containers health status to see if they are ready/compatible
    """
    for container in containers:
        try:
            response = requests.get(f"http://localhost:{container.port}/health")
            if response.json().get("status") == "healthy":
                print(f"{container.name} is healthy.")
            else:
                print(f"{container.name} is not healthy. Status code: {response.status_code}")
        except requests.exceptions.RequestException as e:
            print(f"Error checking {container.name}: {e}")


if __name__ == "__main__":
    with open('container_ports.json', 'r') as file:
        data = json.load(file)
    containers = populate_containers(data)
    for container in containers:
        print(container, " found on port ", container.port)
    check_containers()