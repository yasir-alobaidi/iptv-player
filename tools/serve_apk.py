#!/usr/bin/env python3
"""Hands an APK to a TV on the same Wi-Fi, with no wireless debugging and
no link on the internet (docs/install/android-tv.md, "From this
computer"): on the TV, the Downloader app opens this computer's address,
and every address here answers with the APK.

    python3 tools/serve_apk.py                  # dist/Bijou-TV.apk
    python3 tools/serve_apk.py some/other.apk --port 8000

It prints what to type on the TV (e.g. 192.168.1.254:8000) and runs until
Ctrl+C. Nothing but the APK is served. Standard library only.
"""

import argparse
import http.server
import os
import socket
import sys


def addresses():
    """This computer's IPv4 addresses on the local network."""
    found = []
    try:
        # The address a connection out would leave from (nothing is sent).
        probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        probe.connect(("192.168.0.1", 9))
        found.append(probe.getsockname()[0])
        probe.close()
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            address = info[4][0]
            if not address.startswith("127.") and address not in found:
                found.append(address)
    except OSError:
        pass
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("apk", nargs="?", default=os.path.join("dist", "Bijou-TV.apk"))
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()

    if not os.path.isfile(args.apk):
        sys.exit(f"No APK at {args.apk}: build it with tools/dist_apk.sh first.")
    apk = os.path.abspath(args.apk)
    name = os.path.basename(apk)
    size = os.path.getsize(apk)

    class Handler(http.server.BaseHTTPRequestHandler):
        def _head(self):
            self.send_response(200)
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            self.send_header("Content-Length", str(size))
            self.send_header("Content-Disposition", f'attachment; filename="{name}"')
            self.end_headers()

        def do_HEAD(self):
            self._head()

        def do_GET(self):
            self._head()
            with open(apk, "rb") as f:
                while True:
                    chunk = f.read(1 << 20)
                    if not chunk:
                        break
                    try:
                        self.wfile.write(chunk)
                    except (BrokenPipeError, ConnectionResetError):
                        return
            print(f"  sent {name} to {self.client_address[0]}", flush=True)

        def log_message(self, *_):
            pass

    try:
        server = http.server.ThreadingHTTPServer(("0.0.0.0", args.port), Handler)
    except OSError as error:
        sys.exit(f"Port {args.port} is taken ({error}): try --port 8001.")
    print(f"Serving {name} ({size / 1e6:.0f} MB).")
    print("On the TV, open Downloader and type one of these, then Go:")
    for address in addresses() or ["<this computer's address>"]:
        print(f"  {address}:{args.port}")
    print("Ctrl+C here when the TV has it.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print()


if __name__ == "__main__":
    main()
