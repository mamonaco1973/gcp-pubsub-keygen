#!/bin/bash
# ==============================================================================
# File: api_setup.sh
# ==============================================================================
# Purpose:
#   - Authenticate gcloud using service account credentials.
#   - Set the active GCP project.
#   - Enable required APIs for the KeyGen microservice deployment.
#
# Requirements:
#   - credentials.json must exist in repo root.
#   - jq and gcloud CLI installed.
#   - Service account must have permission to enable services.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Step 0: Validate credentials.json exists
# ------------------------------------------------------------------------------
#echo "NOTE: Validating credentials.json and testing gcloud authentication"

if [[ ! -f "./credentials.json" ]]; then
  echo "ERROR: The file './credentials.json' does not exist." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# Step 1: Authenticate using service account key
# ------------------------------------------------------------------------------
gcloud auth activate-service-account \
  --key-file="./credentials.json" > /dev/null 2> /dev/null

# ------------------------------------------------------------------------------
# Step 2: Extract project_id and set active project
# ------------------------------------------------------------------------------
project_id="$(jq -r '.project_id' "./credentials.json")"

if [[ -z "${project_id}" || "${project_id}" == "null" ]]; then
  echo "ERROR: project_id not found in credentials.json"
  exit 1
fi

gcloud config set project "${project_id}"

# ------------------------------------------------------------------------------
# Step 3: Enable core infrastructure APIs
# ------------------------------------------------------------------------------
#echo "NOTE: Enabling required Google Cloud APIs..."

gcloud services enable compute.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable secretmanager.googleapis.com

# ------------------------------------------------------------------------------
# Step 4: Enable Cloud Functions (Gen2) + Pub/Sub dependencies
# ------------------------------------------------------------------------------
gcloud services enable pubsub.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable eventarc.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# ------------------------------------------------------------------------------
# Step 5: Enable the Firestore TTL policy on keygen_results.expireAt
# ------------------------------------------------------------------------------
# When the policy is not already active the field operation can take
# minutes server-side (one took 6 minutes in testing), and the blocking call
# exited non-zero while waiting on it; with stderr discarded, set -e then
# aborted apply.sh with only "Environment check failed". --async returns as soon as the request is
# accepted; the lab does not need TTL to be active yet, it only cleans up
# expired result documents. Later runs complete immediately either way.
# Only stdout is silenced so a real failure is still reported.
gcloud firestore fields ttls update expireAt \
  --collection-group=keygen_results \
  --enable-ttl --async > /dev/null

echo "NOTE: API enablement complete."