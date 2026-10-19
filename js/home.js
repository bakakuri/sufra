/* home feed, reminders, trends, search, hashtags, saved, single post */
const SHORT=[['rooms','wine','სუფრა'],['places','map','ადგილები'],['sport','trophy','მატჩები'],['help','help','დახმარება'],['toasts','book','სადღეგრძელოები'],['events','cal','ღონისძიებები'],['groups','users','ჯგუფები'],['rides','pin','ერთად წავიდეთ'],['jobs','school','ვაკანსიები'],['market','store','ბაზრობა'],['pages','mega','არხები'],['friends','user','მეგობრები'],['calendar','gift','კალენდარი']];
const FEED={done:false,loading:false,cursor:null,ads:[],adsShown:new Set(),count:0,seen:new Set()};
/* a post and its plain reposts show once in the feed */
const feedKey=p=>p.repost_of&&!String(p.body||'').trim()?p.repost_of:p.id;
const score=p=>{const s=STAT.get(p.id)||blankStat(p.id),h=(Date.now()-new Date(p.created_at).getTime())/36e5;return (1+rTotal(s)+s.comments*2+s.grade_n+(FRIENDS.has(p.author)?3:0)+(p.author===ME.id?1:0))/Math.pow(h+2,1.3)};
const firstName=()=>esc(String(ME.name||'').split(' ')[0]);
R.home=()=>{
 view.innerHTML=`<div class="stories" id="stories" role="list">${'<span class="story sk" aria-hidden="true"><span class="ring seen"><span class="av" style="--s:58px"></span></span><span></span></span>'.repeat(5)}</div>
 <nav class="shortcuts" aria-label="სერვისები">${SHORT.map(([p,i,l])=>`<button class="sc" data-a="page" data-p="${p}">${ic(i)}${l}</button>`).join('')}</nav>
 <div id="fsteps"></div><div id="remind"></div><div id="memo"></div><div id="trends"></div>
 <button class="compose cbtn" data-a="compose">${av('me')}<span class="cph">რა ხდება, ${firstName()}?</span><span class="cq" aria-hidden="true">${ic('image')}${ic('poll')}</span></button>
 <div class="seg feedsw" role="group" aria-label="ფიდის რეჟიმი">${[['for','შენთვის'],['friends','მეგობრები'],['new','ახალი']].map(([k,l])=>`<button data-a="feed" data-f="${k}" aria-pressed="${S.feed===k}">${l}</button>`).join('')}</div>
 <div id="feed">${skel(3)}</div><div id="more" class="morebox" aria-live="polite"></div>`;
 loadStories();loadFirstSteps();loadRemind();loadMemories();loadTrends();loadFeed(true);
 const io=new IntersectionObserver(es=>{if(es.some(e=>e.isIntersecting))loadFeed(false)},{root:view,rootMargin:'600px'});io.observe($('#more'))};
A.feed=t=>{S.feed=t.dataset.f;$$('.feedsw button').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));$('#feed').innerHTML=skel(3);loadFeed(true)};
async function loadAds(){try{const ads=await q(sb.from('ads').select('id,post_id').eq('status','active').limit(6));if(!ads.length)return [];const rows=await fetchPosts(b=>b.in('id',ads.map(a=>a.post_id)));return rows.map(p=>Object.assign(p,{ad:ads.find(a=>a.post_id===p.id).id}))}catch(e){return []}}
async function loadFeed(reset){if(reset){FEED.done=false;FEED.cursor=null;FEED.count=0;FEED.seen=new Set()}if(FEED.loading||FEED.done)return;FEED.loading=true;const mode=S.feed,lim=mode==='for'?30:20,my=++FEED.tok;
 const more=$('#more');if(more&&!reset)more.innerHTML='<span class="spin" aria-label="იტვირთება"></span>';
 try{let rows=await fetchPosts(b=>{b=b.is('group_id',null).eq('hidden',false).order('created_at',{ascending:false}).limit(lim);if(FEED.cursor)b=b.lt('created_at',FEED.cursor);if(mode==='friends')b=b.in('author',[ME.id,...FRIENDS]);return b});
  if(my!==FEED.tok)return;
  if(rows.length)FEED.cursor=rows[rows.length-1].created_at;if(rows.length<lim)FEED.done=true;
  rows=rows.filter(p=>!LOCALHIDE[p.id]&&!LOCALHIDE[feedKey(p)]&&!(p.repost_of&&!p.body&&!POSTS.has(p.repost_of))).filter(p=>{const k=feedKey(p);if(FEED.seen.has(k))return false;FEED.seen.add(k);return true});if(mode==='for')rows.sort((a,b)=>score(b)-score(a));
  if(reset&&mode!=='friends')FEED.ads=await loadAds();
  const feed=$('#feed');if(!feed)return;let html='';
  rows.forEach(p=>{FEED.count++;html+=postHTML(p);if(FEED.count%6===0&&FEED.ads.length){const ad=FEED.ads.shift();html+=postHTML(ad);if(!FEED.adsShown.has(ad.ad)){FEED.adsShown.add(ad.ad);sb.rpc('ad_impression',{p_ad:ad.ad}).then(()=>{})}}if(reset&&FEED.count===2)html+='<div id="sugg"></div>'});
  if(reset){feed.innerHTML=html||empty(mode==='friends'?'მეგობრების პოსტები ჯერ არ არის':'სუფრა ჯერ ცარიელია',mode==='friends'?'დაამატე მეგობრები და მათი პოსტები აქ გამოჩნდება.':'დაწერე პირველი პოსტი ან მოიწვიე მეგობრები.',`<div class="row2"><button class="btn" data-a="compose">პოსტის დაწერა</button><button class="btn ghost" data-a="invite">მეგობრის მოწვევა</button></div>`);staggerIn($$('.post',feed).slice(0,6));loadSuggest()}
  else feed.insertAdjacentHTML('beforeend',html);
  if(more)more.innerHTML=FEED.done&&FEED.count?'<span class="note">ყველაფერი ნახე</span>':''}
 catch(e){const f=$('#feed');if(f&&reset)f.innerHTML=empty('ფიდი ვერ ჩაიტვირთა',errMsg(e),'<button class="btn" data-a="reload">თავიდან ცდა</button>')}
 finally{FEED.loading=false}}
FEED.tok=0;
A.reload=()=>go(S.tab);
A.invite=()=>shareLink(location.origin,'შემოდი სუფრაზე');
async function loadSuggest(){const el=$('#sugg');if(!el)return;try{const s=await rpc('friend_suggestions',{p_limit:10});if(!s.length){el.remove();return}s.forEach(p=>PC.set(p.id,Object.assign(PC.get(p.id)||{},p)));
 el.outerHTML=`<section class="suggest"><div class="shead"><h3>შეიძლება იცნობდე</h3><button class="trb" data-a="page" data-p="friends">ყველა</button></div><div class="hscroll">${s.map(p=>`<div class="pcard2"><button data-a="user" data-u="${p.id}" class="pc2">${av(p,64)}<b>${esc(p.name)}${vb(p)}</b><span>${p.mutual?p.mutual+' საერთო მეგობარი':esc(p.city||'სუფრაზეა')}</span></button><button class="btn sm" data-a="addfriend" data-u="${p.id}">დამატება</button></div>`).join('')}</div></section>`}catch(e){el.remove()}}
async function loadTrends(){const el=$('#trends');if(!el)return;try{const t=await rpc('trending_tags',{p_limit:8});if(!t.length)return;el.innerHTML=`<div class="trends"><span class="eyebrow">ტრენდები</span>${t.map(x=>`<button class="tchip" data-a="tag" data-t="${esc(x.tag)}">#${esc(x.tag)} <em>${x.uses}</em></button>`).join('')}</div>`}catch(e){}}

/* friends' birthdays and name days */
async function upcoming(days){const now=new Date();now.setHours(0,0,0,0);const out=[];let bd=[];try{bd=await rpc('friend_birthdays')}catch(e){}
 const add=(p,m,d,kind,label)=>{let dt=new Date(now.getFullYear(),m-1,d);if(dt<now)dt=new Date(now.getFullYear()+1,m-1,d);const n=Math.round((dt-now)/864e5);if(n<=days)out.push({p,n,dt,kind,label})};
 bd.forEach(p=>{PC.set(p.id,Object.assign(PC.get(p.id)||{},{id:p.id,name:p.name,hue:p.hue,avatar_url:p.avatar_url}));add(p,p.month,p.day,'b','დაბადების დღე')});
 for(const id of FRIENDS){const p=prof(id);for(const[md,f]of nameDaysOf(p)){const[m,d]=md.split('-').map(Number);add(p,m,d,'n',f)}}
 return out.sort((a,b)=>a.n-b.n)}
const whenTxt=n=>n===0?'დღეს':n===1?'ხვალ':n+' დღეში';
const remRow=e=>`<div class="rrow">${av(e.p,40)}<div class="grow"><span class="when">${whenTxt(e.n)} · ${e.dt.getDate()} ${MONTHS[e.dt.getMonth()]}</span><b>${esc(e.p.name)} · ${e.kind==='b'?'დაბადების დღე':'ანგელოზის დღე, '+e.label}</b></div><button class="btn ghost" data-a="greet" data-u="${e.p.id}" data-k="${e.kind}">მილოცვა</button><button class="btn ghost" data-a="gift" data-u="${e.p.id}" aria-label="საჩუქრის გაგზავნა">${ic('gift')}</button></div>`;
async function loadRemind(){const el=$('#remind');if(!el||!FRIENDS.size)return;const u=(await upcoming(14)).slice(0,3);if(!u.length||!$('#remind'))return;
 el.innerHTML=`<section class="remind"><div class="shead" style="padding:0"><h3>არ დაგავიწყდეს</h3><button class="trb" data-a="page" data-p="calendar">კალენდარი</button></div>${u.map(remRow).join('')}</section>`}
A.greet=t=>openCardPicker({uid:t.dataset.u,kind:t.dataset.k==='b'?'b':'n'});
PG.calendar={r(){view.innerHTML=pgHead('კალენდარი',`<button class="btn sm ghost" data-a="page" data-p="namedays">${ic('cal')}სახელის დღეები</button>`)+`<p class="hint" style="padding:12px 16px 0">მეგობრების დაბადების დღეები და ანგელოზის დღეები მომდევნო 4 თვეში.</p><div id="calb">${skel(3)}</div>`;
 upcoming(120).then(u=>{let html='',m=-1;for(const e of u){if(e.dt.getMonth()!==m){m=e.dt.getMonth();html+=`<h3 class="sec2">${MONTHS[m]}</h3>`}html+=`<div class="list">${remRow(e)}</div>`}
  const el=$('#calb');if(el)el.innerHTML=html||empty('ჯერ ცარიელია','დაამატე მეგობრები და მათი თარიღები აქ გამოჩნდება.','<button class="btn" data-a="page" data-p="friends">მეგობრების პოვნა</button>')})}};

/* search, hashtags, saved, single post */
const clean=s=>String(s||'').replace(/[,()%*\\"]/g,' ').trim().slice(0,60);
PG.search={r(qs){S.stab=S.stab||'all';view.innerHTML=pgHead('ძიება')+`<form class="search" id="sf" role="search"><input class="field" id="sq" type="search" placeholder="ადამიანები, პოსტები, #ჰეშთეგები" value="${esc(qs||'')}" aria-label="ძიება" autocomplete="off"></form>
 <div class="chipsbar" role="group" aria-label="რას ეძებ">${[['all','ყველა'],['people','ადამიანები'],['posts','პოსტები'],['pages','გვერდები'],['groups','ჯგუფები']].map(([k,l])=>`<button data-a="stab" data-k="${k}" aria-pressed="${S.stab===k}">${l}</button>`).join('')}</div><div id="sres"></div>`;
 const run=()=>searchRun($('#sq').value);$('#sf').onsubmit=e=>{e.preventDefault();run()};$('#sq').oninput=()=>{clearTimeout(S.st);S.st=setTimeout(run,350)};run();setTimeout(()=>$('#sq')?.focus(),300)}};
A.stab=t=>{S.stab=t.dataset.k;$$('[data-a="stab"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)));searchRun($('#sq').value)};
async function searchRun(raw){const el=$('#sres');if(!el)return;const qv=clean(raw),k=S.stab,tok=++S.stok;
 if(!qv){el.innerHTML=skel(2);try{const[t,s]=await Promise.all([rpc('trending_tags',{p_limit:12}),rpc('friend_suggestions',{p_limit:8})]);if(tok!==S.stok)return;s.forEach(p=>PC.set(p.id,Object.assign(PC.get(p.id)||{},p)));
  el.innerHTML=(t.length?`<h3 class="sec2">ტრენდები</h3><div class="trends" style="padding:0 16px">${t.map(x=>`<button class="tchip" data-a="tag" data-t="${esc(x.tag)}">#${esc(x.tag)} <em>${x.uses}</em></button>`).join('')}</div>`:'')+(s.length?`<h3 class="sec2">შეიძლება იცნობდე</h3><div class="list">${s.map(personRow).join('')}</div>`:'')||empty('დაიწყე წერა','მოძებნე ადამიანები, პოსტები ან #ჰეშთეგები.')}catch(e){el.innerHTML=''}return}
 if(qv.startsWith('#')){const tag=qv.slice(1).toLowerCase();el.innerHTML=`<div class="list"><button class="row" data-a="tag" data-t="${esc(tag)}"><span class="av" style="--s:44px;--h:330">#</span><span class="grow"><b>#${esc(tag)}</b><span class="sub">ნახე ყველა პოსტი ამ ჰეშთეგით</span></span></button></div>`;return}
 el.innerHTML=skel(3);const like=`%${qv}%`,out=[];
 try{if(k==='all'||k==='people'){const ps=await q(sb.from('profiles').select(PCOLS).or(`name.ilike.${like},username.ilike.${like}`).eq('onboarded',true).limit(k==='all'?5:30));ps.forEach(p=>PC.set(p.id,p));if(ps.length)out.push(`<h3 class="sec2">ადამიანები</h3><div class="list">${ps.map(personRow).join('')}</div>`)}
  if(k==='all'||k==='pages'){const pg=await q(sb.from('pages').select('id,name,kind,hue,verified,category').ilike('name',like).limit(k==='all'?4:30));if(pg.length)out.push(`<h3 class="sec2">გვერდები და არხები</h3><div class="list">${pg.map(pageRow).join('')}</div>`)}
  if(k==='all'||k==='groups'){const gs=await q(sb.from('groups').select('id,name,hue,is_private,description').ilike('name',like).limit(k==='all'?4:30));if(gs.length)out.push(`<h3 class="sec2">ჯგუფები</h3><div class="list">${gs.map(groupRow).join('')}</div>`)}
  let posts=[];if(k==='all'||k==='posts'){posts=await fetchPosts(b=>b.ilike('body',like).order('created_at',{ascending:false}).limit(20));if(posts.length)out.push(`<h3 class="sec2">პოსტები</h3><div>${posts.map(postHTML).join('')}</div>`)}
  if(tok!==S.stok)return;el.innerHTML=out.join('')||empty('ვერაფერი მოიძებნა','სცადე სხვა სიტყვით.');staggerIn($$('.row,.post',el).slice(0,8))}
 catch(e){el.innerHTML=empty('ძიება ვერ მოხერხდა',errMsg(e))}}
S.stok=0;
const personRow=p=>`<button class="row" data-a="user" data-u="${p.id}">${av(p,44)}<span class="grow"><b>${esc(p.name)}${vb(p)}</b><span class="sub">${p.username?'@'+esc(p.username)+' · ':''}${p.mutual?p.mutual+' საერთო მეგობარი':esc(p.city||'')}</span></span>${isOnline(p.id)?'<i class="ond" aria-label="ონლაინ"></i>':''}</button>`;
const pageRow=g=>`<button class="row" data-a="pagev" data-id="${g.id}">${avAny({n:g.name,h:g.hue},44).replace('class="av"','class="av sq"')}<span class="grow"><b>${esc(g.name)}${g.verified?vb({verified:1}):''}</b><span class="sub">${g.kind==='business'?'ბიზნესი':'არხი'}${g.category?' · '+esc(g.category):''}</span></span></button>`;
const groupRow=g=>`<button class="row" data-a="group" data-id="${g.id}">${avAny({n:g.name,h:g.hue},44).replace('class="av"','class="av sq"')}<span class="grow"><b>${esc(g.name)}</b><span class="sub">${g.is_private?'დახურული ჯგუფი':'ღია ჯგუფი'}${g.description?' · '+esc(g.description.slice(0,60)):''}</span></span></button>`;
A.search=()=>openPage('search','');
PG.tag={r(tag){view.innerHTML=pgHead('#'+esc(tag),`<button class="btn sm" data-a="composetag" data-t="${esc(tag)}">${ic('plus')}პოსტი</button>`)+`<div id="tagb">${skel(3)}</div>`;
 fetchPosts(b=>b.contains('tags',[tag]).order('created_at',{ascending:false}).limit(40)).then(rows=>{const el=$('#tagb');if(el){el.innerHTML=`<p class="hint" style="padding:12px 16px 4px">${rows.length} პოსტი</p>`+(rows.map(postHTML).join('')||empty('ჯერ არავის დაუწერია','იყავი პირველი ამ ჰეშთეგით.'));staggerIn($$('.post',el).slice(0,6))}}).catch(e=>{const el=$('#tagb');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))})}};
A.composetag=async t=>{await compose();const ta=$('#ct');if(ta){ta.value=' #'+t.dataset.t;ta.oninput&&ta.oninput();ta.focus();ta.setSelectionRange(0,0)}};
PG.saved={r(){view.innerHTML=pgHead('შენახული')+`<div id="savb">${skel(3)}</div>`;
 q(sb.from('saves').select('post_id').eq('user_id',ME.id).order('created_at',{ascending:false}).limit(60)).then(async s=>{const ids=s.map(x=>x.post_id);const rows=ids.length?await fetchPosts(b=>b.in('id',ids)):[];rows.sort((a,b)=>ids.indexOf(a.id)-ids.indexOf(b.id));const el=$('#savb');if(el)el.innerHTML=rows.map(postHTML).join('')||empty('შენახული ჯერ არაფერია','პოსტთან სანიშნეს დააჭირე და აქ გამოჩნდება.')}).catch(e=>{const el=$('#savb');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))})}};
PG.post={r(id){id=+id;view.innerHTML=pgHead('პოსტი')+`<div id="postb">${skel(1)}</div>`;
 fetchPosts(b=>b.eq('id',id)).then(rows=>{const el=$('#postb');if(!el)return;if(!rows.length){el.innerHTML=empty('პოსტი ვერ მოიძებნა','შეიძლება წაშლილია ან დამალული.');return}el.innerHTML=postHTML(rows[0])+`<div style="padding:12px 16px"><button class="btn ghost" data-a="comments" data-pid="${id}">${ic('comment')}კომენტარების ნახვა</button></div>`;if(S.openComments){S.openComments=0;openComments(id)}}).catch(e=>{const el=$('#postb');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))})}};

/* "on this day" memories */
async function loadMemories(){const el=$('#memo');if(!el)return;try{const ids=await rpc('my_memories');if(!ids.length||!$('#memo'))return;const rows=await fetchPosts(b=>b.in('id',ids.slice(0,1)));if(!rows.length)return;const p=rows[0],yrs=new Date().getFullYear()-new Date(p.created_at).getFullYear();
 el.innerHTML=`<section class="memo"><div class="shead" style="padding:0"><h3>ამ დღეს, ${yrs} წლის წინ</h3>${ids.length>1?`<button class="trb" data-a="page" data-p="memories">ყველა · ${ids.length}</button>`:''}</div><div class="memo-in">${postHTML(p)}</div><div class="row2" style="justify-content:flex-start"><button class="btn sm ghost" data-a="sharememo" data-pid="${p.id}">${ic('repost')}მოგონების გაზიარება</button></div></section>`}catch(e){}}
A.sharememo=t=>{const p=POSTS.get(pidOf(t));if(!p)return;compose().then(()=>{const ta=$('#ct');if(ta){ta.value=`მოგონება ${new Date(p.created_at).getFullYear()} წლიდან 💭\n${location.origin}/#post-${p.id}`;ta.oninput&&ta.oninput()}})};
PG.memories={r(){view.innerHTML=pgHead('მოგონებები')+`<div id="memb">${skel(2)}</div>`;rpc('my_memories').then(async ids=>{const rows=ids.length?await fetchPosts(b=>b.in('id',ids)):[];const el=$('#memb');if(el)el.innerHTML=rows.map(p=>`<h3 class="sec2">${new Date(p.created_at).getFullYear()}</h3>`+postHTML(p)).join('')||empty('დღეს მოგონება არ არის')}).catch(e=>{const el=$('#memb');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))})}};

/* drafts and scheduled posts */
PG.drafts={r(){view.innerHTML=pgHead('დრაფტები და დაგეგმილი')+`<p class="hint" style="padding:12px 16px 0">დრაფტებს მხოლოდ შენ ხედავ. დაგეგმილი პოსტი თავისით გამოქვეყნდება მითითებულ დროს.</p><div id="drb">${skel(2)}</div>`;loadDrafts()}};
async function loadDrafts(){const el=$('#drb');if(!el)return;try{const rows=await hydrate(await q(sb.from('posts').select(POSTSEL).eq('author',ME.id).or(`draft.eq.true,created_at.gt.${new Date().toISOString()}`).order('created_at',{ascending:true}).limit(60)));if(!el.isConnected)return;
 el.innerHTML=rows.map(p=>`<div class="draftw" data-id="${p.id}"><div class="draftbar"><span class="ptag${p.draft?'':' ad'}">${p.draft?'დრაფტი':'დაგეგმილია · '+fdate(p.created_at)}</span><span class="sp"></span><button class="btn sm" data-a="dpub" data-pid="${p.id}">${ic('send')}ახლავე</button><button class="btn sm ghost" data-a="dplan" data-pid="${p.id}" aria-label="დროის შეცვლა">${ic('clock')}</button><button class="btn sm ghost" data-a="ddel" data-pid="${p.id}" aria-label="წაშლა">${ic('trash')}</button></div>${postHTML(p)}</div>`).join('')||empty('დრაფტები არ გაქვს','პოსტის წერისას დააჭირე საათის ღილაკს და შეინახე დრაფტად ან დაგეგმე.','<button class="btn" data-a="compose">პოსტის დაწერა</button>')}
 catch(e){el.innerHTML=empty('ვერ ჩაიტვირთა',errMsg(e))}}
A.dpub=async t=>{const id=+t.dataset.pid;t.disabled=true;try{await q(sb.from('posts').update({draft:false,publish_at:null}).eq('id',id));toast('გამოქვეყნდა');loadDrafts()}catch(e){toast(errMsg(e));t.disabled=false}};
A.ddel=t=>{const id=+t.dataset.pid;confirmSheet('წაშლა','დრაფტი წაიშლება.','წაშლა',async()=>{await q(sb.from('posts').delete().eq('id',id));loadDrafts()},true)};
A.dplan=t=>{const id=+t.dataset.pid,pad=n=>String(n).padStart(2,'0'),d=new Date(Date.now()+36e5),v=`${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
 sheet(head('გამოქვეყნების დრო')+`<div class="ph-body"><label class="fld">როდის<input type="datetime-local" id="dp_w" value="${v}"></label></div><div class="ph-foot"><span class="sp"></span><button class="btn" id="dp_ok">${ic('clock')}დაგეგმვა</button></div>`,'short');
 $('#dp_ok').onclick=async()=>{const w=new Date($('#dp_w').value);if(isNaN(w)||w<Date.now()+3e4){toast('აირჩიე მომავალი დრო');return}try{await q(sb.from('posts').update({draft:false,publish_at:w.toISOString()}).eq('id',id));closeSheet();toast('დაიგეგმა: '+fdate(w));loadDrafts()}catch(e){toast(errMsg(e))}}};
