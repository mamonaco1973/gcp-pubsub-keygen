#!/bin/bash
# ==============================================================================
# File: prereq_check.sh
# ==============================================================================
# Purpose:
#   - Validate required CLI tools are available in PATH.
#   - Verify credentials.json exists.
#   - Authenticate to Google Cloud using service account key.
#   - Export GOOGLE_APPLICATION_CREDENTIALS for SDK usage.
#
# Requirements:
#   - gcloud and terraform installed.
#   - credentials.json present in repo root.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Step 0: Validate required CLI commands exist
# ------------------------------------------------------------------------------
echo "NOTE: Validating that required commands are in PATH."

commands=("gcloud" "terraform")
all_found=true

for cmd in "${commands[@]}"; do
  if ! command -v "${cmd}" &> /dev/null; then
    echo "ERROR: ${cmd} not found in current PATH."
    all_found=false
  else
    echo "NOTE: ${cmd} found in current PATH."
  fi
done

if [[ "${all_found}" != true ]]; then
  echo "ERROR: One or more required commands are missing."
  exit 1
fi

echo "NOTE: All required commands are available."

# ------------------------------------------------------------------------------
# Step 1: Validate credentials.json exists
# ------------------------------------------------------------------------------
echo "NOTE: Validating credentials.json and testing gcloud authentication."

if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: The file './credentials.json' does not exist." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Step 2: Authenticate using service account key
# ------------------------------------------------------------------------------
gcloud auth activate-service-account \
  --key-file="./credentials.json"

# ------------------------------------------------------------------------------
# Step 3: Export GOOGLE_APPLICATION_CREDENTIALS
# ------------------------------------------------------------------------------
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/credentials.json"

echo "NOTE: Authentication and environment validation complete."