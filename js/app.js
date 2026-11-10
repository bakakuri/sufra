/* shell: top bar, tabs, create button, realtime, deep links, install, back button */
if(typeof featWrap==='function')featWrap();
/* the tab bar: messages sit in the middle as a big raised button (they open the chats, they are not a tab of their own);
   friends took the place of study, which is in the services menu now */
const TABS=[['home','მთავარი','home'],['friends','მეგობრები','users'],['date','გაცნობა','heart'],['chats','მიმოწერა','msg'],['clips','კლიპები','clips'],['games','თამაშები','dice'],['me','პროფილი','user']];
const TABMID='chats';
const SVC=[['study','school','სწავლა'],['schedule','cal','ლექციების ცხრილი'],['exams','clock','გამოცდები და დავალებები'],['notes','book','კონსპექტები'],['classmates','school','კლასელები და კურსელები'],['tips','help','სასწავლო რჩევები'],['rooms','video','სასწავლო ოთახი'],['rooms','mic','დისკუსია','birja'],['rooms','live','ლაივი','live'],['groups','users','ჯგუფები'],['friends','users','მეგობრები'],['map','globe','ლაივ რუკა'],['events','cal','შეხვედრები'],['jobs','school','ვაკანსიები და CV'],['pages','mega','არხები და გვერდები'],['albums','image','ალბომები'],['market','store','ბაზრობა'],['shop','coin','მაღაზია'],['places','map','ადგილები'],['sport','trophy','მატჩის ოთახი'],['help','help','დახმარება'],['rides','pin','ერთად წავიდეთ'],['namedays','cal','სახელის დღეები'],['tree','tree','ოჯახის ხე'],['calendar','gift','კალენდარი'],['tour','trophy','ტურნირი'],['saved','bookmark','შენახული'],['storyarch','archive','ისტორიების არქივი'],['drafts','clock','დრაფტები'],['coins','coin','მონეტები'],['verify','shield','ვერიფიკაცია'],['settings','gear','პარამეტრები']];
/* the day in Georgia (UTC+4 all year): the daily bonus turns over at midnight in Tbilisi */
const today=()=>new Date(Date.now()+4*36e5).toISOString().slice(0,10);

function renderTop(){if(!ME)return;$('#top').innerHTML=`<button class="logo" data-a="home" aria-label="Peera, მთავარზე დაბრუნება">${kLogo()}</button><span class="sp"></span>
 <span class="hicons"><span id="lpin" class="lpinw"></span><button class="ibtn" data-a="search" aria-label="ძიება">${ic('search')}</button>
 <button class="ibtn" data-a="notifs" aria-label="შეტყობინებები">${ic('bell')}<span class="dot" id="dn" hidden></span></button>
 <button class="ibtn" data-a="guests" aria-label="სტუმრები">${ic('eye')}<span class="dot" id="dg" hidden></span></button>
 <button class="ibtn" data-a="menu" aria-label="სერვისები">${ic('grid')}</button></span>`;if(typeof locBadge==='function')locBadge();renderBadges();fitTop()}
/* the header keeps every button on narrow phones: the name under the logo gets smaller, then only the mark stays */
let TOPRO=null;
function fitTop(){const t=$('#top');if(!t)return;const run=()=>{t.classList.remove('lsm','ltight');if(t.scrollWidth<=t.clientWidth+1)return;t.classList.add('lsm');if(t.scrollWidth<=t.clientWidth+1)return;t.classList.remove('lsm');t.classList.add('ltight')};run();
 if(!TOPRO&&window.ResizeObserver){let f=0;TOPRO=new ResizeObserver(()=>{if(!f)f=requestAnimationFrame(()=>{f=0;run()})});}
 if(TOPRO){TOPRO.disconnect();TOPRO.observe(t);$$('#top .hicons').forEach(e=>TOPRO.observe(e))}
 if(document.fonts&&!fitTop.f){fitTop.f=1;document.fonts.ready.then(()=>fitTop())}}
const visTabs=()=>TABS.filter(t=>typeof tabOk!=='function'||tabOk(t[0]));
function renderTabs(){const v=visTabs(),el=$('#tabs');el.style.setProperty('--tn',v.length);el.innerHTML='<span class="tabind" aria-hidden="true"></span>'+v.map(([k,l,i])=>k===TABMID?
 `<button class="tab tmid" data-tab="${k}" aria-label="${l}"><span class="tmidb">${ic(i)}<span class="dot" id="dm" hidden></span></span><span class="tl">${l}</span></button>`:
 `<button class="tab" data-tab="${k}" aria-current="${k===S.tab}">${ic(i)}<span class="tl">${l}</span>${k==='friends'?'<span class="dot tcount" id="df" hidden></span>':'<i class="tdot" hidden></i>'}</button>`).join('');renderBadges()}
function renderBadges(){const set=(id,n)=>{const d=$('#'+id);if(!d)return;const was=d.hidden?0:parseInt(d.textContent,10)||0;d.hidden=!n;d.textContent=n>99?'99+':String(n);if(n>was)pop(d)};
 set('dn',S.unreadNotes);set('dm',S.unreadMsgs);set('dn2',S.unreadNotes);set('dm2',S.unreadMsgs);set('df',typeof PENDING_IN!=='undefined'?PENDING_IN.size:0);set('dg',S.newGuests||0);
 const me=$('.tab[data-tab="me"] .tdot');if(me){const bon=typeof bonusWaits==='function'&&bonusWaits();me.hidden=!bon;me.classList.toggle('gold',bon)}
 const tot=(S.unreadNotes||0)+(S.unreadMsgs||0);document.title=tot?`(${tot}) Peera`:'Peera';
 try{if(tot&&navigator.setAppBadge)navigator.setAppBadge(tot);else if(navigator.clearAppBadge)navigator.clearAppBadge()}catch(e){}}

/* tabs and pages */
function go(tab,dx){if(!R[tab])tab='home';const oi=TABS.findIndex(t=>t[0]===S.tab),ni=TABS.findIndex(t=>t[0]===tab),wasPage=!!S.page;
 closeSheet(true);closePV(true);stopMedia();S.page=null;S.tab=tab;$$('.tab').forEach(b=>b.setAttribute('aria-current',String(b.dataset.tab===tab)));moveInd(tab);
 const app=$('#app');app.classList.toggle('media',tab==='clips');app.classList.remove('barhidden');view.className=tab==='clips'?'is-clips':'';view.scrollTop=0;
 navStep();
 R[tab]();updateFab();markSide();
 const d=dx!=null?dx:(oi===ni&&!wasPage?0:Math.sign(ni-oi||1)*24);if(d)enterView(d)}
{const op=openPage;openPage=function(...a){if(a[0]==='friends'&&R.friends){go('friends');return}closePV(true);const r=op.apply(this,a);updateFab();markSide();return r}}
R.friends=()=>{PG.friends.r();$('.pghead [data-a="back"]',view)?.remove();$('.pghead',view)?.classList.add('tabhead')};
function updateFab(){const f=$('#fab');if(f)f.hidden=document.body.classList.contains('wide')||!!S.page||!['home','me'].includes(S.tab)}
A.home=()=>{if(S.tab==='home'&&!S.page){view.scrollTo({top:0,behavior:RM()?'auto':'smooth'});return}go('home')};

/* services menu and the create sheet */
A.menu=()=>{navMark('menu',A.menu);const svc=SVC.filter(x=>pageOk(x[0]));if(isStaff())svc.push(['admin','shield','ადმინ პანელი']);
 const standalone=matchMedia('(display-mode: standalone)').matches||navigator.standalone;
 sheet(head('სერვისები')+walletHTML('mwal')+`<div class="svc">${svc.map(([p,i,l,a])=>`<button data-a="${R[p]&&!PG[p]?'tabgo':'page'}" data-p="${p}"${a?` data-arg="${a}"`:''}>${ic(i)}${l}</button>`).join('')}${standalone?'':`<button data-a="install">${ic('download')}აპად დაყენება</button>`}<button data-a="rules">${ic('flag')}წესები</button></div>`,'short')};
const CREATE=[['cpost','edit','პოსტი','ტექსტი, ფოტო, ჰეშთეგი'],['cnote','book','კონსპექტი','ფოტო, ტექსტი, საგანი'],['clesson','cal','ლექცია ცხრილში','დღე, დრო, აუდიტორია'],['cexam','clock','გამოცდა ან დავალება','ვადით'],['croom','video','სასწავლო ოთახი','ვიდეო-შეხვედრა კურსელებთან'],['cbirja','mic','დისკუსია','ხმოვანი ოთახი თემაზე'],['cphoto','image','ფოტო','ფილტრით და ჭრით'],['cclip','clips','კლიპი','მოკლე ვერტიკალური ვიდეო'],['cpoll','poll','გამოკითხვა','მეგობრების აზრი'],['cstory','story','ისტორია','ქრება 24 საათში'],['cevent','cal','შეხვედრა','ლექცია, ექსკურსია, წვეულება'],['clisting','store','განცხადება','გაყიდე ან გააჩუქე'],['cgroup','users','ჯგუფი','საერთო ინტერესით'],['cpage','mega','არხი ან გვერდი','ბიზნესი და რეკლამა'],['cgchat','msg','ჯგუფური ჩატი','რამდენიმე მეგობართან'],['clive','live','ლაივი','პირდაპირი ეთერი'],['cplace','map','ადგილი','კაფე, ბიბლიოთეკა, სივრცე'],['chelp','help','დახმარების თხოვნა','სისხლი, ცხოველი, მოხალისე'],['cride','pin','მგზავრობა','ადგილები მანქანაში'],['cjob','school','ვაკანსია','მოძებნე თანამშრომელი']];
A.create=()=>(navMark('create',A.create),sheet(head('შექმნა')+`<div class="createg">${CREATE.filter(x=>createOk(x[0])).map(([a,i,l,s])=>`<button data-a="${a}"><span class="cgi">${ic(i)}</span><b>${l}</b><small>${s}</small></button>`).join('')}</div>`,'short'));
A.cpost=()=>compose();
A.crecipe=()=>{closeSheet();A.recipenew()};
A.croom=()=>{S.rkind='supra';closeSheet();A.newroom()};
A.cbirja=()=>{S.rkind='birja';closeSheet();A.newroom()};
A.cride=()=>openPage('ridenew',undefined,['rides']);
A.clive=()=>{S.rkind='live';A.newroom()};
A.cplace=()=>openPage('placenew',undefined,['places']);
A.chelp=()=>openPage('helpnew',undefined,['help']);
A.ctoast=()=>A.newtoast();
A.cjob=()=>openPage('jobnew',undefined,['jobs']);
A.cphoto=async()=>{await compose();$('#c_img')?.click()};
A.cclip=()=>newClip();
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
 L.innerHTML=`<button class="logo" data-a="home" aria-label="Peera">${kLogo()}</button><nav class="snavs">${visTabs().filter(t=>t[0]!==TABMID).map(([k,l,i])=>`<button class="snav" data-tab2="${k}">${ic(i)}<span>${l}</span></button>`).join('')}
  <button class="snav" data-a="chats">${ic('msg')}<span>მიმოწერა</span><i class="sdot" id="dm2" hidden></i></button><button class="snav" data-a="notifs">${ic('bell')}<span>შეტყობინებები</span><i class="sdot" id="dn2" hidden></i></button>
  <span class="snavsep"></span>${SVC.filter(x=>pageOk(x[0])).slice(0,8).map(([p,i,l,a])=>`<button class="snav sm" data-a="${R[p]&&!PG[p]?'tabgo':'page'}" data-p="${p}"${a?` data-arg="${a}"`:''}>${ic(i)}<span>${l}</span></button>`).join('')}<button class="snav sm" data-a="menu">${ic('grid')}<span>ყველა სერვისი</span></button></nav>
  <button class="btn wide" data-a="create">${ic('plus')}შექმნა</button><button class="smine" data-tab2="me">${av('me',40)}<span class="grow"><b>${esc(ME.name)}</b><small>${ME.username?'@'+esc(ME.username):'პროფილი'}</small></span></button>`;
 let Rr=$('#sider');if(!Rr){Rr=document.createElement('aside');Rr.id='sider';Rr.className='side-r';Rr.setAttribute('aria-label','აღმოაჩინე');document.body.appendChild(Rr);loadSideR()}
 markSide();renderBadges()}
function markSide(){$$('#sidel [data-tab2]').forEach(b=>b.setAttribute('aria-current',String(!S.page&&b.dataset.tab2===S.tab)))}
async function loadSideR(){const el=$('#sider');if(!el)return;
 el.innerHTML=`<form class="ssearch" id="ssf" role="search">${ic('search')}<input id="ssq" type="search" placeholder="ძიება Peera-ზე" aria-label="ძიება"></form><section class="scard" id="sr_live"></section><section class="scard" id="sr_sg"></section><section class="scard" id="sr_bd"></section><p class="sfoot"><button class="trb" data-a="rules">წესები</button> · <button class="trb" data-a="privacy">კონფიდენციალურობა</button> · Peera ${new Date().getFullYear()}</p>`;
 $('#ssf').onsubmit=e=>{e.preventDefault();openPage('search',$('#ssq').value.trim())};
 try{const[sg,rooms]=await Promise.all([rpc('friend_suggestions',{p_limit:5}),q(sb.from('rooms').select('id,kind,title,host').eq('live',true).gt('created_at',new Date(Date.now()-12*36e5).toISOString()).order('created_at',{ascending:false}).limit(4))]);
  sg.forEach(p=>PC.set(p.id,Object.assign(PC.get(p.id)||{},p)));await loadProfiles(rooms.map(r=>r.host));
  const c=(id,h)=>{const x=$(id);if(x)x.innerHTML=h;if(x&&!h)x.remove()};
  c('#sr_live',rooms.length?`<h3>${ic('live')}ცოცხლად ახლა</h3>${rooms.map(r=>`<button class="srow" data-a="page" data-p="room" data-arg="${r.id}"><span class="rico ${r.kind}">${ic(rkIcon(r.kind))}</span><span class="grow"><b>${esc(r.title)}</b><small>${esc(pname(r.host))}</small></span></button>`).join('')}`:'');
  c('#sr_sg',sg.length?`<h3>შეიძლება იცნობდე</h3>${sg.map(p=>`<div class="srow"><button data-a="user" data-u="${p.id}">${av(p,36)}</button><button class="grow" data-a="user" data-u="${p.id}" style="text-align:left"><b>${esc(p.name)}</b><small>${p.mutual?p.mutual+' საერთო':esc(p.city||'')}</small></button><button class="btn sm" data-a="addfriend" data-u="${p.id}" aria-label="დამატება">${ic('plus')}</button></div>`).join('')}`:'');
  const bd=(await upcoming(7)).slice(0,4);c('#sr_bd',bd.length?`<h3>${ic('gift')}მალე</h3>${bd.map(e=>`<button class="srow" data-a="greet" data-u="${e.p.id}" data-k="${e.kind}">${av(e.p,32)}<span class="grow"><b>${esc(e.p.name)}</b><small>${whenTxt(e.n)} · ${e.kind==='b'?'დაბადების დღე':e.label}</small></span></button>`).join('')}`:'')}catch(e){}}
WIDE.addEventListener?.('change',renderSide);
document.addEventListener('click',e=>{const b=e.target.closest('[data-tab2]');if(b){if(b.dataset.tab2==='games'){gOpenHub();return}go(b.dataset.tab2);markSide()}});
setInterval(()=>{if(document.body.classList.contains('wide')&&!document.hidden)loadSideR()},300000);

/* in-app banner for live notifications */
function banner(html,onTap){const b=$('#inapp');b.innerHTML=html;b.hidden=false;b.onclick=()=>{b.hidden=true;onTap&&onTap()};anim(b,[{opacity:0,transform:'translateY(-120%)'},{opacity:1,transform:'none'}],{duration:420,easing:SPRING});clearTimeout(banner.t);banner.t=setTimeout(()=>{b.hidden=true},4500)}
function listenNotes(){sb.channel('notes-'+ME.id).on('postgres_changes',{event:'INSERT',schema:'public',table:'notifications',filter:'user_id=eq.'+ME.id},({new:n})=>onNote(n)).subscribe()}
async function onNote(n){const r=n.ref||{};if(n.actor)try{await loadProfiles([n.actor])}catch(e){}
 const who=n.actor?`${av(n.actor,36)}<span class="grow"><b>${esc(pname(n.actor))}</b>`:kAv(36)+'<span class="grow">';
 if(n.kind==='message'){if(S.openConv===r.conv)return;S.unreadMsgs++;renderBadges();banner(`${who}<span>${esc(r.text||'ახალი შეტყობინება')}</span></span>`,()=>openChat(+r.conv));return}
 if(n.kind==='friend_req'&&n.actor){PENDING_IN.add(n.actor);if(S.page?.id==='friends')rp();else if(!S.page&&S.tab==='friends')R.friends()}else if(n.kind==='friend_ok'&&n.actor){FRIENDS.add(n.actor);PENDING_OUT.delete(n.actor)}else if(n.kind==='verified'){ME.verified=true}
 S.unreadNotes++;renderBadges();
 banner(`${who}<span>${esc((NOTE_TXT[n.kind]||(()=>'ახალი შეტყობინება'))(r))}</span></span>`,()=>{const t=document.createElement('button');t.dataset.k=n.kind;t.dataset.r=JSON.stringify(r);t.dataset.u=n.actor||'';A.note(t)})}

/* presence: last seen */
function touchSeen(){if(!ME||document.hidden||ME.privacy?.online===false)return;sb.from('profiles').update({last_seen:new Date().toISOString()}).eq('id',ME.id).then(()=>{})}

/* deep links: #post-12, #user-<id>, #chat-3, #group-5, #pagev-2, #event-7, #tag-ლექცია, #notifications, #date */
function route(h){h=String(h||'');if(!h||h==='#'||h.includes('='))return false;let id,arg;
 try{const m=decodeURIComponent(h).match(/^#([a-z]+)(?:-(.+))?$/);if(!m)return false;[,id,arg]=m}catch(e){return false}
 const base=()=>{if(!view.childElementCount)go('home')};
 if(id==='chat'&&arg){base();openChat(+arg);return true}
 if(id==='join'&&/^\d+$/.test(arg||'')){base();joinByLink(+arg);return true}
 if(id==='notifications'){base();openNotes();return true}
 if(id==='storyv'&&arg){base();openStoryById(+arg);return true}
 if(id==='chats'){base();openChats();return true}
 if(R[id]){go(id);return true}
 if(PG[id]||typeof GLZ_PG!=='undefined'&&GLZ_PG.includes(id)){openPage(id,arg);return true}
 return false}

/* service worker, install prompt, push routing */
function registerSW(){if(!('serviceWorker'in navigator))return;navigator.serviceWorker.register('/sw.js').catch(()=>{});
 navigator.serviceWorker.addEventListener('message',e=>{const d=e.data||{};if(d.type==='open'&&d.url){const u=new URL(d.url,location.origin);route(u.hash)}})}
window.addEventListener('beforeinstallprompt',e=>{e.preventDefault();S.installEvt=e});
window.addEventListener('appinstalled',()=>{S.installEvt=null;toast('Peera ტელეფონზე დაყენდა 🎉')});
window.addEventListener('offline',()=>toast('ინტერნეტი გაითიშა'));
window.addEventListener('online',()=>{toast('კავშირი აღდგა');if(ME)countUnread()});
document.addEventListener('visibilitychange',()=>{if(!document.hidden&&ME){countUnread();touchSeen()}});

/* global input */
$('#tabs').addEventListener('click',e=>{const b=e.target.closest('.tab');if(!b)return;if(b.dataset.tab===TABMID){A.chats();return}if(b.dataset.tab==='games'){gOpenHub();return}if(b.dataset.tab===S.tab&&!S.page&&view.scrollTop>10){view.scrollTo({top:0,behavior:RM()?'auto':'smooth'});return}go(b.dataset.tab)});
document.addEventListener('click',e=>{if(!e.target.closest('.rwrap'))$$('.picker').forEach(x=>x.remove());const t=e.target.closest('[data-a]');if(!t)return;const f=A[t.dataset.a];if(!f){/* an action of the games or the admin panel, touched before they came */if(typeof GLZ!=='undefined'&&t.dataset.a&&(!GLZ.ready||ME&&ME.role==='admin'&&!PG.admin))(GLZ.ready?glAdmin():glLoad()).then(()=>{const g=A[t.dataset.a];if(g&&t.isConnected)g(t,e)}).catch(()=>{});return}if(t.tagName==='A')e.preventDefault();try{const r=f(t,e);if(r&&r.catch)r.catch(x=>{toast(errMsg(x));errBug(x,t.dataset.a)})}catch(x){toast(errMsg(x));errBug(x,t.dataset.a)}});
$('#sheet').addEventListener('click',e=>{if(e.target.id==='sheet')closeSheet()});
$('#layer').addEventListener('click',e=>{if(e.target.id==='layer')closeLayer()});
/* a plate or card that acts as a button (role=button with an action) answers Enter and Space like one */
document.addEventListener('keydown',e=>{const t=e.target;if((e.key==='Enter'||e.key===' ')&&t&&t.getAttribute&&t.getAttribute('role')==='button'&&t.dataset&&t.dataset.a&&t.tagName!=='BUTTON'){e.preventDefault();t.click()}});
document.addEventListener('keydown',e=>{if(PV&&!$('#pv')?.hidden&&$('#sheet').hidden&&(e.key==='ArrowRight'||e.key==='ArrowLeft')){const b=$(`#pv .pmnav.${e.key==='ArrowRight'?'next':'prev'}`);if(b)b.click();return}if(e.key!=='Escape')return;if(!$('#layer').hidden)closeLayer();else if($('#pv.top')&&!$('#pv').hidden)closePV();else if(!$('#story').hidden)closeStory();else if(!$('#sheet').hidden)closeSheet();else if($('#pv')&&!$('#pv').hidden)closePV()});
{let lastY=0;view.addEventListener('scroll',()=>{const y=view.scrollTop,app=$('#app');$('#top').classList.toggle('shadow',y>4);if(view.classList.contains('is-clips'))return;
 if(y>lastY+8&&y>90)app.classList.add('barhidden');else if(y<lastY-8||y<40)app.classList.remove('barhidden');lastY=y},{passive:true})}
try{const ro=new ResizeObserver(()=>{const r=document.documentElement.style;r.setProperty('--th',$('#top').offsetHeight+'px');r.setProperty('--bh',$('#tabs').offsetHeight+'px')});ro.observe($('#top'));ro.observe($('#tabs'))}catch(e){}

/* start */
/* an invite link opened before signing in (or before the sign-up mail is confirmed) is kept until the app opens */
try{const m=location.hash.match(/^#join-(\d+)$/);if(m)store.set('pendjoin',+m[1])}catch(e){}
/* ?i=…: who invited; kept until the new account is there, and taken off the address */
try{const u=new URL(location.href),i=u.searchParams.get('i');if(i&&/^[\w@.-]{2,64}$/.test(i)){store.set('pendinv',i);u.searchParams.delete('i');history.replaceState(history.state,'',u.pathname+u.search+u.hash)}}catch(e){}
let ENTERED=false;
async function enterApp(){if(ENTERED)return;ENTERED=true;
 try{const{data}=await sb.auth.getUser();S.email=data?.user?.email||''}catch(e){}
 $('#app').hidden=false;$('#boot')?.remove();renderTop();renderTabs();renderSide();
 if(!ME.offline)await Promise.race([loadFriends(),new Promise(r=>setTimeout(r,2500))]);
 if(ME.offline)go('games');else if(!route(location.hash))go('home');
 navInit();
 {const pj=store.get('pendjoin',null);if(pj&&!ME.offline&&!/^#join-/.test(location.hash))setTimeout(()=>joinByLink(+pj),400)}renderBadges();
 if(!ME.offline){invClaim();setTimeout(welcomeGift,1800);setTimeout(glPrefetch,4000);setTimeout(()=>{try{locResume()}catch(e){}},1200)}
 if(ME.offline){toast('ინტერნეტი არ არის. ბოტებთან თამაში მაინც მუშაობს');return}
 if(ME.banned)toast('შენი ანგარიში შეზღუდულია: პოსტები და შეტყობინებები დროებით გამორთულია');
 try{netInit()}catch(e){}try{listenCalls()}catch(e){}try{listenNotes()}catch(e){}try{coinsInit()}catch(e){}
 loadAppSettings();countUnread();touchSeen();setInterval(touchSeen,120000);registerSW();loadTagFollows();setTimeout(()=>checkBadges(),6000);
 if(store.get('fsw',null)===ME.id){store.set('fsw',null);setTimeout(()=>firstSteps(ME.avatar_url?1:0),700)}}
bootAuth().catch(e=>{if(netDown(e)&&bootOffline())return;toast(errMsg(e));showAuth('in')});
