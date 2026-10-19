/* shared albums: a wedding or a supra where every guest adds their photos */
const AUD_TXT={friends:'მეგობრები ხედავენ',members:'მხოლოდ მონაწილეები',all:'ყველა ხედავს'};
const albumCard=a=>`<button class="albc" data-a="album" data-id="${a.id}"><span class="albcov">${safeU(a.cover_url)?`<img src="${esc(a.cover_url)}" alt="" loading="lazy">`:`<i>${ic('image')}</i>`}<em>${a.photos||0}</em></span><b>${esc(a.title)}</b><small>${a.owner===ME.id?'შენი':esc(pname(a.owner))} · ${ago(a.updated_at||a.created_at)}</small></button>`;
PG.albums={r(){view.innerHTML=pgHead('ალბომები',`<button class="btn sm" data-a="newalbum">${ic('plus')}ახალი</button>`)+`<p class="hint" style="padding:12px 16px 0">საერთო ალბომში ყველა მონაწილე ამატებს თავის ფოტოებს: ქორწილი, დაბადების დღე, ლაშქრობა.</p><div id="albb">${skel(2)}</div>`;
 Promise.all([q(sb.from('albums').select('id,owner,title,cover_url,photos,updated_at,created_at,event_id').eq('owner',ME.id).order('updated_at',{ascending:false}).limit(60)),
  q(sb.from('album_members').select('album_id').eq('user_id',ME.id).limit(100)),
  q(sb.from('albums').select('id,owner,title,cover_url,photos,updated_at,created_at,event_id').neq('owner',ME.id).order('updated_at',{ascending:false}).limit(40))])
 .then(async([mine,mem,other])=>{const el=$('#albb');if(!el)return;const memIds=new Set(mem.map(m=>m.album_id));await loadProfiles(other.map(a=>a.owner));
  const shared=other.filter(a=>memIds.has(a.id)),rest=other.filter(a=>!memIds.has(a.id));
  el.innerHTML=(mine.length?`<h3 class="sec2">ჩემი ალბომები</h3><div class="albgrid">${mine.map(albumCard).join('')}</div>`:'')+(shared.length?`<h3 class="sec2">სადაც მონაწილე ვარ</h3><div class="albgrid">${shared.map(albumCard).join('')}</div>`:'')
   +(rest.length?`<h3 class="sec2">მეგობრების ალბომები</h3><div class="albgrid">${rest.map(albumCard).join('')}</div>`:'')
   ||empty('ალბომები ჯერ არ არის','შექმენი ალბომი და მოიწვიე მეგობრები, რომ თავიანთი ფოტოები დაამატონ.','<button class="btn" data-a="newalbum">ალბომის შექმნა</button>');staggerIn($$('.albc',el).slice(0,8))})
 .catch(e=>{const el=$('#albb');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))})}};
A.album=t=>openPage('album',+t.dataset.id,S.page?[S.page.id,S.page.arg]:['albums']);
A.newalbum=(t,ev)=>albumForm(null,t?.dataset?.ev?+t.dataset.ev:null);
function albumForm(a,eventId){sheet(head(a?'ალბომის რედაქტირება':'ახალი ალბომი')+`<form class="ph-body" id="alf"><label class="fld">სახელი<input id="al_t" maxlength="80" required value="${esc(a?.title||'')}" placeholder="მაგ. ნინოს და გიორგის ქორწილი"></label>
  <label class="fld">აღწერა<textarea id="al_d" maxlength="500" rows="2">${esc(a?.about||'')}</textarea></label>
  <div class="fld"><span>ვინ ნახავს</span><div class="seg flat" role="group" aria-label="ვინ ნახავს">${Object.entries(AUD_TXT).map(([k,l])=>`<button type="button" data-aud="${k}" aria-pressed="${(a?.audience||'friends')===k}">${l}</button>`).join('')}</div></div>
  <p class="note">ფოტოების დამატება შეუძლიათ შენ მიერ მოწვეულ ადამიანებს${eventId||a?.event_id?' და ღონისძიების მონაწილეებს':''}.</p></form><div class="ph-foot"><span class="sp"></span><button class="btn" id="al_ok">${a?'შენახვა':'შექმნა'}</button></div>`);
 let aud=a?.audience||'friends';$$('#alf [data-aud]').forEach(b=>b.onclick=()=>{aud=b.dataset.aud;$$('#alf [data-aud]').forEach(x=>x.setAttribute('aria-pressed',String(x===b)))});
 $('#al_ok').onclick=async()=>{const title=$('#al_t').value.trim();if(!title){toast('ჩაწერე ალბომის სახელი');return}const row={title,about:$('#al_d').value.trim()||null,audience:aud};
  try{if(a){await q(sb.from('albums').update(row).eq('id',a.id));closeSheet();rp();return}
   const n=await q(sb.from('albums').insert(Object.assign(row,{owner:ME.id,event_id:eventId||null})).select('id').single());closeSheet();openPage('album',n.id,['albums'])}catch(e){toast(errMsg(e))}}}
PG.album={r(id){view.innerHTML=pgHead('ალბომი')+`<div id="alb">${skel(2)}</div>`;loadAlbum(+id)}};
let ALB=null;
async function loadAlbum(id){try{const a=await q(sb.from('albums').select('*').eq('id',id).maybeSingle());const el=$('#alb');if(!el)return;if(!a){el.innerHTML=empty('ალბომი ვერ მოიძებნა','შეიძლება წაშლილია ან შენთვის დახურულია.');return}
  const[photos,mem,canAdd]=await Promise.all([q(sb.from('album_photos').select('id,added_by,url,md,sm,w,h,caption,created_at').eq('album_id',id).order('created_at',{ascending:false}).limit(500)),q(sb.from('album_members').select('user_id').eq('album_id',id)),rpc('album_can_add',{a:id,u:ME.id}).catch(()=>false)]);
  const ev=a.event_id?await q(sb.from('events').select('id,title').eq('id',a.event_id).maybeSingle()).catch(()=>null):null;
  await loadProfiles([a.owner,...mem.map(m=>m.user_id),...photos.map(p=>p.added_by)]);ALB={a,photos,own:a.owner===ME.id,canAdd:!!canAdd};
  const people=[...new Set([a.owner,...mem.map(m=>m.user_id),...photos.map(p=>p.added_by)])];$('.pghead h2').textContent=a.title;
  el.innerHTML=`<div class="albhead"><h1>${esc(a.title)}</h1>${a.about?`<p>${esc(a.about)}</p>`:''}<p class="sub">${a.photos||photos.length} ფოტო · ${AUD_TXT[a.audience]||''}${ev?` · <button class="hash" data-a="ev" data-id="${ev.id}">${esc(ev.title)}</button>`:''}</p>
   <div class="avs">${people.slice(0,8).map(u=>`<button data-a="user" data-u="${u}" aria-label="${esc(pname(u))}">${av(u,30)}</button>`).join('')}${people.length>8?`<span>+${people.length-8}</span>`:''}</div>
   <div class="pbtns">${ALB.canAdd?`<button class="btn" data-a="albadd">${ic('image')}ფოტოების დამატება</button>`:''}${ALB.own?`<button class="btn ghost" data-a="albinvite">${ic('users')}მოწვევა</button><button class="ibtn" data-a="albmore" aria-label="მეტი">${ic('more')}</button>`:''}${!ALB.own&&mem.some(m=>m.user_id===ME.id)?`<button class="btn ghost" data-a="albleave">დატოვება</button>`:''}</div></div>
   <div id="albgrid">${albumGrid()}</div>`}
 catch(e){const el=$('#alb');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
function albumGrid(){const P=ALB?.photos||[];return P.length?`<div class="pgrid2">${P.map((p,i)=>`<button class="pgt" data-a="albview" data-i="${i}" aria-label="ფოტოს გახსნა"><img src="${esc(safeU(p.sm)||safeU(p.md)||p.url)}" alt="" loading="lazy" decoding="async"></button>`).join('')}</div>`:empty('ალბომი ცარიელია',ALB?.canAdd?'დაამატე პირველი ფოტოები.':'ფოტოები ჯერ არ დაუმატებიათ.',ALB?.canAdd?'<button class="btn" data-a="albadd">ფოტოების დამატება</button>':'')}
A.albadd=async()=>{if(!ALB)return;const fs=await pickFile('image/*',{multiple:true});if(!fs.length)return;const a=ALB.a,list=fs.slice(0,50);let done=0,fail=0;
 const t=document.createElement('div');t.className='upbar';t.innerHTML=`<span>იტვირთება <b>0</b>/${list.length}</span><i><b style="width:0"></b></i>`;document.body.appendChild(t);
 for(const f of list){try{const b=f.type==='image/gif'?f:await shrink(f,2000);const m=await uploadMedia(b,'image');const row=await q(sb.from('album_photos').insert({album_id:a.id,added_by:ME.id,url:m.url,md:m.md||null,sm:m.sm||null,w:m.w||null,h:m.h||null}).select('id,added_by,url,md,sm,w,h,caption,created_at').single());
   if(ALB&&ALB.a.id===a.id){ALB.photos.unshift(row);const g=$('#albgrid');if(g)g.innerHTML=albumGrid()}done++}catch(e){fail++;if(fail===1)toast(errMsg(e))}
  $('b',t).textContent=done+fail;$('i b',t).style.width=Math.round((done+fail)/list.length*100)+'%'}
 t.remove();toast(fail?`დაემატა ${done}, ვერ აიტვირთა ${fail}`:`დაემატა ${done} ფოტო`)};
/* the viewer: swipe between the album's photos, who added it and when */
A.albview=t=>{const P=ALB?.photos||[];if(!P.length)return;let i=+t.dataset.i||0;let el=$('#pv');
 if(!el){el=document.createElement('div');el.id='pv';el.className='pv';el.setAttribute('role','dialog');el.setAttribute('aria-modal','true');document.body.appendChild(el);el.addEventListener('click',e=>{if(e.target===el)closePV()})}
 PV={id:null,i};el.classList.remove('closing','top');el.hidden=false;navOpen('pv');
 const cap=k=>{const p=P[k];return `${av(p.added_by,28)}<span class="grow"><b>${esc(pname(p.added_by))}</b><small>${fdate(p.created_at)}</small></span>${p.added_by===ME.id||ALB.own||isStaff()?`<button class="ibtn" data-a="albdel" data-id="${p.id}" aria-label="ფოტოს წაშლა">${ic('trash')}</button>`:''}<a class="ibtn" href="${esc(p.url)}" target="_blank" rel="noopener" download aria-label="ჩამოტვირთვა">${ic('download')}</a>`};
 el.innerHTML=`<div class="pvin"><div class="pvtop"><span class="grow"><b>${esc(ALB.a.title)}</b></span><button class="ibtn" data-a="pvclose" aria-label="დახურვა">${ic('x')}</button></div>
  <div class="pvframe"><div class="pvtrack">${P.map(p=>`<div class="pvs"><img src="${esc(safeU(p.md)||p.url)}" alt="" decoding="async" loading="lazy"></div>`).join('')}</div>${P.length>1?`<span class="pvcount"><b>${i+1}</b>/${P.length}</span><button class="pmnav prev" data-a="pmnav" data-d="-1" aria-label="წინა">${ic('back')}</button><button class="pmnav next" data-a="pmnav" data-d="1" aria-label="შემდეგი">${ic('back')}</button>`:''}</div>
  <div class="pvbot albcap" id="albcap">${cap(i)}</div></div>`;
 const tr=$('.pvtrack',el);requestAnimationFrame(()=>{tr.scrollLeft=i*tr.clientWidth});
 tr.addEventListener('scroll',()=>{clearTimeout(tr._t);tr._t=setTimeout(()=>{const k=Math.round(tr.scrollLeft/(tr.clientWidth||1));if(k!==PV?.i&&P[k]){PV.i=k;const c=$('#albcap');if(c)c.innerHTML=cap(k);const n=$('.pvcount b',el);if(n)n.textContent=k+1}},80)},{passive:true});
 document.documentElement.classList.add('pvopen')};
A.albdel=t=>{const id=+t.dataset.id;confirmSheet('ფოტოს წაშლა','ფოტო ალბომიდან წაიშლება ყველასთვის.','წაშლა',async()=>{await q(sb.from('album_photos').delete().eq('id',id));if(ALB){ALB.photos=ALB.photos.filter(p=>p.id!==id);const g=$('#albgrid');if(g)g.innerHTML=albumGrid()}closePV();toast('ფოტო წაიშალა')},true)};
A.albinvite=()=>{if(!ALB)return;const a=ALB.a;q(sb.from('album_members').select('user_id').eq('album_id',a.id)).then(mem=>{
 friendPicker('ვინ დაამატოს ფოტოები','მოწვევა',async sel=>{await q(sb.from('album_members').insert(sel.map(u=>({album_id:a.id,user_id:u,added_by:ME.id}))));closeSheet();toast(`მოწვეულია ${sel.length}`);rp()},new Set(mem.map(m=>m.user_id)))}).catch(e=>toast(errMsg(e)))};
A.albmore=()=>{if(!ALB)return;sheet(head('ალბომი')+`<div class="reasons"><button data-a="albedit">${ic('edit')} რედაქტირება</button><button data-a="albmembers">${ic('users')} მონაწილეები</button><button class="warnbtn" data-a="albremove">${ic('trash')} ალბომის წაშლა</button></div>`,'short')};
A.albedit=()=>{if(ALB)albumForm(ALB.a)};
A.albmembers=async()=>{if(!ALB)return;const a=ALB.a;try{const mem=await q(sb.from('album_members').select('user_id').eq('album_id',a.id));await loadProfiles(mem.map(m=>m.user_id));
 sheet(head('მონაწილეები')+`<div class="ph-body"><div class="list">${mem.map(m=>`<div class="row">${av(m.user_id,40)}<span class="grow"><b>${esc(pname(m.user_id))}</b></span><button class="btn sm ghost" data-a="albkick" data-u="${m.user_id}">მოშორება</button></div>`).join('')||'<p class="muted">ჯერ არავინ. მოიწვიე მეგობრები.</p>'}</div></div>`)}catch(e){toast(errMsg(e))}};
A.albkick=async t=>{if(!ALB)return;try{await q(sb.from('album_members').delete().eq('album_id',ALB.a.id).eq('user_id',t.dataset.u));t.closest('.row').remove();toast('მოშორდა')}catch(e){toast(errMsg(e))}};
A.albleave=()=>{if(!ALB)return;const a=ALB.a;confirmSheet('ალბომის დატოვება','ფოტოებს ვეღარ დაამატებ. შენ მიერ დამატებული ფოტოები დარჩება.','დატოვება',async()=>{await q(sb.from('album_members').delete().eq('album_id',a.id).eq('user_id',ME.id));rp()})};
A.albremove=()=>{if(!ALB)return;const a=ALB.a;confirmSheet('ალბომის წაშლა','წაიშლება ალბომი და მისი ყველა ფოტო.','წაშლა',async()=>{await q(sb.from('albums').delete().eq('id',a.id));openPage('albums')},true)};
/* albums on a profile */
async function profileAlbums(uid,el){const rows=await q(sb.from('albums').select('id,owner,title,cover_url,photos,updated_at,created_at').eq('owner',uid).order('updated_at',{ascending:false}).limit(40));if(!el.isConnected)return;
 el.innerHTML=rows.length?`<div class="albgrid" style="padding:12px 16px">${rows.map(albumCard).join('')}</div>`:empty(uid===ME.id?'ალბომები ჯერ არ გაქვს':'ალბომები ჯერ არ არის',uid===ME.id?'შექმენი ალბომი და მოიწვიე მეგობრები.':'',uid===ME.id?'<button class="btn" data-a="newalbum">ალბომის შექმნა</button>':'')}
