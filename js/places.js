/* places on a map: restaurants, wineries, guesthouses and sights, with reviews and check-ins */
const PKINDS=[['restaurant','რესტორანი','🍽'],['cafe','კაფე','☕'],['bar','ბარი','🍸'],['winery','მარანი','🍷'],['hotel','სასტუმრო','🏨'],['guesthouse','საოჯახო სასტუმრო','🏡'],['sight','ღირსშესანიშნაობა','🏛'],['nature','ბუნება','⛰'],['shop','მაღაზია','🛍'],['other','სხვა','📍']];
const pk=k=>PKINDS.find(x=>x[0]===k)||PKINDS[9];
const TBILISI=[41.7151,44.8271];
const fmtKm=k=>k==null?'':k<1?Math.round(k*1000)+' მ':(k<10?k.toFixed(1):Math.round(k))+' კმ';
const starsTxt=r=>{const n=Math.round(+r||0);return '★'.repeat(n)+'☆'.repeat(5-n)};
const ratingTag=p=>p.reviews?`<span class="stars" aria-label="რეიტინგი ${(+p.rating).toFixed(1)}">${starsTxt(p.rating)}<em>${(+p.rating).toFixed(1)} · ${p.reviews}</em></span>`:'<span class="sub">ჯერ არ შეუფასებიათ</span>';

/* Leaflet is loaded only when a map is actually shown */
let LEAF=null;
function loadLeaflet(){if(window.L)return Promise.resolve(window.L);if(LEAF)return LEAF;
 LEAF=new Promise((res,rej)=>{const c=document.createElement('link');c.rel='stylesheet';c.href='https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css';document.head.appendChild(c);
  const s=document.createElement('script');s.src='https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js';s.onload=()=>res(window.L);s.onerror=()=>{LEAF=null;rej(new Error('რუკა ვერ ჩაიტვირთა'))};document.head.appendChild(s)});return LEAF}
function baseMap(el,center,zoom,opt={}){const map=L.map(el,Object.assign({zoomControl:false,attributionControl:true},opt)).setView(center,zoom);
 L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png',{maxZoom:19,attribution:'© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>'}).addTo(map);
 if(opt.zoomControl!==false&&!opt.static)L.control.zoom({position:'bottomright'}).addTo(map);return map}
const pinIcon=(p,on)=>L.divIcon({className:'mpinw',html:`<span class="mpin${on?' on':''}"><i>${pk(p.kind)[2]}</i>${p.reviews?`<b>${(+p.rating).toFixed(1)}</b>`:''}</span>`,iconSize:[0,0]});
function getGeo(ask){return new Promise(res=>{if(S.geo)return res(S.geo);if(!navigator.geolocation)return res(null);
 const go=()=>navigator.geolocation.getCurrentPosition(p=>{S.geo=[p.coords.latitude,p.coords.longitude];res(S.geo)},()=>res(null),{timeout:9000,maximumAge:300000});
 if(ask)return go();try{navigator.permissions.query({name:'geolocation'}).then(st=>st.state==='granted'?go():res(null)).catch(()=>res(null))}catch(e){res(null)}})}

PG.places={r(){S.pq=S.pq||{kind:'',text:'',view:'map'};const f=S.pq;
 view.innerHTML=pgHead('ადგილები',`<button class="btn sm" data-a="page" data-p="placenew">${ic('plus')}დამატება</button>`)+`<form class="search" id="plf" role="search"><input class="field" id="plq" type="search" placeholder="ხინკალი, მარანი, სასტუმრო, ქალაქი" value="${esc(f.text)}" aria-label="ადგილის ძიება" autocomplete="off"><button type="button" class="ibtn" data-a="plnear" aria-label="ჩემთან ახლოს">${ic('locate')}</button></form>
 <div class="chipsbar" role="group" aria-label="ტიპი"><button data-a="plkind" data-k="" aria-pressed="${!f.kind}">ყველა</button>${PKINDS.map(([k,l,e])=>`<button data-a="plkind" data-k="${k}" aria-pressed="${f.kind===k}">${e} ${l}</button>`).join('')}</div>
 <div class="seg" role="group" aria-label="ხედი" style="margin-top:0">${[['map','რუკა'],['list','სია']].map(([k,l])=>`<button data-a="plview" data-k="${k}" aria-pressed="${f.view===k}">${l}</button>`).join('')}</div>
 <div class="plmapw" id="plmapw"${f.view==='map'?'':' hidden'}><div id="plmap" class="plmap"></div><div id="plpeek" class="plpeek" hidden></div></div><div id="pll"></div>`;
 $('#plf').onsubmit=e=>{e.preventDefault();f.text=$('#plq').value.trim();loadPlaces()};$('#plq').oninput=()=>{clearTimeout(S.plt);S.plt=setTimeout(()=>{f.text=$('#plq').value.trim();loadPlaces()},450)};
 S.plmap=null;getGeo(false).then(g=>{if(!S.pc)S.pc=g||TBILISI;if(f.view==='map')initPlMap();else loadPlaces()})}};
A.plkind=t=>{S.pq.kind=t.dataset.k;$$('[data-a="plkind"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));loadPlaces()};
A.plview=t=>{S.pq.view=t.dataset.k;$$('[data-a="plview"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));$('#plmapw').hidden=S.pq.view!=='map';if(S.pq.view==='map'&&!S.plmap)initPlMap();else{S.plmap?.invalidateSize();loadPlaces()}};
A.plnear=async()=>{toast('ვადგენ შენს მდებარეობას…');const g=await getGeo(true);if(!g){toast('მდებარეობა ვერ დადგინდა. ჩართე ლოკაციაზე წვდომა');return}S.pc=g;if(S.plmap)S.plmap.setView(g,14);else loadPlaces();if(S.plmap){S.plme?.remove();S.plme=L.circleMarker(g,{radius:7,color:'#fff',weight:3,fillColor:'#3E8EF7',fillOpacity:1}).addTo(S.plmap)}};
async function initPlMap(){try{await loadLeaflet()}catch(e){$('#plmapw').innerHTML=`<p class="note" style="padding:16px">${esc(e.message)}. სცადე „სია“.</p>`;return}
 const el=$('#plmap');if(!el)return;const map=S.plmap=baseMap(el,S.pc||TBILISI,S.pz||13);S.plmk=L.layerGroup().addTo(map);
 if(S.geo){S.plme=L.circleMarker(S.geo,{radius:7,color:'#fff',weight:3,fillColor:'#3E8EF7',fillOpacity:1}).addTo(map)}
 map.on('moveend',()=>{const c=map.getCenter();S.pc=[c.lat,c.lng];S.pz=map.getZoom();clearTimeout(S.plmt);S.plmt=setTimeout(loadPlaces,250)});
 map.on('click',()=>{$('#plpeek').hidden=true});setTimeout(()=>map.invalidateSize(),60);loadPlaces()}
async function loadPlaces(){const el=$('#pll');if(!el)return;const f=S.pq,map=S.plmap&&f.view==='map'?S.plmap:null;const tok=S.pltok=(S.pltok||0)+1;
 let c=S.pc||TBILISI,km=f.text?250:30;if(map){const b=map.getBounds(),ce=map.getCenter();c=[ce.lat,ce.lng];km=Math.max(.5,ce.distanceTo(b.getNorthEast())/1000)}
 if(!map)el.innerHTML=skel(3);
 try{const rows=await rpc('places_near',{p_lat:c[0],p_lng:c[1],p_km:km,p_kind:f.kind||null,p_q:clean(f.text)||null,p_limit:map?150:60});if(tok!==S.pltok||!el.isConnected)return;
  if(map){S.plmk.clearLayers();rows.forEach(p=>L.marker([p.lat,p.lng],{icon:pinIcon(p),title:p.name}).on('click',ev=>{L.DomEvent.stopPropagation(ev);peekPlace(p)}).addTo(S.plmk))}
  el.innerHTML=rows.length?`<h3 class="sec2">${map?'ამ ხედზე':'ახლოს'} · ${rows.length}</h3><div class="pllist">${rows.slice(0,map?30:60).map(spotCard).join('')}</div>`:empty(f.text?'ვერაფერი ვიპოვე':'აქ ადგილები ჯერ არ დაუმატებიათ',f.text?'სცადე სხვა სიტყვა ან გადაიტანე რუკა.':'დაამატე შენი საყვარელი რესტორანი, მარანი ან სასტუმრო სახლი.',`<button class="btn" data-a="page" data-p="placenew">${ic('plus')}ადგილის დამატება</button>`);if(!map)staggerIn($$('.plcard',el).slice(0,8))}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
const spotCard=p=>`<button class="plcard" data-a="page" data-p="place" data-arg="${p.id}">${p.photo&&!ECO()?`<img src="${esc(p.photo)}" alt="" loading="lazy">`:`<span class="plico">${pk(p.kind)[2]}</span>`}<span class="grow"><b>${esc(p.name)}</b><span class="sub">${pk(p.kind)[1]}${p.city?' · '+esc(p.city):''}${p.km!=null?' · '+fmtKm(p.km):''}</span>${ratingTag(p)}</span></button>`;
function peekPlace(p){const el=$('#plpeek');if(!el)return;el.hidden=false;el.innerHTML=spotCard(p)+`<button class="ibtn sm" data-a="plpeekx" aria-label="დახურვა">${ic('x')}</button>`}
A.plpeekx=()=>{const el=$('#plpeek');if(el)el.hidden=true};

/* one place */
PG.place={r(id){id=+id;view.innerHTML=pgHead('ადგილი')+`<div id="pdb">${skel(2)}</div>`;openPlace(id)}};
async function openPlace(id){const el=$('#pdb');let p,rv=[],posts=[];
 try{[p,rv,posts]=await Promise.all([q(sb.from('places').select('*').eq('id',id).maybeSingle()),q(sb.from('place_reviews').select('id,author,rating,body,photos,created_at,updated_at,hidden').eq('place_id',id).order('updated_at',{ascending:false}).limit(60)),fetchPosts(b=>b.eq('place_id',id).order('created_at',{ascending:false}).limit(20))])}catch(e){if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e));return}
 if(!el||!el.isConnected)return;if(!p){el.innerHTML=empty('ადგილი ვერ მოიძებნა','შეიძლება წაშლილია.');return}
 await loadProfiles([...rv.map(r=>r.author),p.created_by]);S.place=p;const h=$('.pghead h2');if(h)h.textContent=p.name;
 const mine=rv.find(r=>r.author===ME.id),own=p.created_by===ME.id;
 const friends=[...new Set([...posts.map(x=>x.author),...rv.map(r=>r.author)])].filter(u=>FRIENDS.has(u));
 const photos=[...posts.flatMap(x=>(x.media||[]).filter(m=>m.type==='image').map(m=>m.url)),...rv.flatMap(r=>(r.photos||[]).filter(u=>typeof u==='string'&&/^https:\/\//.test(u)))].slice(0,12);
 const dist=[5,4,3,2,1].map(s=>[s,rv.filter(r=>r.rating===s).length]),tot=rv.length||1;
 const tel=p.phone.replace(/[^\d+]/g,''),nav=`https://www.openstreetmap.org/directions?to=${p.lat}%2C${p.lng}`;
 el.innerHTML=`<div class="plcover">${p.photo&&!ECO()?`<img src="${esc(p.photo)}" alt="">`:''}<div id="pdmap" class="pdmap${p.photo&&!ECO()?' small':''}"></div></div>
 <section class="pro plpro"><div class="pname"><h1>${esc(p.name)}</h1></div><p class="muted">${pk(p.kind)[2]} ${pk(p.kind)[1]}${p.city?' · '+esc(p.city):''}${p.region&&p.region!==p.city?' · '+esc(p.region):''}</p>${p.address?`<p class="muted">${ic('pin')} ${esc(p.address)}</p>`:''}<div>${ratingTag(p)}</div>
  ${p.about?tx(p.about):''}${p.tags?.length?`<div class="chips">${p.tags.map(t=>`<span class="ptag">${esc(t)}</span>`).join('')}</div>`:''}
  <div class="pbtns"><button class="btn sm" data-a="checkin">${ic('pin')}აქ ვარ</button><button class="btn sm ghost" data-a="review">${ic('star')}${mine?'შეფასების შეცვლა':'შეფასება'}</button><a class="btn sm ghost" href="${nav}" target="_blank" rel="noopener">${ic('route')}მარშრუტი</a>${tel?`<a class="btn sm ghost" href="tel:${esc(tel)}">${ic('phone')}დარეკვა</a>`:''}${p.website?`<a class="btn sm ghost" href="${esc(safeHref(p.website))}" target="_blank" rel="noopener nofollow">${ic('globe')}საიტი</a>`:''}<button class="btn sm ghost" data-a="plshare" aria-label="გაზიარება">${ic('share')}</button><button class="btn sm ghost" data-a="plmore" aria-label="მეტი">${ic('more')}</button></div></section>
 ${friends.length?`<h3 class="sec2">მეგობრები აქ იყვნენ</h3><div class="avrow">${friends.slice(0,12).map(u=>`<button data-a="user" data-u="${u}" aria-label="${esc(pname(u))}">${av(u,40)}</button>`).join('')}</div>`:''}
 ${photos.length?`<h3 class="sec2">ფოტოები</h3><div class="pgrid">${photos.map(u=>`<button data-a="imgview" data-src="${esc(u)}" aria-label="ფოტო"><img src="${esc(u)}" alt="" loading="lazy"></button>`).join('')}</div>`:''}
 <h3 class="sec2">შეფასებები · ${rv.length}</h3>${rv.length?`<div class="rvsum"><div class="rvbig"><b>${(+p.rating).toFixed(1)}</b><span class="stars">${starsTxt(p.rating)}</span><small>${rv.length} შეფასება</small></div><div class="rvbars">${dist.map(([s,n])=>`<div><span>${s}</span><i style="--w:${Math.round(n/tot*100)}%"></i><em>${n}</em></div>`).join('')}</div></div>`:''}
 <div class="list">${rv.map(r=>`<div class="rvrow">${av(r.author,36)}<div class="grow"><b>${esc(pname(r.author))}${vb(r.author)}</b><span class="stars sm">${starsTxt(r.rating)}</span><span class="sub">${ago(r.updated_at)}${r.hidden?' · დამალულია':''}</span>${r.body?tx(r.body):''}${(r.photos||[]).filter(u=>typeof u==='string'&&/^https:\/\//.test(u)).length?`<div class="rvph">${r.photos.filter(u=>typeof u==='string'&&/^https:\/\//.test(u)).map(u=>`<button data-a="imgview" data-src="${esc(u)}"><img src="${esc(u)}" alt="" loading="lazy"></button>`).join('')}</div>`:''}</div>${r.author!==ME.id?`<button class="ibtn sm" data-a="report" data-type="review" data-id="${r.id}" aria-label="საჩივარი">${ic('flag')}</button>`:''}${isStaff()?`<button class="ibtn sm" data-a="modhide" data-type="review" data-id="${r.id}" data-h="${r.hidden?0:1}" aria-label="მოდერაცია">${ic(r.hidden?'eye':'lock')}</button>`:''}</div>`).join('')||'<p class="muted">იყავი პირველი, ვინც შეაფასებს.</p>'}</div>
 ${posts.length?`<h3 class="sec2">პოსტები აქედან</h3>${posts.map(postHTML).join('')}`:''}
 <p class="note" style="padding:8px 16px 24px">${p.created_by?`დაამატა ${esc(pname(p.created_by))} · `:''}${ago(p.created_at)}</p>`;
 loadLeaflet().then(()=>{const m=$('#pdmap');if(!m||!m.isConnected)return;const map=baseMap(m,[p.lat,p.lng],15,{dragging:!matchMedia('(pointer:coarse)').matches,scrollWheelZoom:false,zoomControl:false});L.marker([p.lat,p.lng],{icon:pinIcon(p,true)}).addTo(map)}).catch(()=>{const m=$('#pdmap');if(m)m.remove()})}
A.plshare=()=>{if(S.place)shareLink(location.origin+'/#place-'+S.place.id,S.place.name)};
A.checkin=()=>{const p=S.place;if(p)compose({place:{id:p.id,name:p.name}})};
A.plmore=()=>{const p=S.place;if(!p)return;const own=p.created_by===ME.id;
 sheet(head(esc(p.name))+`<div class="reasons">${own||isStaff()?`<button data-a="page" data-p="placenew" data-arg="${p.id}">${ic('edit')} რედაქტირება</button>`:''}${own||isStaff()?`<button class="warnbtn" data-a="pldel">${ic('trash')} წაშლა</button>`:''}${!own?`<button data-a="report" data-type="place" data-id="${p.id}">${ic('flag')} საჩივარი (არასწორი ინფორმაცია, სპამი)</button>`:''}${isStaff()?`<button data-a="modhide" data-type="place" data-id="${p.id}" data-h="${p.hidden?0:1}">${p.hidden?'მოდერაცია: გამოჩენა':'მოდერაცია: დამალვა'}</button>`:''}</div>`,'short')};
A.pldel=()=>{const p=S.place;confirmSheet('ადგილის წაშლა','ადგილი და მისი შეფასებები წაიშლება. პოსტები დარჩება.','წაშლა',async()=>{await q(sb.from('places').delete().eq('id',p.id));toast('წაიშალა');openPage('places')},true)};
A.review=async()=>{const p=S.place;if(!p)return;let mine=null;try{mine=await q(sb.from('place_reviews').select('rating,body,photos').eq('place_id',p.id).eq('author',ME.id).maybeSingle())}catch(e){}
 let rating=mine?.rating||0;const photos=[...(mine?.photos||[])];
 sheet(head('შეფასება · '+esc(p.name))+`<div class="ph-body"><div class="starpick" role="radiogroup" aria-label="ვარსკვლავები">${[1,2,3,4,5].map(i=>`<button type="button" data-st="${i}" role="radio" aria-checked="${i===rating}" aria-label="${i}">★</button>`).join('')}</div>
  <label class="fld">შენი აზრი<textarea id="rv_b" maxlength="1000" rows="4" placeholder="რა მოგეწონა, რას ურჩევ სხვებს? მაგ. ხინკალი, მომსახურება, ფასი">${esc(mine?.body||'')}</textarea></label><div class="cattach" id="rv_ph"></div></div>
  <div class="ph-foot"><button class="ibtn" id="rv_img" aria-label="ფოტოს დამატება">${ic('image')}</button><span class="sp"></span><button class="btn" id="rv_ok">შენახვა</button></div>`,'short');
 const drawSt=()=>$$('[data-st]').forEach(b=>{b.classList.toggle('on',+b.dataset.st<=rating);b.setAttribute('aria-checked',String(+b.dataset.st===rating))});drawSt();
 const drawPh=()=>{$('#rv_ph').innerHTML=photos.map((u,i)=>`<div class="catt"><img src="${esc(u)}" alt=""><button type="button" data-rp="${i}" aria-label="წაშლა">${ic('x')}</button></div>`).join('');$$('[data-rp]').forEach(b=>b.onclick=()=>{photos.splice(+b.dataset.rp,1);drawPh()})};drawPh();
 $$('[data-st]').forEach(b=>b.onclick=()=>{rating=+b.dataset.st;drawSt();pop(b)});
 $('#rv_img').onclick=async()=>{if(photos.length>=4){toast('მაქსიმუმ 4 ფოტო');return}const b=await pickImage({max:ECO()?1080:1400});if(!b)return;try{toast('იტვირთება…');photos.push(await uploadBlob(b,'jpg'));drawPh()}catch(e){toast(errMsg(e))}};
 $('#rv_ok').onclick=async()=>{if(!rating){toast('აირჩიე ვარსკვლავები');return}const b=$('#rv_ok');b.disabled=true;try{await rpc('review_place',{p_place:p.id,p_rating:rating,p_body:$('#rv_b').value.trim(),p_photos:photos});closeSheet();toast('მადლობა, შეფასება შენახულია');openPlace(p.id)}catch(e){toast(errMsg(e));b.disabled=false}}};

/* add or edit a place */
PG.placenew={async r(id){const edit=id?await q(sb.from('places').select('*').eq('id',+id).maybeSingle()).catch(()=>null):null;const p=edit||{};
 view.innerHTML=pgHead(edit?'ადგილის რედაქტირება':'ახალი ადგილი')+`<form class="form" id="pnf"><label class="fld">სახელი<input id="pn_n" maxlength="80" required value="${esc(p.name||'')}" placeholder="მაგ. ხინკლის სახლი, ღვინის მარანი"></label>
 <label class="fld">ტიპი<select id="pn_k">${PKINDS.map(([k,l,e])=>`<option value="${k}"${p.kind===k?' selected':''}>${e} ${l}</option>`).join('')}</select></label>
 <div class="frow"><label class="fld">რეგიონი<select id="pn_r"><option value="">—</option>${REGIONS.map(r=>`<option${(edit?p.region:ME.home_region)===r?' selected':''}>${r}</option>`).join('')}</select></label><label class="fld">ქალაქი ან სოფელი<input id="pn_c" maxlength="60" list="pncities" value="${esc(p.city||ME.city||'')}"></label></div><datalist id="pncities">${CITIES.map(c=>`<option value="${c}">`).join('')}</datalist>
 <label class="fld">მისამართი<input id="pn_a" maxlength="120" value="${esc(p.address||'')}" placeholder="ქუჩა, ნომერი"></label>
 <div class="fld">მდებარეობა რუკაზე<div class="pnmap" id="pnmap"></div><div class="row2" style="justify-content:flex-start"><button type="button" class="btn sm ghost" id="pn_me">${ic('locate')}ჩემი მდებარეობა</button><span class="note" id="pn_ll">შეეხე რუკას ან გადაათრიე ნიშანი</span></div></div>
 <div class="frow"><label class="fld">ტელეფონი<input id="pn_ph" maxlength="30" inputmode="tel" value="${esc(p.phone||'')}"></label><label class="fld">ვებგვერდი<input id="pn_w" maxlength="200" inputmode="url" value="${esc(p.website||'')}" placeholder="https://"></label></div>
 <label class="fld">მოკლე აღწერა<textarea id="pn_ab" maxlength="600" rows="3" placeholder="რით არის გამორჩეული, სამუშაო საათები">${esc(p.about||'')}</textarea></label>
 <label class="fld">თეგები (მძიმით)<input id="pn_t" maxlength="200" value="${esc((p.tags||[]).join(', '))}" placeholder="ხინკალი, მწვადი, ცოცხალი მუსიკა"></label>
 <div class="fld">ფოტო<div class="row2" style="justify-content:flex-start;align-items:center"><span id="pn_phv">${p.photo?`<img class="pnph" src="${esc(p.photo)}" alt="">`:''}</span><button type="button" class="btn sm ghost" id="pn_img">${ic('image')}${p.photo?'შეცვლა':'დამატება'}</button></div></div>
 <button class="btn" id="pn_ok">${ic('check')}${edit?'შენახვა':'დამატება'}</button></form>`;
 let ll=edit?[p.lat,p.lng]:null,photo=p.photo||null,map=null,mk=null;
 const setLL=v=>{ll=v;$('#pn_ll').textContent=`${v[0].toFixed(5)}, ${v[1].toFixed(5)}`;if(map){if(mk)mk.setLatLng(v);else{mk=L.marker(v,{draggable:true,icon:pinIcon({kind:$('#pn_k').value},true)}).addTo(map);mk.on('dragend',()=>{const x=mk.getLatLng();setLL([x.lat,x.lng])})}}};
 loadLeaflet().then(async()=>{const el=$('#pnmap');if(!el)return;const g=ll||await getGeo(false)||S.pc||TBILISI;map=baseMap(el,g,ll?16:14);map.on('click',e=>setLL([e.latlng.lat,e.latlng.lng]));if(ll)setLL(ll);setTimeout(()=>map.invalidateSize(),80)}).catch(e=>{$('#pnmap').innerHTML=`<p class="note" style="padding:12px">${esc(e.message)}. გამოიყენე „ჩემი მდებარეობა“.</p>`});
 $('#pn_k').onchange=()=>{if(mk)mk.setIcon(pinIcon({kind:$('#pn_k').value},true))};
 $('#pn_me').onclick=async()=>{const g=await getGeo(true);if(!g){toast('მდებარეობა ვერ დადგინდა');return}setLL(g);if(map)map.setView(g,17)};
 $('#pn_img').onclick=async()=>{const b=await pickImage({ratios:['169','orig'],ratio:'169',max:ECO()?1080:1600,title:'ადგილის ფოტო'});if(!b)return;try{toast('იტვირთება…');photo=await uploadBlob(b,'jpg');$('#pn_phv').innerHTML=`<img class="pnph" src="${esc(photo)}" alt="">`}catch(e){toast(errMsg(e))}};
 $('#pnf').onsubmit=async e=>{e.preventDefault();if(!ll){toast('მონიშნე ადგილი რუკაზე');return}let w=$('#pn_w').value.trim();if(w&&!/^https?:\/\//i.test(w))w='https://'+w;
  const row={name:$('#pn_n').value.trim(),kind:$('#pn_k').value,region:$('#pn_r').value,city:$('#pn_c').value.trim(),address:$('#pn_a').value.trim(),lat:ll[0],lng:ll[1],phone:$('#pn_ph').value.trim(),website:w,about:$('#pn_ab').value.trim(),photo,tags:$('#pn_t').value.split(/[,،]/).map(s=>s.trim().replace(/^#/,'')).filter(Boolean).slice(0,12)};
  if(row.name.length<2){toast('ჩაწერე სახელი');return}const b=$('#pn_ok');b.disabled=true;
  try{if(edit){await q(sb.from('places').update(row).eq('id',edit.id));toast('შენახულია');openPage('place',edit.id,['places']);return}
   const near=await rpc('places_near',{p_lat:ll[0],p_lng:ll[1],p_km:.3,p_kind:null,p_q:clean(row.name).slice(0,20)||null,p_limit:3}).catch(()=>[]);
   const save=async()=>{const r=await q(sb.from('places').insert(Object.assign(row,{created_by:ME.id})).select('id').single());toast('ადგილი დაემატა');openPage('place',r.id,['places'])};
   if(near.length){b.disabled=false;sheet(head('ასეთი ადგილი უკვე არის?')+`<div class="ph-body"><p>ახლოს უკვე არსებობს:</p>${near.map(spotCard).join('')}</div><div class="ph-foot"><span class="sp"></span><button class="btn" id="pn_force">მაინც დამატება</button></div>`,'short');$('#pn_force').onclick=async()=>{try{closeSheet();await save()}catch(x){toast(errMsg(x))}};return}
   await save()}catch(x){toast(/too_many/.test(x.message)?'დღეს უკვე ბევრი ადგილი დაამატე, სცადე ხვალ':errMsg(x));b.disabled=false}}}};

/* pick a place while writing a post */
async function pickPlace(){return new Promise(resolve=>{let done=false;const fin=v=>{if(!done){done=true;resolve(v)}};
 layer(lhead('სად ხარ?')+`<div class="ph-body"><form class="search" id="ppf" style="padding:0"><input class="field" id="ppq" type="search" placeholder="ადგილის სახელი" autocomplete="off"></form><div id="ppl">${skel(2)}</div><button type="button" class="btn ghost sm" data-a="ppnew">${ic('plus')}ახალი ადგილის დამატება</button></div>`,()=>fin(null));
 const run=async()=>{const v=clean($('#ppq')?.value||''),el=$('#ppl');if(!el)return;const g=S.geo||S.pc||TBILISI;
  try{const rows=v?await q(sb.from('places').select('id,name,kind,city,lat,lng,photo,rating,reviews').ilike('name',`%${v}%`).eq('hidden',false).limit(20)):await rpc('places_near',{p_lat:g[0],p_lng:g[1],p_km:40,p_kind:null,p_q:null,p_limit:20});
   el.innerHTML=rows.map(p=>`<button type="button" class="row" data-pp="${p.id}" data-n="${esc(p.name)}"><span class="plico sm">${pk(p.kind)[2]}</span><span class="grow"><b>${esc(p.name)}</b><span class="sub">${pk(p.kind)[1]}${p.city?' · '+esc(p.city):''}${p.km!=null?' · '+fmtKm(p.km):''}</span></span></button>`).join('')||'<p class="muted">ვერ ვიპოვე. დაამატე ახალი ადგილი.</p>';
   $$('[data-pp]',el).forEach(b=>b.onclick=()=>{LAYER_CB=null;closeLayer();fin({id:+b.dataset.pp,name:b.dataset.n})})}catch(e){el.innerHTML=`<p class="muted">${errMsg(e)}</p>`}};
 $('#ppf').onsubmit=e=>{e.preventDefault();run()};$('#ppq').oninput=()=>{clearTimeout(S.ppt);S.ppt=setTimeout(run,300)};getGeo(false).then(run)})}
A.ppnew=()=>{closeLayer();closeSheet();openPage('placenew',undefined,['places'])};
