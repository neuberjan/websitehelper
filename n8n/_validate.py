#!/usr/bin/env python3
"""
Validates n8n workflow JSON files.
Checks: JSON validity, node connections, orphaned nodes, duplicate IDs.

Usage:
    python3 _validate.py                          # Default: BC MVP Weekly News-10.json
    python3 _validate.py my-workflow.json
"""

import json
import sys
from pathlib import Path
from collections import Counter

def load_workflow(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def get_nodes(wf: dict) -> dict:
    """Returns dict of node name -> node data."""
    nodes = wf.get("nodes", [])
    return {n["name"]: n for n in nodes}

def get_connections(wf: dict) -> list[tuple[str, str, str]]:
    """Returns list of (source, target, connection_type) tuples."""
    conns = []
    for source, outputs in wf.get("connections", {}).items():
        for conn_type, targets_list in outputs.items():
            for targets in targets_list:
                for t in targets:
                    conns.append((source, t["node"], conn_type))
    return conns

def validate(wf: dict) -> list[str]:
    errors = []
    nodes = get_nodes(wf)
    connections = get_connections(wf)

    # Check for duplicate node names
    all_names = [n["name"] for n in wf.get("nodes", [])]
    dupes = [name for name, count in Counter(all_names).items() if count > 1]
    for d in dupes:
        errors.append(f"DUPLIKAT: Node-Name '{d}' kommt mehrfach vor")

    # Check for duplicate node IDs
    all_ids = [n.get("id", "?") for n in wf.get("nodes", [])]
    dupe_ids = [nid for nid, count in Counter(all_ids).items() if count > 1]
    for d in dupe_ids:
        errors.append(f"DUPLIKAT: Node-ID '{d}' kommt mehrfach vor")

    # Check all connection endpoints exist
    connected_nodes = set()
    for source, target, conn_type in connections:
        connected_nodes.add(source)
        connected_nodes.add(target)
        if source not in nodes:
            errors.append(f"VERBINDUNG: Source '{source}' existiert nicht als Node")
        if target not in nodes:
            errors.append(f"VERBINDUNG: Target '{target}' existiert nicht als Node")

    # Check for orphaned nodes (not connected and not a trigger/schedule)
    # Nodes die keine Verbindungen brauchen
    trigger_types = {"n8n-nodes-base.scheduleTrigger", "n8n-nodes-base.manualTrigger",
                     "n8n-nodes-base.webhook", "@n8n/n8n-nodes-langchain.manualChatTrigger",
                     "n8n-nodes-base.stickyNote"}
    for name, node in nodes.items():
        if name not in connected_nodes:
            node_type = node.get("type", "")
            if node_type not in trigger_types:
                # Check if it's an AI sub-node (connected via ai_ prefix)
                is_ai_connected = any(
                    s == name or t == name
                    for s, t, ct in connections
                )
                if not is_ai_connected:
                    errors.append(f"VERWAIST: Node '{name}' ({node_type}) hat keine Verbindungen")

    return errors

def print_connections(wf: dict):
    """Print all connections in readable format."""
    connections = get_connections(wf)
    nodes = get_nodes(wf)

    print(f"\n{'='*60}")
    print(f"  Nodes: {len(nodes)}")
    print(f"  Verbindungen: {len(connections)}")
    print(f"{'='*60}\n")

    # Group by connection type
    by_type: dict[str, list] = {}
    for source, target, conn_type in connections:
        by_type.setdefault(conn_type, []).append((source, target))

    for conn_type, pairs in sorted(by_type.items()):
        label = "Datenfluss" if conn_type == "main" else conn_type.replace("ai_", "AI: ")
        print(f"  [{label}]")
        for source, target in pairs:
            status = "OK" if source in nodes and target in nodes else "FEHLT"
            print(f"    {source} → {target}: {status}")
        print()

def main():
    # Default workflow file
    default_file = "BC MVP Weekly News-10.json"

    if len(sys.argv) > 1:
        workflow_path = sys.argv[1]
    else:
        workflow_path = str(Path(__file__).parent / default_file)

    if not Path(workflow_path).exists():
        print(f"Datei nicht gefunden: {workflow_path}")
        sys.exit(1)

    print(f"Validiere: {Path(workflow_path).name}")

    try:
        wf = load_workflow(workflow_path)
    except json.JSONDecodeError as e:
        print(f"JSON UNGÜLTIG: {e}")
        sys.exit(1)

    print("JSON: valide ✓")

    print_connections(wf)

    errors = validate(wf)
    if errors:
        print(f"{'!'*60}")
        print(f"  {len(errors)} Problem(e) gefunden:")
        for e in errors:
            print(f"    ✗ {e}")
        print(f"{'!'*60}")
        sys.exit(1)
    else:
        print("Ergebnis: Alles OK ✓")

if __name__ == "__main__":
    main()
