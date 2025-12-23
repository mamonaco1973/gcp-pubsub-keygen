import base64
import json
import os
from datetime import datetime, timedelta, timezone

from google.cloud import firestore
from cryptography.hazmat.primitives.asymmetric import rsa, ed25519
from cryptography.hazmat.primitives import serialization


# ==============================================================================
# Pub/Sub worker for asynchronous SSH key generation
# ==============================================================================
# Triggered by messages published to the keygen-requests Pub/Sub topic.
# Generates SSH keypairs in memory and stores results in Firestore with TTL.
# ==============================================================================


def keygen_worker(event, context):
    """
    Pub/Sub-triggered worker function.
    """

    # --------------------------------------------------------------------------
    # Decode Pub/Sub message
    # --------------------------------------------------------------------------
    payload = base64.b64decode(event["data"]).decode("utf-8")
    msg = json.loads(payload)

    request_id = msg["request_id"]
    key_type   = msg.get("key_type", "rsa")
    key_bits   = msg.get("key_bits", 2048)

    db = firestore.Client()
    doc_ref = db.collection("keygen_results").document(request_id)

    # --------------------------------------------------------------------------
    # Mark request as pending
    # --------------------------------------------------------------------------
    doc_ref.set({
        "request_id": request_id,
        "status": "pending",
        "key_type": key_type,
        "key_bits": key_bits,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "expireAt": datetime.now(timezone.utc) + timedelta(hours=1),
    }, merge=True)

    try:
        # ----------------------------------------------------------------------
        # Generate SSH keypair in memory
        # ----------------------------------------------------------------------
        if key_type == "ed25519":
            private_key = ed25519.Ed25519PrivateKey.generate()
        else:
            private_key = rsa.generate_private_key(
                public_exponent=65537,
                key_size=key_bits,
            )

        public_key = private_key.public_key()

        private_bytes = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        )

        public_bytes = public_key.public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        )

        # ----------------------------------------------------------------------
        # Write completed result
        # ----------------------------------------------------------------------
        doc_ref.set({
            "status": "complete",
            "public_key_b64": base64.b64encode(public_bytes).decode("utf-8"),
            "private_key_b64": base64.b64encode(private_bytes).decode("utf-8"),
            "completedAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)

    except Exception as exc:
        # ----------------------------------------------------------------------
        # Write error state
        # ----------------------------------------------------------------------
        doc_ref.set({
            "status": "error",
            "error_message": str(exc),
        }, merge=True)
