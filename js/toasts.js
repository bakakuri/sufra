/* the toast book: toasts for every occasion, liked with a kantsi, usable by the tamada at a virtual supra */
const OCCS=[['supra','სუფრა'],['homeland','სამშობლო'],['parents','მშობლები'],['memorial','შენდობა'],['friends','მეგობრობა'],['love','სიყვარული'],['kids','ბავშვები'],['guests','სტუმარი'],['wedding','ქორწილი'],['christening','ნათლობა'],['birthday','დაბადების დღე'],['other','სხვა']];
const occName=k=>(OCCS.find(o=>o[0]===k)||OCCS[11])[1];
let TLIKED=new Set(),TOASTS_C=new Map();
PG.toasts={r(){S.tq=S.tq||{occ:'',sort:'top'};const f=S.tq;
 view.innerHTML=pgHead('სადღეგრძელოები',`<button class="btn sm" data-a="newtoast">${ic('edit')}დაწერა</button>`)+`<p class="hint" style="padding:12px 16px 4px">თამადის წიგნი: სადღეგრძელოები ყველა შემთხვევისთვის. საუკეთესოს მოუწონე ყანწით, ვირტუალურ სუფრაზე კი თამადა პირდაპირ აქედან ამოიღებს.</p>
 <div class="chipsbar" role="group" aria-label="შემთხვევა"><button data-a="tocc" data-k="" aria-pressed="${!f.occ}">ყველა</button>${OCCS.map(([k,l])=>`<button data-a="tocc" data-k="${k}" aria-pressed="${f.occ===k}">${l}</button>`).join('')}</div>
 <div class="seg" role="group" aria-label="დალაგება" style="margin-top:0">${[['top','საუკეთესო'],['new','ახალი']].map(([k,l])=>`<button data-a="tsort" data-k="${k}" aria-pressed="${f.sort===k}">${l}</button>`).join('')}</div><div id="tsb">${skel(3)}</div>`;loadToasts()}};
A.tocc=t=>{S.tq.occ=t.dataset.k;$$('[data-a="tocc"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));loadToasts()};
A.tsort=t=>{S.tq.sort=t.dataset.k;$$('[data-a="tsort"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));loadToasts()};
async function fetchToasts(occ,sort,limit=60){let b=sb.from('toasts').select('id,author,occasion,title,body,likes,hidden,created_at').eq('hidden',false);if(occ)b=b.eq('occasion',occ);
 b=sort==='new'?b.order('created_at',{ascending:false}):b.order('likes',{ascending:false}).order('created_at',{ascending:true});const rows=await q(b.limit(limit));
 rows.forEach(t=>TOASTS_C.set(t.id,t));await loadProfiles(rows.map(r=>r.author));
 if(rows.length){try{(await q(sb.from('toast_likes').select('toast_id').eq('user_id',ME.id).in('toast_id',rows.map(r=>r.id)))).forEach(x=>TLIKED.add(x.toast_id))}catch(e){}}return rows}
async function loadToasts(){const el=$('#tsb');if(!el)return;el.innerHTML=skel(3);
 try{const rows=await fetchToasts(S.tq.occ,S.tq.sort);if(!el.isConnected)return;el.innerHTML=rows.map(toastCard).join('')||empty('აქ ჯერ ცარიელია','დაწერე პირველი სადღეგრძელო ამ შემთხვევისთვის.',`<button class="btn" data-a="newtoast">${ic('edit')}დაწერა</button>`);staggerIn($$('.tcard',el).slice(0,6))}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
function toastCard(t){const liked=TLIKED.has(t.id),host=typeof ROOM!=='undefined'&&ROOM&&ROOM.isHost&&ROOM.supra;
 return `<article class="tcard" data-tid="${t.id}"><div class="tchead"><span class="ptag">${occName(t.occasion)}</span><span class="sp"></span><span class="sub">${t.author?`<button data-a="user" data-u="${t.author}">${esc(pname(t.author))}</button>`:'სუფრის წიგნიდან'}</span></div>
 <h3>${esc(t.title)}</h3><p class="tcbody${t.body.length>260?' clamp':''}" data-a="texpand">${esc(t.body)}</p>
 <div class="tcacts"><button class="act${liked?' on':''}" data-a="tlike" data-tid="${t.id}" aria-label="მოწონება ყანწით" aria-pressed="${liked}">${KANTSI}<span>${t.likes||''}</span></button><button class="act" data-a="tshare" data-tid="${t.id}" aria-label="გაზიარება">${ic('send')}</button>${host?`<button class="btn sm" data-a="tsay" data-tid="${t.id}">${ic('wine')}სუფრაზე თქმა</button>`:''}<span class="sp"></span><button class="act" data-a="tmore" data-tid="${t.id}" aria-label="მეტი">${ic('more')}</button></div></article>`}
A.texpand=t=>t.classList.toggle('open');
A.tlike=async t=>{const id=+t.dataset.tid,tt=TOASTS_C.get(id);if(!tt)return;const on=!TLIKED.has(id);on?TLIKED.add(id):TLIKED.delete(id);tt.likes=Math.max(0,(tt.likes||0)+(on?1:-1));
 t.classList.toggle('on',on);t.setAttribute('aria-pressed',String(on));$('span',t).textContent=tt.likes||'';if(on){pop(t);burst(t,'#C98A12')}
 try{if(on)await q(sb.from('toast_likes').insert({toast_id:id,user_id:ME.id}));else await q(sb.from('toast_likes').delete().eq('toast_id',id).eq('user_id',ME.id))}catch(e){if(!/duplicate/i.test(e.message))toast(errMsg(e))}};
A.tshare=t=>{const tt=TOASTS_C.get(+t.dataset.tid);if(!tt)return;const txt=`${tt.title}\n\n${tt.body}\n\n— სუფრა`;
 if(navigator.share){navigator.share({title:tt.title,text:txt}).catch(()=>{});return}navigator.clipboard?.writeText(txt).then(()=>toast('ტექსტი დაკოპირდა'),()=>toast('ვერ დაკოპირდა'))};
A.tmore=t=>{const tt=TOASTS_C.get(+t.dataset.tid);if(!tt)return;const mine=tt.author===ME.id;
 sheet(head(esc(tt.title))+`<div class="reasons"><button data-a="tcompose" data-tid="${tt.id}">${ic('edit')} პოსტად გაზიარება</button>${mine?`<button data-a="newtoast" data-tid="${tt.id}">${ic('edit')} რედაქტირება</button><button class="warnbtn" data-a="tdel" data-tid="${tt.id}">${ic('trash')} წაშლა</button>`:`<button data-a="report" data-type="toast" data-id="${tt.id}">${ic('flag')} საჩივარი</button>`}${isStaff()&&!mine?`<button class="warnbtn" data-a="modhide" data-type="toast" data-id="${tt.id}" data-h="1">მოდერაცია: დამალვა</button>`:''}</div>`,'short')};
A.tcompose=t=>{const tt=TOASTS_C.get(+t.dataset.tid);closeSheet();compose().then(()=>{const ta=$('#ct');if(ta){ta.value=`🍷 ${tt.title}\n\n${tt.body}\n\n#სადღეგრძელო`;ta.oninput&&ta.oninput()}})};
A.tdel=t=>{const id=+t.dataset.tid;confirmSheet('სადღეგრძელოს წაშლა','წაშლილს ვეღარ აღადგენ.','წაშლა',async()=>{await q(sb.from('toasts').delete().eq('id',id));$(`.tcard[data-tid="${id}"]`)?.remove()},true)};
A.newtoast=t=>{const tt=t&&t.dataset&&t.dataset.tid?TOASTS_C.get(+t.dataset.tid):null;let occ=tt?tt.occasion:(S.tq?.occ||'supra');
 sheet(head(tt?'რედაქტირება':'ახალი სადღეგრძელო')+`<div class="ph-body"><div class="chips" role="group" aria-label="შემთხვევა">${OCCS.map(([k,l])=>`<button type="button" class="chip" data-oc="${k}" aria-pressed="${k===occ}">${l}</button>`).join('')}</div>
 <label class="fld">სათაური<input id="tn_t" maxlength="80" value="${esc(tt?.title||'')}" placeholder="მაგ. მეგობრობის სადღეგრძელო"></label><label class="fld">სადღეგრძელო<textarea id="tn_b" maxlength="1500" rows="7" placeholder="დაწერე ისე, როგორც სუფრაზე იტყოდი…">${esc(tt?.body||'')}</textarea></label></div>
 <div class="ph-foot"><span class="sp"></span><button class="btn" id="tn_ok">${ic('send')}${tt?'შენახვა':'გამოქვეყნება'}</button></div>`);
 $$('[data-oc]').forEach(b=>b.onclick=()=>{occ=b.dataset.oc;$$('[data-oc]').forEach(z=>z.setAttribute('aria-pressed',String(z===b)))});
 $('#tn_ok').onclick=async()=>{const title=$('#tn_t').value.trim(),body=$('#tn_b').value.trim();if(title.length<2||body.length<10){toast('ჩაწერე სათაური და სადღეგრძელო (მინ. 10 სიმბოლო)');return}const b=$('#tn_ok');b.disabled=true;
  try{if(tt)await q(sb.from('toasts').update({occasion:occ,title,body}).eq('id',tt.id));else await q(sb.from('toasts').insert({author:ME.id,occasion:occ,title,body}));closeSheet();toast(tt?'შენახულია':'გამოქვეყნდა. გაგიმარჯოს!');if(S.page?.id==='toasts'){if(!tt){S.tq.sort='new'}rp()}}catch(e){toast(/too_many/.test(e.message)?'დღეს უკვე ბევრი დაწერე, სცადე ხვალ':errMsg(e));b.disabled=false}}};
/* tamada: pick from the book during a virtual supra */
A.tbook=async()=>{sheet(head('სადღეგრძელოების წიგნი')+`<div class="chipsbar" role="group" aria-label="შემთხვევა" style="padding-top:12px"><button data-a="tbocc" data-k="" aria-pressed="true">ყველა</button>${OCCS.map(([k,l])=>`<button data-a="tbocc" data-k="${k}" aria-pressed="false">${l}</button>`).join('')}</div><div class="ph-body" id="tbl">${skel(3)}</div>`);loadTBook('')};
A.tbocc=t=>{$$('[data-a="tbocc"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));loadTBook(t.dataset.k)};
async function loadTBook(occ){const el=$('#tbl');if(!el)return;el.innerHTML=skel(3);try{const rows=await fetchToasts(occ,'top',40);if(!el.isConnected)return;
 el.innerHTML=rows.map(t=>`<button class="row tbrow" data-a="tsay" data-tid="${t.id}"><span class="grow"><b>${esc(t.title)}</b><span class="sub">${occName(t.occasion)} · ${esc(t.body.slice(0,90))}…</span></span>${ic('wine')}</button>`).join('')||'<p class="muted">ჯერ ცარიელია.</p>'}catch(e){el.innerHTML=`<p class="muted">${errMsg(e)}</p>`}}
A.tsay=t=>{const tt=TOASTS_C.get(+t.dataset.tid);if(!tt)return;if(typeof ROOM==='undefined'||!ROOM||!ROOM.isHost||!ROOM.supra){toast('ჯერ გაშალე სუფრა, შენ იქნები თამადა');return}closeSheet();setRoomState({custom:tt.title,book:tt.body,toast:-1,floor:null});toast('სადღეგრძელო ყველამ დაინახა')};
