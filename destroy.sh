#!/bin/bash
# ==============================================================================
# destroy.sh
# ==============================================================================
# Purpose:
#   Tears down all Terraform-managed resources for the project.
#
# Behavior:
#   - Destroys resources in reverse deployment order to honor dependencies:
#       1) 03-webapp
#       2) 02-functions
#       3) 01-pubsub
#
# Notes:
#   - Uses -auto-approve; no interactive confirmation is required.
#   - Assumes Terraform state is intact in each phase directory.
# ==============================================================================

# Treat unset variables as errors.
set -u

# ------------------------------------------------------------------------------
# Phase 1: Destroy web application resources
# ------------------------------------------------------------------------------
cd 03-webapp

terraform init
terraform destroy -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Phase 2: Destroy Cloud Functions resources
# ------------------------------------------------------------------------------
cd 02-functions

terraform init
terraform destroy -auto-approve

cd ..

# ------------------------------------------------------------------------------
# Phase 3: Destroy Pub/Sub infrastructure
# ------------------------------------------------------------------------------
cd 01-pubsub

terraform init
terraform destroy -auto-approve

cd ..
