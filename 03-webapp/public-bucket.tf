# ==============================================================================
# Static Website Cloud Storage Bucket (Public) - Google Cloud
# ==============================================================================
# Creates:
#   - Globally-unique GCS bucket (random suffix)
#   - Static website configuration (index + 404)
#   - Public read access (allUsers -> objectViewer)
#   - Uploads ./index.html
#
# Notes:
#   - index.html must exist in the Terraform root directory
#   - GCS website endpoint is HTTP-only:
#       http://<bucket>.storage.googleapis.com/
#   - HTTPS requires an external HTTP(S) Load Balancer
# ==============================================================================

# ------------------------------------------------------------------------------
# Random suffix (global uniqueness requirement)
# ------------------------------------------------------------------------------
resource "random_string" "static_suffix" {
  length  = 8
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# ------------------------------------------------------------------------------
# Locals
# ------------------------------------------------------------------------------
locals {
  # GCS bucket names must be globally unique and lowercase.
  static_site_name = "keygen-${random_string.static_suffix.result}"
}

# ------------------------------------------------------------------------------
# Storage bucket
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "static_site" {
  name          = local.static_site_name
  location      = "US"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  labels = {
    project = "static-website"
  }
}

# ------------------------------------------------------------------------------
# Public read access
# ------------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.static_site.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# ------------------------------------------------------------------------------
# Upload index.html
# ------------------------------------------------------------------------------
resource "google_storage_bucket_object" "index" {
  name         = "index.html"
  bucket       = google_storage_bucket.static_site.name
  source       = "${path.root}/index.html"
  content_type = "text/html"
}

# ------------------------------------------------------------------------------
# Outputs
# ------------------------------------------------------------------------------
output "index_page_url" {
  description = "Direct URL to index.html"
  value       = "https://${google_storage_bucket.static_site.name}.storage.googleapis.com/index.html"
}
