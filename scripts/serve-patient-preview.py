#!/usr/bin/env python3
"""Loopback-only development preview. Rebuilt Flutter assets must not return stale 304s."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

# Older Flutter previews installed an offline worker. Retire only Flutter's
# caches so a returning browser loads the current build, while retaining login
# storage and any unrelated cache entries on this origin.
RETIRE_FLUTTER_WORKER = b"""
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', event => event.waitUntil((async () => {
  await Promise.all(['flutter-app-cache', 'flutter-temp-cache', 'flutter-app-manifest']
    .map(name => caches.delete(name)));
  await self.registration.unregister();
  const pages = await self.clients.matchAll({type: 'window'});
  await Promise.all(pages.map(page => page.navigate(page.url)));
})()));
"""

class PreviewHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if urlsplit(self.path).path == '/flutter_service_worker.js':
            self.send_response(200)
            self.send_header('Content-Type', 'application/javascript')
            self.send_header('Content-Length', str(len(RETIRE_FLUTTER_WORKER)))
            self.end_headers()
            self.wfile.write(RETIRE_FLUTTER_WORKER)
            return
        if 'If-Modified-Since' in self.headers:
            del self.headers['If-Modified-Since']
        super().do_GET()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

if __name__ == '__main__':
    root = Path(__file__).resolve().parent.parent / 'ant' / 'build' / 'web'
    ThreadingHTTPServer(('127.0.0.1', 5174), partial(PreviewHandler, directory=str(root))).serve_forever()
