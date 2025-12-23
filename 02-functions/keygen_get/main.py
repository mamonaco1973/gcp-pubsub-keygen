import os

from google.cloud import firestore
from flask import Request, jsonify, make_response


# ==============================================================================
# HTTP API to retrieve SSH key generation results
# ==============================================================================

def _cors_headers():
    origin = os.environ.get("CORS_ALLOW_ORIGIN", "*")

    return {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Methods": "GET,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Max-Age": "3600",
    }


def keygen_get(request: Request):
    # --------------------------------------------------------------------------
    # Handle CORS preflight request
    # --------------------------------------------------------------------------
    if request.method == "OPTIONS":
        resp = make_response("", 204)
        resp.headers.update(_cors_headers())
        return resp

    request_id = request.path.split("/")[-1]

    db = firestore.Client()
    doc = db.collection("keygen_results").document(request_id).get()

    if not doc.exists:
        resp = make_response(jsonify({
            "request_id": request_id,
            "status": "not_found",
        }), 404)
        resp.headers.update(_cors_headers())
        return resp

    resp = make_response(jsonify(doc.to_dict()), 200)
    resp.headers.update(_cors_headers())
    return resp
