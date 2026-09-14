# Security

## What this repository is

The first landing zone I built: private-subnet access with no SSH, no NAT
gateway and no inbound path, proven end to end over SSM Session Manager. A
separate, later project,
[novapay-security-infra](https://github.com/mikedemis1/novapay-security-infra),
builds an independent multi-account landing zone from scratch; it does not
extend or depend on this repo's code.

It is a lab. It was applied against a real AWS account and destroyed after each
test. Nothing here has ever held real data.

## Reporting something

Open an issue, or use GitHub's private vulnerability reporting if the finding
should not be public first.

This repo gets fixes on request, weighted toward anything the Terraform would
teach someone the wrong thing. A finding that matters is worth reporting for
exactly that reason: this code is read as an example.

## What is already known

- No customer-managed keys on most resources. Defaults were used deliberately to
  keep the account inside a small budget, and the README says so.
- Phase 5, monitoring and alerting, was never built. There are no alarms and no
  notifications, so nothing here tells you when something changes.
- The account it ran in no longer exists in the state this code assumes.
  `terraform plan` against a fresh account will differ.

## Secrets

None in the tree, and gitleaks runs over the history. Account identifiers that
appear in the README are the lab's and the lab is gone.
