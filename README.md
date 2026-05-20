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
- Security groups to control traffic at the resource level
- IAM roles with least-privilege access (SSM instead of SSH)
- Encrypted S3 storage with public access fully blocked
- CloudTrail audit logging across all regions

---

## Architecture

```
Internet
    |
Internet Gateway
    |
VPC (10.0.0.0/16)
    |
    |--- Public Subnet (10.0.1.0/24)   → Public SG (HTTPS only)
    |
    |--- Private Subnet (10.0.2.0/24)  → Private SG (no internet, public SG only)

S3 Bucket (encrypted, versioned, public access blocked)
    |
CloudTrail → writes all AWS API activity to S3
```

The public subnet accepts inbound HTTPS (443) from the internet.
The private subnet accepts traffic only from the public security group — nothing else can reach it.

---

## Phases

```
Phase 1: Networking        (Completed)
         ↓
Phase 2: Security Groups & IAM  (Completed)
         ↓
Phase 3: Encrypted Storage (S3)  (Completed)
         ↓
Phase 4: Audit Logging (CloudTrail)  (Completed)
         ↓
Phase 5: Monitoring & Alerting  (Upcoming)
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

## Phase 2 — Security Groups & IAM (Completed)

### `security_groups.tf` — Firewall Rules
Two security groups, one per subnet:
- **Public SG** — allows inbound HTTPS (443) from anywhere, all outbound
- **Private SG** — allows inbound traffic only from the public SG, nothing from the internet

### `iam.tf` — IAM Role
An EC2 instance role with SSM access attached:
- No SSH keys, no port 22 — instances are accessed through AWS Systems Manager
- `AmazonSSMManagedInstanceCore` policy attached
- Instance profile created so the role can be assigned to EC2 instances

---

## Phase 3 — Encrypted Storage (Completed)

### `s3.tf` — S3 Bucket
A dedicated logging bucket with the following:
- **AES256 encryption** on all objects by default
- **Versioning enabled** — nothing gets permanently deleted without a trace
- **Public access fully blocked** — all four public access settings set to true
- Random suffix on the bucket name to ensure global uniqueness

---

## Phase 4 — Audit Logging (Completed)

### `cloudtrail.tf` — CloudTrail
Records every API call made in the AWS account:
- Multi-region trail — captures activity across all regions, not just eu-west-1
- Global service events included (IAM, STS, etc.)
- Log file validation enabled — detects if logs are tampered with after delivery
- Writes to the encrypted S3 bucket from Phase 3

---

## Upcoming

| Phase | Resource | Purpose |
|-------|----------|---------|
| 5 | CloudWatch Alarms | Alert on suspicious activity (root login, failed auth, etc.) |
| 5 | SNS Notifications | Send alerts to email when alarms trigger |

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

**5. SSM over SSH is a real security improvement**
Using IAM roles and SSM to access EC2 instances means no open port 22, no key pairs to manage, and a full audit trail of every session. It felt like extra complexity at first but it's the right way to do it.

**6. CloudTrail needs a specific S3 bucket policy**
CloudTrail doesn't just write to any bucket — it requires the bucket policy to explicitly allow it, and the resource ARN must include the AWS account ID. A wildcard path like `/AWSLogs/*` is not enough. It has to be `/AWSLogs/{account-id}/*`.

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

*Part of an ongoing Cloud Security Engineer portfolio. Phase 5 (Monitoring & Alerting) coming next.*
