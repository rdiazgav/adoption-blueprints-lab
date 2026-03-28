import hashlib

from fastapi import FastAPI
from fastapi.responses import Response
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST

app = FastAPI(title="RetailFlow Recommendations", version="1.0.0")

REQUEST_COUNT = Counter(
    "recommendations_requests_total",
    "Total requests per endpoint",
    ["endpoint"],
)

# ---------------------------------------------------------------------------
# Mock catalogue — 20 products with a popularity score used for ranking
# ---------------------------------------------------------------------------
PRODUCTS = [
    {"id": "p001", "name": "Wireless Mouse",             "category": "peripherals",  "price": 29.99,  "score": 4.8},
    {"id": "p002", "name": "Mechanical Keyboard",        "category": "peripherals",  "price": 79.99,  "score": 4.7},
    {"id": "p003", "name": "4K Monitor",                 "category": "displays",     "price": 399.99, "score": 4.9},
    {"id": "p004", "name": "USB-C Hub",                  "category": "accessories",  "price": 49.99,  "score": 4.5},
    {"id": "p005", "name": "Webcam HD",                  "category": "peripherals",  "price": 89.99,  "score": 4.3},
    {"id": "p006", "name": "Noise-Cancelling Headphones","category": "audio",        "price": 149.99, "score": 4.8},
    {"id": "p007", "name": "Laptop Stand",               "category": "accessories",  "price": 34.99,  "score": 4.6},
    {"id": "p008", "name": "SSD 1TB",                    "category": "storage",      "price": 89.99,  "score": 4.7},
    {"id": "p009", "name": "Gaming Mouse Pad",           "category": "peripherals",  "price": 19.99,  "score": 4.2},
    {"id": "p010", "name": "Thunderbolt Dock",           "category": "accessories",  "price": 199.99, "score": 4.4},
    {"id": "p011", "name": "Bluetooth Speaker",          "category": "audio",        "price": 59.99,  "score": 4.5},
    {"id": "p012", "name": "LED Desk Lamp",              "category": "office",       "price": 39.99,  "score": 4.3},
    {"id": "p013", "name": "Ergonomic Chair",            "category": "office",       "price": 299.99, "score": 4.6},
    {"id": "p014", "name": "Smart Power Strip",          "category": "accessories",  "price": 44.99,  "score": 4.4},
    {"id": "p015", "name": "USB Microphone",             "category": "audio",        "price": 99.99,  "score": 4.7},
    {"id": "p016", "name": "Cable Management Kit",       "category": "accessories",  "price": 14.99,  "score": 4.1},
    {"id": "p017", "name": "Screen Cleaner Kit",         "category": "accessories",  "price": 9.99,   "score": 4.0},
    {"id": "p018", "name": "Portable Charger 20000mAh",  "category": "accessories",  "price": 49.99,  "score": 4.6},
    {"id": "p019", "name": "HDMI Cable 4K",              "category": "accessories",  "price": 12.99,  "score": 4.2},
    {"id": "p020", "name": "Wireless Charger Pad",       "category": "accessories",  "price": 24.99,  "score": 4.3},
]

# Pre-sorted by score descending — computed once at startup
POPULAR = sorted(PRODUCTS, key=lambda p: p["score"], reverse=True)


# ---------------------------------------------------------------------------
# Routes — /recommendations/popular must be declared before /{customerId}
# so FastAPI matches the literal segment first
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    REQUEST_COUNT.labels(endpoint="/health").inc()
    return {"status": "ok", "service": "recommendations"}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/recommendations/popular")
def popular():
    REQUEST_COUNT.labels(endpoint="/recommendations/popular").inc()
    return POPULAR[:10]


@app.get("/recommendations/{customer_id}")
def recommendations(customer_id: str):
    REQUEST_COUNT.labels(endpoint="/recommendations/{customerId}").inc()
    # Deterministic rotation: same customer always gets the same 5 products
    digest = int(hashlib.md5(customer_id.encode()).hexdigest(), 16)
    offset = digest % len(PRODUCTS)
    rotated = PRODUCTS[offset:] + PRODUCTS[:offset]
    return rotated[:5]
