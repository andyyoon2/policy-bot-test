#!/usr/bin/env bash
# Adds a version to each Secret Manager secret the policy-bot service reads.
#
# Usage:
#   scripts/set-secrets.sh <path-to-app-private-key.pem> [project] [service_name]
#
# Prompts for the webhook secret and the OAuth client secret, and generates a
# fresh sessions key. Re-run any time to rotate; Cloud Run reads "latest".
set -euo pipefail

KEY_FILE=${1:?path to the GitHub App private key (.pem)}
PROJECT=${2:-xyla-development-2}
SERVICE=${3:-policy-bot-proto}

add_version() {
  local secret=$1
  gcloud secrets versions add "${SERVICE}-${secret}" --project "$PROJECT" --data-file=-
}

echo "Adding private key from $KEY_FILE"
add_version github-app-private-key < "$KEY_FILE"

read -r -s -p "GitHub App webhook secret: " WEBHOOK; echo
printf '%s' "$WEBHOOK" | add_version github-app-webhook-secret

read -r -s -p "GitHub App OAuth client secret: " CLIENT; echo
printf '%s' "$CLIENT" | add_version github-oauth-client-secret

echo "Generating sessions key"
openssl rand -hex 32 | tr -d '\n' | add_version sessions-key

echo "Done. Now run: terraform apply -var deploy_service=true"
