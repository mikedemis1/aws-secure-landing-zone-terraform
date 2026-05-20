# AWS Secure Landing Zone — Terraform

<div align="center">

![Type](https://img.shields.io/badge/Type-Cloud%20Security%20Infrastructure-red?style=for-the-badge&logo=amazonaws)
![Tool](https://img.shields.io/badge/Tool-Terraform-purple?style=for-the-badge&logo=terraform)
![Cloud](https://img.shields.io/badge/Cloud-AWS-orange?style=for-the-badge&logo=amazonaws)
![Status](https://img.shields.io/badge/Status-In%20Progress-blue?style=for-the-badge)

</div>

---

## Project Overview

This is a hands-on infrastructure project I built as part of my journey into Cloud Security. The idea was simple: instead of clicking through the AWS Console, write everything as code using Terraform. That way the setup is reproducible, easy to audit, and something I can actually show in a portfolio.

The goal is to build a secure AWS environment from scratch. Isolated networking, firewall rules, IAM permissions, encrypted storage, and audit logging. Each piece reflects something you would actually find in a production cloud environment.

### What This Project Covers
- Secure AWS network architecture using VPC, subnets, and routing
- Infrastructure as Code with Terraform
- Network isolation between public and private resources
- How VPCs, subnets, gateways, and route tables fit together

---

## Architecture

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

The public subnet has a Route Table that sends all outbound traffic (`0.0.0.0/0`) through the Internet Gateway.
The private subnet has no such route. It is cut off from the internet by design.

---

## Phases

```
Phase 1: Networking (Completed)
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

## Phase 1 — Networking (Completed)

### `providers.tf`
Configures Terraform to use AWS in `eu-west-1` (Ireland).

### `vpc.tf` — Virtual Private Cloud
The isolated network that contains everything. Nothing enters or exits unless explicitly configured.
- CIDR: `10.0.0.0/16`
- DNS support enabled

### `subnets.tf` — Public & Private Subnets
Splits the VPC into two zones:
- **Public Subnet** (`10.0.1.0/24`) — for resources that need internet access
- **Private Subnet** (`10.0.2.0/24`) — for resources that should stay isolated

### `internet_gateway.tf` — Internet Gateway
Connects the VPC to the internet. Attaches at the VPC level, not to individual subnets.

### `route_tables.tf` — Route Tables
Controls where traffic goes:
- Public subnet → `0.0.0.0/0` → Internet Gateway ✅
- Private subnet → no internet route ✅

---

## Upcoming

| Phase | Resource | Purpose |
|-------|----------|---------|
| 2 | Security Groups | Control inbound/outbound traffic per resource |
| 2 | IAM Roles | Define what AWS services are permitted to do |
| 3 | S3 + Encryption | Secure storage with encryption at rest |
| 4 | CloudTrail | Record every action taken in the AWS account |
| 5 | CloudWatch | Alerts and monitoring for infrastructure events |

---

## Lessons Learned

**1. Every resource needs to know which VPC it belongs to**
Every resource — subnets, route tables, gateways — requires a `vpc_id`. At first it felt repetitive, but it makes sense. AWS needs to know which network each resource belongs to. The VPC is the boundary.

**2. The Route Table and the Subnet are not automatically linked**
I assumed the association happened automatically when creating a route table. It doesn't. The `aws_route_table_association` resource is what actually connects them. Without it, the route table exists but has no effect.

**3. The Internet Gateway attaches to the VPC, not the subnet**
My first instinct was that the IGW should go on the public subnet. In reality it attaches to the VPC, and it's the Route Table that makes a subnet public by pointing traffic through the IGW.

**4. Private subnets are isolated through routing, not firewalls**
The private subnet has no internet access simply because it has no route to the internet. No firewall rule needed. Just the absence of a route.

---

## How to Deploy

**Prerequisites:**
- [Terraform](https://developer.hashicorp.com/terraform/install) installed
- AWS CLI configured (`aws configure`)

```bash
terraform init
terraform plan
terraform apply
```

---

## Tech Stack

| Tool | Details |
|------|---------|
| Terraform | v1.15 |
| AWS | eu-west-1 (Ireland) |

---

*Part of an ongoing Cloud Security Engineer portfolio. Phase 2 (Security Groups & IAM) coming next.*
