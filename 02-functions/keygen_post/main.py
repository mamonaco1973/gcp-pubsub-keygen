import json
import uuid
from datetime import datetime, timedelta, timezone

from google.cloud import firestore, pubsub_v1
from flask import Request, jsonify


# ==============================================================================
# HTTP API to submit SSH key generation requests
# ==============================================================================


def keygen_post(request: Request):
    body = request.get_json(silent=True) or {}

    request_id = str(uuid.uuid4())
    key_type   = body.get("key_type", "rsa")
    key_bits   = body.get("key_bits", 2048)

    db = firestore.Client()
    topic = pubsub_v1.PublisherClient().topic_path(
        project=request.environ["GCP_PROJECT"],
        topic="keygen-requests",
    )

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
    pubsub_v1.PublisherClient().publish(
        topic,
        json.dumps({
            "request_id": request_id,
            "key_type": key_type,
            "key_bits": key_bits,
        }).encode("utf-8"),
    )

    return jsonify({
        "request_id": request_id,
        "status": "submitted",
    })
