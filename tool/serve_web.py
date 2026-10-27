"""Serve the web build with MIME types and isolation headers for SQLite WASM."""
import argparse
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--port',type=int,default=8080)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]/'build'/'web'
class Handler(SimpleHTTPRequestHandler):
    extensions_map={**SimpleHTTPRequestHandler.extensions_map,'.wasm':'application/wasm','.js':'text/javascript'}
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(root),**kwargs)
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        self.send_header('Cache-Control','no-cache')
        super().end_headers()
print(f'Serving RSA web build on port {args.port}',flush=True)
ThreadingHTTPServer(('0.0.0.0',args.port),Handler).serve_forever()
