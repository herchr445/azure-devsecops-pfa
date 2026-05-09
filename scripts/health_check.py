#!/usr/bin/env python3
# ================================================================
# PFA DevSecOps Project - Health Check Script
# Runs on Azure VM via cron every 5 minutes
# Writes results to PostgreSQL for dashboard display
# ================================================================

import requests
import subprocess
import datetime
import sys
import os
import json

# ──────────────────────────────────────────────────────────────
# CONFIGURATION
# ──────────────────────────────────────────────────────────────

VM_PUBLIC_IP = "20.215.191.94"
MONITOR_IP = "20.215.185.239"
LOG_FILE = "/home/azureuser/logs/health_check.log"

# Database connection (reads from environment or .env file)
DB_CONFIG = {
    "host":     os.getenv("DB_HOST", "psql-rami-pfa.postgres.database.azure.com"),
    "port":     os.getenv("DB_PORT", "5432"),
    "database": os.getenv("DB_NAME", "pfa_app_db"),
    "user":     os.getenv("DB_USER", "psqladmin"),
    "password": os.getenv("DB_PASSWORD", "")
}

HTTP_CHECKS = {
    "nginx_http":    f"http://{VM_PUBLIC_IP}",
    "grafana_ui":    f"http://{MONITOR_IP}:3000",
    "prometheus_ui": f"http://{MONITOR_IP}:9090",
}

# ──────────────────────────────────────────────────────────────
# LOGGING
# ──────────────────────────────────────────────────────────────

def log(message, level="INFO"):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{timestamp}] [{level}] {message}"
    print(entry)
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(entry + "\n")
    except Exception:
        pass

# ──────────────────────────────────────────────────────────────
# DATABASE
# ──────────────────────────────────────────────────────────────

def get_db_connection():
    try:
        import psycopg2
        conn = psycopg2.connect(
            host=DB_CONFIG["host"],
            port=DB_CONFIG["port"],
            database=DB_CONFIG["database"],
            user=DB_CONFIG["user"],
            password=DB_CONFIG["password"],
            sslmode="require"
        )
        return conn
    except ImportError:
        log("psycopg2 not installed - skipping DB write", "WARNING")
        return None
    except Exception as e:
        log(f"DB connection failed: {e}", "WARNING")
        return None

def write_check_to_db(component, status, response_ms, message):
    conn = get_db_connection()
    if not conn:
        return
    try:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO infrastructure_checks
            (component, status, response_ms, checked_at, message)
            VALUES (%s, %s, %s, NOW(), %s)
        """, (component, status, response_ms, message))
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        log(f"DB write failed for {component}: {e}", "WARNING")

# ──────────────────────────────────────────────────────────────
# CHECKS
# ──────────────────────────────────────────────────────────────

def check_http(name, url, timeout=10):
    try:
        start = datetime.datetime.now()
        response = requests.get(url, timeout=timeout)
        ms = int((datetime.datetime.now() - start).total_seconds() * 1000)
        if response.status_code < 500:
            log(f"OK {name}: healthy ({response.status_code}, {ms}ms)")
            write_check_to_db(name, "healthy", ms, f"HTTP {response.status_code}")
            return True
        else:
            log(f"FAIL {name}: unhealthy ({response.status_code})", "ERROR")
            write_check_to_db(name, "unhealthy", ms, f"HTTP {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        log(f"FAIL {name}: unreachable", "ERROR")
        write_check_to_db(name, "unreachable", 0, "Connection refused")
        return False
    except requests.exceptions.Timeout:
        log(f"FAIL {name}: timeout", "ERROR")
        write_check_to_db(name, "timeout", timeout * 1000, "Timeout")
        return False
    except Exception as e:
        log(f"FAIL {name}: {str(e)}", "ERROR")
        write_check_to_db(name, "error", 0, str(e))
        return False

def check_docker_service(name, container_name):
    try:
        result = subprocess.run(
            ["docker", "inspect", "--format", "{{.State.Status}}", container_name],
            capture_output=True, text=True, timeout=10
        )
        status = result.stdout.strip()
        if status == "running":
            log(f"OK {name}: running")
            write_check_to_db(name, "healthy", 0, "Container running")
            return True
        else:
            log(f"FAIL {name}: {status}", "ERROR")
            write_check_to_db(name, "unhealthy", 0, f"Container {status}")
            return False
    except Exception as e:
        log(f"FAIL {name}: {str(e)}", "ERROR")
        write_check_to_db(name, "error", 0, str(e))
        return False

def check_postgresql():
    conn = get_db_connection()
    if conn:
        log("OK postgresql: connected")
        write_check_to_db("postgresql", "healthy", 0, "Connected")
        conn.close()
        return True
    else:
        log("FAIL postgresql: disconnected", "ERROR")
        write_check_to_db("postgresql", "unhealthy", 0, "Connection failed")
        return False

# ──────────────────────────────────────────────────────────────
# MAIN
# ──────────────────────────────────────────────────────────────

def main():
    log("=" * 50)
    log("PFA DevSecOps - Health Check Started")
    log("=" * 50)

    # Load .env if exists
    env_file = "/home/azureuser/app/.env"
    if os.path.exists(env_file):
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, val = line.split("=", 1)
                    os.environ[key] = val
                    if key == "DB_PASSWORD":
                        DB_CONFIG["password"] = val
                    elif key == "DB_HOST":
                        DB_CONFIG["host"] = val

    results = {}

    # HTTP checks
    log("--- HTTP Checks ---")
    for name, url in HTTP_CHECKS.items():
        results[name] = check_http(name, url)

    # Docker container checks
    log("--- Docker Checks ---")
    results["app_container"] = check_docker_service("app_container", "pfa-dashboard")
    results["node_exporter"] = check_docker_service("node_exporter", "node-exporter")

    # Database check
    log("--- Database Check ---")
    results["postgresql"] = check_postgresql()

    # Summary
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    log(f"--- Summary: {passed}/{total} checks passed ---")

    if passed == total:
        log("ALL SYSTEMS HEALTHY")
        sys.exit(0)
    else:
        failed = [k for k, v in results.items() if not v]
        log(f"ISSUES: {', '.join(failed)}", "WARNING")
        sys.exit(1)

if __name__ == "__main__":
    main()