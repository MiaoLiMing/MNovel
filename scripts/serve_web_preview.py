"""Serve a Flutter Web build and proxy the production API for local visual QA."""

from __future__ import annotations

import argparse
import http.client
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class PreviewHandler(SimpleHTTPRequestHandler):
    api_origin = "https://api.flowercat.art"

    def do_GET(self) -> None:
        if self.path.startswith("/api/"):
            self._proxy_api()
            return
        super().do_GET()

    def _proxy_api(self) -> None:
        origin = urlsplit(self.api_origin)
        connection = http.client.HTTPSConnection(origin.hostname, timeout=30)
        try:
            connection.request(
                "GET",
                self.path,
                headers={
                    "Accept": "application/json",
                    "User-Agent": "MNovelVisualQA/1.0",
                },
            )
            response = connection.getresponse()
            body = response.read()
            self.send_response(response.status)
            self.send_header(
                "Content-Type",
                response.getheader("Content-Type") or "application/json",
            )
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        finally:
            connection.close()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("web_root", type=Path)
    parser.add_argument("--port", type=int, default=4173)
    args = parser.parse_args()
    web_root = args.web_root.resolve(strict=True)
    handler = partial(PreviewHandler, directory=str(web_root))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
