/* dating: adults only, opt-in, swipe, matches */
S.dmode='swipe';let DECK=[];
const INTERESTS=['ლაშქრობა','მოგზაურობა','ღვინო','ნარდი','ჭადრაკი','კინო','მუსიკა','ცეკვა','სპორტი','წიგნები','ფოტოგრაფია','კულინარია','ყავა','ზღვა','მთა','თამაშები','ხელოვნება','პროგრამირება'];
R.date=()=>{
 if(!isAdult()){view.innerHTML=`<div class="view-pad">${empty('გაცნობა მხოლოდ 18+ მომხმარებლებისთვისაა','ეს ნაწილი შენთვის დახურულია. სუფრის სხვა ფუნქციები ჩვეულებრივ მუშაობს.')}</div>`;return}
 if(!ME.dating){datingSetup();return}
 view.innerHTML=`<div class="seg" role="group" aria-label="გაცნობის რეჟიმი">${[['swipe','სვაიპი'],['likes','მოსწონხარ'],['matches','წყვილები']].map(([k,l])=>`<button data-a="dmode" data-m="${k}" aria-pressed="${S.dmode===k}">${l}${k==='likes'?' <span class="badge" id="lkc" hidden></span>':''}</button>`).join('')}</div><div id="dateb">${skel(1)}</div>
 <div class="dfoot"><button class="trb" data-a="datesettings">${ic('gear')}გაცნობის პროფილი</button></div>`;
 rpc('likes_me_count').then(n=>{const b=$('#lkc');if(b&&n){b.textContent=n;b.hidden=false}}).catch(()=>{});
 if(S.dmode==='swipe')loadDeck();else if(S.dmode==='likes')loadLikes();else loadMatches()};
A.dmode=t=>{S.dmode=t.dataset.m;R.date()};
function datingSetup(edit){const p=ME;const sel=new Set(p.interests||[]);
 const html=`${edit?'':'<div class="dintro"><h2>გაიცანი ახალი ადამიანები</h2><p>გაცნობის პროფილი მხოლოდ 18+ მომხმარებლებს უჩანთ, ვინც თავადაც ჩართო გაცნობა. ნებისმიერ დროს შეგიძლია გამორთვა.</p></div>'}
 <form class="form" id="dsf"><div class="fld">მე ვარ<div class="seg flat" data-g="gender">${[['f','ქალი'],['m','კაცი'],['x','სხვა']].map(([k,l])=>`<button type="button" data-v="${k}" aria-pressed="${p.gender===k}">${l}</button>`).join('')}</div></div>
 <div class="fld">ვეძებ<div class="seg flat" data-g="seeking">${[['f','ქალს'],['m','კაცს'],['all','ყველას']].map(([k,l])=>`<button type="button" data-v="${k}" aria-pressed="${(p.seeking||'all')===k}">${l}</button>`).join('')}</div></div>
 <label class="fld">ჩემ შესახებ<textarea id="ds_b" maxlength="300" placeholder="რა გიყვარს, რას ეძებ">${esc(p.dating_bio||'')}</textarea></label>
 <div class="fld">ინტერესები (მაქს. 6)<div class="chips pick6">${INTERESTS.map(x=>`<button type="button" data-i="${x}" aria-pressed="${sel.has(x)}">${x}</button>`).join('')}</div></div>
 ${p.avatar_url?'':'<p class="note">რჩევა: დაამატე პროფილის ფოტო, ბარათზე ის გამოჩნდება.</p>'}
 <div class="pbtns"><button class="btn">${edit?'შენახვა':'გაცნობის ჩართვა'}</button>${edit?'<button type="button" class="btn ghost warnbtn" id="ds_off">გაცნობის გამორთვა</button>':''}${p.avatar_url?'':'<button type="button" class="btn ghost" data-a="editprofile">ფოტოს დამატება</button>'}</div></form>`;
 if(edit)sheet(head('გაცნობის პროფილი')+`<div class="ph-body">${html}</div>`);else view.innerHTML=`<div class="view-pad" style="gap:8px">${html}</div>`;
 const root=edit?$('#sheet'):view,st={gender:p.gender||null,seeking:p.seeking||'all'};
 $$('[data-g]',root).forEach(g=>$$('button',g).forEach(b=>b.onclick=()=>{st[g.dataset.g]=b.dataset.v;$$('button',g).forEach(z=>z.setAttribute('aria-pressed',String(z===b)))}));
 $$('[data-i]',root).forEach(b=>b.onclick=()=>{const v=b.dataset.i;if(sel.has(v))sel.delete(v);else if(sel.size<6)sel.add(v);b.setAttribute('aria-pressed',String(sel.has(v)))});
 const off=$('#ds_off',root);if(off)off.onclick=async()=>{try{await q(sb.from('profiles').update({dating:false}).eq('id',ME.id));ME.dating=false;closeSheet();R.date()}catch(e){toast(errMsg(e))}};
 $('#dsf',root).onsubmit=async e=>{e.preventDefault();if(!st.gender){toast('აირჩიე, ვინ ხარ');return}const upd={dating:true,gender:st.gender,seeking:st.seeking,dating_bio:$('#ds_b',root).value.trim(),interests:[...sel]};
  try{await q(sb.from('profiles').update(upd).eq('id',ME.id));Object.assign(ME,upd);if(edit)closeSheet();toast('გაცნობის პროფილი შენახულია');R.date()}catch(x){toast(errMsg(x))}}}
A.datesettings=()=>datingSetup(true);
async function loadDeck(){const el=$('#dateb');if(!el)return;try{DECK=await rpc('dating_feed',{p_limit:25});if(S.likesFirst){DECK.sort((a,b)=>b.liked_me-a.liked_me);S.likesFirst=0}renderDeck()}catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
function dcard(p,under){return `<div class="pcard${under?' under':''}" data-id="${p.id}"${under?'':' tabindex="0" aria-label="'+esc(p.name)+', '+p.age+'. ისრებით: მარცხნივ გამოტოვება, მარჯვნივ მოწონება"'}>${p.avatar_url?`<img src="${esc(p.avatar_url)}" alt="">`:`<div class="dph" style="--h:${p.hue}"><span>${esc(p.name[0])}</span></div>`}
 <div class="pinfo"><h3>${esc(String(p.name).split(' ')[0])} <span>${p.age}</span>${vb(p)}</h3>${p.city?`<p>${ic('pin')} ${esc(p.city)}${isOnline(p.id)?' · <i class="ond"></i> ონლაინ':''}</p>`:''}${p.dating_bio?tx(p.dating_bio,'media'):''}${(p.interests||[]).length?`<div class="chips">${p.interests.map(t=>`<span>${esc(t)}</span>`).join('')}</div>`:''}</div>
 <b class="stamp like">მომწონს</b><b class="stamp nope">არა</b></div>`}
function renderDeck(){const el=$('#dateb');if(!el)return;const d=DECK.slice(0,3);
 el.innerHTML=`<div class="deck">${d.length?d.slice().reverse().map((p,k,a)=>dcard(p,k<a.length-1)).join(''):`<div class="empty">${'<h3>ახლა ახალი ადამიანები აღარ არის</h3><p>მოგვიანებით შემოიხედე. რაც მეტი ადამიანი ჩართავს გაცნობას, მით მეტ ბარათს ნახავ.</p><button class="btn" data-a="invite">მეგობრის მოწვევა</button>'}</div>`}</div>
 <div class="dbtns"><button class="round no" data-a="swipe" data-d="-1" aria-label="გამოტოვება">${ic('x')}</button><button class="round sup" data-a="swipe" data-d="2" aria-label="სუპერ მოწონება, 5 მონეტა">${ic('star')}</button><button class="round yes" data-a="swipe" data-d="1" aria-label="მოწონება">${ic('heart')}</button></div>`;bindDeck()}
function bindDeck(){const top=$('.deck .pcard:last-child');if(!top)return;let sx=0,sy=0,dx=0,dy=0,drag=false;
 const set=()=>{top.style.transform=`translate(${dx}px,${dy}px) rotate(${dx/18}deg)`;top.style.setProperty('--l',Math.max(0,Math.min(1,dx/110)));top.style.setProperty('--n',Math.max(0,Math.min(1,-dx/110)))};
 top.onpointerdown=e=>{if(e.target.closest('button'))return;drag=true;sx=e.clientX;sy=e.clientY;top.setPointerCapture(e.pointerId);top.style.transition='none'};
 top.onpointermove=e=>{if(!drag)return;dx=e.clientX-sx;dy=(e.clientY-sy)*.4;set()};
 top.onpointerup=top.onpointercancel=()=>{if(!drag)return;drag=false;top.style.transition='';if(Math.abs(dx)>110)fly(dx>0?1:-1);else{dx=dy=0;top.style.transform='';top.style.setProperty('--l',0);top.style.setProperty('--n',0)}};
 top.onkeydown=e=>{if(e.key==='ArrowRight')fly(1);if(e.key==='ArrowLeft')fly(-1);if(e.key==='ArrowUp')fly(2)}}
async function fly(d){const top=$('.deck .pcard:last-child');if(!top||top._gone)return;const p=DECK[0];if(!p)return;
 if(d===2&&(ME.coins||0)<5){toast('სუპერ მოწონებას 5 მონეტა სჭირდება');openPage('coins');return}top._gone=1;
 top.style.transition='transform .35s ease,opacity .35s';top.style.setProperty(d<0?'--n':'--l',1);top.style.transform=d===2?'translateY(-120%) scale(.9)':`translate(${d*140}%,30px) rotate(${d*24}deg)`;top.style.opacity=0;
 let matched=false;try{matched=await rpc('swipe',{p_target:p.id,p_kind:d===2?'super':d>0?'like':'nope'});if(d===2)setCoins((ME.coins||0)-5)}catch(e){toast(errMsg(e))}
 setTimeout(()=>{DECK.shift();if(S.tab==='date')renderDeck();if(matched)matchSheet(p)},300)}
A.swipe=t=>{const d=+t.dataset.d;if(d>0)burst(t,d===2?'#3E8EF7':'#2FBF80');pop(t);fly(d)};
function matchSheet(p){PC.set(p.id,Object.assign(PC.get(p.id)||{},p));sheet(`<div class="match"><p class="eyebrow">ორმხრივი სიმპათია</p><h2>წყვილი ხართ!</h2><div class="pair">${av('me',96)}${av(p,96)}</div><p>შენ და ${esc(String(p.name).split(' ')[0])} ერთმანეთი მოიწონეთ. პირველი ნაბიჯი შენზეა.</p><button class="btn" data-a="chatwith" data-u="${p.id}">მიწერა</button><button class="btn ghost" data-a="close">სვაიპის გაგრძელება</button></div>`,'short');confetti()}
async function loadLikes(){const el=$('#dateb');if(!el)return;try{const n=await rpc('likes_me_count');el.innerHTML=n?`<div class="likes-cta"><b>${n} ადამიანს მოსწონხარ</b><p class="note">ვინაობას გაიგებ, როცა მათ ბარათს მოიწონებ და წყვილი გახდებით.</p><button class="btn" data-a="likesfirst">ჯერ ისინი მაჩვენე</button></div>`:empty('ახალი მოწონებები ჯერ არ არის','გააგრძელე სვაიპი, ხშირად შემოიხედე.')}catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.likesfirst=()=>{S.likesFirst=1;S.dmode='swipe';R.date()};
async function loadMatches(){const el=$('#dateb');if(!el)return;try{const rows=await q(sb.from('matches').select('a,b,created_at').or(`a.eq.${ME.id},b.eq.${ME.id}`).order('created_at',{ascending:false}));const ids=rows.map(r=>r.a===ME.id?r.b:r.a);await loadProfiles(ids);
 el.innerHTML=ids.length?`<div class="grid3">${ids.map(id=>{const p=prof(id);return `<button class="tile" data-a="chatwith" data-u="${id}">${p.avatar_url?`<img src="${esc(p.avatar_url)}" alt="">`:`<div class="dph" style="--h:${p.hue}"><span>${esc(p.name[0])}</span></div>`}${isOnline(id)?'<i class="on-dot"></i>':''}<span class="tl"><b>${esc(String(p.name).split(' ')[0])}</b>მიწერა</span></button>`}).join('')}</div>`:empty('წყვილები ჯერ არ გაქვს','როცა ორივე მოიწონებთ ერთმანეთს, აქ გამოჩნდება.')}catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
