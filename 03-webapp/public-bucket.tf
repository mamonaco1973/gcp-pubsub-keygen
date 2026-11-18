# ==============================================================================
# GCS: STATIC WEBSITE (PUBLIC)
# ------------------------------------------------------------------------------
# Creates a public static website bucket with random suffix.
# Uploads index.html and enables website hosting.
# HTTP only. HTTPS requires external load balancer.
# ==============================================================================

# ------------------------------------------------------------------------------
# Random suffix for global bucket name uniqueness
# ------------------------------------------------------------------------------
resource "random_string" "static_suffix" {
  length  = 8
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# ------------------------------------------------------------------------------
# LOCALS
# ------------------------------------------------------------------------------
locals {

  # GCS bucket names must be globally unique and lowercase
  static_site_name = "keygen-${random_string.static_suffix.result}"
}

# ------------------------------------------------------------------------------
# Storage bucket configuration
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "static_site" {
  name          = local.static_site_name
  location      = "US"
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  # ---------------------------------------------------------------------------
  # Website configuration (index and 404 pages)
  # ---------------------------------------------------------------------------
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  labels = {
    project = "static-website"
  }
}

# ------------------------------------------------------------------------------
# Public read access (allUsers objectViewer)
# ------------------------------------------------------------------------------
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.static_site.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# ------------------------------------------------------------------------------
# Upload index.html from Terraform root
# ------------------------------------------------------------------------------
resource "google_storage_bucket_object" "index" {
  name         = "index.html"
  bucket       = google_storage_bucket.static_site.name
  source       = "${path.root}/index.html"
  content_type = "text/html"

  # Public GCS objects are served with "public, max-age=3600" by default, so
  # browsers and Google's edge cache keep the old page for up to an hour
  # after a redeploy. no-cache makes them revalidate (cheap, via the ETag) on
  # every load. Content changes themselves are already picked up: the
  # provider compares the file's MD5 (detect_md5hash) on every plan.
  cache_control = "no-cache"
}

# ------------------------------------------------------------------------------
# Upload favicon from Terraform root
# ------------------------------------------------------------------------------
resource "google_storage_bucket_object" "favicon" {
  name         = "favicon.ico"
  bucket       = google_storage_bucket.static_site.name
  source       = "${path.root}/favicon.ico"
  content_type = "image/x-icon"
}

# ------------------------------------------------------------------------------
# OUTPUTS
# ------------------------------------------------------------------------------
output "index_page_url" {
  description = "Direct URL to index.html"
  value       = "https://${google_storage_bucket.static_site.name}.storage.googleapis.com/index.html"
}