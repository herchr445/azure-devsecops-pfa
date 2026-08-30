# 🔐 DevSecOps Cloud-Native Infrastructure on Microsoft Azure

> **Final Year Project (PFA) — EPI Digital School, 2025-2026**
> Cloud Computing & Network Infrastructure Engineering

[![Terraform CI/CD](https://github.com/herchr445/azure-devsecops-pfa/actions/workflows/terraform.yml/badge.svg)](https://github.com/herchr445/azure-devsecops-pfa/actions/workflows/terraform.yml)
[![Deploy Application](https://github.com/herchr445/azure-devsecops-pfa/actions/workflows/deploy.yml/badge.svg)](https://github.com/herchr445/azure-devsecops-pfa/actions/workflows/deploy.yml)
[![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=herchr445_azure-devsecops-pfa&metric=alert_status)](https://sonarcloud.io/project/overview?id=herchr445_azure-devsecops-pfa)

---

## 📋 Overview

A fully automated, production-grade **DevSecOps infrastructure** deployed on Microsoft Azure, implementing security at every layer of the development lifecycle. This project demonstrates end-to-end cloud automation: from infrastructure provisioning with Terraform to application deployment via CI/CD pipelines, with integrated security scanning, real-time monitoring, and a live dashboard.

**Live Dashboard:** http://20.215.191.94  
**Grafana Monitoring:** http://20.215.185.239:3000  
**SonarCloud Analysis:** https://sonarcloud.io/project/overview?id=herchr445_azure-devsecops-pfa

---

## 🏗️ Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  NSG — Ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)             │
│                                                             │
│  rami-vnet (10.0.0.0/16) — Poland Central                  │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────┐  │
│  │ Subnet App       │  │ Subnet Data      │  │ Subnet   │  │
│  │ 10.0.1.0/24      │  │ 10.0.2.0/24      │  │ Monitor  │  │
│  │                  │  │                  │  │ 10.0.3.x │  │
│  │  rami-vm         │  │  PostgreSQL 15   │  │          │  │
│  │  ├── Nginx :80   │  │  (Private only)  │  │ monitor  │  │
│  │  ├── Node.js:3000│  │  pfa_app_db      │  │ -vm      │  │
│  │  ├── Docker      │◄─┤                  │  │ ├─Prom.  │  │
│  │  └── Node Exp.   │  └──────────────────┘  │ └─Grafana│  │
│  └──────────────────┘                        └──────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
  Azure Key Vault      Azure ACR            GitHub Actions
  kv-rami-pfa-2026   ramidevsecopspfa      CI/CD Pipelines
```

---

## 🛠️ Technology Stack

| Category | Technology | Version |
|---|---|---|
| **Cloud Platform** | Microsoft Azure | - |
| **IaC** | Terraform | 1.5.0 |
| **Provider** | azurerm | ~> 3.80 |
| **OS** | Ubuntu Server | 22.04 LTS |
| **Containerization** | Docker Engine | 29.4.1 |
| **Orchestration** | Docker Compose | 5.1.3 |
| **App Runtime** | Node.js | 18 (Alpine) |
| **Framework** | Express | 4.18.2 |
| **Database** | PostgreSQL | 15 |
| **Reverse Proxy** | Nginx | - |
| **Container Registry** | Azure ACR | Basic |
| **CI/CD** | GitHub Actions | - |
| **Code Quality** | SonarCloud | OSS |
| **Security Scan** | Trivy | - |
| **Metrics** | Prometheus | - |
| **Dashboards** | Grafana | - |
| **System Metrics** | Node Exporter | - |
| **Secret Management** | Azure Key Vault | - |
| **Governance** | Azure Policies | 4 policies |
| **Access Control** | Azure RBAC | - |
| **Automation** | Python | 3.10 |

---

## 📁 Project Structure

```
azure-devsecops-pfa/
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                 # Core: VM, VNet, NSG, NIC, Public IP
│   ├── backend.tf              # Remote state — Azure Storage
│   ├── keyvault.tf             # Azure Key Vault + secrets
│   ├── database.tf             # PostgreSQL + Private DNS
│   ├── policies.tf             # 4 Azure Policies
│   ├── security.tf             # Managed Identity + RBAC
│   ├── monitoring.tf           # Monitor VM
│   └── acr.tf                  # Container Registry
│
├── app/                        # Node.js Application
│   ├── server.js               # Express API + DB logic
│   ├── package.json            # Dependencies
│   ├── Dockerfile              # Container build (node:18-alpine)
│   ├── docker-compose.yml      # App + Node Exporter
│   └── public/
│       └── index.html          # Dashboard UI
│
├── scripts/                    # Python Automation
│   ├── health_check.py         # 6-component health monitor
│   ├── fetch_secrets.py        # Key Vault secret fetcher
│   └── infrastructure_report.py # Azure resource inventory
│
├── .github/
│   └── workflows/
│       ├── terraform.yml       # Infrastructure CI/CD
│       └── deploy.yml          # Application CI/CD
│
└── sonar-project.properties    # SonarCloud configuration
```

---

## 🚀 CI/CD Pipelines

### Pipeline 1: Infrastructure (`terraform.yml`)
Triggered on changes to `terraform/**`

```
Git Push → Trivy Config Scan (23s) → Terraform Validate (9s) → Terraform Plan (12s)
```

- **Trivy**: Scans Terraform files for misconfigurations
- **Terraform Validate**: Verifies HCL syntax and references
- **Terraform Plan**: Compares live Azure state with code (remote backend)

### Pipeline 2: Application (`deploy.yml`)
Triggered on changes to `app/**`, `scripts/**`, `sonar-project.properties`

```
Git Push → SonarCloud (46s) → Build+Trivy+ACR (45s) → Deploy to VM (49s)
Total: 2m 28s
```

- **SonarCloud**: Static code analysis, quality gate enforcement
- **Docker Build**: Containerizes Node.js application
- **Trivy Image Scan**: CVE scanning before push to registry
- **ACR Push**: Versioned image storage (`latest` + commit SHA)
- **SSH Deploy**: Pulls from ACR, restarts containers, records deployment

---

## 🔒 Security Implementation

### Secret Management
All credentials stored in **Azure Key Vault** (`kv-rami-pfa-2026`):
- `postgresql-admin-password`
- `app-secret-key`
- `acr-username`
- `acr-password`

Never stored in code, environment variables, or Docker images.

### Azure Policies (Governance)
| Policy | Effect | Scope |
|---|---|---|
| Require Project tag | Deny | rami-pfa-rg |
| Require Environment tag | Deny | rami-pfa-rg |
| Allowed VM sizes (B-series only) | Deny | rami-pfa-rg |
| Storage HTTPS only | Deny | rami-pfa-rg |

### RBAC
- **Managed Identity** `id-github-actions-pfa`: Contributor on `rami-pfa-rg`
- **Key Vault access**: Get + List secrets only (least privilege)
- **Service Principal**: Credentials stored as GitHub Secrets

### Network Security
- PostgreSQL: **Private network only** (10.0.2.0/24), no internet access
- Private DNS Zone: `privatelink.postgres.database.azure.com`
- SSL enforced on all PostgreSQL connections
- SSH: Key-based authentication only (no passwords)

---

## 📊 Monitoring

**Two-layer monitoring architecture:**

### Layer 1: System Metrics (Prometheus + Grafana)
- Node Exporter collects 500+ metrics every 15 seconds
- Prometheus stores time-series data
- Grafana visualizes: CPU, RAM, Disk, Network
- Dashboard: Node Exporter Full (ID: 1860)

### Layer 2: Service Health (Python + PostgreSQL)
- `health_check.py` runs every 5 minutes via cron
- Checks: Nginx, Grafana, Prometheus, App container, Node Exporter, PostgreSQL
- Results written to PostgreSQL `infrastructure_checks` table
- Displayed in real-time on the Node.js dashboard

---

## 🖥️ Application Dashboard

Live at: **http://20.215.191.94**

| Section | Data Source | Update Frequency |
|---|---|---|
| Application Status | `/api/health` (live) | 30 seconds |
| Infrastructure Info | Static | - |
| Security Status | Static | - |
| Health Checks | PostgreSQL | 5 minutes (cron) |
| Recent Deployments | PostgreSQL | On each deploy |
| System Information | Static | - |

### API Endpoints
```
GET  /api/health        → App + DB status
GET  /api/deployments   → Deployment history
POST /api/deployments   → Record new deployment (called by CI/CD)
GET  /api/checks        → Health check history
GET  /api/status        → Infrastructure info
```

---

## ⚙️ Python Automation Scripts

### `health_check.py`
Runs every 5 minutes via cron on the Azure VM:
```bash
*/5 * * * * cd /home/azureuser && python3 scripts/health_check.py
```
Checks 6 components and writes results to PostgreSQL.

### `fetch_secrets.py`
One-time setup script — fetches secrets from Key Vault and creates `.env`:
```bash
python3 scripts/fetch_secrets.py
```

### `infrastructure_report.py`
Generates a complete Azure resource inventory:
```bash
python3 scripts/infrastructure_report.py
```

---

## 💰 Cost Analysis

| Resource | Size | Monthly Cost |
|---|---|---|
| App VM (rami-vm) | Standard_B2ts_v2 | ~$18 |
| Monitor VM (rami-monitor-vm) | Standard_B2ts_v2 | ~$18 |
| PostgreSQL Flexible Server | B1ms | ~$15 |
| Azure Container Registry | Basic | ~$5 |
| Public IPs (×2) + Storage | Standard | ~$6 |
| **Total** | | **~$62/month** |

Budget available: **$100 Azure for Students** ✅

---

## 🗺️ Azure Resources

| Resource | Name | Region |
|---|---|---|
| Resource Group | rami-pfa-rg | Poland Central |
| Virtual Network | rami-vnet | Poland Central |
| App VM | rami-vm | Poland Central |
| Monitor VM | rami-monitor-vm | Poland Central |
| PostgreSQL | psql-rami-pfa | Poland Central |
| Key Vault | kv-rami-pfa-2026 | Poland Central |
| Container Registry | ramidevsecopspfa | Poland Central |
| Storage (TF state) | stramitfstate2024pfa | Poland Central |

---

## 🔑 GitHub Secrets Required

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | Service Principal App ID |
| `AZURE_CLIENT_SECRET` | Service Principal Password |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |
| `AZURE_TENANT_ID` | Azure Tenant ID |
| `SSH_PRIVATE_KEY` | VM SSH Private Key |
| `VM_PUBLIC_IP` | App VM Public IP |
| `SONAR_TOKEN` | SonarCloud Token |
| `ACR_USERNAME` | Container Registry Username |
| `ACR_PASSWORD` | Container Registry Password |

---

## 📈 Key Metrics

- **45** Azure resources provisioned via Terraform
- **2m 28s** from git push to live deployment
- **6/6** infrastructure components healthy
- **500+** Prometheus metrics collected
- **2** CI/CD pipelines fully automated
- **4** Azure Policies enforcing governance
- **$62/$100** monthly budget used

---

## 🧑‍💻 Author

**Rami Horch**  
Cloud Computing & Network Infrastructure Engineering  
EPI Digital School — EPISousse  
Academic Year: 2025-2026

---

## 📄 License

This project was developed as an academic final year project (PFA) at EPI Digital School. All rights reserved.
