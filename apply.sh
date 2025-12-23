#!/bin/bash
# ==============================================================================
# apply.sh
# ==============================================================================
# Purpose:
#   Orchestrates a three-phase Terraform deployment:
#     1) 01-pubsub    - Pub/Sub infrastructure
#     2) 02-functions - Cloud Functions deployment
#     3) 03-webapp    - Static web app with API base injection
#
# Behavior:
#   - Runs ./check_env.sh to validate prerequisites
#   - Applies Terraform in each phase directory in order
#   - Generates index.html from index.html.tmpl using envsubst
#
# Notes:
#   - credentials.json must exist and contain a "project_id" field
#   - jq, envsubst, and terraform must be installed
#   - Uses -auto-approve; no interactive confirmation is required
# ==============================================================================

# Treat unset variables as errors.
set -u

# ------------------------------------------------------------------------------
# Phase 0: Environment validation
# ------------------------------------------------------------------------------
# Ensures required tools, credentials, and configuration are present.
# ------------------------------------------------------------------------------
./check_env.sh
if [ $? -ne 0 ]; then
  echo "ERROR: Environment check failed. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Phase 1: Provision Pub/Sub infrastructure
# ------------------------------------------------------------------------------

cd 01-pubsub

# Initialize Terraform providers and backend.
terraform init

# Apply Pub/Sub resources without manual approval.
terraform apply -auto-approve
if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-pubsub. Exiting."
  exit 1
fi

# Return to project root.
cd ..

# ------------------------------------------------------------------------------
# Phase 2: Deploy Cloud Functions
# ------------------------------------------------------------------------------

cd 02-functions

terraform init
terraform apply -auto-approve
if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 02-functions. Exiting."
  exit 1
fi

cd ..

# ------------------------------------------------------------------------------
# Phase 3: Build and deploy web application
# ------------------------------------------------------------------------------

cd 03-webapp

# Read GCP project_id from credentials.json.
project_id=$(jq -r '.project_id' "../credentials.json")

if [ -z "${project_id}" ] || [ "${project_id}" = "null" ]; then
  echo "ERROR: project_id not found in credentials.json. Exiting."
  exit 1
fi

# Construct Cloud Functions base URL.
URL="https://us-central1-${project_id}.cloudfunctions.net"
export API_BASE="${URL}"

echo "NOTE: API Base URL: ${API_BASE}"

# Generate index.html from template using API_BASE.
envsubst '${API_BASE}' < index.html.tmpl > index.html
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to generate index.html. Exiting."
  exit 1
fi

terraform init
terraform apply -auto-approve
if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 03-webapp. Exiting."
  exit 1
fi

cd ..
