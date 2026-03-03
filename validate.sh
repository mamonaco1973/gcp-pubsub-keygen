#!/bin/bash
# ==============================================================================
# File: validate.sh
# ==============================================================================
# Purpose:
#   End-to-end validation for the GCP Pub/Sub KeyGen microservice.
#   - Reads the deployed web app URL from Terraform output (03-webapp).
#   - Derives the Cloud Functions base URL from credentials.json (project_id).
#   - Submits a key generation request to the HTTP endpoint.
#   - Parses the returned request_id.
#   - Polls the result endpoint until the generated SSH keypair is available.
#
# Requirements:
#   - curl, jq, and envsubst installed.
#   - Terraform deployment completed successfully for all phases.
#   - credentials.json exists at repo root (or referenced path) with "project_id".
#   - Optional env vars:
#       KEY_TYPE = rsa | ed25519            (default: rsa)
#       KEY_BITS = 2048 | 4096 (RSA only)   (default: 2048)
#
# Notes:
#   - This script assumes your Cloud Functions expose:
#       POST /keygen
#       GET  /result/<request_id>
#   - If your Functions require auth (recommended), you must provide an
#     Authorization header (e.g., identity token) and allow the caller via IAM.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Step 0: Read the deployed web app URL (03-webapp)
# ------------------------------------------------------------------------------
cd ./03-webapp || exit 1
INDEX_PAGE_URL="$(terraform output -raw index_page_url)"
cd ..

echo "NOTE: Webapp index page URL: ${INDEX_PAGE_URL}"

# ------------------------------------------------------------------------------
# Step 1: Derive Cloud Functions base URL from credentials.json
# ------------------------------------------------------------------------------
echo "NOTE: Deriving Cloud Functions API endpoint..."

project_id="$(jq -r '.project_id' "./credentials.json")"

if [ -z "${project_id}" ] || [ "${project_id}" = "null" ]; then
  echo "ERROR: project_id not found in ./credentials.json. Exiting."
  exit 1
fi

# Construct Cloud Functions base URL.
URL="https://us-central1-${project_id}.cloudfunctions.net"
export API_BASE="${URL}"

echo "NOTE: API Base URL: ${API_BASE}"

# ------------------------------------------------------------------------------
# Step 2: Submit SSH key generation request
# ------------------------------------------------------------------------------
KEY_TYPE="${KEY_TYPE:-rsa}"
KEY_BITS="${KEY_BITS:-2048}"

REQ_PAYLOAD="$(jq -n --arg kt "${KEY_TYPE}" --arg kb "${KEY_BITS}" \
  '{ key_type: $kt, key_bits: ($kb | tonumber) }')"

echo "NOTE: Sending request - key_type=${KEY_TYPE}, key_bits=${KEY_BITS}"

RESPONSE="$(curl -sS -X POST "${API_BASE}/keygen" \
  -H "Content-Type: application/json" \
  -d "${REQ_PAYLOAD}")"

REQUEST_ID="$(echo "${RESPONSE}" | jq -r '.request_id // empty')"

if [ -z "${REQUEST_ID}" ]; then
  echo "ERROR: No request_id returned."
  echo "NOTE: Response was: ${RESPONSE}"
  exit 1
fi

echo "NOTE: Submitted keygen request (${REQUEST_ID})."
echo "NOTE: Polling for result..."

# ------------------------------------------------------------------------------
# Step 3: Poll result endpoint until response available
# ------------------------------------------------------------------------------
MAX_ATTEMPTS=30
SLEEP_SECONDS=2

for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  RESULT="$(curl -sS "${API_BASE}/result/${REQUEST_ID}")"
  STATUS="$(echo "${RESULT}" | jq -r '.status // empty')"

  if [ "${STATUS}" = "complete" ]; then
    echo "NOTE: Key generation complete."
    break
  fi

  if [ "${STATUS}" = "error" ]; then
    echo "ERROR: Service reported an error."
    echo "${RESULT}" | jq
    exit 1
  fi

  echo "NOTE: Attempt ${i}/${MAX_ATTEMPTS}: pending..."
  sleep "${SLEEP_SECONDS}"

  if [ "${i}" -eq "${MAX_ATTEMPTS}" ]; then
    echo "ERROR: Key generation did not complete."
    exit 1
  fi
done

# ------------------------------------------------------------------------------
# Final Quick Start Output
# ------------------------------------------------------------------------------
echo ""
echo "============================================================================"
echo "GCP Pub/Sub Quick Start - Validation Output"
echo "============================================================================"
echo ""

if [ -n "${INDEX_PAGE_URL}" ] && [ "${INDEX_PAGE_URL}" != "None" ]; then
  echo "NOTE: Test Web URL:    ${INDEX_PAGE_URL}"
else
  echo "WARN: Static website URL not found"
fi

if [ -n "${API_BASE}" ] && [ "${API_BASE}" != "None" ]; then
  echo "NOTE: API Base URI:    ${API_BASE}"
else
  echo "WARN: Cloud Functions endpoint not found"
fi

echo ""
echo "NOTE: Validation complete."