/* admin panel: overview, reports, all content, users and coins, verification, sponsored posts and stories, notifications to everyone, site settings, pages, words, the log */
Object.assign(ERR,{admin_only:'ეს მხოლოდ ადმინისტრატორს შეუძლია',cannot_ban_admin:'ადმინისტრატორს ვერ შეზღუდავ',cannot_demote_self:'საკუთარ თავს როლს ვერ ჩამოართმევ',not_pending:'ეს რეკლამა უკვე განხილულია',bad_type:'ამ ტიპის შინაარსს ასე ვერ დამალავ',staff_only:'ეს მხოლოდ გუნდს შეუძლია'});
const ADM={tab:'overview',rst:'open',uf:'new',st:{},ct:'post',cq:'',ch:false,pt:'mine',promos:[]};
const ATABS=[['overview','მიმოხილვა',null,0],['reports','საჩივრები','open_reports',0],['content','კონტენტი',null,0],['users','მომხმარებლები',null,0],['verify','ვერიფიკაცია','pending_verifications',0],['promo','რეკლამა','pending_ads',0],['notify','შეტყობინებები',null,1],['site','საიტი',null,1],['pages','გვერდები',null,0],['words','სიტყვები',null,0],['log','ჟურნალი',null,0]];
const atabs=()=>ATABS.filter(t=>!t[3]||ME.role==='admin');
const TTYPE={post:'პოსტი',comment:'კომენტარი',user:'პროფილი',listing:'განცხადება',message:'შეტყობინება',page:'გვერდი',story:'ისტორია',event:'ღონისძიება',job:'ვაკანსია',ride:'მგზავრობა',room:'ოთახი',fixture:'მატჩი',place:'ადგილი',review:'შეფასება',toast:'სადღეგრძელო',help:'დახმარების თხოვნა'};
const ROLE_L={user:'მომხმარებელი',moderator:'მოდერატორი',admin:'ადმინისტრატორი'};

PG.admin={r(arg){if(!isStaff()){view.innerHTML=pgHead('ადმინ პანელი')+empty('წვდომა არ გაქვს','ეს გვერდი მხოლოდ მოდერატორებისთვისაა.');return}
 if(arg&&ATABS.some(t=>t[0]===arg))ADM.tab=arg;
 view.innerHTML=pgHead('ადმინ პანელი',`<span class="ptag">${ROLE_L[ME.role]}</span>`)+`<div class="chipsbar adtabs" role="group" aria-label="განყოფილება" id="adtabs"></div><div id="adb">${skel(3)}</div>`;
 loadAdmin()}};
async function loadAdmin(){try{ADM.st=await rpc('admin_stats')||{}}catch(e){ADM.st={};toast(errMsg(e))}if(!atabs().some(t=>t[0]===ADM.tab))ADM.tab='overview';drawAdTabs();adminTab()}
function drawAdTabs(){const el=$('#adtabs');if(!el)return;el.innerHTML=atabs().map(([k,l,c])=>`<button data-a="adtab" data-k="${k}" aria-pressed="${ADM.tab===k}">${l}${c&&ADM.st[c]?` <span class="badge">${ADM.st[c]}</span>`:''}</button>`).join('')}
A.adtab=t=>{ADM.tab=t.dataset.k;drawAdTabs();adminTab()};
async function refreshStats(){try{ADM.st=await rpc('admin_stats')||{};drawAdTabs()}catch(e){}}
function adminTab(){const el=$('#adb');if(!el)return;el.innerHTML=skel(3);({overview:admOverview,reports:admReports,content:admContent,users:admUsers,verify:admVerify,promo:admPromo,ads:admAds,notify:admNotify,site:admSite,pages:admPages,words:admWords,log:admLog})[ADM.tab](el).catch(e=>{if(el.isConnected)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e),'<button class="btn" data-a="adreload">თავიდან ცდა</button>')})}
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
 sheet(head(esc(p.name))+`<div class="ph-body"><div class="row" style="padding:0">${av(p,52)}<span class="grow"><b>${esc(p.name)}${vb(p)}</b><span class="sub">${p.username?'@'+esc(p.username)+' · ':''}${ROLE_L[p.role]||''} · დარეგისტრირდა ${ago(p.created_at)}</span></span></div><div class="auinfo" id="aui"><span class="spin"></span></div></div>
 <div class="reasons"><button data-a="user" data-u="${p.id}">${ic('user')} პროფილის ნახვა</button><button data-a="admsg" data-u="${p.id}">${ic('msg')} შეტყობინება გუნდის სახელით</button>${adm?`<button data-a="adcoins" data-u="${p.id}">${ic('coin')} მონეტების მიცემა ან ჩამოჭრა</button>`:''}
 ${p.verified?`<button data-a="adunv" data-u="${p.id}">${ic('shield')} ვერიფიკაციის მოხსნა</button>`:''}
 ${!me&&p.role!=='admin'?`<button class="${p.banned?'':'warnbtn'}" data-a="adban" data-u="${p.id}" data-b="${p.banned?0:1}">${ic('block')} ${p.banned?'შეზღუდვის მოხსნა':'შეზღუდვა'}</button>`:''}
 ${adm&&!me?Object.keys(ROLE_L).filter(r=>r!==p.role).map(r=>`<button data-a="adrole" data-u="${p.id}" data-r="${r}">${ic(r==='user'?'user':r==='admin'?'crown':'shield')} როლი: ${ROLE_L[r]}</button>`).join(''):''}</div>`,'short');admUserInfo(p.id)};
A.adunv=async t=>{try{await rpc('admin_unverify',{p_user:t.dataset.u});const p=PC.get(t.dataset.u);if(p)p.verified=false;closeSheet();toast('ვერიფიკაცია მოიხსნა');admUserList()}catch(e){toast(errMsg(e))}};
A.adrole=t=>{const u=t.dataset.u,r=t.dataset.r;confirmSheet('როლის შეცვლა',`${esc(pname(u))} გახდება „${ROLE_L[r]}“.${r==='admin'?' ადმინისტრატორს სრული წვდომა აქვს, მათ შორის როლების შეცვლაზე.':r==='moderator'?' მოდერატორი განიხილავს საჩივრებს, ვერიფიკაციას და რეკლამას.':''}`,'შეცვლა',async()=>{await rpc('admin_set_role',{p_user:u,p_role:r});const p=PC.get(u);if(p)p.role=r;toast('როლი შეიცვალა');admUserList()},r==='admin')};

/* pages: verify business pages and channels */
async function admPages(el){if(!$('#apq',el)){el.innerHTML=`<form class="search" id="apf" role="search"><input class="field" id="apq" type="search" placeholder="გვერდის სახელი" aria-label="გვერდის ძიება" autocomplete="off"></form><div id="apr">${skel(3)}</div>`;
 $('#apf').onsubmit=e=>{e.preventDefault();admPageList()};$('#apq').oninput=()=>{clearTimeout(ADM.t);ADM.t=setTimeout(admPageList,350)}}
 await admPageList()}
async function admPageList(){const el=$('#apr');if(!el)return;const qv=clean($('#apq')?.value||'');let b=sb.from('pages').select('id,name,kind,hue,verified,category,owner,created_at,avatar_url').order('created_at',{ascending:false}).limit(40);if(qv)b=b.ilike('name',`%${qv}%`);
 try{const rows=await q(b);await loadProfiles(rows.map(r=>r.owner));if(!el.isConnected)return;
  el.innerHTML=rows.length?`<div class="list">${rows.map(g=>`<div class="row">${avAny({n:g.name,h:g.hue,u:g.avatar_url},44).replace('class="av"','class="av sq"')}<button class="grow" data-a="pagev" data-id="${g.id}" style="text-align:left"><b>${esc(g.name)}${g.verified?vb({verified:1}):''}</b><span class="sub">${g.kind==='business'?'ბიზნესი':'არხი'} · ${esc(pname(g.owner))}</span></button><button class="btn sm${g.verified?' ghost':''}" data-a="adpv" data-id="${g.id}" data-v="${g.verified?0:1}">${g.verified?'მოხსნა':ic('check')+'ვერიფიკაცია'}</button><button class="ibtn sm" data-a="adpdel" data-id="${g.id}" data-n="${esc(g.name)}" aria-label="წაშლა">${ic('trash')}</button></div>`).join('')}</div>`:empty('გვერდები არ არის')}
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

/* ---------- one person: numbers, a message from the team, coins ---------- */
async function admUserInfo(u){const el=$('#aui');try{const d=await rpc('admin_user_info',{p_user:u});if(!el||!el.isConnected)return;
 const it=(n,l)=>`<span><b>${fmt(n||0)}</b>${l}</span>`;
 el.innerHTML=`<div class="auin">${it(d.posts,'პოსტი')}${it(d.comments,'კომენტარი')}${it(d.friends,'მეგობარი')}${it(d.coins,'მონეტა')}${it(d.reports,'საჩივარი პროფილზე')}${it(d.reported_content,'საჩივარი პოსტებზე')}</div><p class="sub">${d.last_seen?'ბოლოს იყო '+ago(d.last_seen):'ჯერ არ შემოსულა'}${d.email?' · '+esc(d.email):''}</p>`}
 catch(e){if(el)el.innerHTML=`<p class="note">${esc(errMsg(e))}</p>`}}
A.admsg=t=>{const u=t.dataset.u;sheet(head('შეტყობინება · '+esc(String(pname(u)).split(' ')[0]))+`<form class="ph-body" id="amf"><p class="note">მივა მის შეტყობინებებში „სუფრის გუნდის“ სახელით. ამ ტიპს ვერ გამორთავს, ამიტომ გამოიყენე მნიშვნელოვანი საკითხისთვის.</p><label class="fld">ტექსტი<textarea id="am_t" maxlength="300" rows="4" placeholder="მაგ. შენი პოსტი წაიშალა, რადგან წესებს არღვევდა"></textarea></label><button class="btn">${ic('send')}გაგზავნა</button></form>`,'short');
 $('#amf').onsubmit=async e=>{e.preventDefault();const v=$('#am_t').value.trim();if(v.length<2){toast('დაწერე ტექსტი');return}try{await rpc('admin_notify_user',{p_user:u,p_text:v});closeSheet();toast('გაიგზავნა')}catch(x){toast(errMsg(x))}}};
A.adcoins=t=>{const u=t.dataset.u;sheet(head('მონეტები · '+esc(String(pname(u)).split(' ')[0]))+`<form class="ph-body" id="acof"><div class="seg flat" role="group" aria-label="მოქმედება"><button type="button" data-s="1" aria-pressed="true">მიცემა</button><button type="button" data-s="-1" aria-pressed="false">ჩამოჭრა</button></div>
 <div class="chips">${[5,10,25,50,100].map(n=>`<button type="button" class="chip" data-n="${n}">${n}</button>`).join('')}</div><label class="fld">რაოდენობა<input id="aco_n" type="number" min="1" max="100000" value="10"></label><label class="fld">მიზეზი (ნახავს მომხმარებელი)<input id="aco_r" maxlength="80" placeholder="მაგ. კონკურსის გამარჯვებული"></label><button class="btn">${ic('coin')}შენახვა</button></form>`,'short');
 const f=$('#acof');let sign=1;$$('.seg button',f).forEach(b=>b.onclick=()=>{sign=+b.dataset.s;$$('.seg button',f).forEach(x=>x.setAttribute('aria-pressed',String(x===b)))});$$('[data-n]',f).forEach(b=>b.onclick=()=>{$('#aco_n').value=b.dataset.n});
 f.onsubmit=async e=>{e.preventDefault();const n=Math.floor(+$('#aco_n').value);if(!(n>0)){toast('ჩაწერე რაოდენობა');return}try{const c=await rpc('admin_coins',{p_user:u,p_amount:sign*n,p_note:$('#aco_r').value.trim()});closeSheet();toast(`შენახულია. ახლა აქვს ${c} მონეტა`);if(u===ME.id)setCoins(c)}catch(x){toast(errMsg(x))}}};
A.adpdel=t=>{const id=+t.dataset.id;confirmSheet('გვერდის წაშლა',`„${esc(t.dataset.n)}“ და მისი პოსტები წაიშლება.`,'წაშლა',async()=>{await q(sb.from('pages').delete().eq('id',id));toast('წაიშალა');admPageList()},true)};

/* ---------- overview: the numbers and the last two weeks ---------- */
function dayChart(days,k,title){if(!days||!days.length)return '';const vals=days.map(d=>+d[k]||0),top=Math.max(...vals),mx=Math.max(1,top),tot=vals.reduce((a,b)=>a+b,0),iMax=vals.indexOf(top),last=vals.length-1;
 const dl=d=>{const x=new Date(d+'T12:00:00');return x.getDate()+' '+MONTHS[x.getMonth()].slice(0,3)};
 return `<figure class="dchart"><figcaption><b>${title}</b><span>14 დღე · სულ ${fmt(tot)}</span></figcaption>
 <div class="dcbars" role="img" aria-label="${title}, დღეების მიხედვით: ${days.map((d,i)=>dl(d.d)+' '+vals[i]).join(', ')}">${days.map((d,i)=>`<span class="dcb${i===last?' now':''}" tabindex="0" style="--v:${vals[i]/mx}" data-tip="${dl(d.d)} · ${vals[i]}">${(i===last||i===iMax)&&vals[i]?`<em>${vals[i]}</em>`:''}<i></i></span>`).join('')}</div>
 <div class="dcx"><span>${dl(days[0].d)}</span><span>დღეს</span></div>
 <details class="dctbl"><summary>ცხრილით</summary><table><tbody>${days.map((d,i)=>`<tr><td>${dl(d.d)}</td><td>${vals[i]}</td></tr>`).join('')}</tbody></table></details></figure>`}
async function admOverview(el){try{ADM.st=await rpc('admin_stats')||ADM.st}catch(e){}const s=ADM.st||{};if(!el.isConnected)return;
 const T=(k,l)=>`<div class="adtile"><b>${fmt(s[k]||0)}</b><span>${l}</span></div>`;
 el.innerHTML=`<h3 class="sec2">ხალხი</h3><div class="adstats">${T('users','მომხმარებელი')}${T('users_today','ახალი, 24 სთ')}${T('active_today','აქტიური დღეს')}${T('active_week','აქტიური კვირაში')}</div>
 <h3 class="sec2">ბოლო 24 საათი</h3><div class="adstats">${T('posts_today','პოსტი')}${T('comments_today','კომენტარი')}${T('messages_today','მესიჯი')}${T('stories_live','ისტორია ახლა')}</div>
 <div class="adcharts">${dayChart(s.days,'users','ახალი მომხმარებლები')}${dayChart(s.days,'posts','ახალი პოსტები')}</div>
 <h3 class="sec2">საიტზე</h3><div class="adstats">${T('groups','ჯგუფი')}${T('pages','გვერდი')}${T('events_soon','ღონისძიება წინ')}${T('rooms_live','ცოცხალი ოთახი')}${T('listings','განცხადება')}${T('recipes','რეცეპტი')}${T('promos_live','აქტიური რეკლამა')}${T('banned','შეზღუდული')}</div>
 <div class="adstats wide">${T('coins_total','მონეტა მომხმარებლებთან ჯამში')}${T('open_reports','ღია საჩივარი')}</div>
 ${ME.role==='admin'?`<div class="adquick"><button class="btn" data-a="adpromonew" data-k="post">${ic('mega')}ახალი რეკლამა</button><button class="btn ghost" data-a="adtab" data-k="notify">${ic('bell')}შეტყობინება ყველას</button><button class="btn ghost" data-a="adtab" data-k="site">${ic('gear')}საიტის პარამეტრები</button></div>`:''}`;
 $$('.adtile b',el).forEach(b=>{const n=parseInt(b.textContent,10);if(n>0&&!/K/.test(b.textContent))animNum(b,0,n)})}

/* ---------- all content in one place: find, open, hide, remove ---------- */
const CT=[['post','პოსტები','posts','id,author,body,media,hidden,created_at','author','body',1],['comment','კომენტარები','comments','id,author,body,post_id,hidden,created_at','author','body',1],['story','ისტორიები','stories','id,author,media_url,media_type,created_at,expires_at','author',null,0],['group','ჯგუფები','groups','id,owner,name,description,avatar_url,created_at','owner','name',0],['event','ღონისძიებები','events','id,host,title,starts_at,created_at','host','title',0],['listing','განცხადებები','listings','id,seller,title,media,hidden,created_at','seller','title',1],['place','ადგილები','places','id,created_by,name,photo,hidden,created_at','created_by','name',1],['recipe','რეცეპტები','recipes','id,author,title,photo_url,created_at','author','title',0],['toast','სადღეგრძელოები','toasts','id,author,title,body,hidden,created_at','author','title',1],['help','დახმარება','help_requests','id,author,title,media,hidden,created_at','author','title',1],['job','ვაკანსიები','jobs','id,poster,title,company,hidden,created_at','poster','title',1],['ride','მგზავრობა','rides','id,driver,from_city,to_city,depart_at,created_at','driver','from_city',0],['room','ოთახები','rooms','id,host,kind,title,live,created_at','host','title',0],['album','ალბომები','albums','id,owner,title,cover_url,created_at','owner','title',0]];
const C_OPEN={post:r=>['post',r.id],comment:r=>['post',r.post_id],group:r=>['group',r.id],event:r=>['event',r.id],place:r=>['place',r.id],recipe:r=>['recipe',r.id],help:r=>['helpreq',r.id],job:r=>['job',r.id],ride:r=>['ride',r.id],room:r=>['room',r.id],album:r=>['album',r.id]};
async function admContent(el){if(!$('#acq',el)){el.innerHTML=`<div class="chipsbar" role="group" aria-label="რა ვნახოთ">${CT.map(c=>`<button data-a="act" data-k="${c[0]}" aria-pressed="${ADM.ct===c[0]}">${c[1]}</button>`).join('')}</div>
 <form class="search" id="acf" role="search"><input class="field" id="acq" type="search" placeholder="ძიება ტექსტში" value="${esc(ADM.cq)}" aria-label="ძიება" autocomplete="off"></form><label class="chk adhid"><input type="checkbox" id="ach"${ADM.ch?' checked':''}><span>მხოლოდ დამალული</span></label><div id="acr">${skel(3)}</div>`;
 $('#acf').onsubmit=e=>{e.preventDefault();ADM.cq=$('#acq').value.trim();admContentList()};$('#acq').oninput=()=>{clearTimeout(ADM.t);ADM.t=setTimeout(()=>{ADM.cq=$('#acq').value.trim();admContentList()},350)};$('#ach').onchange=()=>{ADM.ch=$('#ach').checked;admContentList()}}
 await admContentList()}
A.act=t=>{ADM.ct=t.dataset.k;$$('[data-a="act"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));admContentList()};
async function admContentList(more){const el=$('#acr');if(!el)return;const c=CT.find(x=>x[0]===ADM.ct),[,,tbl,cols,own,txt,canHide]=c,tok=ADM.ctok=(ADM.ctok||0)+1;
 const hb=$('.adhid');if(hb)hb.hidden=!canHide;if(!more)el.innerHTML=skel(3);
 const from=more?ADM.coff:0;let b=sb.from(tbl).select(cols).order('created_at',{ascending:false}).range(from,from+39);
 if(ADM.cq&&txt)b=b.ilike(txt,'%'+ADM.cq.replace(/[%_,()]/g,' ')+'%');if(ADM.ch&&canHide)b=b.eq('hidden',true);
 try{const rows=await q(b);if(tok!==ADM.ctok)return;await loadProfiles(rows.map(r=>r[own]).filter(Boolean));ADM.coff=from+rows.length;ADM.crows=more?[...(ADM.crows||[]),...rows]:rows;
  const html=rows.map(r=>contentRow(c,r)).join('');
  if(more){$('#acmore')?.remove();el.insertAdjacentHTML('beforeend',html)}else el.innerHTML=html||empty('აქ არაფერია',ADM.cq?'სხვა სიტყვით სცადე.':'');
  if(rows.length===40)el.insertAdjacentHTML('beforeend','<button class="btn ghost wide" id="acmore" data-a="acmore">მეტის ჩატვირთვა</button>')}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.acmore=()=>admContentList(true);
function contentRow(c,r){const[k,,,,own,txt,canHide]=c,o=r[own],m=Array.isArray(r.media)?r.media[0]:null;
 const img=r.media_url||r.photo||r.photo_url||r.cover_url||r.avatar_url||(m&&(typeof m==='string'?m:(m.sm||m.url))),vid=r.media_type==='video'||(m&&m.type==='video');
 const text=k==='ride'?`${r.from_city||''} → ${r.to_city||''}`:String(r[txt]||r.body||'').slice(0,160);
 const tags=`${r.hidden?'<span class="ptag warn">დამალულია</span>':''}${k==='room'?(r.live?'<span class="ptag ad">ცოცხალი</span>':'<span class="ptag">დასრულდა</span>'):''}${k==='story'&&new Date(r.expires_at)<new Date()?'<span class="ptag">არქივში</span>':''}`;
 return `<article class="acrow" data-k="${k}" data-id="${r.id}">${img?`<span class="acth">${vid?`<video src="${esc(img)}" muted playsinline preload="metadata"></video>`:`<img src="${esc(img)}" alt="" loading="lazy">`}</span>`:''}<div class="grow"><p>${text?esc(text):'<span class="muted">ტექსტის გარეშე</span>'}</p><span class="sub">${o?esc(pname(o))+' · ':''}${ago(r.created_at)} ${tags}</span>
  <div class="pbtns">${C_OPEN[k]||k==='story'?`<button class="btn sm ghost" data-a="acopen">${ic('eye')}ნახვა</button>`:''}${canHide?`<button class="btn sm ghost" data-a="achide" data-h="${r.hidden?0:1}">${ic(r.hidden?'eye':'lock')}${r.hidden?'გამოჩენა':'დამალვა'}</button>`:''}${k==='room'?(r.live?`<button class="btn sm ghost" data-a="acend">${ic('hangup')}დასრულება</button>`:''):`<button class="btn sm ghost warnbtn" data-a="acdel">${ic('trash')}წაშლა</button>`}${o&&o!==ME.id?`<button class="btn sm ghost" data-a="aduser" data-u="${o}">${ic('user')}ავტორი</button>`:''}</div></div></article>`}
const acRow=t=>{const row=t.closest('.acrow');return row?{row,k:row.dataset.k,r:(ADM.crows||[]).find(x=>String(x.id)===row.dataset.id)}:{}};
A.acopen=t=>{const{k,r}=acRow(t);if(!r)return;if(k==='story'){openImage(r.media_url,{video:r.media_type==='video'});return}if(k==='comment')S.openComments=true;const f=C_OPEN[k];if(f){const[pg,arg]=f(r);openPage(pg,arg)}};
A.achide=async t=>{const{row,k,r}=acRow(t);if(!r)return;const h=t.dataset.h==='1';t.disabled=true;try{await rpc('admin_hide',{p_type:k,p_id:r.id,p_hidden:h});r.hidden=h;row.outerHTML=contentRow(CT.find(x=>x[0]===k),r);toast(h?'დაიმალა ყველასთვის':'ისევ ჩანს')}catch(e){toast(errMsg(e));t.disabled=false}};
A.acdel=t=>{const{row,k,r}=acRow(t);if(!r)return;const c=CT.find(x=>x[0]===k);confirmSheet('სამუდამოდ წაშლა',`${esc(c[1])}: ეს ჩანაწერი წაიშლება და ვეღარ აღდგება.`,'წაშლა',async()=>{await q(sb.from(c[2]).delete().eq('id',r.id));row.remove();toast('წაიშალა')},true)};
A.acend=t=>{const{row,r}=acRow(t);if(!r)return;confirmSheet('ოთახის დასრულება','ოთახი ყველასთვის დაიხურება.','დასრულება',async()=>{await q(sb.from('rooms').update({live:false,ended_at:new Date().toISOString()}).eq('id',r.id));r.live=false;row.outerHTML=contentRow(CT.find(x=>x[0]==='room'),r);toast('ოთახი დასრულდა')},true)};

/* ---------- sponsored posts and stories ---------- */
const PRLINKS=[['#recipes','სამზარეულო'],['#events','ღონისძიებები'],['#market','ბაზრობა'],['#rooms','სუფრები'],['#games','თამაშები'],['#coins','მონეტები']];
const linkOk=l=>!l||/^https:\/\/[^\s"'<>()]+$/.test(l)||/^#[a-z]+(-[^\s"'<>()]+)?$/.test(l);
async function admPromo(el){const adm=ME.role==='admin';if(!adm)ADM.pt='pages';
 el.innerHTML=(adm?`<div class="seg" role="group" aria-label="რეკლამის სახე"><button data-a="adpt" data-k="mine" aria-pressed="${ADM.pt==='mine'}">სუფრის რეკლამა</button><button data-a="adpt" data-k="pages" aria-pressed="${ADM.pt==='pages'}">გვერდების რეკლამა${ADM.st.pending_ads?` <span class="badge">${ADM.st.pending_ads}</span>`:''}</button></div>`:'')+`<div id="apb">${skel(2)}</div>`;
 const b=$('#apb');if(ADM.pt==='pages'){await admAds(b);return}
 const rows=await q(sb.from('promos').select(PSEL).order('created_at',{ascending:false}).limit(60));ADM.promos=rows;if(!b.isConnected)return;
 b.innerHTML=`<div class="adquick"><button class="btn" data-a="adpromonew" data-k="post">${ic('plus')}რეკლამა ფიდში</button><button class="btn ghost" data-a="adpromonew" data-k="story">${ic('story')}სარეკლამო ისტორია</button></div>
  <p class="hint" style="padding:0 16px 8px">ფიდის რეკლამა პოსტებს შორის ჩნდება, ისტორია კი ისტორიების რიგში, ყველას საკუთარი ისტორიის შემდეგ. „ნახა“ ადამიანებს ითვლის, თითოს ერთხელ.</p>
  ${rows.length?rows.map(promoCard).join(''):empty('რეკლამა ჯერ არ არის','შექმენი პირველი და ყველა მომხმარებელი დაინახავს.')}`}
A.adpt=t=>{ADM.pt=t.dataset.k;adminTab()};
function promoState(p){const now=new Date();if(!p.active)return['პაუზაზეა','warn'];if(new Date(p.starts_at)>now)return['იწყება '+fdate(p.starts_at),''];if(p.ends_at&&new Date(p.ends_at)<=now)return['დასრულდა',''];return['აქტიურია','ad']}
function promoCard(p){const[st,cls]=promoState(p),ctr=p.reach?Math.round(p.clicks/p.reach*1000)/10:0;
 return `<article class="repcard prcard" data-id="${p.id}"><div class="rephead"><span class="ptag">${p.kind==='story'?'ისტორია':'ფიდში'}</span><span class="ptag ${cls}">${esc(st)}</span><span class="sp"></span><span class="sub">${ago(p.created_at)}</span></div>
  <div class="reppv">${p.media_url?(p.media_type==='video'?`<video src="${esc(p.media_url)}" muted playsinline preload="metadata"></video>`:`<img src="${esc(p.media_url)}" alt="" loading="lazy">`):''}<div class="grow"><b>${esc(p.title||p.brand)}</b>${p.body?`<p>${esc(String(p.body).slice(0,160))}</p>`:''}${p.link?`<span class="sub">${esc(p.link)}</span>`:''}</div></div>
  <div class="prstats"><span><b>${fmt(p.reach)}</b>ნახა</span><span><b>${fmt(p.clicks)}</b>დააჭირა</span><span><b>${ctr}%</b>დაჭერის წილი</span></div>${p.ends_at?`<p class="sub">მთავრდება: ${fdate(p.ends_at)}</p>`:''}
  <div class="pbtns"><button class="btn sm ghost" data-a="adpromoview" data-id="${p.id}">${ic('eye')}ნახვა</button><button class="btn sm ghost" data-a="adpromoedit" data-id="${p.id}">${ic('edit')}შეცვლა</button><button class="btn sm${p.active?' ghost':''}" data-a="adpromoact" data-id="${p.id}" data-v="${p.active?0:1}">${ic(p.active?'pause':'play')}${p.active?'პაუზა':'გაშვება'}</button><button class="btn sm ghost warnbtn" data-a="adpromodel" data-id="${p.id}">${ic('trash')}წაშლა</button></div></article>`}
const admP=t=>ADM.promos.find(x=>x.id===+t.dataset.id);
A.adpromonew=t=>promoEditor(null,t.dataset.k||'post');
A.adpromoedit=t=>{const p=admP(t);if(p)promoEditor(p)};
A.adpromoview=t=>{const p=admP(t);if(!p)return;if(p.kind==='story'){openStory(0,0,[{a:'promo:'+p.id,promo:p,preview:true,list:[{id:'p'+p.id,media_url:p.media_url,media_type:p.media_type,created_at:p.starts_at,promo:p}]}]);return}
 sheet(head('ასე გამოჩნდება ფიდში')+`<div class="ph-body prev">${promoHTML(p)}</div>`)};
A.adpromoact=async t=>{const p=admP(t);if(!p)return;t.disabled=true;try{await q(sb.from('promos').update({active:t.dataset.v==='1'}).eq('id',p.id));toast(t.dataset.v==='1'?'რეკლამა გაეშვა':'რეკლამა დაპაუზდა');PROMOS.at=0;adminTab()}catch(e){toast(errMsg(e));t.disabled=false}};
A.adpromodel=t=>{const p=admP(t);if(!p)return;confirmSheet('რეკლამის წაშლა','რეკლამა და მისი სტატისტიკა წაიშლება.','წაშლა',async()=>{await q(sb.from('promos').delete().eq('id',p.id));toast('წაიშალა');PROMOS.at=0;adminTab()},true)};
function promoEditor(p,kind){const isNew=!p;p=p||{kind:kind||'post',brand:'სუფრა',brand_url:null,title:'',body:'',media_url:null,media_type:'image',w:null,h:null,link:'',cta:'',every:8,starts_at:new Date().toISOString(),ends_at:null,active:true};
 const st={kind:p.kind,media:p.media_url?{url:p.media_url,type:p.media_type,w:p.w,h:p.h}:null,logo:{url:p.brand_url||null},busy:null};
 const dt=v=>{if(!v)return '';const d=new Date(v);d.setMinutes(d.getMinutes()-d.getTimezoneOffset());return d.toISOString().slice(0,16)};
 sheet(head(isNew?'ახალი რეკლამა':'რეკლამის შეცვლა')+`<form class="ph-body prform" id="prf">
  <div class="seg flat" role="group" aria-label="სად გამოჩნდეს" id="pr_k"><button type="button" data-k="post" aria-pressed="${p.kind==='post'}">${ic('home')}ფიდში</button><button type="button" data-k="story" aria-pressed="${p.kind==='story'}">${ic('story')}ისტორიად</button></div>
  <div class="prmd" id="prmd"></div>
  <div class="row2"><button type="button" class="btn sm ghost" id="pr_img">${ic('image')}ფოტო</button><button type="button" class="btn sm ghost" id="pr_vid">${ic('clips')}ვიდეო</button><button type="button" class="btn sm ghost" id="pr_rm"${st.media?'':' hidden'}>მოშორება</button></div>
  <label class="fld">ვისი სახელით<input id="pr_b" maxlength="60" value="${esc(p.brand)}"></label>${picField('pr_logo',p.brand_url,'ლოგო','არასავალდებულო, მრგვალში ჩანს')}
  <label class="fld">სათაური<input id="pr_t" maxlength="120" value="${esc(p.title||'')}" placeholder="მაგ. ახალი სამზარეულო სუფრაზე"></label>
  <label class="fld">ტექსტი<textarea id="pr_x" maxlength="1000" rows="3">${esc(p.body||'')}</textarea></label>
  <label class="fld">ბმული<input id="pr_l" maxlength="300" value="${esc(p.link||'')}" placeholder="https://… ან საიტის გვერდი ქვემოთ"></label>
  <div class="chips prlinks">${PRLINKS.map(([h,l])=>`<button type="button" class="chip" data-l="${h}">${l}</button>`).join('')}</div>
  <label class="fld">ღილაკის ტექსტი<input id="pr_c" maxlength="30" value="${esc(p.cta||'')}" placeholder="გაიგე მეტი"></label>
  <label class="fld" id="pr_ew">ფიდში ჩნდება ყოველ<span class="inl"><input id="pr_e" type="number" min="3" max="50" value="${p.every}"><span>პოსტში</span></span></label>
  <div class="frow"><label class="fld">დაწყება<input id="pr_s" type="datetime-local" value="${dt(p.starts_at)}"></label><label class="fld">დასრულება<input id="pr_n" type="datetime-local" value="${dt(p.ends_at)}"></label></div>
  <button class="btn" id="pr_ok">${ic('check')}${isNew?'გაშვება':'შენახვა'}</button></form>`);
 bindPic('pr_logo',st.logo,'ლოგო');
 const draw=()=>{const m=st.media,box=$('#prmd');$$('#pr_k button').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.k===st.kind)));$('#pr_ew').hidden=st.kind!=='post';$('#pr_rm').hidden=!m;
  box.className='prmd'+(st.kind==='story'?' story':'');box.style.setProperty('--ar',st.kind==='story'?'9/16':m&&m.w&&m.h?String(boxRatio(m)):'16/9');
  box.innerHTML=m?(m.type==='video'?`<video src="${esc(m.url)}" muted playsinline autoplay loop></video>`:`<img src="${esc(m.url)}" alt="">`):`<span>${st.kind==='story'?'ისტორიას ფოტო ან ვიდეო სჭირდება (9:16)':'ფოტო ან ვიდეო არასავალდებულოა'}</span>`};
 const up=async(b,type)=>{const box=$('#prmd');box.classList.add('busy');try{const m=await uploadMedia(b,type);st.media={url:type==='image'?(m.md||m.url):m.url,type,w:m.w||null,h:m.h||null}}catch(e){toast(errMsg(e))}finally{box.classList.remove('busy');draw()}};
 $$('#pr_k button').forEach(b=>b.onclick=()=>{st.kind=b.dataset.k;draw()});
 $('#pr_img').onclick=async()=>{const b=await pickImage({ratios:['orig','916','45','1','169'],ratio:st.kind==='story'?'916':'orig',max:1600,title:'რეკლამის ფოტო'});if(b)st.busy=up(b,'image')};
 $('#pr_vid').onclick=async()=>{const v=await pickVideo();if(v){toast('ვიდეო იტვირთება…');st.busy=up(v,'video')}};
 $('#pr_rm').onclick=()=>{st.media=null;draw()};
 $$('.prlinks [data-l]').forEach(b=>b.onclick=()=>{$('#pr_l').value=b.dataset.l});
 draw();
 $('#prf').onsubmit=async e=>{e.preventDefault();const ok=$('#pr_ok');ok.disabled=true;
  try{if(st.busy)await st.busy;if(st.logo.p)await st.logo.p;const link=$('#pr_l').value.trim(),title=$('#pr_t').value.trim(),body=$('#pr_x').value.trim(),s0=$('#pr_s').value,e0=$('#pr_n').value;
   const fail=m=>{toast(m);ok.disabled=false};
   if(st.kind==='story'&&!st.media)return fail('ისტორიას ფოტო ან ვიდეო სჭირდება');
   if(!title&&!body&&!st.media)return fail('დაწერე სათაური ან ტექსტი, ან დაამატე ფოტო');
   if(!linkOk(link))return fail('ბმული https://-ით ან #-ით უნდა იწყებოდეს');
   const start=s0?new Date(s0):new Date(),end=e0?new Date(e0):null;if(end&&end<=start)return fail('დასრულება დაწყების შემდეგ უნდა იყოს');
   const row={kind:st.kind,brand:$('#pr_b').value.trim()||'სუფრა',brand_url:st.logo.url||null,title:title||null,body:body||null,media_url:st.media?st.media.url:null,media_type:st.media?st.media.type:'image',w:st.media&&st.media.w?Math.round(st.media.w):null,h:st.media&&st.media.h?Math.round(st.media.h):null,link:link||null,cta:$('#pr_c').value.trim()||null,every:Math.max(3,Math.min(50,+$('#pr_e').value||8)),starts_at:start.toISOString(),ends_at:end?end.toISOString():null};
   if(isNew)await q(sb.from('promos').insert(row));else await q(sb.from('promos').update(row).eq('id',p.id));
   closeSheet();PROMOS.at=0;toast(isNew?'რეკლამა გაეშვა':'შენახულია');ADM.tab='promo';ADM.pt='mine';if(S.page&&S.page.id==='admin'){drawAdTabs();adminTab()}else openPage('admin','promo')}
  catch(x){toast(errMsg(x));ok.disabled=false}}}

/* ---------- a notification to everyone ---------- */
const AUD_L={all:'ყველას',active:'აქტიურებს (7 დღე)',region:'კუთხეს',verified:'ვერიფიცირებულებს',me:'მხოლოდ მე'};
async function admNotify(el){el.innerHTML=`<form class="form adnf" id="anf"><p class="note">მივა შეტყობინებებში და ტელეფონზე (push), ვისაც ჩართული აქვს. ნებისმიერს შეუძლია ეს ტიპი გამორთოს შეტყობინებების პარამეტრებში („სიახლეები და რეკლამა“), ამიტომ იყოს იშვიათი და საინტერესო.</p>
 <label class="fld">ტექსტი<textarea id="an_t" maxlength="200" rows="3" placeholder="მაგ. სუფრაზე ახალი სამზარეულოა: ქართული რეცეპტები და კერძი ნაბიჯ-ნაბიჯ 🍲"></textarea><small class="cnt" id="an_c">0 / 200</small></label>
 <label class="fld">ბმული (არასავალდებულო)<input id="an_l" maxlength="300" placeholder="https://… ან საიტის გვერდი ქვემოთ"></label>
 <div class="chips prlinks">${PRLINKS.map(([h,l])=>`<button type="button" class="chip" data-l="${h}">${l}</button>`).join('')}</div>
 <label class="fld">ვის მიუვიდეს<select id="an_a">${Object.entries(AUD_L).map(([k,l])=>`<option value="${k}">${l}</option>`).join('')}</select></label>
 <label class="fld" id="an_rw" hidden>კუთხე<select id="an_r">${REGIONS.map(r=>`<option>${esc(r)}</option>`).join('')}</select></label>
 <p class="anest" id="an_n"><span class="spin"></span></p>
 <div class="row2"><button type="button" class="btn ghost" id="an_test">${ic('bell')}ტესტი ჩემთვის</button><span class="sp"></span><button class="btn" id="an_go">${ic('send')}გაგზავნა</button></div></form>
 <h3 class="sec2">გაგზავნილი</h3><div id="anh">${skel(2)}</div>`;
 const aud=()=>$('#an_a').value,reg=()=>aud()==='region'?$('#an_r').value:null;let n=0,tk=0;
 const est=async()=>{const my=++tk;$('#an_rw').hidden=aud()!=='region';try{n=await rpc('admin_broadcast',{p_text:'..',p_link:null,p_aud:aud(),p_region:reg(),p_dry:true});if(my===tk&&$('#an_n'))$('#an_n').innerHTML=`${ic('users')} მიიღებს <b>${n}</b> ადამიანი`}catch(e){if($('#an_n'))$('#an_n').textContent=errMsg(e)}};
 $('#an_t').oninput=()=>{$('#an_c').textContent=$('#an_t').value.length+' / 200'};$('#an_a').onchange=est;$('#an_r').onchange=est;$$('#anf .prlinks [data-l]').forEach(b=>b.onclick=()=>{$('#an_l').value=b.dataset.l});
 const send=async(a)=>{const t=$('#an_t').value.trim(),l=$('#an_l').value.trim();if(t.length<2){toast('დაწერე ტექსტი');return}if(!linkOk(l)){toast('ბმული https://-ით ან #-ით უნდა იწყებოდეს');return}
  try{const k=await rpc('admin_broadcast',{p_text:t,p_link:l||null,p_aud:a,p_region:a==='region'?$('#an_r').value:null,p_dry:false});toast(a==='me'?'ტესტი გამოგეგზავნა. ნახე შეტყობინებებში':`გაეგზავნა ${k} ადამიანს`);if(a!=='me'){$('#an_t').value='';$('#an_l').value=''}admNotifyHist()}catch(e){toast(errMsg(e))}};
 $('#an_test').onclick=()=>send('me');
 $('#anf').onsubmit=e=>{e.preventDefault();const t=$('#an_t').value.trim();if(t.length<2){toast('დაწერე ტექსტი');return}const a=aud();if(a==='me'){send('me');return}
  confirmSheet('შეტყობინების გაგზავნა',`„${esc(t.slice(0,80))}“ მიუვა ${n} ადამიანს (${esc(a==='region'?$('#an_r').value:AUD_L[a])}). გაგზავნილს უკან ვეღარ დააბრუნებ.`,'გაგზავნა',()=>send(a),false)};
 est();admNotifyHist()}
async function admNotifyHist(){const el=$('#anh');if(!el)return;try{const rows=await q(sb.from('broadcasts').select('id,sent_by,text,link,audience,sent,created_at').order('created_at',{ascending:false}).limit(30));await loadProfiles(rows.map(r=>r.sent_by));if(!el.isConnected)return;
 el.innerHTML=rows.length?`<div class="list">${rows.map(r=>{const a=r.audience||{};return `<div class="row bcrow"><span class="nsic">${ic(a.aud==='me'?'eye':'bell')}</span><span class="grow"><span>${esc(r.text)}</span><span class="sub">${esc(a.aud==='region'?a.region:AUD_L[a.aud]||'')} · ${r.sent} ადამიანი · ${ago(r.created_at)}${r.sent_by?' · '+esc(pname(r.sent_by)):''}</span></span></div>`}).join('')}</div>`:'<p class="note" style="padding:0 16px">ჯერ არაფერი გაგზავნილა.</p>'}catch(e){el.innerHTML=`<p class="note">${esc(errMsg(e))}</p>`}}

/* ---------- the site: a banner and sections switched on or off ---------- */
async function admSite(el){let rows=[];try{rows=await q(sb.from('app_settings').select('key,value,updated_at,updated_by'))}catch(e){}if(!el.isConnected)return;
 const m=Object.fromEntries(rows.map(r=>[r.key,r.value])),b=Object.assign({on:false,text:'',link:'',tone:'info',cta:''},m.banner||{}),off=new Set((m.features&&m.features.off)||[]);
 el.innerHTML=`<section class="tourcard adsite"><h3>ბანერი ყველასთვის</h3><p class="note">ჩანს მთავარი გვერდის თავში. ვინც დახურავს, იმავე ტექსტს აღარ დაინახავს. ახალი ტექსტი ყველას ისევ გამოუჩნდება.</p>
  <div class="setrow"><div class="grow"><span>ბანერი ჩართულია</span></div><button type="button" class="switch" role="switch" id="bn_on" aria-checked="${!!b.on}" aria-label="ბანერი ჩართულია"></button></div>
  <label class="fld">ტექსტი<textarea id="bn_t" maxlength="160" rows="2" placeholder="მაგ. შაბათს 12:00-დან სუფრაზე დიდი ონლაინ ჯოკერის ტურნირია 🃏">${esc(b.text||'')}</textarea></label>
  <div class="seg flat" role="group" aria-label="ბანერის სახე" id="bn_tone">${[['info','სიახლე'],['warn','გაფრთხილება'],['fest','დღესასწაული']].map(([k,l])=>`<button type="button" data-k="${k}" aria-pressed="${(b.tone||'info')===k}">${l}</button>`).join('')}</div>
  <div class="frow"><label class="fld">ბმული<input id="bn_l" maxlength="300" value="${esc(b.link||'')}" placeholder="#recipes ან https://…"></label><label class="fld">ღილაკი<input id="bn_c" maxlength="24" value="${esc(b.cta||'')}" placeholder="ნახვა"></label></div>
  <div id="bn_pv" class="bnpv"></div><button class="btn" id="bn_save">${ic('check')}ბანერის შენახვა</button></section>
 <section class="tourcard adsite"><h3>განყოფილებები</h3><p class="note">გამორთული განყოფილება მომხმარებლებს მენიუდან ქრება, მისი გვერდები კი „დროებით გამორთულია“-ს აჩვენებს. შენ, როგორც ადმინისტრატორი, ყველაფერს მაინც ხედავ.</p>
  <div class="feats">${FEATS.map(([k,l])=>`<div class="setrow"><div class="grow"><span>${esc(l)}</span></div><button type="button" class="switch" role="switch" data-a="adfeat" data-k="${k}" aria-checked="${!off.has(k)}" aria-label="${esc(l)}"></button></div>`).join('')}</div></section>`;
 let tone=b.tone||'info';
 const pv=()=>{const t=$('#bn_t').value.trim();$('#bn_pv').innerHTML=t?`<div class="annc t-${tone}"><span class="anic">${ic(tone==='warn'?'flag':tone==='fest'?'gift':'mega')}</span><span class="grow">${esc(t)}</span>${$('#bn_l').value.trim()?`<span class="btn sm">${esc($('#bn_c').value.trim()||'ნახვა')}</span>`:''}</div>`:''};
 $('#bn_on').onclick=e=>{const s=e.currentTarget;s.setAttribute('aria-checked',String(s.getAttribute('aria-checked')!=='true'))};
 $$('#bn_tone button').forEach(x=>x.onclick=()=>{tone=x.dataset.k;$$('#bn_tone button').forEach(y=>y.setAttribute('aria-pressed',String(y===x)));pv()});
 ['bn_t','bn_l','bn_c'].forEach(id=>{$('#'+id).oninput=pv});pv();
 $('#bn_save').onclick=async()=>{const v={on:$('#bn_on').getAttribute('aria-checked')==='true',text:$('#bn_t').value.trim(),link:$('#bn_l').value.trim(),cta:$('#bn_c').value.trim(),tone};
  if(v.on&&v.text.length<2){toast('დაწერე ბანერის ტექსტი');return}if(!linkOk(v.link)){toast('ბმული https://-ით ან #-ით უნდა იწყებოდეს');return}
  try{await q(sb.from('app_settings').upsert({key:'banner',value:v},{onConflict:'key'}));APPSET.banner=v;try{localStorage.removeItem('annc')}catch(e){}toast(v.on?'ბანერი ჩანს ყველასთვის':'ბანერი გამოირთო')}catch(e){toast(errMsg(e))}}}
A.adfeat=async t=>{const on=t.getAttribute('aria-checked')!=='true';t.setAttribute('aria-checked',String(on));const off=$$('[data-a="adfeat"]').filter(x=>x.getAttribute('aria-checked')!=='true').map(x=>x.dataset.k);
 try{await q(sb.from('app_settings').upsert({key:'features',value:{off}},{onConflict:'key'}));APPSET.features={off};applyAppSettings();const l=(FEATS.find(f=>f[0]===t.dataset.k)||[])[1];toast(`${l}: ${on?'ჩართულია':'გამორთულია ყველასთვის'}`)}catch(e){t.setAttribute('aria-checked',String(!on));toast(errMsg(e))}};

/* ---------- the log: who from the team did what ---------- */
const LOG_L={ban:'შეზღუდა',unban:'შეზღუდვა მოუხსნა',role:'როლი შეცვალა',verify:'ვერიფიკაცია დაუდასტურა',unverify:'ვერიფიკაცია მოუხსნა',hide:'დამალა',unhide:'ისევ გამოაჩინა',delete:'წაშალა',coins:'მონეტები',message:'მისწერა გუნდის სახელით',broadcast:'შეტყობინება გაგზავნა',settings:'შეცვალა საიტის პარამეტრები',promo_new:'შექმნა რეკლამა',promo_on:'გაუშვა რეკლამა',promo_off:'დააპაუზა რეკლამა',promo_del:'წაშალა რეკლამა'};
const LOG_T={posts:'პოსტი',comments:'კომენტარი',stories:'ისტორია',groups:'ჯგუფი',pages:'გვერდი',events:'ღონისძიება',listings:'განცხადება',recipes:'რეცეპტი',jobs:'ვაკანსია',places:'ადგილი',toasts:'სადღეგრძელო',help_requests:'დახმარება',albums:'ალბომი',rides:'მგზავრობა'};
const isUid=x=>/^[0-9a-f-]{36}$/.test(String(x||''));
async function admLog(el){const rows=await q(sb.from('admin_log').select('id,actor,action,target,detail,created_at').order('created_at',{ascending:false}).limit(100));
 await loadProfiles(rows.flatMap(r=>[r.actor,isUid(r.target)?r.target:null,r.detail&&isUid(r.detail.owner)?r.detail.owner:null]).filter(Boolean));if(!el.isConnected)return;
 el.innerHTML=rows.length?`<p class="hint" style="padding:12px 16px 0">ბოლო 100 მოქმედება. ჟურნალს ვერავინ შეცვლის, მას ბაზა თავად წერს.</p><div class="list adlog">${rows.map(logRow).join('')}</div>`:empty('ჟურნალი ცარიელია','აქ ჩაიწერება გუნდის ყველა მნიშვნელოვანი მოქმედება.')}
function logRow(r){const d=r.detail||{},who=r.actor?pname(r.actor):'სისტემა',what=LOG_L[r.action]||r.action,tg=String(r.target||'');let obj='';
 if(r.action==='delete'){const t=tg.split(':')[0];obj=`${LOG_T[t]||t}${d.owner&&isUid(d.owner)?' · '+pname(d.owner):''}${d.text?' · „'+String(d.text).slice(0,60)+'“':''}`}
 else if(r.action==='hide'||r.action==='unhide'){const[t,id]=tg.split(':');obj=`${TTYPE[t]||t} #${id}`}
 else if(r.action==='coins')obj=`${pname(tg)} · ${d.amount>0?'+':''}${d.amount}${d.note?' · '+d.note:''}`;
 else if(r.action==='message')obj=`${pname(tg)} · „${String(d.text||'').slice(0,60)}“`;
 else if(r.action==='broadcast')obj=`„${String(d.text||'').slice(0,60)}“ · ${d.sent||0} ადამიანს`;
 else if(r.action==='role')obj=`${d.name||pname(tg)} · ${ROLE_L[d.from]||d.from} → ${ROLE_L[d.to]||d.to}`;
 else if(r.action==='settings')obj=tg==='banner'?'ბანერი':tg==='features'?'განყოფილებები':tg;
 else if(r.action.startsWith('promo'))obj=d.title?`„${String(d.title).slice(0,50)}“`:'';
 else if(isUid(tg))obj=d.name||pname(tg);
 return `<div class="row lgrow">${r.actor?av(r.actor,36):'<span class="av" style="--s:36px;--h:330" aria-hidden="true">ს</span>'}<span class="grow"><span><b>${esc(who)}</b> ${esc(what)}${obj?': '+esc(obj):''}</span><span class="sub">${ago(r.created_at)}</span></span></div>`}
