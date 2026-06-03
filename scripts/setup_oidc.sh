#!/usr/bin/env bash
set -euo pipefail

ROLE_NAME="url-shortener-github-terraform"
ACCOUNT_ID="449095351082"
REPO="cmomodo/url_shortener_ECS"
REGION="us-east-1"

echo "==> Creating OIDC provider (skipping if exists)..."
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 \
  --region "$REGION" 2>/dev/null || echo "    OIDC provider already exists, skipping."

echo "==> Creating IAM role: $ROLE_NAME..."
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file://role.json \
  --description "Assumed by GitHub Actions via OIDC to run Terraform for $REPO" \
  --region "$REGION"

echo "==> Attaching AdministratorAccess..."
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo ""
echo "Done. Set this as AWS_TERRAFORM_ROLE_ARN in GitHub Actions secrets:"
echo "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
