"""Generate an explicit static-asset cache. Never intercept API or media requests."""
from pathlib import Path
import hashlib
import json
root = Path('build/web')
assets = sorted(str(p.relative_to(root)) for p in root.rglob('*')
                if p.is_file() and p.suffix not in {'.map'}
                and p.name not in {'rsa_service_worker.js', 'flutter_service_worker.js'})
version = hashlib.sha256(b''.join((root / p).read_bytes() for p in assets)).hexdigest()[:16]
script = """const CACHE='rsa-shell-VERSION';
const FILES=FILES_JSON;
const URLS=new Set(FILES.map(p=>new URL(p,self.registration.scope).href));
self.addEventListener('install',event=>event.waitUntil(
  caches.open(CACHE).then(c=>c.addAll(FILES)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(
  caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('rsa-shell-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
  const request=event.request;
  if(request.method!=='GET'||new URL(request.url).origin!==self.location.origin)return;
  if(request.mode==='navigate'){
    event.respondWith(fetch(request).catch(()=>caches.match(new URL('index.html',self.registration.scope))));
  }else if(URLS.has(request.url)){
    event.respondWith(caches.match(request).then(hit=>hit||fetch(request)));
  }
});
""".replace('FILES_JSON',json.dumps(assets)).replace('VERSION',version)
(root / 'rsa_service_worker.js').write_text(script)
print(f'App shell: {len(assets)} static assets, cache {version}')
