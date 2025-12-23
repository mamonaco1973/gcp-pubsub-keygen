# ==============================================================================
# Pub/Sub worker function for SSH key generation
# ==============================================================================

# ------------------------------------------------------------------------------
# Archive worker function source
# ------------------------------------------------------------------------------
data "archive_file" "worker_zip" {
  type        = "zip"
  source_dir  = "./keygen_worker"
  output_path = "./keygen_work/keygen_worker.zip"
}

# ------------------------------------------------------------------------------
# Random suffix for globally-unique storage bucket name
# ------------------------------------------------------------------------------
resource "random_string" "functions_bucket_suffix" {
  length  = 6
  upper   = false
  special = false
}

# ------------------------------------------------------------------------------
# Storage bucket for function source archives
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "functions_src" {
  name          = "keygen-${random_string.functions_bucket_suffix.result}"
  location      = "US"
  storage_class = "STANDARD"
  force_destroy = true
}


# ------------------------------------------------------------------------------
# Upload worker source archive
# ------------------------------------------------------------------------------
resource "google_storage_bucket_object" "worker_object" {
  name   = "keygen_worker.zip"
  bucket = google_storage_bucket.functions_src.name
  source = data.archive_file.worker_zip.output_path
}

# ------------------------------------------------------------------------------
# Service account for worker function
# ------------------------------------------------------------------------------
resource "google_service_account" "worker_sa" {
  account_id   = "keygen-worker-sa"
  display_name = "SSH KeyGen worker function"
}

# ------------------------------------------------------------------------------
# IAM permissions for worker
# ------------------------------------------------------------------------------
resource "google_project_iam_member" "worker_pubsub" {
  project = local.credentials.project_id
  role   = "roles/pubsub.subscriber"
  member = "serviceAccount:${google_service_account.worker_sa.email}"
}

resource "google_project_iam_member" "worker_firestore" {
  project = local.credentials.project_id
  role   = "roles/datastore.user"
  member = "serviceAccount:${google_service_account.worker_sa.email}"
}

# ------------------------------------------------------------------------------
# Cloud Functions (2nd gen) worker
# ------------------------------------------------------------------------------
resource "google_cloudfunctions2_function" "worker" {
  name     = "keygen-worker"
  location = "us-central1"

  build_config {
    runtime     = "python311"
    entry_point = "keygen_worker"

    source {
      storage_source {
        bucket = google_storage_bucket.functions_src.name
        object = google_storage_bucket_object.worker_object.name
      }
    }
  }

  service_config {
    service_account_email = google_service_account.worker_sa.email
    timeout_seconds       = 60
    available_memory      = "256M"
  }

  event_trigger {
    event_type = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic = data.google_pubsub_topic.keygen_requests.id
    retry_policy = "RETRY_POLICY_RETRY"
  }
}

# ------------------------------------------------------------------------------
# Primary Pub/Sub topic for inbound key generation requests
# ------------------------------------------------------------------------------
data "google_pubsub_topic" "keygen_requests" {
  name = "keygen-requests"
}
