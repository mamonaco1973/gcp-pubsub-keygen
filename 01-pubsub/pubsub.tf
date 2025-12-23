# ==============================================================================
# Pub/Sub resources for SSH KeyGen service
# Replaces AWS SQS and Azure Service Bus queues
# ==============================================================================

# ------------------------------------------------------------------------------
# Primary Pub/Sub topic for inbound key generation requests
# ------------------------------------------------------------------------------
resource "google_pubsub_topic" "keygen_requests" {
  name = "keygen-requests"
}

# ------------------------------------------------------------------------------
# Dead-letter topic for messages that exceed retry limits
# ------------------------------------------------------------------------------
resource "google_pubsub_topic" "keygen_requests_dlq" {
  name = "keygen-requests-dlq"
}

# ------------------------------------------------------------------------------
# Subscription consumed by the key generation worker
# ------------------------------------------------------------------------------
resource "google_pubsub_subscription" "keygen_requests_sub" {
  name  = "keygen-requests-sub"
  topic = google_pubsub_topic.keygen_requests.name

  ack_deadline_seconds = 30

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.keygen_requests_dlq.id
    max_delivery_attempts = 5
  }
}
