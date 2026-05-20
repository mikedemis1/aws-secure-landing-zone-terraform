# AWS Secure Landing Zone — Terraform

<div align="center">

![Type](https://img.shields.io/badge/Type-Cloud%20Security%20Infrastructure-red?style=for-the-badge&logo=amazonaws)
![Tool](https://img.shields.io/badge/Tool-Terraform-purple?style=for-the-badge&logo=terraform)
![Cloud](https://img.shields.io/badge/Cloud-AWS-orange?style=for-the-badge&logo=amazonaws)
![Status](https://img.shields.io/badge/Status-In%20Progress-blue?style=for-the-badge)

</div>

---

## 🎯 Project Overview

This is a hands-on infrastructure project I built as part of my journey to become a Cloud Security Engineer. Instead of clicking through the AWS Console, everything is written as code using Terraform — making the setup reproducible, version-controlled, and auditable.

The goal is to deploy a secure AWS environment from scratch: isolated networking, firewall rules, IAM permissions, encrypted storage, and full audit logging. Each component is deliberately chosen to reflect real-world cloud security practices.

### What This Project Demonstrates
- Designing and deploying secure AWS network architecture
- Infrastructure as Code (IaC) with Terraform
- Network isolation between public and private resources
- Understanding of how VPCs, subnets, and routing work together

---

## 🏗️ Architecture

```
Internet
    |
Internet Gateway
    |
VPC (10.0.0.0/16)
    |
    |--- Public Subnet (10.0.1.0/24)   → internet-facing resources (web servers)
    |
    |--- Private Subnet (10.0.2.0/24)  → isolated resources (databases, app servers)
```

The public subnet has a Route Table that directs all outbound traffic (`0.0.0.0/0`) through the Internet Gateway.
The private subnet has no such route — it is intentionally cut off from the internet.

---

## 📋 Phases

```
Phase 1: Networking (Current)
         ↓
Phase 2: Security Groups & IAM
         ↓
Phase 3: Encrypted Storage (S3)
         ↓
Phase 4: Audit Logging (CloudTrail)
         ↓
Phase 5: Monitoring & Alerting
```

---

## ✅ Phase 1 — Networking (Completed)

### `providers.tf`
Configures Terraform to use AWS in `eu-west-1` (Ireland).

### `vpc.tf` — Virtual Private Cloud
The isolated network that contains all resources. Nothing enters or exits unless explicitly allowed.
- CIDR: `10.0.0.0/16`
- DNS support enabled

### `subnets.tf` — Public & Private Subnets
Divides the VPC into two zones:
- **Public Subnet** (`10.0.1.0/24`) — for resources that need internet access
- **Private Subnet** (`10.0.2.0/24`) — for sensitive resources that must stay isolated

### `internet_gateway.tf` — Internet Gateway
The front door between the VPC and the internet. Attached at the VPC level — not to individual subnets.

### `route_tables.tf` — Route Tables
Directs traffic like a traffic controller:
- Public subnet → `0.0.0.0/0` → Internet Gateway ✅
- Private subnet → no internet route (intentional) ✅

---

## ⏳ Upcoming

| Phase | Resource | Purpose |
|-------|----------|---------|
| 2 | Security Groups | Firewall rules — control inbound/outbound traffic per resource |
| 2 | IAM Roles | Define what AWS services are allowed to do |
| 3 | S3 + Encryption | Secure storage with encryption at rest |
| 4 | CloudTrail | Audit log — every action in the AWS account is recorded |
| 5 | CloudWatch | Alerts and monitoring for infrastructure events |

---

## 📚 Lessons Learned

**1. Everything in a VPC needs to declare where it belongs**
Every resource — subnets, route tables, gateways — needs `vpc_id`. At first this felt repetitive, but it makes sense: AWS needs to know which network each resource belongs to. The VPC is the boundary.

**2. The Route Table and the Subnet are separate things**
I assumed associating a subnet with a route table happened automatically. It doesn't. The `aws_route_table_association` resource is what actually connects them — without it, the route table exists but does nothing.

**3. The Internet Gateway attaches to the VPC, not the subnet**
My instinct was that the IGW should attach to the public subnet directly. In reality it attaches to the VPC, and it's the Route Table that makes a subnet "public" by routing traffic through the IGW.

**4. Private subnets have no internet access by design**
The private subnet is isolated not because of a firewall rule, but simply because it has no route to the internet. This is the simplest and most effective form of network isolation.

---

## 🚀 How to Deploy

**Prerequisites:**
- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- AWS CLI configured (`aws configure`)

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy to AWS
terraform apply
```

---

## 🔧 Tech Stack

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | 1.15 | Infrastructure as Code |
| AWS | — | Cloud Provider |
| Region | eu-west-1 | Ireland |

---

*This project is part of an ongoing Cloud Security Engineer portfolio. Follow for Phase 2 (Security Groups & IAM) updates.*
