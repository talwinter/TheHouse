"""Serve the web build locally with correct MIME types, then open it in Edge.

    python tools/serve_web.py            (serves build/web on http://localhost:8060)

Python's default server reads MIME types from the Windows registry, which often maps
.js to text/plain; browsers then refuse Godot's audio worklets. This fixes the types.
"""
import functools
import http.server
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8060
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".js": "application/javascript",
        ".mjs": "application/javascript",
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".html": "text/html",
        ".png": "image/png",
    }

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


if __name__ == "__main__":
    handler = functools.partial(Handler, directory=ROOT)
    print("Serving %s at http://localhost:%d  (Ctrl+C to stop)" % (ROOT, PORT))
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), handler).serve_forever()
