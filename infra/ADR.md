# ADR 0007: Migration from CloudFormation to Terraform

## Context
Infrastructure for Cognito, S3, SQS, and IAM was managed using AWS CloudFormation templates. To achieve better infrastructure-as-code portability, state tracking, and cloud-agnostic modularity, we decided to migrate infrastructure management to Terraform and HCP Terraform.

## Decision
We migrated existing CloudFormation resources to Terraform configurations (`.tf`) using Terraform 1.17+ import blocks (`import {}`).
- Authentication resources (`auth.tf`) were imported without recreation.
- Reports S3 and SQS resources (`reports.tf`) were imported into state.
- AI Lambda parser IAM resources (`ai.tf`) were specified for unified infrastructure management.

## Consequences
- Single state file managed via HCP Terraform.
- Zero downtime during resource import.
- CloudFormation templates replaced entirely in the `infra/` directory.
