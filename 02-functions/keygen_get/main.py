from google.cloud import firestore
from flask import Request, jsonify


# ==============================================================================
# HTTP API to retrieve SSH key generation results
# ==============================================================================


def keygen_get(request: Request):
    request_id = request.path.split("/")[-1]

    db = firestore.Client()
    doc = db.collection("keygen_results").document(request_id).get()

    if not doc.exists:
        return jsonify({
            "request_id": request_id,
            "status": "not_found",
        }), 404

    return jsonify(doc.to_dict())
