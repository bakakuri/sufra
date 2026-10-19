/* admin panel: stats, reports queue, verification, ads review, users, pages */
Object.assign(ERR,{admin_only:'ეს მხოლოდ ადმინისტრატორს შეუძლია',cannot_ban_admin:'ადმინისტრატორს ვერ შეზღუდავ',cannot_demote_self:'საკუთარ თავს როლს ვერ ჩამოართმევ',not_pending:'ეს რეკლამა უკვე განხილულია',bad_type:'ამ ტიპის შინაარსს ასე ვერ დამალავ'});
const ADM={tab:'reports',rst:'open',uf:'new',st:{}};
const ATABS=[['reports','საჩივრები','open_reports'],['verify','ვერიფიკაცია','pending_verifications'],['ads','რეკლამა','pending_ads'],['users','მომხმარებლები',null],['pages','გვერდები',null],['words','სიტყვები',null]];
const TTYPE={post:'პოსტი',comment:'კომენტარი',user:'პროფილი',listing:'განცხადება',message:'შეტყობინება',page:'გვერდი',story:'ისტორია',event:'ღონისძიება',job:'ვაკანსია',ride:'მგზავრობა',room:'ოთახი',fixture:'მატჩი',place:'ადგილი',review:'შეფასება',toast:'სადღეგრძელო',help:'დახმარების თხოვნა'};
const ROLE_L={user:'მომხმარებელი',moderator:'მოდერატორი',admin:'ადმინისტრატორი'};

PG.admin={r(){if(!isStaff()){view.innerHTML=pgHead('ადმინ პანელი')+empty('წვდომა არ გაქვს','ეს გვერდი მხოლოდ მოდერატორებისთვისაა.');return}
 view.innerHTML=pgHead('ადმინ პანელი',`<span class="ptag">${ROLE_L[ME.role]}</span>`)+`<div class="adstats" id="adst">${'<div class="adtile"><b>·</b><span>&nbsp;</span></div>'.repeat(4)}</div>
 <div class="chipsbar" role="group" aria-label="განყოფილება" id="adtabs"></div><div id="adb">${skel(3)}</div>`;
 loadAdmin()}};
async function loadAdmin(){try{ADM.st=await rpc('admin_stats')||{}}catch(e){ADM.st={};toast(errMsg(e))}
 const el=$('#adst');if(el){el.innerHTML=[['users','მომხმარებელი'],['users_today','ახალი დღეს'],['posts_today','პოსტი დღეს'],['banned','შეზღუდული']].map(([k,l])=>`<div class="adtile"><b data-n="${ADM.st[k]||0}">0</b><span>${l}</span></div>`).join('');$$('b',el).forEach(b=>animNum(b,0,+b.dataset.n))}
 drawAdTabs();adminTab()}
function drawAdTabs(){const el=$('#adtabs');if(!el)return;el.innerHTML=ATABS.map(([k,l,c])=>`<button data-a="adtab" data-k="${k}" aria-pressed="${ADM.tab===k}">${l}${c&&ADM.st[c]?` <span class="badge">${ADM.st[c]}</span>`:''}</button>`).join('')}
A.adtab=t=>{ADM.tab=t.dataset.k;drawAdTabs();adminTab()};
async function refreshStats(){try{ADM.st=await rpc('admin_stats')||{};drawAdTabs()}catch(e){}}
function adminTab(){const el=$('#adb');if(!el)return;el.innerHTML=skel(3);({reports:admReports,verify:admVerify,ads:admAds,users:admUsers,pages:admPages,words:admWords})[ADM.tab](el).catch(e=>{if(el.isConnected)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e),'<button class="btn" data-a="adreload">თავიდან ცდა</button>')})}
A.adreload=()=>adminTab();

/* reports: grouped by target, with a preview and one-tap actions */
async function admReports(el){
 const rows=await q(sb.from('reports').select('id,reporter,target_type,target_id,reason,details,status,created_at').eq('status',ADM.rst==='open'?'open':ADM.rst).order('created_at',{ascending:ADM.rst==='open'}).limit(80));
 const groups=new Map();rows.forEach(r=>{const k=r.target_type+':'+r.target_id;if(!groups.has(k))groups.set(k,{type:r.target_type,id:r.target_id,list:[]});groups.get(k).list.push(r)});
 const by=t=>[...groups.values()].filter(g=>g.type===t).map(g=>g.id);
 const num=a=>a.map(Number).filter(n=>Number.isFinite(n));
 const T={};const grab=async(type,b)=>{try{(await q(b)).forEach(x=>T[type+':'+x.id]=x)}catch(e){}};
 const jobs=[];
 if(by('post').length)jobs.push(grab('post',sb.from('posts').select('id,author,body,media,hidden,created_at').in('id',num(by('post')))));
 if(by('comment').length)jobs.push(grab('comment',sb.from('comments').select('id,author,body,post_id,hidden').in('id',num(by('comment')))));
 if(by('listing').length)jobs.push(grab('listing',sb.from('listings').select('id,seller,title,media,hidden').in('id',num(by('listing')))));
 if(by('page').length)jobs.push(grab('page',sb.from('pages').select('id,name,owner,verified').in('id',num(by('page')))));
 if(by('story').length)jobs.push(grab('story',sb.from('stories').select('id,author,media_url,media_type').in('id',num(by('story')))));
 if(by('event').length)jobs.push(grab('event',sb.from('events').select('id,title,host').in('id',num(by('event')))));
 if(by('place').length)jobs.push(grab('place',sb.from('places').select('id,name,about,photo,created_by,hidden').in('id',num(by('place')))));
 if(by('review').length)jobs.push(grab('review',sb.from('place_reviews').select('id,author,body,photos,place_id,hidden').in('id',num(by('review')))));
 if(by('toast').length)jobs.push(grab('toast',sb.from('toasts').select('id,author,title,body,hidden').in('id',num(by('toast')))));
 if(by('help').length)jobs.push(grab('help',sb.from('help_requests').select('id,author,title,body,media,hidden').in('id',num(by('help')))));
 await Promise.all(jobs);
 const people=[...rows.map(r=>r.reporter),...by('user'),...Object.values(T).map(x=>x.author||x.seller||x.owner||x.host||x.created_by)];await loadProfiles(people);
 if(!el.isConnected)return;
 const seg=`<div class="seg" role="group" aria-label="სტატუსი">${[['open','ღია'],['resolved','გადაწყვეტილი'],['dismissed','უარყოფილი']].map(([k,l])=>`<button data-a="adrst" data-k="${k}" aria-pressed="${ADM.rst===k}">${l}</button>`).join('')}</div>`;
 if(!groups.size){el.innerHTML=seg+empty(ADM.rst==='open'?'საჩივრები არ არის':'აქ ცარიელია',ADM.rst==='open'?'ყველაფერი წესრიგშია.':'');return}
 el.innerHTML=seg+[...groups.values()].sort((a,b)=>b.list.length-a.list.length).map(g=>repCard(g,T[g.type+':'+g.id])).join('');staggerIn($$('.repcard',el).slice(0,6))}
A.adrst=t=>{ADM.rst=t.dataset.k;adminTab()};
function repCard(g,x){const k=g.type,owner=k==='user'?g.id:x&&(x.author||x.seller||x.owner||x.host||x.created_by);const ids=g.list.map(r=>r.id).join(',');
 const reasons=[...new Set(g.list.map(r=>r.reason))];
 let prev='';
 if(k==='user')prev=`<button class="row" data-a="user" data-u="${esc(g.id)}">${av(g.id,40)}<span class="grow"><b>${esc(pname(g.id))}${vb(g.id)}</b><span class="sub">${prof(g.id).banned?'შეზღუდულია':'@'+esc(prof(g.id).username||'')}</span></span></button>`;
 else if(!x)prev=`<p class="note">${k==='message'?'პირადი მიმოწერა მოდერატორს არ უჩანს. გადაწყვიტე საჩივრის აღწერით ან შეზღუდე ავტორი პროფილიდან.':'შინაარსი უკვე წაშლილია ან ვადა გაუვიდა.'}</p>`;
 else{const media=(x.media||[])[0],img=x.media_url||x.photo||(x.photos||[])[0]||(typeof media==='string'?media:media&&media.url),isVid=x.media_type==='video'||media&&media.type==='video';
  prev=`<div class="reppv">${img?(isVid?`<video src="${esc(img)}" muted playsinline preload="metadata"></video>`:`<img src="${esc(img)}" alt="" loading="lazy">`):''}<div class="grow">${owner?`<button class="pname" data-a="user" data-u="${owner}"><b>${esc(pname(owner))}</b></button>`:''}<p>${esc(String(x.body||x.title||x.name||'').slice(0,280))||'<span class="muted">ტექსტის გარეშე</span>'}</p>${x.hidden?'<span class="ptag warn">დამალულია</span>':''}</div></div>`}
 const canHide=['post','comment','listing','place','review','toast','help'].includes(k)&&x,canDel=['post','comment','listing','story','event','place','review','toast','help'].includes(k)&&x;
 const open=k==='post'&&x?`<button class="btn sm ghost" data-a="openpost" data-pid="${x.id}">${ic('eye')}ნახვა</button>`:k==='comment'&&x?`<button class="btn sm ghost" data-a="openpost" data-pid="${x.post_id}">${ic('eye')}პოსტი</button>`:k==='page'&&x?`<button class="btn sm ghost" data-a="pagev" data-id="${x.id}">${ic('eye')}ნახვა</button>`:k==='event'&&x?`<button class="btn sm ghost" data-a="page" data-p="event" data-arg="${x.id}">${ic('eye')}ნახვა</button>`:(k==='place'||k==='review')&&x?`<button class="btn sm ghost" data-a="page" data-p="place" data-arg="${x.place_id||x.id}">${ic('eye')}ნახვა</button>`:k==='help'&&x?`<button class="btn sm ghost" data-a="page" data-p="helpreq" data-arg="${x.id}">${ic('eye')}ნახვა</button>`:'';
 return `<article class="repcard" data-ids="${ids}"><div class="rephead"><span class="ptag">${TTYPE[k]||k}</span><b>${g.list.length} საჩივარი</b><span class="sp"></span><span class="sub">${ago(g.list[g.list.length-1].created_at)}</span></div>
 <div class="chips">${reasons.map(r=>`<span>${esc(r)}</span>`).join('')}</div>${g.list.filter(r=>r.details).slice(0,3).map(r=>`<p class="note">„${esc(r.details)}“</p>`).join('')}
 ${prev}
 <div class="pbtns">${open}${canHide?`<button class="btn sm" data-a="adhide" data-type="${k}" data-id="${x.id}" data-h="${x.hidden?0:1}">${ic(x.hidden?'eye':'lock')}${x.hidden?'გამოჩენა':'დამალვა'}</button>`:''}${canDel?`<button class="btn sm ghost" data-a="addel" data-type="${k}" data-id="${x.id}">${ic('trash')}წაშლა</button>`:''}${owner&&owner!==ME.id?`<button class="btn sm ghost" data-a="adban" data-u="${owner}" data-b="${prof(owner).banned?0:1}">${ic('block')}${prof(owner).banned?'შეზღუდვის მოხსნა':'ავტორის შეზღუდვა'}</button>`:''}
 ${ADM.rst==='open'?`<button class="btn sm ghost" data-a="adres" data-s="resolved">${ic('check')}გადაწყვეტილია</button><button class="btn sm ghost" data-a="adres" data-s="dismissed">${ic('x')}უარყოფა</button>`:`<button class="btn sm ghost" data-a="adres" data-s="open">ხელახლა გახსნა</button>`}</div></article>`}
async function resolveCard(card,status){const ids=String(card.dataset.ids).split(',').map(Number);await Promise.all(ids.map(id=>rpc('admin_resolve_report',{p_id:id,p_status:status})));
 anim(card,[{opacity:1,transform:'none'},{opacity:0,transform:'translateX(40px)'}],{duration:260,easing:EASE});setTimeout(()=>{card.remove();if(!$('.repcard'))adminTab()},240);refreshStats()}
A.adres=async t=>{const c=t.closest('.repcard');t.disabled=true;try{await resolveCard(c,t.dataset.s);toast(t.dataset.s==='resolved'?'მონიშნულია გადაწყვეტილად':t.dataset.s==='dismissed'?'საჩივარი უარყოფილია':'ხელახლა გაიხსნა')}catch(e){toast(errMsg(e));t.disabled=false}};
A.adhide=async t=>{const c=t.closest('.repcard'),h=t.dataset.h==='1';t.disabled=true;try{await rpc('admin_hide',{p_type:t.dataset.type,p_id:+t.dataset.id,p_hidden:h});toast(h?'დაიმალა ყველასთვის':'ისევ ჩანს');if(h&&c&&ADM.rst==='open')await resolveCard(c,'resolved');else adminTab()}catch(e){toast(errMsg(e));t.disabled=false}};
A.addel=t=>{const k=t.dataset.type,id=+t.dataset.id,c=t.closest('.repcard'),tbl={post:'posts',comment:'comments',listing:'listings',story:'stories',event:'events',place:'places',review:'place_reviews',toast:'toasts',help:'help_requests'}[k];
 confirmSheet('სამუდამოდ წაშლა',`${TTYPE[k]} წაიშლება და ვეღარ აღდგება.`,'წაშლა',async()=>{await q(sb.from(tbl).delete().eq('id',id));toast('წაიშალა');if(c&&ADM.rst==='open')await resolveCard(c,'resolved');else if(c)c.remove()},true)};
A.adban=t=>{const u=t.dataset.u,b=t.dataset.b==='1';const run=async()=>{await rpc('admin_ban',{p_user:u,p_banned:b});const p=PC.get(u);if(p)p.banned=b;toast(b?'შეიზღუდა':'შეზღუდვა მოიხსნა');refreshStats();if(ADM.tab==='users')adminTab();else{const c=t.closest('.repcard');if(c&&b&&ADM.rst==='open')await resolveCard(c,'resolved');else adminTab()}};
 if(b)confirmSheet('მომხმარებლის შეზღუდვა',`${esc(pname(u))} ვეღარ დაწერს პოსტებს, კომენტარებს და შეტყობინებებს, სანამ შეზღუდვას არ მოხსნი.`,'შეზღუდვა',run,true);else run().catch(e=>toast(errMsg(e)))};

/* verification: compare the selfie with the profile */
async function admVerify(el){const rows=await q(sb.from('verification_requests').select('id,user_id,selfie_url,created_at').eq('status','pending').order('created_at').limit(30));
 if(!rows.length){el.innerHTML=empty('მოთხოვნები არ არის','ახალი მოთხოვნა აქ გამოჩნდება.');return}
 await loadProfiles(rows.map(r=>r.user_id));const urls={};
 try{const{data}=await sb.storage.from('verify').createSignedUrls(rows.map(r=>r.selfie_url),600);(data||[]).forEach(d=>{if(d.signedUrl)urls[d.path]=d.signedUrl})}catch(e){}
 if(!el.isConnected)return;
 el.innerHTML=`<p class="hint" style="padding:12px 16px 0">შეადარე სელფი პროფილის ფოტოს. სელფის ბმული 10 წუთი მოქმედებს.</p>`+rows.map(r=>{const p=prof(r.user_id);return `<article class="repcard vreq" data-id="${r.id}"><div class="rephead">${av(p,40)}<div class="grow"><b>${esc(p.name)}</b><span class="sub">${p.username?'@'+esc(p.username)+' · ':''}${ago(r.created_at)}</span></div><button class="btn sm ghost" data-a="user" data-u="${p.id}">პროფილი</button></div>
  <div class="vcmp"><figure>${p.avatar_url?`<img src="${esc(p.avatar_url)}" alt="პროფილის ფოტო">`:`<div class="dph" style="--h:${p.hue||200}"><span>${esc(String(p.name||'?')[0])}</span></div>`}<figcaption>პროფილი</figcaption></figure><figure>${urls[r.selfie_url]?`<img src="${esc(urls[r.selfie_url])}" alt="სელფი">`:'<div class="dph"><span>?</span></div>'}<figcaption>სელფი</figcaption></figure></div>
  <div class="pbtns"><button class="btn sm" data-a="adver" data-id="${r.id}" data-ok="1">${ic('check')}დადასტურება</button><button class="btn sm ghost" data-a="adver" data-id="${r.id}" data-ok="0">${ic('x')}უარყოფა</button></div></article>`}).join('')}
A.adver=async t=>{const c=t.closest('.repcard'),ok=t.dataset.ok==='1';$$('button',c).forEach(b=>b.disabled=true);try{await rpc('admin_verify',{p_req:+t.dataset.id,p_approve:ok});toast(ok?'ვერიფიცირდა ✓':'უარყოფილია');if(ok)burst(t,'#3E8EF7');
 anim(c,[{opacity:1},{opacity:0,transform:'scale(.97)'}],{duration:240});setTimeout(()=>{c.remove();if(!$('.vreq'))adminTab()},230);refreshStats()}catch(e){toast(errMsg(e));$$('button',c).forEach(b=>b.disabled=false)}};

/* ads: review pending, see what runs */
async function admAds(el){const rows=await q(sb.from('ads').select('id,page_id,post_id,budget,spent,status,created_at,page:pages!ads_page_id_fkey(id,name,hue,verified)').in('status',['pending','active']).order('created_at',{ascending:false}).limit(40));
 const posts=rows.length?await fetchPosts(b=>b.in('id',rows.map(r=>r.post_id))):[];const P=new Map(posts.map(p=>[p.id,p]));
 if(!el.isConnected)return;const pend=rows.filter(r=>r.status==='pending'),act=rows.filter(r=>r.status==='active');
 if(!rows.length){el.innerHTML=empty('რეკლამები არ არის','ბიზნეს გვერდების რეკლამები განსახილველად აქ გამოჩნდება.');return}
 const card=r=>`<article class="repcard adcard" data-id="${r.id}"><div class="rephead"><span class="ptag ad">${r.status==='pending'?'განსახილველი':'აქტიური'}</span><b>${esc(r.page?.name||'გვერდი')}</b><span class="sp"></span><span class="sub">${r.status==='active'?`${r.spent}/${r.budget} ნახვა`:`ბიუჯეტი ${r.budget} ${ic('coin')}`}</span></div>
  ${P.has(r.post_id)?`<div class="adprev">${postHTML(P.get(r.post_id))}</div>`:'<p class="note">პოსტი წაშლილია</p>'}
  ${r.status==='pending'?`<div class="pbtns"><button class="btn sm" data-a="adad" data-id="${r.id}" data-ok="1">${ic('check')}დამტკიცება</button><button class="btn sm ghost" data-a="adad" data-id="${r.id}" data-ok="0">${ic('x')}უარყოფა (მონეტები დაბრუნდება)</button></div>`:''}</article>`;
 el.innerHTML=(pend.length?`<h3 class="sec2">განსახილველი · ${pend.length}</h3>${pend.map(card).join('')}`:'')+(act.length?`<h3 class="sec2">აქტიური · ${act.length}</h3>${act.map(card).join('')}`:'')}
A.adad=async t=>{const c=t.closest('.repcard'),ok=t.dataset.ok==='1';$$('.pbtns button',c).forEach(b=>b.disabled=true);try{await rpc('admin_review_ad',{p_ad:+t.dataset.id,p_approve:ok});toast(ok?'რეკლამა დამტკიცდა':'უარყოფილია, მონეტები დაბრუნდა');refreshStats();adminTab()}catch(e){toast(errMsg(e));$$('.pbtns button',c).forEach(b=>b.disabled=false)}};

/* users: search, filters, role, ban, verification */
async function admUsers(el){if(!$('#auq',el)){el.innerHTML=`<form class="search" id="auf" role="search"><input class="field" id="auq" type="search" placeholder="სახელი ან @username" aria-label="მომხმარებლის ძიება" autocomplete="off"></form>
 <div class="chipsbar" role="group" aria-label="ფილტრი">${[['new','ახალი'],['banned','შეზღუდული'],['staff','გუნდი'],['verified','ვერიფიცირებული']].map(([k,l])=>`<button data-a="auf" data-k="${k}" aria-pressed="${ADM.uf===k}">${l}</button>`).join('')}</div><div id="aur">${skel(3)}</div>`;
 $('#auf').onsubmit=e=>{e.preventDefault();admUserList()};$('#auq').oninput=()=>{clearTimeout(ADM.t);ADM.t=setTimeout(admUserList,350)}}
 await admUserList()}
A.auf=t=>{ADM.uf=t.dataset.k;$$('[data-a="auf"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));admUserList()};
async function admUserList(){const el=$('#aur');if(!el)return;const qv=clean($('#auq')?.value||'').replace(/^@/,''),tok=ADM.tok=(ADM.tok||0)+1;
 let b=sb.from('profiles').select(PCOLS).order('created_at',{ascending:false}).limit(40);
 if(qv)b=b.or(`name.ilike.%${qv}%,username.ilike.%${qv}%`);
 if(ADM.uf==='banned')b=b.eq('banned',true);else if(ADM.uf==='staff')b=b.in('role',['admin','moderator']);else if(ADM.uf==='verified')b=b.eq('verified',true);
 try{const rows=await q(b);if(tok!==ADM.tok)return;rows.forEach(p=>PC.set(p.id,p));
  el.innerHTML=rows.length?`<div class="list">${rows.map(p=>`<button class="row" data-a="aduser" data-u="${p.id}">${av(p,44)}<span class="grow"><b>${esc(p.name)}${vb(p)}</b><span class="sub">${p.username?'@'+esc(p.username)+' · ':''}${p.role!=='user'?ROLE_L[p.role]+' · ':''}${p.banned?'<span class="ptag warn">შეზღუდულია</span> · ':''}${ago(p.created_at)}</span></span>${ic('more')}</button>`).join('')}</div>`:empty('ვერავინ მოიძებნა')}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.aduser=t=>{const p=prof(t.dataset.u),me=p.id===ME.id,adm=ME.role==='admin';
 sheet(head(esc(p.name))+`<div class="ph-body"><div class="row" style="padding:0">${av(p,52)}<span class="grow"><b>${esc(p.name)}${vb(p)}</b><span class="sub">${p.username?'@'+esc(p.username)+' · ':''}${ROLE_L[p.role]||''} · დარეგისტრირდა ${ago(p.created_at)}</span></span></div></div>
 <div class="reasons"><button data-a="user" data-u="${p.id}">${ic('user')} პროფილის ნახვა</button>
 ${p.verified?`<button data-a="adunv" data-u="${p.id}">${ic('shield')} ვერიფიკაციის მოხსნა</button>`:''}
 ${!me&&p.role!=='admin'?`<button class="${p.banned?'':'warnbtn'}" data-a="adban" data-u="${p.id}" data-b="${p.banned?0:1}">${ic('block')} ${p.banned?'შეზღუდვის მოხსნა':'შეზღუდვა'}</button>`:''}
 ${adm&&!me?Object.keys(ROLE_L).filter(r=>r!==p.role).map(r=>`<button data-a="adrole" data-u="${p.id}" data-r="${r}">${ic(r==='user'?'user':r==='admin'?'crown':'shield')} როლი: ${ROLE_L[r]}</button>`).join(''):''}</div>`,'short')};
A.adunv=async t=>{try{await rpc('admin_unverify',{p_user:t.dataset.u});const p=PC.get(t.dataset.u);if(p)p.verified=false;closeSheet();toast('ვერიფიკაცია მოიხსნა');admUserList()}catch(e){toast(errMsg(e))}};
A.adrole=t=>{const u=t.dataset.u,r=t.dataset.r;confirmSheet('როლის შეცვლა',`${esc(pname(u))} გახდება „${ROLE_L[r]}“.${r==='admin'?' ადმინისტრატორს სრული წვდომა აქვს, მათ შორის როლების შეცვლაზე.':r==='moderator'?' მოდერატორი განიხილავს საჩივრებს, ვერიფიკაციას და რეკლამას.':''}`,'შეცვლა',async()=>{await rpc('admin_set_role',{p_user:u,p_role:r});const p=PC.get(u);if(p)p.role=r;toast('როლი შეიცვალა');admUserList()},r==='admin')};

/* pages: verify business pages and channels */
async function admPages(el){if(!$('#apq',el)){el.innerHTML=`<form class="search" id="apf" role="search"><input class="field" id="apq" type="search" placeholder="გვერდის სახელი" aria-label="გვერდის ძიება" autocomplete="off"></form><div id="apr">${skel(3)}</div>`;
 $('#apf').onsubmit=e=>{e.preventDefault();admPageList()};$('#apq').oninput=()=>{clearTimeout(ADM.t);ADM.t=setTimeout(admPageList,350)}}
 await admPageList()}
async function admPageList(){const el=$('#apr');if(!el)return;const qv=clean($('#apq')?.value||'');let b=sb.from('pages').select('id,name,kind,hue,verified,category,owner,created_at,avatar_url').order('created_at',{ascending:false}).limit(40);if(qv)b=b.ilike('name',`%${qv}%`);
 try{const rows=await q(b);await loadProfiles(rows.map(r=>r.owner));if(!el.isConnected)return;
  el.innerHTML=rows.length?`<div class="list">${rows.map(g=>`<div class="row">${avAny({n:g.name,h:g.hue,u:g.avatar_url},44).replace('class="av"','class="av sq"')}<button class="grow" data-a="pagev" data-id="${g.id}" style="text-align:left"><b>${esc(g.name)}${g.verified?vb({verified:1}):''}</b><span class="sub">${g.kind==='business'?'ბიზნესი':'არხი'} · ${esc(pname(g.owner))}</span></button><button class="btn sm${g.verified?' ghost':''}" data-a="adpv" data-id="${g.id}" data-v="${g.verified?0:1}">${g.verified?'მოხსნა':ic('check')+'ვერიფიკაცია'}</button></div>`).join('')}</div>`:empty('გვერდები არ არის')}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.adpv=async t=>{t.disabled=true;try{await rpc('admin_verify_page',{p_page:+t.dataset.id,p_verified:t.dataset.v==='1'});toast(t.dataset.v==='1'?'გვერდი ვერიფიცირდა':'ვერიფიკაცია მოიხსნა');admPageList()}catch(e){toast(errMsg(e));t.disabled=false}};

/* words that get masked in posts and comments; a word also catches its endings (ცუდი → ცუდისიტყვა) */
async function admWords(el){const rows=await q(sb.from('bad_words').select('word,created_at').order('word'));
 el.innerHTML=`<div class="form" style="gap:10px"><p class="note">ჩამოთვლილი სიტყვები პოსტებსა და კომენტარებში ავტომატურად იცვლება („ც***“). სიტყვა ფუძედაც მუშაობს: ჩაწერე ის ნაწილი, რომლითაც ყველა ფორმა იწყება. პირად მიმოწერაზე ფილტრი არ მოქმედებს.</p>
  <form class="search" id="bwf" style="margin:0;gap:8px"><input class="field" id="bwi" maxlength="40" placeholder="სიტყვა ან ფუძე" aria-label="სიტყვა" autocomplete="off"><button class="btn">დამატება</button></form>
  <div class="bwlist">${rows.map(r=>`<span class="bw">${esc(r.word)}<button data-a="bwdel" data-w="${esc(r.word)}" aria-label="წაშლა">${ic('x')}</button></span>`).join('')||'<p class="muted">სია ცარიელია.</p>'}</div>
  <p class="note">ასევე ავტომატურად: ერთი ადამიანი წუთში 8 კომენტარზე, საათში 15 პოსტზე და წუთში 30 მესიჯზე მეტს ვერ წერს; ერთი და იგივე ტექსტი ბევრგან ჩერდება; ახალი ანგარიში (24 საათამდე) ბმულებს შეზღუდულად აზიარებს; 3 სხვადასხვა საჩივრის შემდეგ პოსტი ან კომენტარი იმალება, სანამ მოდერატორი ნახავს.</p></div>`;
 $('#bwf').onsubmit=async e=>{e.preventDefault();const w=$('#bwi').value.trim().toLowerCase();if(w.length<2){toast('მინიმუმ 2 ასო');return}try{await q(sb.from('bad_words').insert({word:w}));adminTab()}catch(x){toast(errMsg(x))}}}
A.bwdel=async t=>{try{await q(sb.from('bad_words').delete().eq('word',t.dataset.w));t.closest('.bw').remove()}catch(e){toast(errMsg(e))}};
