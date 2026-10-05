// Sheikha POS offline support: keeps the app and the Firebase library on
// the computer so the till opens and sells even without internet.
// App files: network first (updates arrive as soon as they are published),
// falling back to the saved copy. Libraries and fonts: saved copy first.
const CACHE='sheikha-pos-v3';
const SDK='https://www.gstatic.com/firebasejs/10.12.2/';
const PRECACHE=['./','./index.html','./manifest.json','./icon-192.png','./icon-512.png','./apple-touch-icon.png']
  .concat(['firebase-app-compat.js','firebase-auth-compat.js','firebase-firestore-compat.js'].map(f=>SDK+f));

self.addEventListener('install',e=>{
  e.waitUntil(caches.open(CACHE).then(c=>Promise.all(PRECACHE.map(u=>c.add(u).catch(()=>{})))));
  self.skipWaiting();
});
self.addEventListener('activate',e=>{
  e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()));
});
self.addEventListener('fetch',e=>{
  const req=e.request;
  if(req.method!=='GET')return;
  const u=new URL(req.url);
  const save=res=>{if(res&&res.ok){const copy=res.clone();caches.open(CACHE).then(c=>c.put(req,copy))}return res};
  if(u.origin===self.location.origin){
    e.respondWith(fetch(req).then(save).catch(()=>caches.match(req,{ignoreSearch:true}).then(r=>r||caches.match('./index.html'))));
  }else if((u.host==='www.gstatic.com'&&u.pathname.startsWith('/firebasejs/'))||u.host==='fonts.googleapis.com'||u.host==='fonts.gstatic.com'){
    e.respondWith(caches.match(req).then(r=>r||fetch(req).then(save)));
  }
  // everything else (Firebase data, sign-in) goes straight to the network
});
