# ==============================================================================
# PROVIDER: GOOGLE CLOUD
# ------------------------------------------------------------------------------
# Configures the Google provider using project ID and a JSON credentials file.
# ==============================================================================

provider "google" {
  project     = local.credentials.project_id
  credentials = file("../credentials.json")
}

# ==============================================================================
# LOCALS: CREDENTIALS
# ------------------------------------------------------------------------------
# Decodes the JSON credentials file for reuse (project_id, client_email).
# ==============================================================================

locals {
  credentials           = jsondecode(file("../credentials.json"))
  service_account_email = local.credentials.client_email
}