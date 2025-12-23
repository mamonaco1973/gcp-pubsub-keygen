# ==============================================================================
# SSH KeyGen serverless functions (GCP)
# ==============================================================================
# Deploys a complete asynchronous SSH key generation service using:
#   - Pub/Sub for request queuing
#   - Cloud Functions (2nd gen) for compute
#   - Firestore for temporary result storage
#
# Functions deployed:
#   1. Pub/Sub worker function (async key generation)
#   2. HTTP POST function to submit keygen requests
#   3. HTTP GET function to retrieve keygen results
#
# All function source is packaged, uploaded, and deployed via Terraform.
# ==============================================================================

# ------------------------------------------------------------------------------
# Archive function source directories
# ------------------------------------------------------------------------------
# Packages each function directory into a zip archive suitable for deployment
# to Cloud Functions (2nd gen). These archives are later uploaded to GCS.
# ------------------------------------------------------------------------------

data "archive_file" "worker_zip" {
  type        = "zip"
  source_dir  = "./keygen_worker"
  output_path = "./keygen_work/keygen_worker.zip"
}

data "archive_file" "post_zip" {
  type        = "zip"
  source_dir  = "./keygen_post"
  output_path = "./keygen_post/keygen_post.zip"
}

data "archive_file" "get_zip" {
  type        = "zip"
  source_dir  = "./keygen_get"
  output_path = "./keygen_get/keygen_get.zip"
}

# ------------------------------------------------------------------------------
# Random suffix for globally-unique storage bucket name
# ------------------------------------------------------------------------------
# GCS bucket names are global across all projects. A random suffix prevents
# naming collisions and allows safe creation and teardown per environment.
# ------------------------------------------------------------------------------
resource "random_string" "functions_bucket_suffix" {
  length  = 6
  upper   = false
  special = false
}

# ------------------------------------------------------------------------------
# Storage bucket for function source archives
# ------------------------------------------------------------------------------
# Stores zipped function source code used by Cloud Functions build steps.
# This bucket is Terraform-managed and destroyed with the environment.
# ------------------------------------------------------------------------------
resource "google_storage_bucket" "functions_src" {
  name          = "keygen-${random_string.functions_bucket_suffix.result}"
  location      = "US"
  storage_class = "STANDARD"
  force_destroy = true
}

# ------------------------------------------------------------------------------
# Upload function source archives
# ------------------------------------------------------------------------------
# Uploads the packaged zip files to the source bucket so they can be referenced
# by Cloud Functions build configurations.
# ------------------------------------------------------------------------------

resource "google_storage_bucket_object" "worker_object" {
  name   = "keygen_worker.zip"
  bucket = google_storage_bucket.functions_src.name
  source = data.archive_file.worker_zip.output_path
}

resource "google_storage_bucket_object" "post_object" {
  name   = "keygen_post.zip"
  bucket = google_storage_bucket.functions_src.name
  source = data.archive_file.post_zip.output_path
}

resource "google_storage_bucket_object" "get_object" {
  name   = "keygen_get.zip"
  bucket = google_storage_bucket.functions_src.name
  source = data.archive_file.get_zip.output_path
}

# ------------------------------------------------------------------------------
# Service accounts for functions
# ------------------------------------------------------------------------------
# Separate service accounts are used to enforce least privilege:
#   - Worker SA: consumes Pub/Sub messages and writes Firestore results
#   - HTTP SA: publishes Pub/Sub messages and reads Firestore results
# ------------------------------------------------------------------------------

resource "google_service_account" "worker_sa" {
  account_id   = "keygen-worker-sa"
  display_name = "SSH KeyGen worker function"
}

resource "google_service_account" "http_sa" {
  account_id   = "keygen-http-sa"
  display_name = "SSH KeyGen HTTP functions"
}

# ------------------------------------------------------------------------------
# IAM permissions for worker
# ------------------------------------------------------------------------------
# Grants the worker function permission to:
#   - Consume messages from the Pub/Sub request topic
#   - Write key generation results to Firestore
# ------------------------------------------------------------------------------

resource "google_project_iam_member" "worker_pubsub" {
  project = local.credentials.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.worker_sa.email}"
}

resource "google_project_iam_member" "worker_firestore" {
  project = local.credentials.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.worker_sa.email}"
}

# ------------------------------------------------------------------------------
# IAM permissions for HTTP functions
# ------------------------------------------------------------------------------
# Grants HTTP functions permission to:
#   - Publish keygen requests to Pub/Sub
#   - Read and write request metadata in Firestore
# ------------------------------------------------------------------------------

resource "google_project_iam_member" "http_firestore" {
  project = local.credentials.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.http_sa.email}"
}

resource "google_project_iam_member" "http_pubsub" {
  project = local.credentials.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.http_sa.email}"
}

# ------------------------------------------------------------------------------
# Cloud Functions (2nd gen) worker
# ------------------------------------------------------------------------------
# Asynchronous worker function triggered by Pub/Sub messages.
# Responsibilities:
#   - Consume key generation requests
#   - Generate SSH keypairs entirely in memory
#   - Persist results to Firestore with a TTL expiration
#
# Uses Eventarc to receive Pub/Sub messagePublished events.
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
    event_type   = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic = data.google_pubsub_topic.keygen_requests.id
    retry_policy = "RETRY_POLICY_RETRY"
  }
}

# ------------------------------------------------------------------------------
# HTTP POST /keygen function
# ------------------------------------------------------------------------------
# Synchronous HTTP endpoint used to submit new SSH key generation requests.
# Responsibilities:
#   - Generate a unique request_id
#   - Create an initial Firestore record
#   - Publish the request to the Pub/Sub queue
# ------------------------------------------------------------------------------

resource "google_cloudfunctions2_function" "post" {
  name     = "keygen"
  location = "us-central1"

  build_config {
    runtime     = "python311"
    entry_point = "keygen_post"

    source {
      storage_source {
        bucket = google_storage_bucket.functions_src.name
        object = google_storage_bucket_object.post_object.name
      }
    }
  }

  service_config {
    service_account_email = google_service_account.http_sa.email
  }
}

# ------------------------------------------------------------------------------
# HTTP GET /result/{request_id} function
# ------------------------------------------------------------------------------
# Synchronous HTTP endpoint used to retrieve the status and results of a
# previously submitted key generation request.
# Reads directly from Firestore using request_id as the document key.
# ------------------------------------------------------------------------------

resource "google_cloudfunctions2_function" "get" {
  name     = "results"
  location = "us-central1"

  build_config {
    runtime     = "python311"
    entry_point = "keygen_get"

    source {
      storage_source {
        bucket = google_storage_bucket.functions_src.name
        object = google_storage_bucket_object.get_object.name
      }
    }
  }

  service_config {
    service_account_email = google_service_account.http_sa.email
  }
}

# ------------------------------------------------------------------------------
# Public access to HTTP functions (unauthenticated invoke)
# ------------------------------------------------------------------------------
resource "google_cloudfunctions2_function_iam_member" "post_public" {
  project        = google_cloudfunctions2_function.post.project
  location       = google_cloudfunctions2_function.post.location
  cloud_function = google_cloudfunctions2_function.post.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_cloudfunctions2_function_iam_member" "get_public" {
  project        = google_cloudfunctions2_function.get.project
  location       = google_cloudfunctions2_function.get.location
  cloud_function = google_cloudfunctions2_function.get.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

# ------------------------------------------------------------------------------
# Primary Pub/Sub topic for inbound key generation requests
# ------------------------------------------------------------------------------
# Existing Pub/Sub topic that acts as the request queue.
# This topic is resolved as a data source to avoid lifecycle conflicts.
# ------------------------------------------------------------------------------

data "google_pubsub_topic" "keygen_requests" {
  name = "keygen-requests"
}
