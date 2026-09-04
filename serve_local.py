import http.server
import socketserver
import os
import urllib.parse

PORT = 8080
WEB_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), 'build', 'web'))

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def translate_path(self, path):
        # Extract pure path without query strings
        url_path = urllib.parse.urlparse(path).path
        if url_path.startswith('/portal-new'):
            url_path = url_path[len('/portal-new'):]
        
        if not url_path or url_path == '/':
            url_path = '/index.html'
        
        local_path = os.path.normpath(os.path.join(WEB_DIR, url_path.lstrip('/')))
        # Fallback to index.html for SPA client-side routing if file doesn't exist
        if not os.path.exists(local_path):
            return os.path.join(WEB_DIR, 'index.html')
        return local_path

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == '' or parsed.path == '/':
            self.send_response(302)
            self.send_header('Location', '/portal-new/')
            self.end_headers()
            return
        return super().do_GET()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Access-Control-Allow-Origin', '*')
        super().end_headers()

if __name__ == '__main__':
    with ThreadedHTTPServer(("", PORT), CustomHandler) as httpd:
        print(f"Serving Nissie Ideal Shelters Portal at: http://localhost:{PORT}/portal-new/")
        httpd.serve_forever()
