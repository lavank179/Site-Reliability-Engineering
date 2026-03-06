# from prometheus_client import start_http_server, Summary
# import random
# import time

# # Create a metric to track time spent and requests made.
# REQUEST_TIME = Summary('request_processing_seconds', 'Time spent processing request')

# # Decorate function with metric.
# @REQUEST_TIME.time()
# def process_request(t):
#     """A dummy function that takes some time."""
#     time.sleep(t)

# if __name__ == '__main__':
#     # Start up the server to expose the metrics.
#     print("starting server on 8000.")
#     start_http_server(8000)
#     # Generate some requests.
#     while True:
#         process_request(random.random())


from http.server import BaseHTTPRequestHandler, HTTPServer
import time
import random

from prometheus_client import (
    Counter,
    Histogram,
    Gauge,
    generate_latest,
    CONTENT_TYPE_LATEST
)

# ---------- METRICS ----------

# Request metrics
REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status"]
)

REQUEST_LATENCY = Histogram(
    "http_request_latency_seconds",
    "Request latency",
    ["path"]
)

# Business metrics
ORDERS_CREATED = Counter(
    "orders_created_total",
    "Total orders created"
)

ORDERS_FAILED = Counter(
    "orders_failed_total",
    "Total order failures"
)

IN_PROGRESS_ORDERS = Gauge(
    "orders_in_progress",
    "Orders currently being processed"
)

# ---------- HTTP HANDLER ----------

class Handler(BaseHTTPRequestHandler):

    def do_GET(self):
        start_time = time.time()

        if self.path == "/metrics":
            self.send_response(200)
            self.send_header("Content-Type", CONTENT_TYPE_LATEST)
            self.end_headers()
            self.wfile.write(generate_latest())
            return

        if self.path == "/order":
            self.handle_order()
            return

        self.send_response(404)
        self.end_headers()

    def handle_order(self):
        IN_PROGRESS_ORDERS.inc()
        time.sleep(random.uniform(0.1, 0.6))  # simulate work

        success = random.random() > 0.2  # 80% success

        if success:
            ORDERS_CREATED.inc()
            status = 200
            response = b"Order created"
        else:
            ORDERS_FAILED.inc()
            status = 500
            response = b"Order failed"

        IN_PROGRESS_ORDERS.dec()
        self.send_response(status)
        self.end_headers()
        self.wfile.write(response)

    def log_request(self, code="-", size="-"):
        latency = time.time() - self.request_time
        REQUEST_LATENCY.labels(path=self.path).observe(latency)
        REQUEST_COUNT.labels(
            method=self.command,
            path=self.path,
            status=code
        ).inc()

    def handle_one_request(self):
        self.request_time = time.time()
        super().handle_one_request()


# ---------- SERVER ----------

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8000), Handler)
    print("Server running on port 8000")
    server.serve_forever()
