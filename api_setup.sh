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

# Enable TTL support so values are temporary

gcloud firestore fields ttls update expireAt \
  --collection-group=keygen_results \
  --enable-ttl > /dev/null 2> /dev/null

echo "NOTE: API enablement complete."