# ==============================================================================
# PUBSUB: SSH KEYGEN MESSAGING
# ------------------------------------------------------------------------------
# Defines Pub/Sub topics and subscription for async key generation.
# Replaces SQS (AWS) and Service Bus (Azure) queue patterns.
# ==============================================================================

# ------------------------------------------------------------------------------
# Primary topic for inbound SSH key generation requests
# ------------------------------------------------------------------------------
resource "google_pubsub_topic" "keygen_requests" {
  name = "keygen-requests"
}

# ------------------------------------------------------------------------------
# Dead-letter topic for messages exceeding retry limits
# ------------------------------------------------------------------------------
resource "google_pubsub_topic" "keygen_requests_dlq" {
  name = "keygen-requests-dlq"
}

# ------------------------------------------------------------------------------
# Subscription consumed by key generation worker function
# ------------------------------------------------------------------------------
resource "google_pubsub_subscription" "keygen_requests_sub" {
  name  = "keygen-requests-sub"
  topic = google_pubsub_topic.keygen_requests.name

  # ----------------------------------------------------------------------------
  # Ack deadline (seconds) before message redelivery
  # ----------------------------------------------------------------------------
  ack_deadline_seconds = 30

  # ----------------------------------------------------------------------------
  # Exponential backoff retry configuration
  # ----------------------------------------------------------------------------
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  # ----------------------------------------------------------------------------
  # Dead-letter routing after max delivery attempts
  # ----------------------------------------------------------------------------
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.keygen_requests_dlq.id
    max_delivery_attempts = 5
  }
}