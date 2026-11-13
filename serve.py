"""Preview the independent organizer build without caching previous versions."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from functools import partial
from pathlib import Path
import socket


class OrganizerHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        super().end_headers()

    def do_GET(self):
        if self.path in ('/', '/organizer'):
            self.send_response(302)
            self.send_header('Location', '/organizer/')
            self.end_headers()
            return
        if not self.path.startswith('/organizer/'):
            self.send_error(404)
            return
        self.path = self.path[len('/organizer'):]
        super().do_GET()


class OrganizerServer(ThreadingHTTPServer):
    allow_reuse_address = False

    def server_bind(self):
        if hasattr(socket, 'SO_EXCLUSIVEADDRUSE'):
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()


if __name__ == '__main__':
    root = Path(__file__).resolve().parent / 'site'
    server = OrganizerServer(('127.0.0.1', 8081), partial(OrganizerHandler, directory=str(root)))
    print('Organizer: http://127.0.0.1:8081/organizer/', flush=True)
    server.serve_forever()
