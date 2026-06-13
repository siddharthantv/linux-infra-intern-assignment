#!/usr/bin/env python3
"""
infra-demo: A minimal HTTP health service.
Reads PORT and LOG_PATH from environment variables (set via systemd EnivronmentFile).
"""

import os
import json
import socket
import logging
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("INFRA_DEMO_PORT", "8080"))
LOG_PATH = os.environ.get("INFRA_DEMO_LOG_PATH", "/var/log/infra-demo/infra-demo.log")

# Ensure log directory exists
os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)

logging.basicConfig(
	level=logging.INFO,
	format="%(asctime)s %(levelname)s %(message)s",
	handlers=[
		logging.FileHandler(LOG_PATH),
		logging.StreamHandler()  # also goes to journald via systemd
	]
)

START_TIME = datetime.now(timezone.utc)

class HealthHandler(BaseHTTPRequestHandler):
	def _send_json(self, status_code, payload):
		body =  (json.dumps(payload) + "\n") .encode("utf-8")   # Fix: added escape character to move to new line
		self.send_response(status_code)
		self.send_header("Content-Type", "application/json")
		self.send_header("Content-Length", str(len(body)))
		self.end_headers()
		self.wfile.write(body)

	def do_GET(self):
		if self.path == "/health":
			uptime = (datetime.now(timezone.utc) - START_TIME).total_seconds()
			payload = {
				"status": "ok",
				"hostname":socket.gethostname(),
				"uptime_seconds": round(uptime, 2),
				"timestamp": datetime.now(timezone.utc).isoformat()
			}

			logging.info("Health check OK from %s", self.client_address[0])
			self._send_json(200, payload)

		elif self.path == "/":
			self._send_json(200, {"message": "infra-demo service is running. Try /health"})

		else:
			self._send_json(404, {"error": "not found"})

	def log_message(self, format, *args):
		# suppress default stderr logging; we handle logging ourselves
		pass

def main():
	logging.info("Starting infra-demo service on port %s", PORT)
	server = ThreadingHTTPServer(("0.0.0.0", PORT), HealthHandler)

	try:
	  	server.serve_forever()

	except KeyboardInterrupt:
		logging.info("shutting down infra-demo service")
		server.shutdown()

if __name__ == "__main__":
	main()
