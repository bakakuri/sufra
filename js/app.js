/* shell: top bar, tabs, create button, realtime, deep links, install, back button */
const TABS=[['home','მთავარი','home'],['clips','კლიპები','clips'],['date','გაცნობა','heart'],['games','თამაშები','dice'],['me','პროფილი','user']];
const SVC=[['rooms','wine','ვირტუალური სუფრა'],['rooms','mic','ბირჟა','birja'],['rooms','live','ლაივი','live'],['places','map','ადგილები'],['sport','trophy','მატჩის ოთახი'],['help','help','დახმარება'],['rides','pin','ერთად წავიდეთ'],['jobs','school','ვაკანსიები და CV'],['friends','users','მეგობრები'],['groups','users','ჯგუფები'],['pages','mega','არხები და გვერდები'],['events','cal','ღონისძიებები'],['albums','image','ალბომები'],['market','store','ბაზრობა'],['toasts','book','სადღეგრძელოები'],['namedays','cal','სახელის დღეები'],['tree','tree','ოჯახის ხე'],['calendar','gift','კალენდარი'],['tour','trophy','ტურნირი'],['saved','bookmark','შენახული'],['drafts','clock','დრაფტები'],['coins','coin','მონეტები'],['verify','shield','ვერიფიკაცია'],['settings','gear','პარამეტრები']];
const today=()=>new Date().toISOString().slice(0,10);

function renderTop(){if(!ME)return;$('#top').innerHTML=`<button class="logo" data-a="home" aria-label="სუფრა, მთავარზე დაბრუნება">სუფრა</button><span class="sp"></span>
 <button class="coinchip${ME.last_bonus===today()?'':' bonus'}" data-a="page" data-p="coins" aria-label="მონეტები">${ic('coin')}<span id="coinv">${ME.coins??0}</span></button>
 <span class="hicons"><button class="ibtn" data-a="search" aria-label="ძიება">${ic('search')}</button>
 <button class="ibtn" data-a="chats" aria-label="მიმოწერა">${ic('msg')}<span class="dot" id="dm" hidden></span></button>
 <button class="ibtn" data-a="notifs" aria-label="შეტყობინებები">${ic('bell')}<span class="dot" id="dn" hidden></span></button>
 <button class="ibtn" data-a="page" data-p="friends" aria-label="მეგობრები">${ic('users')}<span class="dot" id="df" hidden></span></button>
 <button class="ibtn" data-a="guests" aria-label="სტუმრები">${ic('eye')}<span class="dot" id="dg" hidden></span></button>
 <button class="ibtn" data-a="menu" aria-label="სერვისები">${ic('grid')}</button></span>`;renderBadges()}
function renderTabs(){$('#tabs').innerHTML='<span class="tabind" aria-hidden="true"></span>'+TABS.map(([k,l,i])=>`<button class="tab" data-tab="${k}" aria-current="${k===S.tab}">${ic(i)}<span>${l}</span><i class="tdot" hidden></i></button>`).join('')}
function renderBadges(){const set=(id,n)=>{const d=$('#'+id);if(!d)return;const was=d.hidden?0:parseInt(d.textContent,10)||0;d.hidden=!n;d.textContent=n>99?'99+':String(n);if(n>was)pop(d)};
 set('dn',S.unreadNotes);set('dm',S.unreadMsgs);set('dn2',S.unreadNotes);set('dm2',S.unreadMsgs);set('df',typeof PENDING_IN!=='undefined'?PENDING_IN.size:0);set('dg',S.newGuests||0);
 const me=$('.tab[data-tab="me"] .tdot');if(me)me.hidden=!(typeof PENDING_IN!=='undefined'&&PENDING_IN.size);
 const tot=(S.unreadNotes||0)+(S.unreadMsgs||0);document.title=tot?`(${tot}) სუფრა`:'სუფრა';
 try{if(tot&&navigator.setAppBadge)navigator.setAppBadge(tot);else if(navigator.clearAppBadge)navigator.clearAppBadge()}catch(e){}}

/* tabs and pages */
function go(tab,dx){if(!R[tab])tab='home';const oi=TABS.findIndex(t=>t[0]===S.tab),ni=TABS.findIndex(t=>t[0]===tab),wasPage=!!S.page;
 closeSheet(true);closePV(true);stopMedia();S.page=null;S.tab=tab;$$('.tab').forEach(b=>b.setAttribute('aria-current',String(b.dataset.tab===tab)));moveInd(ni);
 const app=$('#app');app.classList.toggle('media',tab==='clips');app.classList.remove('barhidden');view.className=tab==='clips'?'is-clips':'';view.scrollTop=0;
 navStep();
 R[tab]();updateFab();markSide();
 const d=dx!=null?dx:(oi===ni&&!wasPage?0:Math.sign(ni-oi||1)*24);if(d)enterView(d)}
{const op=openPage;openPage=function(...a){closePV(true);const r=op.apply(this,a);updateFab();markSide();return r}}
function updateFab(){const f=$('#fab');if(f)f.hidden=document.body.classList.contains('wide')||!!S.page||!['home','me'].includes(S.tab)}
A.home=()=>{if(S.tab==='home'&&!S.page){view.scrollTo({top:0,behavior:RM()?'auto':'smooth'});return}go('home')};

/* services menu and the create sheet */
A.menu=()=>{navMark('menu',A.menu);const svc=[...SVC];if(isStaff())svc.push(['admin','shield','ადმინ პანელი']);
 const standalone=matchMedia('(display-mode: standalone)').matches||navigator.standalone;
 sheet(head('სერვისები')+`<div class="svc">${svc.map(([p,i,l,a])=>`<button data-a="page" data-p="${p}"${a?` data-arg="${a}"`:''}>${ic(i)}${l}</button>`).join('')}${standalone?'':`<button data-a="install">${ic('download')}აპად დაყენება</button>`}<button data-a="rules">${ic('flag')}წესები</button></div>`,'short')};
const CREATE=[['cpost','edit','პოსტი','ტექსტი, ფოტო, ჰეშთეგი'],['croom','wine','სუფრის გაშლა','ვიდეო, თამადა, სადღეგრძელოები'],['cbirja','mic','ბირჟა','ხმოვანი ოთახი თემაზე'],['cphoto','image','ფოტო','ფილტრით და ჭრით'],['cclip','clips','კლიპი','მოკლე ვერტიკალური ვიდეო'],['cpoll','poll','გამოკითხვა','მეგობრების აზრი'],['cstory','story','ისტორია','ქრება 24 საათში'],['cevent','cal','ღონისძიება','სუფრა, შეხვედრა, ქორწილი'],['clisting','store','განცხადება','გაყიდე ან გააჩუქე'],['cgroup','users','ჯგუფი','საერთო ინტერესით'],['cpage','mega','არხი ან გვერდი','ბიზნესი და რეკლამა'],['cgchat','msg','ჯგუფური ჩატი','რამდენიმე მეგობართან'],['clive','live','ლაივი','პირდაპირი ეთერი'],['cplace','map','ადგილი','რესტორანი, მარანი, სასტუმრო'],['chelp','help','დახმარების თხოვნა','სისხლი, ცხოველი, მოხალისე'],['ctoast','book','სადღეგრძელო','თამადის წიგნისთვის'],['cride','pin','მგზავრობა','ადგილები მანქანაში'],['cjob','school','ვაკანსია','მოძებნე თანამშრომელი']];
A.create=()=>(navMark('create',A.create),sheet(head('შექმნა')+`<div class="createg">${CREATE.map(([a,i,l,s])=>`<button data-a="${a}"><span class="cgi">${ic(i)}</span><b>${l}</b><small>${s}</small></button>`).join('')}</div>`,'short'));
A.cpost=()=>compose();
A.croom=()=>{S.rkind='supra';closeSheet();A.newroom()};
A.cbirja=()=>{S.rkind='birja';closeSheet();A.newroom()};
A.cride=()=>openPage('ridenew',undefined,['rides']);
A.clive=()=>{S.rkind='live';A.newroom()};
A.cplace=()=>openPage('placenew',undefined,['places']);
A.chelp=()=>openPage('helpnew',undefined,['help']);
A.ctoast=()=>A.newtoast();
A.cjob=()=>openPage('jobnew',undefined,['jobs']);
A.cphoto=async()=>{await compose();$('#c_img')?.click()};
A.cclip=()=>compose({clip:true});
A.cpoll=async()=>{await compose();$('#c_poll')?.click()};
A.cstory=()=>A.addstory();
A.cevent=()=>openPage('evnew',undefined,S.page?[S.page.id,S.page.arg]:null);
A.clisting=()=>openPage('mknew',undefined,['market']);
A.cgroup=()=>A.newgroup();
A.cpage=()=>A.newpage();
A.cgchat=()=>A.newgroupchat();

/* wide screens: navigation on the left, discovery on the right */
const WIDE=matchMedia('(min-width:1000px)');
function renderSide(){const on=WIDE.matches&&!!ME;document.body.classList.toggle('wide',on);if(!on){$('#sidel')?.remove();$('#sider')?.remove();return}
 let L=$('#sidel');if(!L){L=document.createElement('aside');L.id='sidel';L.className='side-l';L.setAttribute('aria-label','ნავიგაცია');document.body.appendChild(L)}
 L.innerHTML=`<button class="logo" data-a="home" aria-label="სუფრა">სუფრა</button><nav class="snavs">${TABS.map(([k,l,i])=>`<button class="snav" data-tab2="${k}">${ic(i)}<span>${l}</span></button>`).join('')}
  <button class="snav" data-a="chats">${ic('msg')}<span>მიმოწერა</span><i class="sdot" id="dm2" hidden></i></button><button class="snav" data-a="notifs">${ic('bell')}<span>შეტყობინებები</span><i class="sdot" id="dn2" hidden></i></button>
  <span class="snavsep"></span>${SVC.slice(0,8).map(([p,i,l,a])=>`<button class="snav sm" data-a="page" data-p="${p}"${a?` data-arg="${a}"`:''}>${ic(i)}<span>${l}</span></button>`).join('')}<button class="snav sm" data-a="menu">${ic('grid')}<span>ყველა სერვისი</span></button></nav>
  <button class="btn wide" data-a="create">${ic('plus')}შექმნა</button><button class="smine" data-tab2="me">${av('me',40)}<span class="grow"><b>${esc(ME.name)}</b><small>${ME.username?'@'+esc(ME.username):'პროფილი'}</small></span></button>`;
 let Rr=$('#sider');if(!Rr){Rr=document.createElement('aside');Rr.id='sider';Rr.className='side-r';Rr.setAttribute('aria-label','აღმოაჩინე');document.body.appendChild(Rr);loadSideR()}
 markSide();renderBadges()}
function markSide(){$$('#sidel [data-tab2]').forEach(b=>b.setAttribute('aria-current',String(!S.page&&b.dataset.tab2===S.tab)))}
async function loadSideR(){const el=$('#sider');if(!el)return;
 el.innerHTML=`<form class="ssearch" id="ssf" role="search">${ic('search')}<input id="ssq" type="search" placeholder="ძიება სუფრაზე" aria-label="ძიება"></form><section class="scard" id="sr_live"></section><section class="scard" id="sr_tr"></section><section class="scard" id="sr_sg"></section><section class="scard" id="sr_bd"></section><p class="sfoot"><button class="trb" data-a="rules">წესები</button> · <button class="trb" data-a="privacy">კონფიდენციალურობა</button> · სუფრა ${new Date().getFullYear()}</p>`;
 $('#ssf').onsubmit=e=>{e.preventDefault();openPage('search',$('#ssq').value.trim())};
 try{const[t,sg,rooms]=await Promise.all([rpc('trending_tags',{p_limit:8}),rpc('friend_suggestions',{p_limit:5}),q(sb.from('rooms').select('id,kind,title,host').eq('live',true).gt('created_at',new Date(Date.now()-12*36e5).toISOString()).order('created_at',{ascending:false}).limit(4))]);
  sg.forEach(p=>PC.set(p.id,Object.assign(PC.get(p.id)||{},p)));await loadProfiles(rooms.map(r=>r.host));
  const c=(id,h)=>{const x=$(id);if(x)x.innerHTML=h;if(x&&!h)x.remove()};
  c('#sr_live',rooms.length?`<h3>${ic('live')}ცოცხლად ახლა</h3>${rooms.map(r=>`<button class="srow" data-a="page" data-p="room" data-arg="${r.id}"><span class="rico ${r.kind}">${ic(rkIcon(r.kind))}</span><span class="grow"><b>${esc(r.title)}</b><small>${esc(pname(r.host))}</small></span></button>`).join('')}`:'');
  c('#sr_tr',t.length?`<h3>ტრენდები</h3>${t.map(x=>`<button class="srow" data-a="tag" data-t="${esc(x.tag)}"><span class="grow"><b>#${esc(x.tag)}</b><small>${x.uses} პოსტი</small></span></button>`).join('')}`:'');
  c('#sr_sg',sg.length?`<h3>შეიძლება იცნობდე</h3>${sg.map(p=>`<div class="srow"><button data-a="user" data-u="${p.id}">${av(p,36)}</button><button class="grow" data-a="user" data-u="${p.id}" style="text-align:left"><b>${esc(p.name)}</b><small>${p.mutual?p.mutual+' საერთო':esc(p.city||'')}</small></button><button class="btn sm" data-a="addfriend" data-u="${p.id}" aria-label="დამატება">${ic('plus')}</button></div>`).join('')}`:'');
  const bd=(await upcoming(7)).slice(0,4);c('#sr_bd',bd.length?`<h3>${ic('gift')}მალე</h3>${bd.map(e=>`<button class="srow" data-a="greet" data-u="${e.p.id}" data-k="${e.kind}">${av(e.p,32)}<span class="grow"><b>${esc(e.p.name)}</b><small>${whenTxt(e.n)} · ${e.kind==='b'?'დაბადების დღე':e.label}</small></span></button>`).join('')}`:'')}catch(e){}}
WIDE.addEventListener?.('change',renderSide);
document.addEventListener('click',e=>{const b=e.target.closest('[data-tab2]');if(b){go(b.dataset.tab2);markSide()}});
setInterval(()=>{if(document.body.classList.contains('wide')&&!document.hidden)loadSideR()},300000);

/* in-app banner for live notifications */
function banner(html,onTap){const b=$('#inapp');b.innerHTML=html;b.hidden=false;b.onclick=()=>{b.hidden=true;onTap&&onTap()};anim(b,[{opacity:0,transform:'translateY(-120%)'},{opacity:1,transform:'none'}],{duration:420,easing:SPRING});clearTimeout(banner.t);banner.t=setTimeout(()=>{b.hidden=true},4500)}
function listenNotes(){sb.channel('notes-'+ME.id).on('postgres_changes',{event:'INSERT',schema:'public',table:'notifications',filter:'user_id=eq.'+ME.id},({new:n})=>onNote(n)).subscribe()}
async function onNote(n){const r=n.ref||{};if(n.actor)try{await loadProfiles([n.actor])}catch(e){}
 const who=n.actor?`${av(n.actor,36)}<span class="grow"><b>${esc(pname(n.actor))}</b>`:'<span class="grow">';
 if(n.kind==='message'){if(S.openConv===r.conv)return;S.unreadMsgs++;renderBadges();banner(`${who}<span>${esc(r.text||'ახალი შეტყობინება')}</span></span>`,()=>openChat(+r.conv));return}
 if(n.kind==='friend_req'&&n.actor){PENDING_IN.add(n.actor);if(S.page?.id==='friends')rp()}else if(n.kind==='friend_ok'&&n.actor){FRIENDS.add(n.actor);PENDING_OUT.delete(n.actor)}else if(n.kind==='verified'){ME.verified=true}
 S.unreadNotes++;renderBadges();
 banner(`${who}<span>${esc((NOTE_TXT[n.kind]||(()=>'ახალი შეტყობინება'))(r))}</span></span>`,()=>{const t=document.createElement('button');t.dataset.k=n.kind;t.dataset.r=JSON.stringify(r);t.dataset.u=n.actor||'';A.note(t)})}

/* presence: last seen */
function touchSeen(){if(!ME||document.hidden||ME.privacy?.online===false)return;sb.from('profiles').update({last_seen:new Date().toISOString()}).eq('id',ME.id).then(()=>{})}

/* deep links: #post-12, #user-<id>, #chat-3, #group-5, #pagev-2, #event-7, #tag-ღვინო, #notifications, #date */
function route(h){h=String(h||'');if(!h||h==='#'||h.includes('='))return false;let id,arg;
 try{const m=decodeURIComponent(h).match(/^#([a-z]+)(?:-(.+))?$/);if(!m)return false;[,id,arg]=m}catch(e){return false}
 const base=()=>{if(!view.childElementCount)go('home')};
 if(id==='chat'&&arg){base();openChat(+arg);return true}
 if(id==='notifications'){base();openNotes();return true}
 if(id==='chats'){base();openChats();return true}
 if(R[id]){go(id);return true}
 if(PG[id]){openPage(id,arg);return true}
 return false}

/* service worker, install prompt, push routing */
function registerSW(){if(!('serviceWorker'in navigator))return;navigator.serviceWorker.register('/sw.js').catch(()=>{});
 navigator.serviceWorker.addEventListener('message',e=>{const d=e.data||{};if(d.type==='open'&&d.url){const u=new URL(d.url,location.origin);route(u.hash)}})}
window.addEventListener('beforeinstallprompt',e=>{e.preventDefault();S.installEvt=e});
window.addEventListener('appinstalled',()=>{S.installEvt=null;toast('სუფრა დაყენდა 🎉')});
window.addEventListener('offline',()=>toast('ინტერნეტი გაითიშა'));
window.addEventListener('online',()=>{toast('კავშირი აღდგა');if(ME)countUnread()});
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&ME){countUnread();touchSeen()}});

/* global input */
$('#tabs').addEventListener('click',e=>{const b=e.target.closest('.tab');if(!b)return;if(b.dataset.tab===S.tab&&!S.page&&view.scrollTop>10){view.scrollTo({top:0,behavior:RM()?'auto':'smooth'});return}go(b.dataset.tab)});
document.addEventListener('click',e=>{if(!e.target.closest('.rwrap'))$$('.picker').forEach(x=>x.remove());const t=e.target.closest('[data-a]');if(!t)return;const f=A[t.dataset.a];if(!f)return;if(t.tagName==='A')e.preventDefault();try{const r=f(t,e);if(r&&r.catch)r.catch(x=>toast(errMsg(x)))}catch(x){toast(errMsg(x))}});
$('#sheet').addEventListener('click',e=>{if(e.target.id==='sheet')closeSheet()});
$('#layer').addEventListener('click',e=>{if(e.target.id==='layer')closeLayer()});
document.addEventListener('keydown',e=>{if(PV&&!$('#pv')?.hidden&&$('#sheet').hidden&&(e.key==='ArrowRight'||e.key==='ArrowLeft')){const b=$(`#pv .pmnav.${e.key==='ArrowRight'?'next':'prev'}`);if(b)b.click();return}if(e.key!=='Escape')return;if(!$('#layer').hidden)closeLayer();else if($('#pv.top')&&!$('#pv').hidden)closePV();else if(!$('#story').hidden)closeStory();else if(!$('#sheet').hidden)closeSheet();else if($('#pv')&&!$('#pv').hidden)closePV()});
{let lastY=0;view.addEventListener('scroll',()=>{const y=view.scrollTop,app=$('#app');$('#top').classList.toggle('shadow',y>4);if(view.classList.contains('is-clips'))return;
 if(y>lastY+8&&y>90)app.classList.add('barhidden');else if(y<lastY-8||y<40)app.classList.remove('barhidden');lastY=y},{passive:true})}
try{const ro=new ResizeObserver(()=>{const r=document.documentElement.style;r.setProperty('--th',$('#top').offsetHeight+'px');r.setProperty('--bh',$('#tabs').offsetHeight+'px')});ro.observe($('#top'));ro.observe($('#tabs'))}catch(e){}

/* start */
let ENTERED=false;
async function enterApp(){if(ENTERED)return;ENTERED=true;
 try{const{data}=await sb.auth.getUser();S.email=data?.user?.email||''}catch(e){}
 $('#app').hidden=false;$('#boot')?.remove();renderTop();renderTabs();renderSide();
 await Promise.race([loadFriends(),new Promise(r=>setTimeout(r,2500))]);
 if(!route(location.hash))go('home');
 navInit();renderBadges();
 if(ME.banned)toast('შენი ანგარიში შეზღუდულია: პოსტები და შეტყობინებები დროებით გამორთულია');
 try{netInit()}catch(e){}try{listenCalls()}catch(e){}try{listenNotes()}catch(e){}
 countUnread();touchSeen();setInterval(touchSeen,120000);registerSW();
 if(store.get('fsw',null)===ME.id){store.set('fsw',null);setTimeout(()=>firstSteps(ME.avatar_url?1:0),700)}}
bootAuth().catch(e=>{toast(errMsg(e));showAuth('in')});
