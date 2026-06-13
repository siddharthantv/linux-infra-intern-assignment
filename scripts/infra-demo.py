#!/usr/bin/env python3
"""
infra-demo: A minimal HTTP health service.

Exposes two endpoints:
  GET /        - confirms the service is alive
  GET /health  - returns JSON with hostname, uptime, and timestamp

Reads PORT and LOG_PATH from environment variables (set via systemd EnvironmentFile).
"""

import os
import json
import socket
import logging
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# --- Configuration ---
# Fall back to sane defaults if environment variables are not set.
# In production, these should always be injected by the systemd EnvironmentFile.
PORT = int(os.environ.get("INFRA_DEMO_PORT", "8080"))
LOG_PATH = os.environ.get("INFRA_DEMO_LOG_PATH", "/var/log/infra-demo/infra-demo.log")

# Create the log directory if it doesn't already exist.
# exist_ok=True prevents a race condition if the directory is created between
# the check and the mkdir call.
os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)

# --- Logging setup ---
# Dual-sink: writes to a log file for persistence and to stdout so systemd's
# journald captures it automatically when running as a service unit.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_PATH),
        logging.StreamHandler()  # stdout is captured by journald under systemd
    ]
)

# Record the service start time so we can calculate uptime on each health check.
START_TIME = datetime.now(timezone.utc)


class HealthHandler(BaseHTTPRequestHandler):
    """Request handler for the health service.

    Handles GET requests on / and /health. All other paths return 404.
    Inherits from BaseHTTPRequestHandler; each request is dispatched to do_GET.
    """

    def _send_json(self, status_code, payload):
        """Serialize payload to JSON and write it as an HTTP response.

        Args:
            status_code (int): HTTP status code (e.g. 200, 404).
            payload (dict):    Data to serialize and send as the response body.
        """
        # Append a newline so curl and similar tools display output cleanly.
        body = (json.dumps(payload) + "\n").encode("utf-8")

        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        # Explicit Content-Length avoids chunked transfer encoding and lets
        # clients know when the response is fully received.
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        """Route incoming GET requests to the appropriate handler."""

        if self.path == "/health":
            # Calculate how long the service has been running.
            uptime = (datetime.now(timezone.utc) - START_TIME).total_seconds()

            payload = {
                "status": "ok",
                "hostname": socket.gethostname(),
                "uptime_seconds": round(uptime, 2),
                # ISO 8601 with UTC offset — unambiguous for log parsing and monitoring tools.
                "timestamp": datetime.now(timezone.utc).isoformat()
            }

            logging.info("Health check OK from %s", self.client_address[0])
            self._send_json(200, payload)

        elif self.path == "/":
            # Lightweight liveness check — no metrics, just a human-readable hint.
            self._send_json(200, {"message": "infra-demo service is running. Try /health"})

        else:
            self._send_json(404, {"error": "not found"})

    def log_message(self, format, *args):
        """Suppress BaseHTTPRequestHandler's default stderr logging.

        The parent class writes every request to stderr by default.
        We override this with a no-op so our structured logging handlers
        (file + journald) remain the single source of truth.
        """
        pass


def main():
    """Entry point: configure and start the HTTP server."""

    logging.info("Starting infra-demo service on port %s", PORT)

    # ThreadingHTTPServer spawns a new thread per request, which prevents a
    # slow client from blocking other health checks.
    server = ThreadingHTTPServer(("0.0.0.0", PORT), HealthHandler)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        # Graceful shutdown on Ctrl-C (or SIGINT from systemd during stop).
        logging.info("Shutting down infra-demo service")
        server.shutdown()


if __name__ == "__main__":
    main()
