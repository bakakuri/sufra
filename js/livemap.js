/* the live map: where friends are right now, on a satellite globe, a 3D map with mountains and buildings, or a street map;
   and sharing one's own place live. A place is shared only by choice, for a while (15 minutes, an hour, 8 hours or until
   stopped), with friends or with everyone, exactly or roughly (about a kilometre, rounded on the server). It moves while
   Peera is open on that phone; a phone that closed the site leaves its last place, greyed, with how long ago it was.
   Who sees what is decided on the server (live_map): the admin sees every shared place; others see themselves, friends
   who share, and those who share with everyone when they may reach each other (an adult and a pupil under 18 who do not
   know each other never do; a pupil under 18 shares with friends only). Only the latest place is kept; stopping deletes it.
   The map library (MapLibre) comes from this site, only when the map is opened */
/* global maplibregl */
Object.assign(ERR,{minor_public:'18 წლამდე ლოკაციას მხოლოდ მეგობრებს უზიარებ',bad_location:'მდებარეობა ვერ დადგინდა'});

/* ---- sharing one's own place: runs on every page while it is on ---- */
const LOC={on:null,watch:null,fix:null,sent:null,sentAt:0,t:null,busy:false};
const LOC_MIN=[[15,'15 წთ'],[60,'1 სთ'],[480,'8 სთ'],[0,'სანამ გავთიშავ']];
const geoKm=(a,b)=>{const r=Math.PI/180,x=Math.sin((b[0]-a[0])*r/2)**2+Math.cos(a[0]*r)*Math.cos(b[0]*r)*Math.sin((b[1]-a[1])*r/2)**2;return 12742*Math.asin(Math.min(1,Math.sqrt(x)))};
const locGet=()=>new Promise((res,rej)=>{if(!navigator.geolocation)return rej({code:-1});navigator.geolocation.getCurrentPosition(res,rej,{enableHighAccuracy:true,maximumAge:10000,timeout:20000})});
const locErr=e=>e&&e.code===1?'ლოკაციაზე წვდომა არ მოგვეცა. ჩართე ბრაუზერის ან ტელეფონის პარამეტრებში':e&&e.code===-1?'ამ მოწყობილობაზე ლოკაცია მიუწვდომელია':'მდებარეობა ვერ დადგინდა. სცადე ცოტა ხანში';
/* how long a share still runs: "45 წთ", "7 სთ 20 წთ"; null when it runs until stopped */
function locLeft(o=LOC.on){if(!o||!o.expires_at)return null;const m=Math.max(1,Math.ceil((new Date(o.expires_at)-Date.now())/60000));return m>=60?Math.floor(m/60)+' სთ'+(m%60?' '+m%60+' წთ':''):m+' წთ'}
const locMine=()=>LOC.fix?[LOC.fix.coords.latitude,LOC.fix.coords.longitude]:null;
const locNum=v=>v==null||!isFinite(v)?null:v;
function locWatch(){if(LOC.watch!=null||!LOC.on||!navigator.geolocation)return;
 LOC.watch=navigator.geolocation.watchPosition(p=>{LOC.fix=p;locTick();if(S.page&&S.page.id==='map')lmMeMove()},e=>{if(e.code===1){locUnwatch();toast(locErr(e));locBadge()}},{enableHighAccuracy:true,maximumAge:5000,timeout:30000});
 clearInterval(LOC.t);LOC.t=setInterval(()=>{locTick();locBadge()},15000);locBadge()}
function locUnwatch(){if(LOC.watch!=null){try{navigator.geolocation.clearWatch(LOC.watch)}catch(e){}LOC.watch=null}clearInterval(LOC.t);LOC.t=null}
/* sent when it moved (every 8 seconds at most) or, standing still, every 45 seconds, so friends see it is still live */
async function locTick(){if(!LOC.on)return;if(LOC.on.expires_at&&new Date(LOC.on.expires_at)<=Date.now()){locEnded();return}
 const p=LOC.fix;if(!p||LOC.busy)return;const c=p.coords,now=Date.now(),moved=LOC.sent?geoKm([LOC.sent.lat,LOC.sent.lng],[c.latitude,c.longitude])*1000:1e9;
 if(now-LOC.sentAt<(moved>=15?8000:45000))return;LOC.busy=true;
 try{const r=await rpc('loc_update',{p_lat:c.latitude,p_lng:c.longitude,p_acc:Math.round(locNum(c.accuracy)||0),p_heading:locNum(c.heading)==null?null:Math.round(c.heading),p_speed:locNum(c.speed)});
  if(r&&r.on===false){locEnded();return}
  if(r&&!r.skip){LOC.sent={lat:c.latitude,lng:c.longitude};LOC.sentAt=now}if(r&&LOC.on)LOC.on.expires_at=r.expires_at??null}catch(e){}finally{LOC.busy=false}}
function locEnded(){const was=!!LOC.on;locUnwatch();LOC.on=null;LOC.sent=null;locBadge();if(was)toast('ლაივ ლოკაციის გაზიარება დასრულდა');if(S.page&&S.page.id==='map')lmRows()}
/* start sharing, or change how: who sees it, for how long, how exactly */
async function locStart(o){let p;try{p=await locGet()}catch(e){toast(locErr(e));return false}
 const c=p.coords;let r;try{r=await rpc('loc_share',{p_lat:c.latitude,p_lng:c.longitude,p_acc:Math.round(locNum(c.accuracy)||0),p_audience:o.aud,p_minutes:o.min,p_approx:!!o.approx})}catch(e){toast(errMsg(e));return false}
 LOC.on=r;LOC.fix=p;LOC.sent={lat:c.latitude,lng:c.longitude};LOC.sentAt=Date.now();store.set('lshare',{aud:o.aud,min:o.min,approx:!!o.approx});locWatch();locBadge();return true}
async function locStop(){try{await rpc('loc_stop')}catch(e){toast(errMsg(e));return false}locUnwatch();LOC.on=null;LOC.sent=null;locBadge();if(S.page&&S.page.id==='map')lmRows();return true}
/* after a reload: a share that still runs goes on by itself if the phone already allows the location, otherwise it waits for a tap */
async function locResume(){if(!ME||ME.offline||!pageOk('map'))return;
 try{const r=await q(sb.from('live_locations').select('audience,approx,started_at,expires_at').eq('user_id',ME.id).maybeSingle());
  if(!r||(r.expires_at&&new Date(r.expires_at)<=Date.now()))return;LOC.on=Object.assign({on:true},r);
  let st='prompt';try{st=(await navigator.permissions.query({name:'geolocation'})).state}catch(e){}
  if(st==='granted')locWatch();locBadge()}catch(e){}}
/* the pin in the top bar while sharing; grey when the place is not being refreshed */
function locBadge(){const el=$('#lpin');if(el){el.innerHTML=LOC.on?`<button class="ibtn lpin${LOC.watch==null?' paused':''}" data-a="page" data-p="map" aria-label="${LOC.watch==null?'ლაივ ლოკაცია: განახლება შეჩერებულია':'ლაივ ლოკაცია ჩართულია'}">${ic('locate')}<i aria-hidden="true"></i></button>`:'';if(typeof fitTop==='function')fitTop()}
 if(S.page&&S.page.id==='map')lmBar()}
document.addEventListener('visibilitychange',()=>{if(document.hidden)return;if(LOC.on){LOC.sentAt=0;locTick()}if(S.page&&S.page.id==='map')lmRows()});

/* the share sheet */
A.lmshare=()=>{const o=Object.assign({aud:'friends',min:60,approx:false},store.get('lshare',{}));if(LOC.on){o.aud=LOC.on.audience;o.approx=!!LOC.on.approx}
 const minor=(age(ME.birthday)??99)<18;if(minor)o.aud='friends';if(!LOC_MIN.some(([m])=>m===o.min))o.min=60;S.lsh=Object.assign(o,{touched:false});
 const seg=(k,opts,cur)=>`<div class="seg lsseg" role="group" aria-label="${k==='aud'?'ვინ დაინახოს':k==='min'?'რამდენ ხანს':'სიზუსტე'}">${opts.map(([v,l,dis])=>`<button type="button" data-a="lsopt" data-k="${k}" data-v="${v}" aria-pressed="${String(v)===String(cur)}"${dis?' disabled':''}>${l}</button>`).join('')}</div>`;
 sheet(head('ლაივ ლოკაცია')+`<div class="ph-body lsh"><p class="lsh-lead">${ic('locate')}<span>შენი ადგილი რუკაზე შენთან ერთად იმოძრავებს, სანამ Peera გახსნილი გაქვს.</span></p>
  <p class="lslbl">ვინ დაინახოს</p>${seg('aud',[['friends','მეგობრებმა'],['public','ყველამ',minor]],o.aud)}${minor?'<p class="note">18 წლამდე ლოკაციას მხოლოდ მეგობრებს უზიარებ.</p>':''}
  <p class="lslbl">რამდენ ხანს</p>${seg('min',LOC_MIN,o.min)}
  <p class="lslbl">სიზუსტე</p>${seg('approx',[['0','ზუსტი'],['1','მიახლოებით, ~1 კმ']],o.approx?'1':'0')}
  <p class="note lsh-note">გაზიარებულ ლოკაციას საიტის ადმინისტრაციაც ხედავს. ისტორია არ ინახება: გათიშვისას შენი ადგილი იშლება.</p></div>
  <div class="ph-foot">${LOC.on?'<button class="btn ghost danger" data-a="lmstop">გაჩერება</button>':'<button class="btn ghost" data-a="close">გაუქმება</button>'}<span class="sp"></span><button class="btn" id="ls_go">${ic('locate')}${LOC.on?'შენახვა':'გაზიარება'}</button></div>`,'short');
 $('#ls_go').onclick=async()=>{const b=$('#ls_go');b.disabled=true;const s=S.lsh,ok=await locStart({aud:s.aud,min:+s.min,approx:s.approx});if(!b.isConnected)return;b.disabled=false;if(!ok)return;closeSheet();
  toast(s.aud==='public'?'შენი ლოკაცია ყველას უჩანს':'შენი ლოკაცია მეგობრებს უჩანს');if(S.page&&S.page.id==='map'){lmRows();lmGoMe()}else openPage('map')}};
A.lsopt=t=>{const s=S.lsh;if(!s||t.disabled)return;const k=t.dataset.k,v=t.dataset.v;
 if(k==='aud'){s.aud=v;if(!s.touched){s.approx=v==='public';$$('[data-a="lsopt"][data-k="approx"]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.v===(s.approx?'1':'0'))))}}
 else if(k==='min')s.min=+v;else{s.approx=v==='1';s.touched=true}
 $$(`[data-a="lsopt"][data-k="${k}"]`).forEach(b=>b.setAttribute('aria-pressed',String(b===t)))};
A.lmstop=async()=>{if(await locStop()){closeSheet();toast('ლაივ ლოკაცია გაითიშა')}};
A.lmresume=()=>{if(!LOC.on)return;locWatch();toast('ვადგენ შენს მდებარეობას…')};

/* ---- the map page ---- */
const ML_V='5.24.0';let MLP=null;
function mlLoad(){if(window.maplibregl)return Promise.resolve(window.maplibregl);if(MLP)return MLP;
 MLP=new Promise((res,rej)=>{const c=document.createElement('link');c.rel='stylesheet';c.href=`/js/vendor/maplibre-gl-${ML_V}.css`;document.head.appendChild(c);
  const s=document.createElement('script');s.src=`/js/vendor/maplibre-gl-${ML_V}.js`;s.onload=()=>window.maplibregl?res(window.maplibregl):(MLP=null,rej(new Error('map')));s.onerror=()=>{MLP=null;s.remove();rej(new Error('map'))};document.head.appendChild(s)});return MLP}
/* the pictures: satellite photos (Esri World Imagery) with place names over them, the height of the ground (Terrain Tiles,
   open data on AWS) for the 3D view with buildings (OpenFreeMap), and the street map (OpenStreetMap) */
const LMS={
 sat:{type:'raster',tiles:['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],tileSize:256,maxzoom:19,attribution:'Esri, Maxar, Earthstar Geographics, GIS User Community'},
 lbl:{type:'raster',tiles:['https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}'],tileSize:256,maxzoom:19},
 osm:{type:'raster',tiles:['https://tile.openstreetmap.org/{z}/{x}/{y}.png'],tileSize:256,maxzoom:19,attribution:'© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>'},
 dem:{type:'raster-dem',tiles:['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],tileSize:256,maxzoom:15,encoding:'terrarium',attribution:'რელიეფი: Mapzen, AWS Open Data'},
 ofm:{type:'vector',url:'https://tiles.openfreemap.org/planet',attribution:'<a href="https://openfreemap.org" target="_blank" rel="noopener">OpenFreeMap</a> © OpenMapTiles'}};
const LM_MODES=[['sat','სატელიტი'],['3d','3D'],['map','რუკა']];
const LM_LOC={'NavigationControl.ZoomIn':'გადიდება','NavigationControl.ZoomOut':'დაპატარავება','NavigationControl.ResetBearing':'ჩრდილოეთისკენ','AttributionControl.ToggleAttribution':'წყაროები','Map.Title':'რუკა','Marker.Title':'ადგილი','GlobeControl.Enable':'გლობუსი','GlobeControl.Disable':'ბრტყელი რუკა'};
const LM={map:null,mk:new Map(),self:null,rows:[],t:null,tok:0,mode:'sat',fit:false,fol:null,loaded:false,ready:false};
const lmLive=r=>Date.now()-new Date(r.updated_at).getTime()<180000;
const lmAgo=ts=>{const a=ago(ts);return a==='ახლა'?'ახლა':a+' წინ'};
const lmFirst=p=>String(p&&p.name||'').trim().split(/\s+/)[0]||'მომხმარებელი';
/* a rough share: a circle of about a kilometre around the rounded point */
function lmZones(){const f=[];for(const r of LM.rows){if(!r.approx)continue;const ring=[],km=.8;for(let i=0;i<=48;i++){const a=i/48*2*Math.PI;ring.push([r.lng+km/(111.32*Math.cos(r.lat*Math.PI/180))*Math.cos(a),r.lat+km/110.57*Math.sin(a)])}f.push({type:'Feature',properties:{},geometry:{type:'Polygon',coordinates:[ring]}})}return{type:'FeatureCollection',features:f}}
function lmStyle(mode){const st={version:8,projection:{type:'globe'},sources:{},layers:[{id:'bg',type:'background',paint:{'background-color':mode==='map'?'#dfe7ee':'#0b1424'}}],
  sky:{'sky-color':'#071330','horizon-color':'#86b4ff','fog-color':'#d6e6ff','sky-horizon-blend':.6,'horizon-fog-blend':.7,'fog-ground-blend':.7,'atmosphere-blend':['interpolate',['linear'],['zoom'],0,1,5,1,8,0]}};
 if(mode==='map'){st.sources.osm=LMS.osm;st.layers.push({id:'osm',type:'raster',source:'osm'})}
 else{st.sources.sat=LMS.sat;st.layers.push({id:'sat',type:'raster',source:'sat'});
  if(mode==='3d'){st.sources.dem=LMS.dem;st.terrain={source:'dem',exaggeration:1.4};st.sources.ofm=LMS.ofm;
   st.layers.push({id:'bld',type:'fill-extrusion',source:'ofm','source-layer':'building',minzoom:14.5,paint:{'fill-extrusion-color':'#EFE7DA','fill-extrusion-height':['coalesce',['get','render_height'],6],'fill-extrusion-base':['coalesce',['get','render_min_height'],0],'fill-extrusion-opacity':.85}})}
  st.sources.lbl=LMS.lbl;st.layers.push({id:'lbl',type:'raster',source:'lbl',paint:{'raster-opacity':.92}})}
 st.sources.zones={type:'geojson',data:lmZones()};
 st.layers.push({id:'zones',type:'fill',source:'zones',paint:{'fill-color':'#3E8EF7','fill-opacity':.18}},{id:'zonel',type:'line',source:'zones',paint:{'line-color':'#8CC0FF','line-width':1.5,'line-dasharray':[2,2]}});
 return st}

PG.map={cls:'is-map',r(){lmPage()}};
function lmPage(){lmClose();const m=store.get('lmmode','sat');LM.mode=LM_MODES.some(x=>x[0]===m)?m:'sat';LM.fit=false;LM.fol=null;LM.rows=[];LM.loaded=false;LM.ready=false;
 view.innerHTML=pgHead('ლაივ რუკა',`<button class="btn sm" data-a="lmshare">${ic('locate')}<span id="lmsb">${LOC.on?'ჩემი ლოკაცია':'გაზიარება'}</span></button>`)+`<div class="lmw" id="lmw">
  <div id="lmap" class="lmap"></div>
  <div class="seg lm-modes" role="group" aria-label="რუკის ხედი">${LM_MODES.map(([k,l])=>`<button data-a="lmmode" data-k="${k}" aria-pressed="${k===LM.mode}">${l}</button>`).join('')}</div>
  <div class="lm-ctl"><button class="lm-b" data-a="lmme" aria-label="ჩემი ადგილი">${ic('locate')}</button><button class="lm-b" data-a="lmglobe" aria-label="მთელი დედამიწა">${ic('globe')}</button></div>
  <div class="lm-bot"><div id="lmbar"></div><div class="lm-ppl" id="lmppl" role="list" aria-label="ვინ ჩანს რუკაზე"></div></div>
  <div class="lm-load" id="lmload"><span class="spin" aria-label="რუკა იტვირთება"></span></div></div>`;
 S.chanCleanup=lmClose;lmBar();lmRows();LM.t=setInterval(()=>{if(!document.hidden)lmRows()},10000);
 mlLoad().then(lmInit).catch(lmFail)}
/* leaving the page: the map lets its graphics go (a phone keeps only a few of them) */
function lmClose(){clearInterval(LM.t);LM.t=null;LM.tok++;for(const m of LM.mk.values())cancelAnimationFrame(m._raf);LM.mk.clear();LM.self=null;LM.ready=false;
 if(LM.map){const m=LM.map;LM.map=null;try{m.remove()}catch(e){}}}
function lmInit(){const el=$('#lmap');if(!el||LM.map||!S.page||S.page.id!=='map')return;let map;
 try{map=new maplibregl.Map({container:el,style:lmStyle(LM.mode),center:[43.4,42.1],zoom:1.3,pitch:0,maxPitch:78,attributionControl:false,locale:LM_LOC,fadeDuration:150})}catch(e){lmFail();return}
 LM.map=map;map.addControl(new maplibregl.NavigationControl({visualizePitch:true}),'top-right');map.addControl(new maplibregl.AttributionControl({compact:true}),'top-left');
 map.on('error',()=>{});/* a picture that did not come is simply missing */
 map.on('load',()=>{const l=$('#lmload');if(l)l.hidden=true;LM.ready=true;if(LM.mode==='3d')map.easeTo({pitch:55,duration:0});lmDraw()});
 map.on('dragstart',()=>{LM.fol=null});
 lmDraw()}
function lmFail(){const l=$('#lmload');if(l)l.hidden=true;const el=$('#lmap');if(!el)return;$('#lmw')?.classList.add('nomap');
 el.innerHTML=`<div class="lm-fail">${empty('რუკა ვერ გაიხსნა','ამ მოწყობილობაზე ან ბრაუზერში რუკა ვერ ჩაირთო. ვინც ლოკაციას გიზიარებს, ქვემოთ ჩანს.','<button class="btn" data-a="lmretry">თავიდან ცდა</button>')}</div>`}
A.lmretry=()=>{if(S.page&&S.page.id==='map')lmPage()};
async function lmRows(){if(!S.page||S.page.id!=='map')return;const tok=++LM.tok;let rows;
 try{rows=await rpc('live_map')}catch(e){if(tok===LM.tok&&!LM.loaded){LM.loaded=true;lmPeople(true)}return}
 rows=Array.isArray(rows)?rows:[];try{await loadProfiles(rows.map(r=>r.user_id))}catch(e){}
 if(tok!==LM.tok||!S.page||S.page.id!=='map')return;LM.rows=rows;LM.loaded=true;
 lmDraw()}
function lmDraw(){if(!S.page||S.page.id!=='map')return;lmPeople();lmBar();const map=LM.map;if(!map)return;const seen=new Set();
 for(const r of LM.rows){const id=r.user_id;seen.add(id);const pos=lmPos(r);let m=LM.mk.get(id);
  if(!m){const el=lmEl(r);m=new maplibregl.Marker({element:el,anchor:'bottom'}).setLngLat(pos).addTo(map);LM.mk.set(id,m)}else lmMove(m,pos);lmCls(m.getElement(),r)}
 for(const[id,m]of LM.mk)if(!seen.has(id)){cancelAnimationFrame(m._raf);m.remove();LM.mk.delete(id)}
 {const mr=LM.rows.find(x=>x.user_id===ME.id);if(LM.self&&mr&&!mr.approx){LM.self.remove();LM.self=null}}
 if(LM.ready){try{map.getSource('zones')?.setData(lmZones())}catch(e){}}
 if(LM.fol){const r=LM.rows.find(x=>x.user_id===LM.fol);if(r)map.easeTo({center:lmPos(r),duration:RM()?0:900});else LM.fol=null}
 if(!LM.fit&&LM.loaded&&LM.ready)lmFit()}
/* my own marker follows the phone at once, without waiting for the server */
const lmPos=r=>r.user_id===ME.id&&LOC.fix&&!r.approx?[LOC.fix.coords.longitude,LOC.fix.coords.latitude]:[r.lng,r.lat];
function lmMeMove(){const m=LM.mk.get(ME.id),r=LM.rows.find(x=>x.user_id===ME.id);if(m&&r&&!r.approx)lmMove(m,lmPos(r));lmPeople()}
/* the first look: from space down to whoever is on the map */
function lmFit(){LM.fit=true;const map=LM.map;if(!map)return;const d=RM()?0:2800,pts=LM.rows.map(lmPos),mine=locMine();
 if(!pts.length){map.flyTo(mine?{center:[mine[1],mine[0]],zoom:13,duration:d}:{center:[43.5,42.2],zoom:5.6,duration:d});return}
 if(pts.length===1){map.flyTo({center:pts[0],zoom:14,duration:d});return}
 const b=new maplibregl.LngLatBounds(pts[0],pts[0]);pts.forEach(p=>b.extend(p));map.fitBounds(b,{padding:{top:70,bottom:190,left:50,right:70},maxZoom:14,duration:d})}
function lmEl(r){const el=document.createElement('div');el.className='lmk';
 el.innerHTML=`<button type="button" class="lmk-p" data-a="lmpeek" data-u="${esc(r.user_id)}">${av(prof(r.user_id),40)}</button><b class="lmk-n"></b>`;return el}
function lmCls(el,r){const me=r.user_id===ME.id,live=lmLive(r),p=prof(r.user_id);
 /* the map keeps its own classes on the element (its place on the map comes from them) */
 const set=(k,on)=>el.classList.toggle(k,!!on);set('lmk',1);set('me',me);set('fr',!me&&r.friend);set('pub',!me&&!r.friend);set('live',live);set('stale',!live);set('approx',r.approx);set('fol',LM.fol===r.user_id);
 const n=$('.lmk-n',el);if(n)n.textContent=me?'შენ':lmFirst(p);
 const b=$('.lmk-p',el);if(b)b.setAttribute('aria-label',`${me?'შენ':p.name}, ${live?'ახლა აქ არის':'ბოლოს '+lmAgo(r.updated_at)}`)}
function lmMove(m,to){const from=m.getLngLat();cancelAnimationFrame(m._raf);
 if(RM()||geoKm([from.lat,from.lng],[to[1],to[0]])>30||(from.lng===to[0]&&from.lat===to[1])){m.setLngLat(to);return}
 const t0=performance.now();const step=t=>{const k=Math.min(1,(t-t0)/900),e=1-(1-k)**3;m.setLngLat([from.lng+(to[0]-from.lng)*e,from.lat+(to[1]-from.lat)*e]);if(k<1)m._raf=requestAnimationFrame(step)};m._raf=requestAnimationFrame(step)}
/* the strip at the bottom: everyone on the map, nearest news first; a tap flies there */
function lmPeople(failed){const el=$('#lmppl');if(!el)return;if(!LM.loaded){el.innerHTML='';return}
 const meRow=LM.rows.find(r=>r.user_id===ME.id),mine=locMine()||(meRow?[meRow.lat,meRow.lng]:null)||S.geo||null,rows=LM.rows.filter(r=>r.user_id!==ME.id);
 if(failed&&!rows.length){el.innerHTML=`<div class="lm-empty" role="listitem">${ic('globe')}<span><b>ვერ ჩაიტვირთა</b><small>შეამოწმე ინტერნეტი, რუკა თავად განახლდება.</small></span></div>`;return}
 if(!rows.length){el.innerHTML=`<div class="lm-empty" role="listitem">${ic('users')}<span><b>ჯერ არავინ ჩანს</b><small>${LOC.on?'მეგობრები აქ გამოჩნდებიან, როცა ლოკაციას გააზიარებენ.':'გააზიარე შენი ლოკაცია და მეგობრებსაც უთხარი.'}</small></span></div>`;return}
 el.innerHTML=(isAdm()?`<span class="lm-adm" role="listitem" title="ადმინი ხედავს ყველა გაზიარებულ ლოკაციას">${ic('shield')}${rows.length}</span>`:'')+rows.map(r=>{const p=prof(r.user_id),live=lmLive(r),km=mine?geoKm(mine,[r.lat,r.lng]):null;
  return `<button class="lmp${live?' live':''}${r.friend?'':' pub'}" role="listitem" data-a="lmfly" data-u="${esc(r.user_id)}">${av(p,34)}<span><b>${esc(lmFirst(p))}</b><small>${lmAgo(r.updated_at)}${km!=null?' · '+fmtKm(km):''}</small></span></button>`}).join('')}
/* my own sharing, above the strip */
function lmBar(){const el=$('#lmbar');if(!el)return;const sb=$('#lmsb');if(sb)sb.textContent=LOC.on?'ჩემი ლოკაცია':'გაზიარება';
 if(!LOC.on){el.innerHTML=`<button class="lm-cta" data-a="lmshare">${ic('locate')}<span><b>ლაივ ლოკაციის გაზიარება</b><small>მეგობრები დაინახავენ, სად ხარ ახლა</small></span></button>`;return}
 const paused=LOC.watch==null,left=locLeft();
 el.innerHTML=`<div class="lm-on${paused?' paused':''}"><i class="lm-pulse" aria-hidden="true"></i><button class="lm-onx" data-a="lmshare" aria-label="გაზიარების შეცვლა"><b>${paused?'განახლება შეჩერებულია':'შენი ლოკაცია ჩანს'}</b><small>${LOC.on.audience==='public'?'ყველას':'მეგობრებს'}${LOC.on.approx?' · მიახლოებით':''} · ${left?left+' დარჩა':'სანამ გათიშავ'}</small></button>${paused?'<button class="btn sm" data-a="lmresume">გაგრძელება</button>':''}<button class="btn sm danger" data-a="lmstop">გაჩერება</button></div>`}
/* a person on the map: when it was, how far, until when; their profile, a message, following them, the way there */
A.lmpeek=t=>lmPeek(t.dataset.u);
function lmPeek(id){const r=LM.rows.find(x=>x.user_id===id);if(!r)return;const p=prof(id),me=id===ME.id,live=lmLive(r),mine=locMine()||S.geo||null;
 const km=!me&&mine?geoKm(mine,[r.lat,r.lng]):null;
 const facts=[[live?'ახლა აქ არის':'ბოლოს განახლდა '+lmAgo(r.updated_at),'clock'],km!=null&&['შენგან '+fmtKm(km),'route'],!r.approx&&r.speed>1.2&&live&&[`მოძრაობს, ~${Math.round(r.speed*3.6)} კმ/სთ`,'pin'],
  r.approx&&['მიახლოებითი ადგილი, ~1 კმ','map'],[r.audience==='public'?'ყველას უზიარებს':'მეგობრებს უზიარებს','users'],r.expires_at&&[`დასრულდება ${locLeft(r)}-ში`,'timer']].filter(Boolean);
 sheet(`<div class="ph-head lmph">${av(p,48)}<span class="grow"><h2>${me?'შენ':esc(p.name)}${me?'':vb(p)}</h2>${p.username&&!me?`<small>@${esc(p.username)}</small>`:''}</span><button class="ibtn" data-a="close" aria-label="დახურვა">${ic('x')}</button></div>
  <div class="ph-body"><ul class="lmfacts">${facts.map(([t,i])=>`<li>${ic(i)}<span>${t}</span></li>`).join('')}</ul></div>
  <div class="ph-foot lmpf">${me?'<button class="btn ghost" data-a="lmshare">შეცვლა</button><span class="sp"></span><button class="btn danger" data-a="lmstop">გაჩერება</button>':
   `<button class="btn ghost" data-a="user" data-u="${esc(id)}">${ic('user')}პროფილი</button><button class="btn ghost" data-a="chatwith" data-u="${esc(id)}">${ic('msg')}მიწერა</button><button class="btn ghost" data-a="lmfollow" data-u="${esc(id)}">${ic('locate')}მიყოლა</button><a class="btn" href="https://www.google.com/maps/dir/?api=1&amp;destination=${+r.lat},${+r.lng}" target="_blank" rel="noopener">${ic('route')}მარშრუტი</a>`}</div>`,'short lmpeek')}
A.lmfly=t=>{const id=t.dataset.u,r=LM.rows.find(x=>x.user_id===id),map=LM.map;if(!r)return;if(!map||!LM.ready){lmPeek(id);return}
 const pos=lmPos(r),c=map.getCenter();if(geoKm([c.lat,c.lng],[pos[1],pos[0]])<.05&&map.getZoom()>=14){lmPeek(id);return}
 LM.fol=null;map.flyTo({center:pos,zoom:Math.max(map.getZoom(),r.approx?13:15.5),pitch:LM.mode==='3d'?60:map.getPitch(),duration:RM()?0:2000})};
A.lmfollow=t=>{const id=t.dataset.u,r=LM.rows.find(x=>x.user_id===id);closeSheet();if(!r||!LM.map)return;LM.fol=id;
 LM.map.flyTo({center:lmPos(r),zoom:Math.max(LM.map.getZoom(),16),duration:RM()?0:1800});lmDraw();toast(`რუკა მიჰყვება: ${lmFirst(prof(id))}. რუკის გაწევა შეწყვეტს`)};
A.lmmode=t=>{const k=t.dataset.k;if(!LM_MODES.some(x=>x[0]===k)||k===LM.mode)return;LM.mode=k;store.set('lmmode',k);$$('[data-a="lmmode"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));
 const map=LM.map;if(!map)return;map.setStyle(lmStyle(k),{diff:false});map.easeTo({pitch:k==='3d'?(map.getZoom()>=6?60:45):0,duration:RM()?0:900})};
/* after sharing: to my marker (the rounded point when the share is rough) */
function lmGoMe(){const g=locMine(),map=LM.map;if(!g||!map)return;const c=LOC.on&&LOC.on.approx?[Math.round(g[1]*100)/100,Math.round(g[0]*100)/100]:[g[1],g[0]];LM.fol=null;map.flyTo({center:c,zoom:Math.max(map.getZoom(),LOC.on&&LOC.on.approx?13.5:15),duration:RM()?0:1800})}
A.lmme=async()=>{let g=locMine();if(!g){toast('ვადგენ შენს მდებარეობას…');try{const p=await locGet();g=[p.coords.latitude,p.coords.longitude];S.geo=g}catch(e){toast(locErr(e));return}}
 const map=LM.map;if(!map||!S.page||S.page.id!=='map')return;
 /* the blue dot is where the phone is; with a rough share the marker others see stays on the rounded point */
 const mr=LM.rows.find(x=>x.user_id===ME.id);if(!mr||mr.approx){if(!LM.self){const el=document.createElement('div');el.className='lm-self';el.setAttribute('role','img');el.setAttribute('aria-label','შენ აქ ხარ');LM.self=new maplibregl.Marker({element:el}).setLngLat([g[1],g[0]]).addTo(map)}else LM.self.setLngLat([g[1],g[0]])}
 LM.fol=null;map.flyTo({center:[g[1],g[0]],zoom:Math.max(map.getZoom(),15),duration:RM()?0:1800})};
A.lmglobe=()=>{const map=LM.map;if(!map)return;LM.fol=null;map.flyTo({center:map.getCenter(),zoom:1.4,pitch:0,bearing:0,duration:RM()?0:2200})};
