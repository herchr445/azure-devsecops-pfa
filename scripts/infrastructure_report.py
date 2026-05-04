#!/usr/bin/env python3
# ================================================================
# PFA DevSecOps Project - Infrastructure Report
# Lists all Azure resources and their status
# Generates a report file
# ================================================================

import subprocess
import json
import datetime
import os

# ──────────────────────────────────────────────────────────────
# CONFIGURATION
# ──────────────────────────────────────────────────────────────

AZ_CMD = r"C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
RESOURCE_GROUP = "rami-pfa-rg"
REPORT_FILE = "infrastructure_report.txt"

# ──────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ──────────────────────────────────────────────────────────────

def run_az_command(args):
    """Run Azure CLI command and return JSON output."""
    try:
        result = subprocess.run(
            [AZ_CMD] + args,
            capture_output=True,
            text=True,
            timeout=60
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
        return None
    except Exception:
        return None

def get_vm_status(vm_name):
    """Get VM power state."""
    result = subprocess.run([
        AZ_CMD, "vm", "get-instance-view",
        "--resource-group", RESOURCE_GROUP,
        "--name", vm_name,
        "--query", "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus",
        "--output", "tsv"
    ], capture_output=True, text=True, timeout=30)
    return result.stdout.strip() if result.returncode == 0 else "Unknown"

# ──────────────────────────────────────────────────────────────
# REPORT SECTIONS
# ──────────────────────────────────────────────────────────────

def generate_report():
    """Generate complete infrastructure report."""
    lines = []
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    lines.append("=" * 60)
    lines.append("PFA DevSecOps - Infrastructure Report")
    lines.append(f"Generated: {now}")
    lines.append(f"Resource Group: {RESOURCE_GROUP}")
    lines.append("=" * 60)

    # Section 1: Virtual Machines
    lines.append("\n--- VIRTUAL MACHINES ---")
    lines.append("-" * 40)
    vms = run_az_command([
        "vm", "list",
        "--resource-group", RESOURCE_GROUP,
        "--query", "[].{Name:name, Size:hardwareProfile.vmSize, Location:location}",
        "--output", "json"
    ])

    if vms:
        for vm in vms:
            status = get_vm_status(vm['Name'])
            lines.append(f"  Name:     {vm['Name']}")
            lines.append(f"  Size:     {vm['Size']}")
            lines.append(f"  Location: {vm['Location']}")
            lines.append(f"  Status:   {status}")
            lines.append("")
    else:
        lines.append("  No VMs found")

    # Section 2: PostgreSQL
    lines.append("\n--- POSTGRESQL DATABASE ---")
    lines.append("-" * 40)
    pg = run_az_command([
        "postgres", "flexible-server", "show",
        "--resource-group", RESOURCE_GROUP,
        "--name", "psql-rami-pfa",
        "--query", "{Name:name, State:state, Version:version, SKU:sku.name}",
        "--output", "json"
    ])

    if pg:
        lines.append(f"  Name:    {pg['Name']}")
        lines.append(f"  State:   {pg['State']}")
        lines.append(f"  Version: {pg['Version']}")
        lines.append(f"  SKU:     {pg['SKU']}")
    else:
        lines.append("  PostgreSQL server not found")

    # Section 3: Key Vault
    lines.append("\n--- KEY VAULT ---")
    lines.append("-" * 40)
    kv = run_az_command([
        "keyvault", "show",
        "--name", "kv-rami-pfa-2026",
        "--query", "{Name:name, Location:location, Status:properties.provisioningState}",
        "--output", "json"
    ])

    if kv:
        lines.append(f"  Name:     {kv['Name']}")
        lines.append(f"  Location: {kv['Location']}")
        lines.append(f"  Status:   {kv['Status']}")

        secrets = run_az_command([
            "keyvault", "secret", "list",
            "--vault-name", "kv-rami-pfa-2026",
            "--query", "length(@)",
            "--output", "json"
        ])
        if secrets is not None:
            lines.append(f"  Secrets:  {secrets} stored")
    else:
        lines.append("  Key Vault not found")

    # Section 4: Network
    lines.append("\n--- NETWORKING ---")
    lines.append("-" * 40)
    vnets = run_az_command([
        "network", "vnet", "list",
        "--resource-group", RESOURCE_GROUP,
        "--query", "[].{Name:name, AddressSpace:addressSpace.addressPrefixes[0]}",
        "--output", "json"
    ])

    if vnets:
        for vnet in vnets:
            lines.append(f"  VNet: {vnet['Name']} ({vnet['AddressSpace']})")
    else:
        lines.append("  No VNets found")

    # Section 5: Policies
    lines.append("\n--- AZURE POLICIES ---")
    lines.append("-" * 40)
    policies = run_az_command([
        "policy", "assignment", "list",
        "--resource-group", RESOURCE_GROUP,
        "--query", "[].{Name:displayName}",
        "--output", "json"
    ])

    if policies:
        for policy in policies:
            lines.append(f"  [OK] {policy['Name']}")
    else:
        lines.append("  No policies found")

    # Summary
    lines.append("\n" + "=" * 60)
    lines.append("SUMMARY")
    lines.append("=" * 60)
    vm_count = len(vms) if vms else 0
    lines.append(f"  Virtual Machines:  {vm_count}")
    lines.append(f"  Databases:         1 (PostgreSQL)")
    lines.append(f"  Key Vaults:        1")
    lines.append(f"  Active Policies:   {len(policies) if policies else 0}")
    lines.append(f"\n  Report saved to:   {REPORT_FILE}")
    lines.append("=" * 60)

    return "\n".join(lines)

# ──────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────

def main():
    print("Generating infrastructure report...")
    report = generate_report()

    # Print to console
    print(report)

    # Save to file
    with open(REPORT_FILE, "w", encoding="utf-8") as f:
        f.write(report)

    print(f"\nReport saved to: {REPORT_FILE}")

if __name__ == "__main__":
    main()