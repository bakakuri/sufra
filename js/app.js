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
/* the bottom bar as the app's (tab_bar.dart): pictures only, no words; the Peera mark for the feed, my picture in a
   ring for the profile, the round chat button standing out in the middle; the open tab's icon filled in a soft pill */
const BARIC={
 friends:{body:'<circle cx="9" cy="7.8" r="3.7"/><path d="M2.6 20.1c.4-3.9 3.1-6.2 6.4-6.2s6 2.3 6.4 6.2a.9.9 0 0 1-.9 1H3.5a.9.9 0 0 1-.9-1z"/>',soft:'<circle cx="16.9" cy="8.6" r="3"/><path d="M16.3 14.1c3.1-.2 5.1 1.8 5.4 5a.9.9 0 0 1-.9 1h-3.2c-.1-2.4-.5-4.3-1.3-6z"/>',detail:'',line:'<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.7-3.5 3.4-5.5 6.5-5.5s5.8 2 6.5 5.5M16 4.5a3.5 3.5 0 0 1 0 7M18 14.6c2 .8 3.2 2.6 3.5 5.4"/>'},
 heart:{body:'<path d="M12 20.3s-7.4-4.5-9.4-9.3a5.2 5.2 0 0 1 9.4-3.4 5.2 5.2 0 0 1 9.4 3.4c-2 4.8-9.4 9.3-9.4 9.3z"/>',soft:'',detail:'<path d="M6.6 8.7a2.8 2.8 0 0 1 2.4-2"/>',line:'<path d="M12 20s-7-4.4-9-9a5 5 0 0 1 9-3 5 5 0 0 1 9 3c-2 4.6-9 9-9 9z"/>'},
 clips:{body:'<rect x="4" y="2.8" width="16" height="18.4" rx="4.6"/>',soft:'',detail:'<path d="M10.2 8.6v6.8l5.6-3.4z" fill="1"/>',line:'<rect x="4" y="3" width="16" height="18" rx="4"/><path d="M10 9l5 3-5 3z"/>'},
 games:{body:'<path d="M7.2 6.8h9.6a4.8 4.8 0 0 1 4.7 3.9l1 5.5a2.9 2.9 0 0 1-5 2.5l-2.1-2.3H8.6l-2.1 2.3a2.9 2.9 0 0 1-5-2.5l1-5.5a4.8 4.8 0 0 1 4.7-3.9z"/>',soft:'',detail:'<path d="M7.4 10.2v3.6M5.6 12h3.6"/><circle cx="15.9" cy="10.9" r="1.2" fill="1"/><circle cx="18.2" cy="13.2" r="1.2" fill="1"/>',line:'<path d="M7.2 6.8h9.6a4.8 4.8 0 0 1 4.7 3.9l1 5.5a2.9 2.9 0 0 1-5 2.5l-2.1-2.3H8.6l-2.1 2.3a2.9 2.9 0 0 1-5-2.5l1-5.5a4.8 4.8 0 0 1 4.7-3.9z"/><path d="M7.4 10.2v3.6M5.6 12h3.6"/><circle cx="15.9" cy="10.9" r="1.2" fill="1"/><circle cx="18.2" cy="13.2" r="1.2" fill="1"/>'},
 chat:{body:'<path d="M12 3.8c5 0 9.2 3.4 9.2 7.7S17 19.2 12 19.2c-1.1 0-2.2-.2-3.2-.5L4.3 20.4l1.3-3.6C4 15.4 2.8 13.6 2.8 11.5c0-4.3 4.2-7.7 9.2-7.7z"/>',soft:'',detail:'<circle cx="8" cy="11.6" r="1.25" fill="1"/><circle cx="12" cy="11.6" r="1.25" fill="1"/><circle cx="16" cy="11.6" r="1.25" fill="1"/>',line:''}};
/* lines when closed; filled when open: the body in the accent (a softer second body), the details in the bar's colour */
function barIc(k,on,cls=''){const x=BARIC[k];if(!x)return ic(k);const F=(s,c)=>s.replace(/fill="1"/g,`fill="${c}" stroke="none"`);
 if(!on)return `<svg class="bic${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${F(x.line,'currentColor')}</svg>`;
 return `<svg class="bic on${cls}" viewBox="0 0 24 24" aria-hidden="true"><g fill="currentColor" opacity=".45">${x.soft}</g><g class="bicb" fill="currentColor">${x.body}</g><g class="bicd" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${F(x.detail,'var(--bicd)')}</g></svg>`}
const TABPIC={home:'mark',friends:'friends',date:'heart',clips:'clips',games:'games',me:'me'};
function tabPic(k,on){const t=TABPIC[k];if(t==='mark')return `<span class="tmark">${kMark()}</span>`;if(t==='me')return `<span class="tme">${av(ME||{},32)}</span>`;return barIc(t||k,on)}
function renderTabs(){const v=visTabs(),el=$('#tabs');el.style.setProperty('--tn',v.length);el.innerHTML='<span class="tabind" aria-hidden="true"></span>'+v.map(([k,l,i])=>k===TABMID?
 `<button class="tab tmid" data-tab="${k}" aria-label="${l}" title="${l}"><span class="tmidb">${barIc('chat',true,' tchat')}<span class="dot" id="dm" hidden></span></span></button>`:
 `<button class="tab${k==='me'?' tabme':''}" data-tab="${k}" aria-label="${l}" title="${l}" aria-current="${k===S.tab}"><span class="tpic">${tabPic(k,k===S.tab)}${k==='friends'?'<span class="dot tcount" id="df" hidden></span>':'<i class="tdot" hidden></i>'}</span></button>`).join('');
 el.classList.toggle('onme',S.tab==='me');renderBadges()}
/* the open tab's picture fills in, the one left goes back to lines */
function markTabs(tab){$$('#tabs .tab:not(.tmid)').forEach(b=>{const on=b.dataset.tab===tab,p=$('.tpic',b);b.setAttribute('aria-current',String(on));
 if(p&&BARIC[TABPIC[b.dataset.tab]]){const svg=$('svg.bic',p);if(svg&&svg.classList.contains('on')!==on)svg.outerHTML=barIc(TABPIC[b.dataset.tab],on)}});$('#tabs')?.classList.toggle('onme',tab==='me')}
function renderBadges(){const set=(id,n)=>{const d=$('#'+id);if(!d)return;const was=d.hidden?0:parseInt(d.textContent,10)||0;d.hidden=!n;d.textContent=n>99?'99+':String(n);if(n>was)pop(d)};
 set('dn',S.unreadNotes);set('dm',S.unreadMsgs);set('dn2',S.unreadNotes);set('dm2',S.unreadMsgs);set('df',typeof PENDING_IN!=='undefined'?PENDING_IN.size:0);set('dg',S.newGuests||0);
 const me=$('.tab[data-tab="me"] .tdot');if(me){const bon=typeof bonusWaits==='function'&&bonusWaits();me.hidden=!bon;me.classList.toggle('gold',bon)}
 const tot=(S.unreadNotes||0)+(S.unreadMsgs||0);document.title=tot?`(${tot}) Peera`:'Peera';
 try{if(tot&&navigator.setAppBadge)navigator.setAppBadge(tot);else if(navigator.clearAppBadge)navigator.clearAppBadge()}catch(e){}}

/* tabs and pages */
function go(tab,dx){if(!R[tab])tab='home';const oi=TABS.findIndex(t=>t[0]===S.tab),ni=TABS.findIndex(t=>t[0]===tab),wasPage=!!S.page;
 closeSheet(true);closePV(true);stopMedia();S.page=null;S.tab=tab;markTabs(tab);moveInd(tab);
 const app=$('#app');app.classList.toggle('media',tab==='clips');app.classList.remove('barhidden');view.className=tab==='clips'?'is-clips':'';view.scrollTop=0;
 navStep();
 R[tab]();updateFab();markSide();
 const d=dx!=null?dx:(oi===ni&&!wasPage?0:Math.sign(ni-oi||1)*24);if(d)enterView(d)}
{const op=openPage;openPage=function(...a){if(a[0]==='friends'&&R.friends){go('friends');return}closePV(true);const r=op.apply(this,a);updateFab();markSide();return r}}
R.friends=()=>{PG.friends.r();$('.pghead [data-a="back"]',view)?.remove();$('.pghead',view)?.classList.add('tabhead')};
function updateFab(){const f=$('#fab');if(f)f.hidden=document.body.classList.contains('wide')||!!S.page||S.tab!=='home'}
A.home=()=>{if(S.tab==='home'&&!S.page){view.scrollTo({top:0,behavior:RM()?'auto':'smooth'});return}go('home')};

/* services menu and the create sheet */
/* the services menu as the app's (services_menu.dart): a search, the groups in a row like a cover flow (the middle one
   straight, the others turned toward it), and under it the middle group's pages, each with a line on what it does */
const SVGROUPS=[
 ['study','school','სწავლა','სკოლა და უნივერსიტეტი ერთ ადგილას',['#5B5BF0','#9B5CF6'],'schedule',[['study','school','სწავლის გვერდი','დღევანდელი ლექციები, ვადები და შენი ჯგუფი ერთად'],['schedule','cal','ლექციების ცხრილი','კვირის ლექციები, აუდიტორია და დრო'],['exams','clock','გამოცდები და დავალებები','ვადები და შეხსენებები, რომ არაფერი გამოგრჩეს'],['notes','book','კონსპექტები','ჩანაწერები და ფოტოები საგნების მიხედვით'],['classmates','users','კლასელები და კურსელები','შენი სკოლის და უნივერსიტეტის ხალხი'],['tips','help','სასწავლო რჩევები','გამოცდილება, კითხვები და პასუხები'],['rooms','video','სასწავლო ოთახი','ვიდეო-შეხვედრა კურსელებთან'],['rooms','mic','დისკუსია','ხმოვანი საუბარი ერთ თემაზე','birja']]],
 ['people','users','ხალხი და თემები','მეგობრები, საზოგადოებები და შეხვედრები',['#0EA5E9','#6366F1'],'groups',[['friends','user','მეგობრები','მოთხოვნები, ნაცნობები და შემოთავაზებები'],['groups','users','ჯგუფები','კლასი, კურსი და ინტერესები'],['pages','mega','არხები და გვერდები','სიახლეები, ბიზნესი და ბრენდები'],['events','cal','შეხვედრები','ლექციები, ექსკურსიები, წვეულებები'],['map','globe','ლაივ რუკა','სად არიან მეგობრები ახლა'],['albums','image','ალბომები','საერთო ფოტოები ერთად']]],
 ['daily','store','ყოველდღიური','ყიდვა-გაყიდვა, სამსახური, ადგილები და გზა',['#EAB308','#F97316'],'market',[['market','store','ბაზრობა','იყიდე, გაყიდე, გააჩუქე'],['jobs','work','ვაკანსიები და CV','სამსახური, სტაჟირება და შენი რეზიუმე'],['places','map','ადგილები','კაფეები, ბიბლიოთეკები, სივრცეები'],['rides','pin','ერთად წავიდეთ','მგზავრობა ერთ მანქანაში'],['help','help','დახმარება','დონორები, ცხოველები, მოხალისეები']]],
 ['fun','live','გართობა და ლაივი','პირდაპირი ეთერი, მატჩები და შეჯიბრებები',['#15A34A','#065F46'],'sport',[['rooms','live','ლაივი','პირდაპირი ეთერი და მაყურებლები','live'],['sport','trophy','მატჩის ოთახი','მატჩები და პროგნოზები მეგობრებთან'],['tour','trophy','ტურნირი','შეჯიბრებები და ცხრილები']]],
 ['roots','tree','ტრადიცია და ოჯახი','დაბადების დღეები, სახელის დღეები და შენი გვარი',['#EF4444','#F472B6'],'calendar',[['calendar','gift','კალენდარი','დაბადების და სახელის დღეები'],['namedays','cal','სახელის დღეები','ვისი სახელობის დღეა დღეს და მალე'],['tree','tree','ოჯახის ხე','შენი გვარი და ნათესავები']]],
 ['mine','gear','ჩემი სივრცე','რაც შეინახე, დაიწყე და შენი პარამეტრები',['#334155','#64748B'],null,[['saved','bookmark','შენახული','შენახული პოსტები კოლექციებში'],['storyarch','archive','ისტორიების არქივი','შენი ძველი ისტორიები'],['drafts','clock','დრაფტები','დაწყებული და დაუსრულებელი პოსტები'],['coins','coin','მონეტები','ბალანსი და მისი ისტორია'],['verify','shield','ვერიფიკაცია','დადასტურებული პროფილის ნიშანი'],['settings','gear','პარამეტრები','პროფილი, კონფიდენციალურობა, შეტყობინებები']]]];
/* the groups as this person sees them: switched-off pages left out, the admin's panel for the staff */
const menuGroups=()=>SVGROUPS.map(g=>{const items=g[6].filter(i=>pageOk(i[0]));if(g[0]==='mine'&&isStaff())items.push(['admin','shield','ადმინ პანელი','საიტის მართვა: საჩივრები, მომხმარებლები, კონტენტი']);return items.length?[...g.slice(0,6),items]:null}).filter(Boolean);
const MF={p:0,gs:[],raf:0,drag:null,el:null,step:120,at:-1};
A.menu=()=>{navMark('menu',A.menu);MF.gs=menuGroups();MF.p=0;MF.at=-1;const n=MF.gs.reduce((s,g)=>s+g[6].length,0);
 sheet(`<div class="mnu"><div class="mnu-h"><h2>სერვისები</h2><small>${MF.gs.length} ჯგუფი · ${n} გვერდი</small><button class="ibtn" data-a="close" aria-label="დახურვა">${ic('x')}</button></div>
  <label class="mnu-q">${ic('search')}<input id="mnuq" type="search" placeholder="მოძებნე სერვისი" autocomplete="off" aria-label="მოძებნე სერვისი"></label>
  <div id="mnub"><div class="mflow" id="mflow" role="listbox" aria-label="სერვისების ჯგუფები">${MF.gs.map((g,i)=>mfCard(g,i)).join('')}</div>
  <div class="mdots" aria-hidden="true">${MF.gs.map((g,i)=>`<i style="--c:${g[4][0]}"></i>`).join('')}</div><div id="mgl" class="mgl"></div></div>
  <div id="mnuf" class="mgl" hidden></div>${INAPP?'':`<div class="mnu-x">${ANDROID?`<button data-a="install">${ic('download')}Android აპი</button>`:''}<button data-a="rules">${ic('flag')}წესები</button></div>`}</div>`,'tall mnusheet');
 MF.el=$('#mflow');mfWire();mfMeasure();mfRender();
 $('#mnuq').oninput=e=>mfFind(e.target.value)};
function mfCard(g,i){const [a,b]=g[4],art=g[5]&&typeof svArt==='function'?svArt(g[5]):'',names=g[6].map(x=>x[2]);
 return `<button class="mfc" role="option" data-i="${i}" style="--a:${a};--b:${b}" aria-label="${g[2]}"><span class="mfc-top"><span class="mfc-ic">${ic(g[1])}</span><em>${g[6].length} გვერდი</em></span>
  <span class="mfc-art">${art||`<span class="mfc-big">${ic(g[1])}</span>`}</span><b>${g[2]}</b><small>${g[3]}</small>
  <span class="mfc-pills">${names.slice(0,2).map(t=>`<i>${t}</i>`).join('')}${names.length>2?`<i class="st">+${names.length-2}</i>`:''}</span><span class="mfc-sh"></span></button>`}
function mfMeasure(){const el=MF.el;if(!el)return;const cw=el.clientWidth||360,w=Math.max(160,Math.min(230,cw*.47)),h=w*1.4;el.style.setProperty('--mw',w+'px');el.style.height=(h+40)+'px';
 MF.w=w;MF.first=w*.62;MF.gap=Math.max(14,Math.min(64,(cw/2-MF.first-w*.1)/1.5));MF.step=MF.first}
const mfX=a=>a<=1?a*MF.first:MF.first+(a-1)*MF.gap;
function mfRender(){const el=MF.el;if(!el||!el.isConnected)return;const n=MF.gs.length,p=MF.p;
 $$('.mfc',el).forEach(c=>{const i=+c.dataset.i;let d=((i-p)%n+n)%n;if(d>n/2)d-=n;const ad=Math.abs(d),sg=Math.sign(d),t=Math.min(ad,1);
  c.style.transform=`translateX(${(sg*mfX(ad)).toFixed(1)}px) translateZ(${(-(t*110+Math.max(0,ad-1)*60)).toFixed(1)}px) rotateY(${(-sg*t*58).toFixed(2)}deg) scale(${(1-t*.06).toFixed(3)})`;
  c.style.opacity=ad<=2?'1':String(Math.max(0,(2.6-ad)/.6).toFixed(3));c.style.zIndex=String(100-Math.round(ad*10));c.style.setProperty('--sh',(.22*t).toFixed(3));c.style.visibility=ad>2.6?'hidden':'';
  c.classList.toggle('on',ad<.5);c.setAttribute('aria-selected',String(ad<.5));c.tabIndex=ad<.5?0:-1});
 const at=((Math.round(p)%n)+n)%n;if(at!==MF.at){MF.at=at;mfList()}}
function mfList(){const g=MF.gs[MF.at],el=$('#mgl');if(!g||!el)return;$$('.mdots i').forEach((d,i)=>d.classList.toggle('on',i===MF.at));
 el.innerHTML=`<div class="mgh"><span class="mgi" style="--a:${g[4][0]};--b:${g[4][1]}">${ic(g[1])}</span><b>${g[2]}</b><small>${g[6].length} გვერდი</small></div>${g[6].map((it,k)=>mfRow(it,g,k)).join('')}`}
function mfRow(it,g,k,showG){const s=typeof SVART!=='undefined'&&SVART[it[0]],a=s?s[0]:g[4][0],b=s?s[1]:g[4][1];
 return `<button class="mrw" style="--i:${Math.min(k,8)}" data-a="mnugo" data-p="${it[0]}"${it[4]?` data-arg="${it[4]}"`:''}><span class="mri" style="--a:${a};--b:${b}">${ic(it[1])}</span><span class="grow">${showG?`<em style="color:${g[4][0]}">${g[2]}</em>`:''}<b>${it[2]}</b><small>${it[3]}</small></span>${ic('chev')}</button>`}
function mfFind(q){q=q.trim().toLowerCase();const f=$('#mnuf'),b=$('#mnub');if(!q){f.hidden=true;b.hidden=false;return}b.hidden=true;f.hidden=false;
 const found=[];MF.gs.forEach(g=>g[6].forEach(it=>{if(it[2].toLowerCase().includes(q)||it[3].toLowerCase().includes(q)||g[2].toLowerCase().includes(q))found.push([it,g])}));
 f.innerHTML=found.length?found.map(([it,g],k)=>mfRow(it,g,k,true)).join(''):'<p class="mnone">ასეთი სერვისი ვერ ვიპოვე</p>'}
function mfGo(k){cancelAnimationFrame(MF.raf);const from=MF.p,dur=Math.min(640,280+Math.abs(k-from)*120),t0=performance.now();
 const step=now=>{const x=Math.min(1,(now-t0)/dur),e=1-Math.pow(1-x,3);MF.p=from+(k-from)*e;mfRender();if(x<1)MF.raf=requestAnimationFrame(step)};MF.raf=requestAnimationFrame(step)}
function mfWire(){const el=MF.el;let sx=0,sp=0,lx=0,lt=0,v=0,moved=0;
 el.addEventListener('pointerdown',e=>{cancelAnimationFrame(MF.raf);MF.drag=e.pointerId;sx=lx=e.clientX;sp=MF.p;lt=performance.now();v=0;moved=0});
 el.addEventListener('pointermove',e=>{if(MF.drag!==e.pointerId)return;const dx=e.clientX-sx;if(Math.abs(dx)>6&&!moved){moved=1;try{el.setPointerCapture(e.pointerId)}catch(x){}}
  if(moved){const now=performance.now();v=(e.clientX-lx)/Math.max(1,now-lt)*1000;lx=e.clientX;lt=now;MF.p=sp-dx/MF.step;mfRender()}});
 const up=e=>{if(MF.drag!==e.pointerId)return;MF.drag=null;if(!moved){const c=e.target.closest('.mfc');if(c&&!c.classList.contains('on')){const n=MF.gs.length,i=+c.dataset.i;let d=((i-MF.p)%n+n)%n;if(d>n/2)d-=n;mfGo(Math.round(MF.p+d))}return}
  mfGo(Math.abs(v)<300?Math.round(MF.p):(v<0?Math.floor(MF.p)+1:Math.ceil(MF.p)-1))};
 el.addEventListener('pointerup',up);el.addEventListener('pointercancel',up);
 el.addEventListener('keydown',e=>{if(e.key==='ArrowRight'){e.preventDefault();mfGo(Math.round(MF.p)+1)}else if(e.key==='ArrowLeft'){e.preventDefault();mfGo(Math.round(MF.p)-1)}});
 try{const ro=new ResizeObserver(()=>{if(el.isConnected){mfMeasure();mfRender()}else ro.disconnect()});ro.observe(el)}catch(e){}}
A.mnugo=t=>{const p=t.dataset.p,arg=t.dataset.arg;closeSheet(true);if(p==='admin'){openPage('admin');return}if(R[p]&&!PG[p]){go(p);return}openPage(p,arg)};
const CREATE=[['cpost','edit','პოსტი','ტექსტი, ფოტო, ჰეშთეგი'],['cnote','book','კონსპექტი','ფოტო, ტექსტი, საგანი'],['clesson','cal','ლექცია ცხრილში','დღე, დრო, აუდიტორია'],['cexam','clock','გამოცდა ან დავალება','ვადით'],['croom','video','სასწავლო ოთახი','ვიდეო-შეხვედრა კურსელებთან'],['cbirja','mic','დისკუსია','ხმოვანი ოთახი თემაზე'],['cphoto','image','ფოტო','ფილტრით და ჭრით'],['cclip','clips','კლიპი','მოკლე ვერტიკალური ვიდეო'],['cpoll','poll','გამოკითხვა','მეგობრების აზრი'],['cstory','story','ისტორია','ქრება 24 საათში'],['cevent','cal','შეხვედრა','ლექცია, ექსკურსია, წვეულება'],['clisting','store','განცხადება','გაყიდე ან გააჩუქე'],['cgroup','users','ჯგუფი','საერთო ინტერესით'],['cpage','mega','არხი ან გვერდი','ბიზნესი და რეკლამა'],['cgchat','msg','ჯგუფური ჩატი','რამდენიმე მეგობართან'],['clive','live','ლაივი','პირდაპირი ეთერი'],['cplace','map','ადგილი','კაფე, ბიბლიოთეკა, სივრცე'],['chelp','help','დახმარების თხოვნა','სისხლი, ცხოველი, მოხალისე'],['cride','pin','მგზავრობა','ადგილები მანქანაში'],['cjob','school','ვაკანსია','მოძებნე თანამშრომელი']];
A.create=()=>(navMark('create',A.create),sheet(head('შექმნა')+`<div class="createg">${CREATE.filter(x=>createOk(x[0])).map(([a,i,l,s])=>`<button data-a="${a}"><span class="cgi">${ic(i)}</span><b>${l}</b><small>${s}</small></button>`).join('')}</div>`,'short'));
A.cpost=()=>compose();
A.croom=()=>{S.rkind='supra';closeSheet();A.newroom()};
A.cbirja=()=>{S.rkind='birja';closeSheet();A.newroom()};
A.cride=()=>openPage('ridenew',undefined,['rides']);
A.clive=()=>{S.rkind='live';A.newroom()};
A.cplace=()=>openPage('placenew',undefined,['places']);
A.chelp=()=>openPage('helpnew',undefined,['help']);
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
document.addEventListener('click',e=>{const b=e.target.closest('[data-tab2]');if(b){go(b.dataset.tab2);markSide()}});
setInterval(()=>{if(document.body.classList.contains('wide')&&!document.hidden)loadSideR()},300000);

/* in-app banner for live notifications */
function banner(html,onTap){const b=$('#inapp');b.innerHTML=html;b.hidden=false;b.onclick=()=>{b.hidden=true;onTap&&onTap()};anim(b,[{opacity:0,transform:'translateY(-120%)'},{opacity:1,transform:'none'}],{duration:420,easing:SPRING});clearTimeout(banner.t);banner.t=setTimeout(()=>{b.hidden=true},4500)}
function listenNotes(){sb.channel('notes-'+ME.id).on('postgres_changes',{event:'INSERT',schema:'public',table:'notifications',filter:'user_id=eq.'+ME.id},({new:n})=>onNote(n)).subscribe()}
async function onNote(n){const r=n.ref||{};if(n.actor)try{await loadProfiles([n.actor])}catch(e){}
 const who=n.actor?`${av(n.actor,36)}<span class="grow"><b>${esc(pname(n.actor))}</b>`:kAv(36)+'<span class="grow">';
 if(n.kind==='message'){if(S.openConv===r.conv)return;S.unreadMsgs++;renderBadges();banner(`${who}<span>${esc(r.text||'ახალი შეტყობინება')}</span></span>`,()=>openChat(+r.conv));return}
 if(n.kind==='friend_req'&&n.actor){PENDING_IN.add(n.actor);if(S.page?.id==='friends')rp();else if(!S.page&&S.tab==='friends')R.friends()}else if(n.kind==='friend_ok'&&n.actor){FRIENDS.add(n.actor);PENDING_OUT.delete(n.actor)}else if(n.kind==='verified'){ME.verified=true}
 if(S.page?.id==='notes'&&n.kind!=='message'){NT.rows.unshift({...n,ref:r});ntDraw();store.set(ntSeenKey(),new Date().toISOString())}else{S.unreadNotes++;renderBadges()}
 banner(`${who}<span>${esc((NOTE_TXT[n.kind]||(()=>'ახალი შეტყობინება'))(r))}</span></span>`,()=>{const t=document.createElement('button');t.dataset.k=n.kind;t.dataset.r=JSON.stringify(r);t.dataset.u=n.actor||'';t.dataset.g=String(n.id||'');A.note(t)})}

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
 if(id==='chats'){go('chats');return true}
 if(id==='post'&&/^\d+$/.test(arg||'')){base();openPost(+arg);return true}
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
$('#tabs').addEventListener('click',e=>{const b=e.target.closest('.tab');if(!b)return;if(b.dataset.tab==='games'&&S.game&&S.tab==='games'&&!S.page){if(typeof A.lobby==='function')A.lobby();return}if(b.dataset.tab===S.tab&&!S.page&&view.scrollTop>10){view.scrollTo({top:0,behavior:RM()?'auto':'smooth'});return}go(b.dataset.tab)});
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
