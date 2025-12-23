#!/bin/bash

# Run the environment check script to ensure required environment variables, tools, or configurations are present.
./check_env.sh
if [ $? -ne 0 ]; then
  # If the check_env script exits with a non-zero status, it indicates a failure.
  echo "ERROR: Environment check failed. Exiting."
  exit 1  # Stop script execution immediately if environment check fails.
fi

# Phase 1 of the build - Build pubsub infrastructure
cd 01-pubsub

# Initialize Terraform (download providers, set up backend, etc.).
terraform init

# Apply the Terraform configuration, automatically approving all changes (no manual confirmation required).
terraform apply -auto-approve

if [ $? -ne 0 ]; then
  echo "ERROR: Terraform apply failed in 01-directory. Exiting."
  exit 1
fi

# Return to the previous (parent) directory.
cd ..
