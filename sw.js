/* სუფრა service worker: app shell offline, fonts cache, web push */
const V='202610190548';
const SHELL='sufra-shell-'+V,RUNTIME='sufra-rt-1';
const ASSETS=['/','/manifest.webmanifest','/icons/icon-192.png','/icons/icon-512.png','/icons/badge-96.png',
 '/css/base.css?v='+V,'/css/app.css?v='+V,
 ...['lib-icons','lib-lang','lib-motion','core','stickers','namedays','auth','feed','home','people','chat','community','rooms','sport','rides','jobs','places','toasts','help','family','dating','games-core','games-engines','settings','firststeps','albums','admin','app'].map(f=>`/js/${f}.js?v=${V}`)];
self.addEventListener('install',e=>{e.waitUntil(caches.open(SHELL).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k.startsWith('sufra-shell-')&&k!==SHELL).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{const r=e.request;if(r.method!=='GET')return;const u=new URL(r.url);
 if(r.mode==='navigate'){e.respondWith(fetch(r).then(res=>{const cp=res.clone();caches.open(SHELL).then(c=>c.put('/',cp));return res}).catch(()=>caches.match('/')));return}
 if(u.origin===location.origin){e.respondWith(caches.match(r).then(hit=>hit||fetch(r).then(res=>{if(res.ok&&/^\/(js|css|icons)\//.test(u.pathname)){const cp=res.clone();caches.open(SHELL).then(c=>c.put(r,cp))}return res})));return}
 if(/fonts\.(googleapis|gstatic)\.com$|cdn\.jsdelivr\.net$|cdnjs\.cloudflare\.com$/.test(u.hostname)){e.respondWith(caches.open(RUNTIME).then(c=>c.match(r).then(hit=>{const net=fetch(r).then(res=>{if(res.ok||res.type==='opaque')c.put(r,res.clone());return res}).catch(()=>hit);return hit||net})));return}
 /* everything else (Supabase API, storage, realtime) goes straight to the network */});

self.addEventListener('push',e=>{let d={};try{d=e.data?e.data.json():{}}catch(x){d={body:e.data&&e.data.text()}}
 const title=d.title||'სუფრა',url=d.url||'/';
 e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{
  /* if the app is open and visible, the in-app banner already shows it */
  if(list.some(c=>c.visibilityState==='visible'&&c.focused))return;
  return self.registration.showNotification(title,{body:d.body||'',icon:'/icons/icon-192.png',badge:'/icons/badge-96.png',tag:d.tag||undefined,renotify:!!d.tag,data:{url},lang:'ka',vibrate:[60,40,60]})}))});
self.addEventListener('notificationclick',e=>{e.notification.close();const url=new URL((e.notification.data&&e.notification.data.url)||'/',self.location.origin).href;
 e.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(list=>{
  for(const c of list){if(new URL(c.url).origin===self.location.origin){c.postMessage({type:'open',url});return c.focus()}}
  return self.clients.openWindow(url)}))});
self.addEventListener('pushsubscriptionchange',e=>{/* the app re-subscribes on next open from settings */});
