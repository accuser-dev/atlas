#!/usr/bin/env python3
"""
Dynamic Ansible inventory from Terraform/OpenTofu outputs.

Reads `tofu output -json` from the appropriate environment directory
and generates an Ansible inventory for configured services.

Usage:
    ENV=cluster01 ansible-inventory --list
    ENV=cluster01 ansible-playbook playbooks/forgejo-runner.yml
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def get_env_dir() -> Path:
    """Get the environment directory based on ENV variable."""
    env = os.environ.get("ENV", "cluster01")
    repo_root = Path(__file__).parent.parent.parent
    env_dir = repo_root / "environments" / env

    if not env_dir.exists():
        sys.stderr.write(f"Error: Environment directory not found: {env_dir}\n")
        sys.exit(1)

    return env_dir


def get_terraform_output(env_dir: Path) -> dict:
    """Run tofu output and return parsed JSON."""
    try:
        result = subprocess.run(
            ["tofu", "output", "-json"],
            cwd=env_dir,
            capture_output=True,
            text=True,
            check=True,
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        sys.stderr.write(f"Error running tofu output: {e.stderr}\n")
        sys.exit(1)
    except json.JSONDecodeError as e:
        sys.stderr.write(f"Error parsing tofu output: {e}\n")
        sys.exit(1)


def get_incus_remote() -> str:
    """Get the Incus remote name based on ENV variable."""
    env = os.environ.get("ENV", "cluster01")
    # For cluster environments, use the cluster remote
    if env == "cluster01":
        return "cluster01"
    # For iapetus (local), no remote prefix needed
    return ""


def build_inventory(tf_output: dict) -> dict:
    """Build Ansible inventory from Terraform outputs."""
    env = os.environ.get("ENV", "cluster01")
    incus_remote = get_incus_remote()

    # Define all service groups
    service_groups = [
        "forgejo_runners",
        "prometheus",
        "forgejo",
        "postgresql",
        "alertmanager",
        "step_ca",
        "mosquitto",
        "alloy",
        "grafana",
        "loki",
        "coredns",
        "openfga",
        "dex",
    ]

    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "children": service_groups
        },
    }

    # Initialize all groups with connection settings
    for group in service_groups:
        inventory[group] = {
            "hosts": [],
            "vars": {
                "ansible_connection": "community.general.incus",
                "ansible_incus_remote": incus_remote,
            }
        }

    # Helper function to add instances to a group
    def add_instances_to_group(group_name: str, instances_key: str, vars_key: str):
        if instances_key in tf_output:
            instances = tf_output[instances_key]["value"]
            # Skip if instances is None or empty
            if instances:
                for instance_name, instance_data in instances.items():
                    # Add to group
                    inventory[group_name]["hosts"].append(instance_name)
                    # Add host variables
                    inventory["_meta"]["hostvars"][instance_name] = {
                        "ansible_incus_host": instance_name,
                        "ipv4_address": instance_data.get("ipv4_address", ""),
                    }

        # Add ansible_vars from Terraform if available and not null
        if vars_key in tf_output:
            ansible_vars = tf_output[vars_key]["value"]
            if ansible_vars is not None:
                inventory[group_name]["vars"].update(ansible_vars)

    # Process each service group
    add_instances_to_group(
        "forgejo_runners",
        "forgejo_runner_instances",
        "forgejo_runner_ansible_vars"
    )
    add_instances_to_group(
        "prometheus",
        "prometheus_instances",
        "prometheus_ansible_vars"
    )
    add_instances_to_group(
        "forgejo",
        "forgejo_instances",
        "forgejo_ansible_vars"
    )
    add_instances_to_group(
        "postgresql",
        "postgresql_instances",
        "postgresql_ansible_vars"
    )
    add_instances_to_group(
        "alertmanager",
        "alertmanager_instances",
        "alertmanager_ansible_vars"
    )
    add_instances_to_group(
        "step_ca",
        "step_ca_instances",
        "step_ca_ansible_vars"
    )
    add_instances_to_group(
        "mosquitto",
        "mosquitto_instances",
        "mosquitto_ansible_vars"
    )
    add_instances_to_group(
        "alloy",
        "alloy_instances",
        "alloy_ansible_vars"
    )
    add_instances_to_group(
        "grafana",
        "grafana_instances",
        "grafana_ansible_vars"
    )
    add_instances_to_group(
        "loki",
        "loki_instances",
        "loki_ansible_vars"
    )
    add_instances_to_group(
        "coredns",
        "coredns_instances",
        "coredns_ansible_vars"
    )
    add_instances_to_group(
        "openfga",
        "openfga_instances",
        "openfga_ansible_vars"
    )
    add_instances_to_group(
        "dex",
        "dex_instances",
        "dex_ansible_vars"
    )

    return inventory


def main():
    """Main entry point."""
    # Parse arguments
    if len(sys.argv) == 2 and sys.argv[1] == "--list":
        env_dir = get_env_dir()
        tf_output = get_terraform_output(env_dir)
        inventory = build_inventory(tf_output)
        print(json.dumps(inventory, indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == "--host":
        # Return empty dict for host mode (not used with _meta)
        print(json.dumps({}))
    else:
        sys.stderr.write("Usage: terraform.py --list | --host <hostname>\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
