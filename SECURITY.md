# Security

## What this repository is

The first landing zone I built, kept as the record of it. Feature work is frozen
and the current platform work lives in
[novapay-security-infra](https://github.com/mikedemis1/novapay-security-infra).

It is a lab. It was applied against a real AWS account and destroyed after each
test. Nothing here has ever held real data.

## Reporting something

Open an issue, or use GitHub's private vulnerability reporting if the finding
should not be public first.

Since the repository is frozen, expect a fix only where the Terraform would
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
