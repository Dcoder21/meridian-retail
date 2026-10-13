"""Check routing and a signup/catalog/order journey through the proxy."""
import json
import sys
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen

base = sys.argv[1].rstrip("/")


def request(path, data=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data is not None else None
    with urlopen(Request(base + path, body, headers), timeout=15) as response:
        assert response.status == 200
        return json.load(response)


with urlopen(base + "/", timeout=15) as response:
    assert response.status == 200 and b"Meridian" in response.read()
for service in ("auth", "catalog", "orders"):
    assert request(f"/api/{service}/healthz")["status"] == "ok"
products = request("/api/catalog/products")
assert products, "Catalog must contain seeded products"
user = request("/api/auth/signup", {
    "email": f"smoke-{uuid.uuid4().hex}@example.com",
    "password": "smoke-test-correct-horse-battery-staple",
})
order = request("/api/orders", {"product_id": products[0]["id"], "quantity": 1}, user["token"])
orders = request("/api/orders", token=user["token"])
assert any(row["id"] == order["order_id"] for row in orders)
try:
    request("/api/unknown")
except HTTPError as error:
    assert error.code == 404
else:
    raise AssertionError("Unknown API route should return 404")
print("PASS: storefront, health aliases, catalog, signup, order, and unknown API routing")
