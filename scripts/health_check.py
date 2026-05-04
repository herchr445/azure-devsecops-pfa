#!/usr/bin/env python3
# ================================================================
# PFA DevSecOps Project - Health Check Script
# Checks if all infrastructure components are running
# Can be run manually or scheduled via cron job
# ================================================================

import requests
import subprocess
import json
import datetime
import sys
import os

# ──────────────────────────────────────────────────────────────
# CONFIGURATION
# ──────────────────────────────────────────────────────────────

AZ_CMD = r"C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
VM_PUBLIC_IP = "20.215.191.94"
MONITOR_IP = "20.215.185.239"

CHECKS = {
    "nginx_http":    f"http://{VM_PUBLIC_IP}",
    "grafana_ui":    f"http://{MONITOR_IP}:3000",
    "prometheus_ui": f"http://{MONITOR_IP}:9090",
}

LOG_FILE = "health_check_results.log"

# ──────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ──────────────────────────────────────────────────────────────

def log(message, level="INFO"):
    """Write message to console and log file."""
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] [{level}] {message}"
    print(log_entry)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(log_entry + "\n")

def check_http(name, url, timeout=10):
    """Check if an HTTP endpoint is responding."""
    try:
        response = requests.get(url, timeout=timeout)
        if response.status_code < 500:
            log(f"✅ {name}: HEALTHY (HTTP {response.status_code}, {response.elapsed.total_seconds():.2f}s)")
            return True
        else:
            log(f"❌ {name}: UNHEALTHY (HTTP {response.status_code})", "ERROR")
            return False
    except requests.exceptions.ConnectionError:
        log(f"❌ {name}: UNREACHABLE (Connection refused)", "ERROR")
        return False
    except requests.exceptions.Timeout:
        log(f"❌ {name}: TIMEOUT (>{timeout}s)", "ERROR")
        return False
    except Exception as e:
        log(f"❌ {name}: ERROR ({str(e)})", "ERROR")
        return False

def check_azure_vm(resource_group, vm_name):
    """Check Azure VM power state via Azure CLI."""
    try:
        result = subprocess.run([
            AZ_CMD, "vm", "get-instance-view",
            "--resource-group", resource_group,
            "--name", vm_name,
            "--query", "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus",
            "--output", "tsv"
        ], capture_output=True, text=True, timeout=30)

        status = result.stdout.strip()
        if "running" in status.lower():
            log(f"✅ Azure VM '{vm_name}': {status}")
            return True
        else:
            log(f"❌ Azure VM '{vm_name}': {status}", "WARNING")
            return False
    except Exception as e:
        log(f"❌ Azure VM '{vm_name}': ERROR ({str(e)})", "ERROR")
        return False

def check_postgresql(resource_group, server_name):
    """Check PostgreSQL server state via Azure CLI."""
    try:
        result = subprocess.run([
            AZ_CMD, "postgres", "flexible-server", "show",
            "--resource-group", resource_group,
            "--name", server_name,
            "--query", "state",
            "--output", "tsv"
        ], capture_output=True, text=True, timeout=30)

        state = result.stdout.strip()
        if state.lower() == "ready":
            log(f"✅ PostgreSQL '{server_name}': {state}")
            return True
        else:
            log(f"❌ PostgreSQL '{server_name}': {state}", "WARNING")
            return False
    except Exception as e:
        log(f"❌ PostgreSQL '{server_name}': ERROR ({str(e)})", "ERROR")
        return False

# ──────────────────────────────────────────────────────────────
# MAIN HEALTH CHECK
# ──────────────────────────────────────────────────────────────

def main():
    log("=" * 60)
    log("PFA DevSecOps - Infrastructure Health Check")
    log("=" * 60)

    results = {}

    # Check 1: HTTP endpoints
    log("\n--- HTTP Endpoint Checks ---")
    for name, url in CHECKS.items():
        results[name] = check_http(name, url)

    # Check 2: Azure VM status
    log("\n--- Azure VM Status ---")
    results["app_vm"] = check_azure_vm("rami-pfa-rg", "rami-vm")
    results["monitor_vm"] = check_azure_vm("rami-pfa-rg", "rami-monitor-vm")

    # Check 3: PostgreSQL status
    log("\n--- Database Status ---")
    results["postgresql"] = check_postgresql("rami-pfa-rg", "psql-rami-pfa")

    # Summary
    log("\n--- Summary ---")
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    log(f"Checks passed: {passed}/{total}")

    if passed == total:
        log("🎉 ALL SYSTEMS HEALTHY!", "SUCCESS")
        sys.exit(0)
    else:
        failed = [k for k, v in results.items() if not v]
        log(f"⚠️  ISSUES DETECTED: {', '.join(failed)}", "WARNING")
        sys.exit(1)

if __name__ == "__main__":
    main()