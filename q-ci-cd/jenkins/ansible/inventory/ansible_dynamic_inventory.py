#!/usr/bin/env python3

import os
from pathlib import Path
from funcy import partition
from pydantic import BaseModel


def parse_hosts(comma_separated_data: str) -> tuple[str, ...]:
    host_ip_pairs = partition(2, comma_separated_data.split(","))
    return tuple(f"{host.strip()}.q.ai" for host, ip in host_ip_pairs)


class EnvVariables(BaseModel):
    andromeda_venv_path: Path
    ansible_ssh_user: str


class HostsAndVariables(BaseModel):
    hosts: list[str]
    vars: EnvVariables


class Inventory(BaseModel):
    all: HostsAndVariables


def display_inventory(raw_hosts_data: str):
    hosts = parse_hosts(raw_hosts_data)
    venv_path = os.environ.get("VENV_PATH", '/home/recorder/new-silent-speech-system/venv')
    
    if os.environ.get('RECORDERS_AND_JRECORDERS_TO_UPDATE'):
        env_vars = EnvVariables(
            andromeda_venv_path=Path(venv_path),
            ansible_ssh_user="recorder",
        )
    elif os.environ.get('JETFIRES_TO_UPDATE'):
        env_vars = EnvVariables(
            andromeda_venv_path=Path(venv_path),
            ansible_ssh_user="q",
        )

    inventory = Inventory(all=HostsAndVariables(hosts=hosts, vars=env_vars))
    print(inventory.model_dump_json(indent=4))


if __name__ == "__main__":
    hosts_data = (
        os.environ.get("RECORDERS_AND_JRECORDERS_TO_UPDATE")
        or os.environ.get("JETFIRES_TO_UPDATE")
    )
    
    if hosts_data is None:
        raise ValueError("Environment variable not found")
    
    display_inventory(hosts_data)
