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
- IAM role prepared for SSM-based access (no SSH, no port 22) — instance not deployed yet
- Encrypted S3 storage with public access fully blocked
- CloudTrail audit logging across all regions
- VPC flow logs for network-level visibility

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
    |--- Private Subnet (10.0.2.0/24)  → Private SG (inbound from public SG only)
         (no route to the IGW — isolation is enforced by routing, not by the SG)

S3 log archive (encrypted, versioned, TLS-only, public access blocked, 90-day retention)
    |
    |--- CloudTrail   → every AWS API call, all regions
    |--- VPC flow logs → every accepted/rejected network flow in the VPC
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
Phase 4: Audit Logging (CloudTrail + VPC flow logs)  (Completed)
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
- **Private SG** — allows inbound TCP 443 only, and only from the public SG (source is a security group, not a CIDR, so membership decides, not IP). Egress is still open: it is inert today because the private subnet has no internet route, and it is narrowed to the SSM endpoints in Phase 2b
- Rules are standalone `aws_vpc_security_group_ingress_rule` / `egress_rule` resources, one per rule, each with a `description` that states why it exists

### `iam.tf` — IAM Role
An EC2 instance role with SSM access attached, prepared for hosts that are not built yet:
- No SSH keys, no port 22 — the intent is that instances are reached through AWS Systems Manager Session Manager
- No EC2 instance exists in this repo yet, and a host in the private subnet would also need VPC interface endpoints for `ssm`, `ssmmessages`, `ec2messages` to reach SSM (see Known gaps)
- `AmazonSSMManagedInstanceCore` policy attached
- Instance profile created so the role can be assigned to EC2 instances

---

## Phase 3 — Encrypted Storage (Completed)

### `s3.tf` — S3 Bucket
A central log archive. CloudTrail and VPC flow logs both write here, partitioned by AWS under `AWSLogs/<account>/`. One bucket, one policy, one lifecycle; it would be split only if retention or readers diverged.
- **AES256 encryption** (SSE-S3) on all objects by default
- **Versioning enabled** — overwrites keep the previous version. Versions can still be deleted by anyone with `s3:DeleteObjectVersion`; there is no Object Lock or MFA delete (see Known gaps)
- **Public access fully blocked** — all four public access settings set to true
- **ACLs disabled** (`BucketOwnerEnforced`) — the bucket owner owns every object; access is decided by the bucket policy only
- **TLS enforced** — an explicit `Deny` for any request with `aws:SecureTransport = false`, on both the bucket and its objects. A `Deny` is the one place `Principal: "*"` is safe: it can only shrink access
- **Retention is a decision, not an accident** — lifecycle expires current objects after 90 days, non-current versions after 30, and aborts stale multipart uploads after 7
- **Bucket policy** holds every writer's statements in one place: CloudTrail (pinned to the exact trail ARN via `aws:SourceArn`) and flow-log delivery (pinned via `aws:SourceAccount` plus an `ArnLike` on the `logs` service ARN). Both are confused-deputy guards: the service can only write on behalf of this account
- `force_destroy = true` so `terraform destroy` can remove a versioned bucket with objects in it. Lab setting, never for a production archive
- Random suffix on the bucket name to ensure global uniqueness

---

## Phase 4 — Audit Logging (Completed)

### `cloudtrail.tf` — CloudTrail
Records every API call made in the AWS account:
- Multi-region trail — captures activity across all regions, not just eu-west-1
- Global service events included (IAM, STS, etc.)
- Log file validation enabled — detects if logs are tampered with after delivery
- Writes to the log archive from Phase 3; `depends_on` the bucket policy because the trail checks it can write at creation time

### `flow_logs.tf` — VPC Flow Logs
Every accepted and rejected flow in the VPC, delivered to the same log archive:
- `traffic_type = "ALL"` — rejects are the interesting part for detection, accepts for forensics
- S3 destination needs no IAM role; the bucket policy is what authorises `delivery.logs.amazonaws.com`
- `depends_on` the bucket policy, otherwise Terraform may create the flow log first and delivery fails with `Access error`

---

## Known gaps and next decisions

These are the things a reviewer would find first. Listing them here is deliberate: I would rather explain a gap than have it discovered.

| # | Current state | Why it matters | What I would change |
|---|---------------|----------------|---------------------|
| 1 | Both subnets in a single AZ (`eu-west-1a`) | No HA; an ALB needs two AZs | Add a second AZ with a public and private subnet each |
| 2 | ~~Private SG allows all ports/protocols from the public SG~~ Fixed: TCP 443 from the public SG only | Blast radius: a compromised web host could reach every listening port on the app host | Done. Egress on both SGs is still `0.0.0.0/0` and is narrowed together with the SSM endpoints (#3) |
| 3 | SSM role exists but nothing can use it | No instance, and no network path from the private subnet to SSM | Add VPC interface endpoints (`ssm`, `ssmmessages`, `ec2messages`) and a test host, prove a Session Manager session, then destroy |
| 4 | No NAT gateway | Private hosts cannot reach the internet for patches | Intentional for now: endpoints cover AWS APIs at lower cost and smaller surface than NAT |
| 5 | Log bucket uses SSE-S3 (`AES256`), not a KMS CMK | No key policy, no key-usage audit trail (CIS 3.7) | Chosen for cost (~$1/month per key plus API calls). Mitigations in place: TLS deny, public access block, versioning. A CMK earns its place once a second consumer of the logs exists |
| 6 | ~~Bucket policy has no `aws:SecureTransport` deny~~ Fixed | Plaintext HTTP to the log bucket was not forbidden | Done: explicit `Deny` on bucket and objects |
| 7 | Versioning on, lifecycle on, but no Object Lock / MFA delete | Log file validation detects tampering; it does not prevent deletion | Object Lock can only be enabled at bucket creation, never disabled, and with a retention rule it blocks `terraform destroy`. Incompatible with a tear-down lab; right answer for a real archive |
| 8 | CloudTrail writes to S3 and stops | Logs nobody reads are storage, not detection | Phase 5: CloudWatch Logs + metric filters + alarms |
| 9 | ~~No VPC flow logs~~ Fixed | No network-level visibility | Done: flow logs (ALL traffic) to the log archive |
| 10 | Local Terraform state, no backend | State holds every resource and lives on one machine with no locking | S3 backend with DynamoDB locking; kept out of this demo so it deploys in one `apply` |
| 11 | Everything hardcoded (region, CIDRs, names) | Cannot deploy a second environment | Variables + `terraform.tfvars.example` |
| 12 | Flat layout, no modules | Fine at this size | First seam would be `network/` vs `logging/` modules |

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
Using IAM roles and SSM to access EC2 instances means no open port 22, no key pairs to manage, and a full audit trail of every session. It felt like extra complexity at first but it's the right way to do it. What I learned building this: the role alone is not enough — the SSM agent also needs a network path to the SSM endpoints, which a private subnet with no NAT does not have.

**6. CloudTrail needs a specific S3 bucket policy**
CloudTrail doesn't just write to any bucket — it requires the bucket policy to explicitly allow it, and the resource ARN must include the AWS account ID. A wildcard path like `/AWSLogs/*` is not enough. It has to be `/AWSLogs/{account-id}/*`.

**7. Flow logs are delivered by the logs service, not by EC2**
The principal is `delivery.logs.amazonaws.com` and the `aws:SourceArn` to pin is `arn:aws:logs:<region>:<account>:*` with `ArnLike`. Pinning the VPC or flow-log ARN instead looks right and fails silently with `Access error`.

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
