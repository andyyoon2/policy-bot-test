#!/usr/bin/env bash
# Posts a pull request review as a GitHub App, standing in for the
# auto-approver service during the prototype.
#
# Usage:
#   scripts/approve-as-bot.sh <app_id> <private-key.pem> <owner/repo> <pr_number> [APPROVE|COMMENT]
#
# Requires: openssl, curl, jq. The App must be installed on the repo with
# "Pull requests: write".
set -euo pipefail

APP_ID=${1:?app id}
KEY=${2:?private key path}
REPO=${3:?owner/repo}
PR=${4:?pull request number}
EVENT=${5:-APPROVE}
API=https://api.github.com

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

now=$(date +%s)
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$((now - 60))" "$((now + 540))" "$APP_ID" | b64url)
signature=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$KEY" | b64url)
jwt="$header.$payload.$signature"

installation=$(curl -fsS -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "$API/repos/$REPO/installation" | jq -r .id)
token=$(curl -fsS -X POST -H "Authorization: Bearer $jwt" -H "Accept: application/vnd.github+json" \
  "$API/app/installations/$installation/access_tokens" | jq -r .token)

head_sha=$(curl -fsS -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" \
  "$API/repos/$REPO/pulls/$PR" | jq -r .head.sha)

body="Prototype auto-approval for backend/ files at ${head_sha:0:7}. Posted by scripts/approve-as-bot.sh."
curl -fsS -X POST -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" \
  "$API/repos/$REPO/pulls/$PR/reviews" \
  -d "$(jq -cn --arg e "$EVENT" --arg b "$body" --arg s "$head_sha" '{event: $e, body: $b, commit_id: $s}')" \
  | jq '{id, state, user: .user.login, commit_id}'
