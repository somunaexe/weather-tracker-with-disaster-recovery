# ⛅ Multi-Cloud Weather Tracker with Disaster Recovery

A production-grade weather tracking application deployed across **AWS** and **Azure** with automated DNS failover, infrastructure-as-code via Terraform, and a CI/CD pipeline using GitHub Actions.

> Built as a portfolio project to demonstrate multi-cloud architecture, infrastructure automation, disaster recovery engineering, and DevOps practices — not just a working app, but a showcase of cloud engineering knowledge across the full stack.

---

## 🏗️ Full Architecture
(./architecture.png)
```
<link href="architecture.html" rel="import" />
                    ┌─────────────────────────────────────────────┐
                    │                   USERS                      │
                    └─────────────────────┬───────────────────────┘
                                          │
                    ┌─────────────────────▼───────────────────────┐
                    │           AWS Route53 (DNS Failover)         │
                    │        Health check every 30s on /health     │
                    │    PRIMARY ──────────── SECONDARY (standby)  │
                    └───────────┬──────────────────────┬──────────┘
                                │                      │
                    ┌───────────▼──────┐   ┌───────────▼──────────┐
                    │   AWS (PRIMARY)   │   │   AZURE (SECONDARY)  │
                    │                  │   │   Activates on AWS   │
                    │  EC2 → Node.js   │   │   failure via DNS    │
                    │  PM2 + port 80   │   │   App Service (arch  │
                    │                  │   │   ready, quota issue)│
                    └───────────┬──────┘   └──────────────────────┘
                                │
                    ┌───────────▼──────┐
                    │     AWS S3       │
                    │  Weather history │
                    │  + Terraform     │
                    │    state file    │
                    └──────────────────┘
```

---

## ☁️ AWS Infrastructure

### Networking & Compute

| | Service | What it does in this project |
|---|---|---|
| <img src="https://icon.icepanel.io/AWS/svg/Networking-Content-Delivery/VPC.svg" width="32"> | **VPC** | Isolated private network. CIDR `10.0.0.0/16` split into a public subnet (`10.0.1.0/24`) and private subnet (`10.0.2.0/24`) across two availability zones in `eu-west-2` |
| <img src="https://icon.icepanel.io/AWS/svg/Compute/EC2.svg" width="32"> | **EC2** | `t2.micro` Ubuntu 22.04 LTS instance running the Node.js weather app via PM2. Free tier eligible. Sits in the public subnet with an Elastic IP |
| <img src="https://icon.icepanel.io/AWS/svg/Networking-Content-Delivery/Elastic-IP-address.svg" width="32"> | **Elastic IP** | Permanent public IP attached to the EC2 so the address never changes on restart — critical for Route53 health checks and CI/CD secrets |
| <img src="https://icon.icepanel.io/AWS/svg/Security-Identity-Compliance/Security-Hub.svg" width="32"> | **Security Groups** | Firewall allowing HTTP (80), HTTPS (443), SSH (22) inbound. All outbound allowed. Port 80 is iptables-forwarded to Node.js port 3000 |
| <img src="https://icon.icepanel.io/AWS/svg/Networking-Content-Delivery/Internet-Gateway.svg" width="32"> | **Internet Gateway** | Connects the VPC to the public internet. Attached to the public route table which points `0.0.0.0/0` traffic through it |

### Storage & State

| | Service | What it does in this project |
|---|---|---|
| <img src="https://icon.icepanel.io/AWS/svg/Storage/Simple-Storage-Service.svg" width="32"> | **S3 (weather-tracker-weather-data)** | Stores every weather search as a timestamped JSON file at `weather/{city}/{timestamp}.json`. Historical record of all lookups |
| <img src="https://icon.icepanel.io/AWS/svg/Storage/Simple-Storage-Service.svg" width="32"> | **S3 (weather-tracker-tfstate)** | Terraform remote state backend. Keeps infrastructure state persistent across Codespace sessions. Native S3 locking (`use_lockfile = true`) prevents concurrent state writes |

### DNS, Monitoring & Security

| | Service | What it does in this project |
|---|---|---|
| <img src="https://icon.icepanel.io/AWS/svg/Networking-Content-Delivery/Route-53.svg" width="32"> | **Route53** | DNS with active/passive failover. Pings `/health` on EC2 every 30 seconds. After 3 consecutive failures (~90s), automatically updates DNS to point to Azure |
| <img src="https://icon.icepanel.io/AWS/svg/Management-Governance/CloudWatch.svg" width="32"> | **CloudWatch** | Two alarms: EC2 CPU > 80% (fires if server is struggling) and health check failure (fires when failover activates). Early warning before full outages |
| <img src="https://icon.icepanel.io/AWS/svg/Security-Identity-Compliance/Identity-and-Access-Management.svg" width="32"> | **IAM** | EC2 instance profile with S3 full access. No hardcoded credentials — the EC2 authenticates to S3 automatically via its attached role |
| <img src="https://icon.icepanel.io/AWS/svg/Database/DynamoDB.svg" width="32"> | **DynamoDB** *(deprecated in this setup)* | Originally created for Terraform state locking. Replaced by native S3 `use_lockfile = true` introduced in Terraform 1.10+. Table still exists but is unused |

### Cross-Cloud Networking

| | Service | What it does in this project |
|---|---|---|
| <img src="https://icon.icepanel.io/AWS/svg/Networking-Content-Delivery/Site-to-Site-VPN.svg" width="32"> | **Virtual Private Gateway** | AWS anchor point for the cross-cloud VPN tunnel. Attached to the VPC and propagates routes to the public route table |
| <img src="https://icon.icepanel.io/AWS/svg/Networking-Content-Delivery/Customer-Gateway.svg" width="32"> | **Customer Gateway** | Tells AWS the public IP of the Azure VPN gateway so it knows where to send tunnel traffic |
| <img src="https://icon.icepanel.io/AWS/svg/Networking-Content-Delivery/Site-to-Site-VPN.svg" width="32"> | **VPN Connection** | IPsec tunnel between AWS and Azure. Static routes only. Commented out — re-enable by uncommenting `terraform/modules/networking/main.tf` |

### AWS Network Layout

```
VPC — 10.0.0.0/16 (eu-west-2)
│
├── Internet Gateway
│   └── Route table: 0.0.0.0/0 → IGW
│
├── Public Subnet — 10.0.1.0/24 (eu-west-2a)
│   ├── EC2 Instance (t2.micro, Ubuntu 22.04)
│   │   └── Node.js weather app via PM2
│   └── Elastic IP (permanent public address)
│
├── Private Subnet — 10.0.2.0/24 (eu-west-2b)
│   └── Reserved for databases / private services
│
└── Virtual Private Gateway (vgw)
    └── Customer Gateway → Azure VPN (commented out)
```

---

## 🔷 Azure Infrastructure

### Networking

| | Service | What it does in this project |
|---|---|---|
| <img src="https://icon.icepanel.io/Azure/svg/Management-Governance/Resource-Groups.svg" width="32"> | **Resource Group** | Container for all Azure resources. `weather-tracker-rg` in `uksouth` (London). Everything in this project lives inside it |
| <img src="https://icon.icepanel.io/Azure/svg/Networking/Virtual-Networks.svg" width="32"> | **Virtual Network (VNet)** | Azure equivalent of AWS VPC. CIDR `10.1.0.0/16` — deliberately different from AWS `10.0.0.0/16` to avoid IP conflicts when the two clouds are connected via VPN |
| <img src="https://icon.icepanel.io/Azure/svg/Networking/Subnets.svg" width="32"> | **Subnets** | Public (`10.1.1.0/24`) and private (`10.1.2.0/24`) — mirrors the AWS subnet layout for consistency |
| <img src="https://icon.icepanel.io/Azure/svg/Networking/Network-Security-Groups.svg" width="32"> | **Network Security Group** | Azure's firewall equivalent. Priority-based rules: allow HTTP (100), allow HTTPS (110). Attached to the VNet |

### Compute & Storage

| | Service | What it does in this project |
|---|---|---|
| <img src="https://icon.icepanel.io/Azure/svg/Compute/App-Services.svg" width="32"> | **App Service** *(architecture ready, quota blocked)* | Would host the Node.js weather app as the DR failover target. F1 free plan (Linux). Commented out because Azure free accounts have a VM quota of 0. Full Terraform config exists — re-enable after quota increase or Pay As You Go upgrade |
| <img src="https://icon.icepanel.io/Azure/svg/Compute/App-Service-Plans.svg" width="32"> | **App Service Plan** *(architecture ready, quota blocked)* | Defines the compute resources for the App Service. `F1` SKU (free tier, Linux). Commented out alongside the App Service |
| <img src="https://icon.icepanel.io/Azure/svg/Storage/Storage-Accounts.svg" width="32"> | **Storage Account** | `weathertrackerexe` — Standard LRS storage account. Azure equivalent of AWS S3. Hosts the blob container for weather data |
| <img src="https://icon.icepanel.io/Azure/svg/Storage/Storage-Accounts.svg" width="32"> | **Blob Container** | Private container `weather-data` inside the storage account. Mirrors the S3 bucket structure for weather history when the app runs on Azure |

### Cross-Cloud Networking *(configured, commented out — ~£25/month)*

| | Service | What it does in this project |
|---|---|---|
| <img src="https://icon.icepanel.io/Azure/svg/Networking/Virtual-Network-Gateways.svg" width="32"> | **VPN Gateway** | Azure side of the cross-cloud IPsec tunnel. `VpnGw1AZ` SKU with zone redundancy. Takes 30-45 minutes to provision. Commented out to avoid the fixed monthly charge |
| <img src="https://icon.icepanel.io/Azure/svg/Networking/Local-Network-Gateways.svg" width="32"> | **Local Network Gateway** | Tells Azure where the AWS network is — stores the AWS tunnel IP and CIDR `10.0.0.0/16`. Required for Azure to know how to route traffic to AWS |
| <img src="https://icon.icepanel.io/Azure/svg/Networking/Virtual-Network-Gateways.svg" width="32"> | **VPN Connection** | The actual IPsec connection on the Azure side. Uses a shared key that matches the AWS VPN connection. Status was `Connected` when both gateways were active |
| <img src="https://icon.icepanel.io/Azure/svg/Networking/Public-IP-Addresses.svg" width="32"> | **Public IP** | Static Standard SKU IP for the VPN gateway. Zone redundant (`zones = ["1","2","3"]`). Required by Azure VPN Gateway — it cannot use a dynamic IP |
| <img src="https://icon.icepanel.io/Azure/svg/Networking/Subnets.svg" width="32"> | **Gateway Subnet** | Special subnet `GatewaySubnet` (`10.1.255.0/27`) required by Azure specifically for VPN gateways. Azure enforces this naming convention |

### Azure Network Layout

```
Resource Group — weather-tracker-rg (uksouth)
│
└── Virtual Network — 10.1.0.0/16
    │
    ├── Public Subnet — 10.1.1.0/24
    │   └── App Service (failover target — architecture ready, quota blocked)
    │
    ├── Private Subnet — 10.1.2.0/24
    │   └── Reserved for private resources
    │
    └── GatewaySubnet — 10.1.255.0/27
        ├── VPN Gateway (commented out — ~£25/month)
        └── Public IP (static, zone-redundant)
```

---

## 🔗 Multi-Cloud Networking

The architecture supports **private cross-cloud communication** via an IPsec VPN tunnel. Commented out in the current deployment to save cost, but the full Terraform configuration exists and can be re-enabled instantly.

```
AWS (eu-west-2)                              Azure (uksouth)
──────────────────────────────────────────────────────────────
Virtual Private Gateway (vgw)  ←──────────→  VPN Gateway (vng)
        │                       IPsec/IKE          │
Customer Gateway (cgw)          shared key   Local Network Gateway
        │                                          │
VPN Connection                              VPN Connection
Static route: 10.1.0.0/16 → tunnel         Route: 10.0.0.0/16 → tunnel
```

**Why this matters:** In production, if the app used a shared database or microservices split across clouds, all inter-cloud traffic would flow through this encrypted private tunnel — never over the public internet. For this project, DNS failover handles disaster recovery independently of the VPN.

---

## 🚨 Disaster Recovery

### How Failover Works

```
Normal:   User → Route53 → EC2 (AWS) ✅ 200 OK

Disaster:
  t=0s    EC2 goes down
  t=30s   Route53 health check fails (attempt 1)
  t=60s   Route53 health check fails (attempt 2)
  t=90s   Route53 health check fails (attempt 3) → threshold met
  t=90s   CloudWatch alarm fires: "weather-tracker-health-check-failed"
  t=90s   Route53 updates DNS → points to Azure App Service
  t=90s+  User → Route53 → Azure ✅

Recovery:
  EC2 restarts → health check passes → Route53 switches back to AWS automatically
```

**RTO (Recovery Time Objective):** ~90 seconds  
**RPO (Recovery Point Objective):** 0 — weather data is fetched live from OpenWeatherMap on every request

### Route53 Records

| Record | Type | Target | Role |
|---|---|---|---|
| `weathertracker-app.com` | A | EC2 Elastic IP | PRIMARY — serves all traffic normally |
| `www.weathertracker-app.com` | CNAME | Azure App Service URL | SECONDARY — standby, activates on primary failure |

---

## 🏗️ Infrastructure as Code

All infrastructure is defined in Terraform and split into reusable modules:

```
terraform/
├── environments/
│   ├── main.tf           → provider config, S3 backend, module wiring
│   ├── variables.tf      → input variable declarations (no values here)
│   ├── outputs.tf        → values printed to terminal after apply
│   └── terraform.tfvars  → actual values (gitignored, never committed)
│
└── modules/
    ├── aws/              → VPC, subnets, IGW, EC2, EIP, S3, security groups, IAM
    ├── azure/            → resource group, VNet, NSG, storage, app service
    ├── networking/       → VPN gateways, customer gateway, cross-cloud tunnel
    └── dr/               → Route53 health checks, DNS records, CloudWatch alarms
```

**Key Terraform concepts demonstrated:**
- Remote state in S3 with native locking (`use_lockfile = true`)
- Module composition — parent passes variables down, modules send outputs up
- `prevent_destroy` lifecycle rules on critical resources
- `terraform import` workflow for recovering from state mismatches
- Targeted applies (`-target`) for surgical infrastructure changes
- State management (`terraform state rm`, `terraform force-unlock`)

---

## 🔄 CI/CD Pipeline

Every push to `main` automatically deploys the latest code to EC2:

```
git push → GitHub Actions spins up Ubuntu runner
                  ↓
         Checkout code + npm install
                  ↓
         SSH into EC2 (appleboy/ssh-action)
                  ↓
         git clone (first run) or git pull (subsequent)
                  ↓
         npm install on EC2
                  ↓
         pm2 restart (or pm2 start if first deploy)
                  ↓
         Deployment complete ✅
```

**GitHub Actions secrets used (never in code):**

| Secret | Purpose |
|---|---|
| `EC2_PUBLIC_IP` | Elastic IP of the EC2 instance |
| `EC2_SSH_KEY` | Full contents of the `.pem` private key file |
| `WEATHER_API_KEY` | OpenWeatherMap API key — passed to Node.js at runtime |

---

## 🌦️ The Application

A **Node.js/Express** backend with a **vanilla JS** frontend.

### What it does
- Fetches real-time weather for any city via OpenWeatherMap API
- Returns a 5-day forecast in 3-hour intervals
- Saves every search to S3 as a timestamped JSON file
- Exposes `/health` endpoint monitored by Route53 every 30 seconds
- Identifies which cloud is currently serving (`"cloud": "aws"` or `"cloud": "azure"`)

### API Endpoints

| Endpoint | Description | Example Response |
|---|---|---|
| `GET /health` | Route53 health check target | `{"status":"healthy","cloud":"aws"}` |
| `GET /api/weather/:city` | Current weather | temp, humidity, wind, description |
| `GET /api/forecast/:city` | 5-day forecast | array of 3-hour intervals |

### S3 Data Structure

```
weather-tracker-weather-data/
└── weather/
    ├── London/
    │   ├── 1779931085230.json    ← { city, temp, humidity, timestamp, cloud }
    │   └── 1779934521000.json
    └── Lagos/
        └── 1779928523166.json
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Primary Cloud | AWS (`eu-west-2` — London) |
| Secondary Cloud | Azure (`uksouth` — London) |
| Infrastructure as Code | Terraform 1.10+ |
| Runtime | Node.js 18, PM2 |
| Backend Framework | Express.js |
| Primary Storage | AWS S3 |
| Failover Storage | Azure Blob Storage |
| DNS & Failover | AWS Route53 |
| Monitoring | AWS CloudWatch |
| CI/CD | GitHub Actions |
| Weather Data | OpenWeatherMap API (free tier) |
| Development Environment | GitHub Codespaces |

---

## 🚀 Deploying This Yourself

### Prerequisites
- AWS account with IAM user (programmatic access)
- Azure account with a subscription
- Terraform 1.10+
- Node.js 18+
- OpenWeatherMap API key ([free tier](https://openweathermap.org/api))

### Steps

```bash
# 1. Clone the repo
git clone https://github.com/somunaexe/weather-tracker-with-disaster-recovery.git
cd weather-tracker-with-disaster-recovery

# 2. Create the Terraform state S3 bucket
aws s3api create-bucket \
  --bucket your-tfstate-bucket-name \
  --region eu-west-2 \
  --create-bucket-configuration LocationConstraint=eu-west-2

# 3. Configure your variables
cp terraform/environments/terraform.tfvars.example terraform/environments/terraform.tfvars
# edit terraform.tfvars with your values

# 4. Deploy all infrastructure
cd terraform/environments
terraform init
terraform plan
terraform apply

# 5. Deploy the app to EC2
cd ../../app
export WEATHER_API_KEY=your_api_key_here
./deploy.sh
```

### GitHub Actions Setup

Add these to your repo under **Settings → Secrets and variables → Actions**:

```
EC2_PUBLIC_IP     → your EC2 elastic IP
EC2_SSH_KEY       → full contents of your .pem key file
WEATHER_API_KEY   → your OpenWeatherMap API key
```

---

## 📝 Architecture Decisions & Lessons Learned

**Why Route53 for failover instead of a load balancer?**  
Route53 DNS failover is cloud-agnostic — it can route between AWS and Azure. A load balancer is cloud-specific and cannot natively route to another cloud provider.

**Why PM2 instead of Docker?**  
Keeps things simple on a `t2.micro` free tier instance. Docker adds overhead without meaningful benefit at this scale. PM2 provides process management, auto-restart, and logging natively.

**Why is the VPN commented out?**  
The Azure VPN Gateway costs ~£25/month regardless of usage. For this app, Route53 DNS failover handles disaster recovery independently. The full configuration exists in `terraform/modules/networking/main.tf` and can be enabled by uncommenting it.

**Why is the Azure App Service commented out?**  
Azure free accounts enforce a VM quota of 0 in most regions, blocking App Service creation even on the free F1 plan. The full Terraform config is ready — it requires either upgrading to Pay As You Go or requesting a quota increase.

**Why S3 for Terraform state?**  
GitHub Codespaces resets the local filesystem between sessions. S3 keeps state persistent, accessible from any machine, and safe from accidental deletion.

**What I would do differently:**
- Add an Application Load Balancer in front of EC2 for more resilient health checks
- Use AWS Secrets Manager for the API key instead of an environment variable
- Add Terraform workspaces for proper dev/staging/prod environment separation
- Set up SNS email notifications on CloudWatch alarms

---

## 👤 Author

**@somunaexe**  
[GitHub](https://github.com/somunaexe/weather-tracker-with-disaster-recovery)
