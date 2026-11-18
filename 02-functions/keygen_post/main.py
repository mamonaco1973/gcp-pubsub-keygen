import json
import os
import uuid
from datetime import datetime, timedelta, timezone

from google.cloud import firestore, pubsub_v1


# ==============================================================================
# Shared clients
# ==============================================================================
# Created once per instance, not per request: building them means new gRPC
# channels and an auth token fetch, which is slow on a small instance.
# ==============================================================================

db = firestore.Client()
publisher = pubsub_v1.PublisherClient()
topic = publisher.topic_path(
    project=os.environ["GOOGLE_CLOUD_PROJECT"],
    topic="keygen-requests",
)


# ==============================================================================
# HTTP API to submit SSH key generation requests
# ==============================================================================

def _cors_headers():
    origin = os.environ.get("CORS_ALLOW_ORIGIN", "*")

    return {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Methods": "POST,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Max-Age": "3600",
    }


def keygen_post(request):
    # --------------------------------------------------------------------------
    # Handle CORS preflight request
    # --------------------------------------------------------------------------
    if request.method == "OPTIONS":
        return ("", 204, _cors_headers())

    body = request.get_json(silent=True) or {}

    request_id = str(uuid.uuid4())
    key_type   = body.get("key_type", "rsa")
    key_bits   = body.get("key_bits", 2048)

    # --------------------------------------------------------------------------
    # Create initial Firestore record
    # --------------------------------------------------------------------------
    db.collection("keygen_results").document(request_id).set({
        "request_id": request_id,
        "status": "submitted",
        "key_type": key_type,
        "key_bits": key_bits,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "expireAt": datetime.now(timezone.utc) + timedelta(hours=1),
    })

    # --------------------------------------------------------------------------
    # Publish request to Pub/Sub
    # --------------------------------------------------------------------------
    # Wait for the publish to finish before replying. publish() only queues
    # the message for a background thread, and once the response is sent
    # Cloud Functions throttles the instance's CPU, so an unawaited message
    # reached the worker 4-10 seconds late.
    # --------------------------------------------------------------------------
    publisher.publish(
        topic,
        json.dumps({
            "request_id": request_id,
            "key_type": key_type,
            "key_bits": key_bits,
        }).encode("utf-8"),
    ).result(timeout=30)

    headers = {
        "Content-Type": "application/json",
        **_cors_headers(),
    }

    return (
        json.dumps({
            "request_id": request_id,
            "status": "submitted",
        }),
        200,
        headers,
    )
