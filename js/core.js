/* Peera · core: client, helpers, state, sheets, pages, translation, media */
const SUPA_URL='https://iasospzhhdedpilykpiu.supabase.co';
const SUPA_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlhc29zcHpoaGRlZHBpbHlrcGl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzMzk3NzIsImV4cCI6MjEwNzkxNTc3Mn0.iHnk-s1ePtNWJrn0Md3svxbNa2vhUTATNxuS3VPUfhI';
const sb=supabase.createClient(SUPA_URL,SUPA_KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});

const $=(s,r=document)=>r.querySelector(s),$$=(s,r=document)=>[...r.querySelectorAll(s)];
const view=$('#view');
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]);
const store={get(k,d){try{const v=localStorage.getItem('sufra:'+k);return v==null?d:JSON.parse(v)}catch(e){return d}},set(k,v){try{localStorage.setItem('sufra:'+k,JSON.stringify(v))}catch(e){}}};
const fmt=n=>n>=10000?Math.round(n/1000)+'K':n>=1000?(n/1000).toFixed(1).replace('.0','')+'K':String(n||0);
const MONTHS=['იანვარი','თებერვალი','მარტი','აპრილი','მაისი','ივნისი','ივლისი','აგვისტო','სექტემბერი','ოქტომბერი','ნოემბერი','დეკემბერი'];
const WDAYS=['კვირა','ორშაბათი','სამშაბათი','ოთხშაბათი','ხუთშაბათი','პარასკევი','შაბათი'];
function ago(ts){const d=(Date.now()-new Date(ts).getTime())/1000;if(d<60)return 'ახლა';if(d<3600)return Math.floor(d/60)+' წთ';if(d<86400)return Math.floor(d/3600)+' სთ';if(d<604800)return Math.floor(d/86400)+' დღე';const t=new Date(ts);return t.getDate()+' '+MONTHS[t.getMonth()].slice(0,3)}
function fdate(ts){const t=new Date(ts);return `${WDAYS[t.getDay()]}, ${t.getDate()} ${MONTHS[t.getMonth()]}, ${String(t.getHours()).padStart(2,'0')}:${String(t.getMinutes()).padStart(2,'0')}`}
function toast(t){const el=$('#toast');el.textContent=t;el.hidden=false;clearTimeout(toast.t);toast.t=setTimeout(()=>el.hidden=true,2800)}
const ERR={not_seller:'ჯერ გამყიდველი არ ხარ: გააგზავნე განაცხადი',already_seller:'შენ უკვე გამყიდველი ხარ',bad_title:'ჩაწერე პროდუქტის სახელი',bad_price:'ფასი მინიმუმ 10 მონეტა',bad_media:'ფოტო ვერ მიიღეს, ატვირთე ხელახლა',too_many:'მაქსიმუმ 50 პროდუქტი',not_approved:'ჯერ ადმინისტრატორმა უნდა დაადასტუროს',own_item:'საკუთარ პროდუქტს ვერ იყიდი',sold_out:'ამოიწურა',bad_delivery:'დაწერე, სად და როგორ მიიღებ',bad_name:'ჩაწერე სახელი',not_adult:'ეს 18 წლიდან შეიძლება',not_verified:'ჯერ ვერიფიკაცია გაიარე',too_new_payout:'ლარად გატანა რეგისტრაციიდან 30 დღის შემდეგ შეიძლება',below_min:'მინიმუმ 10,000 მონეტა, 100-ის ჯერადი',not_enough_cash:'ამდენი მონეტა არ გაქვს',bad_bet:'ფსონი ლიმიტს გარეთაა',casino_day_cap:'დღევანდელი ფსონების ლიმიტი ამოიწურა. ხვალ ისევ შეგიძლია',games_locked:'თამაშები დროებით მხოლოდ ადმინისტრატორისთვისაა',avl_late:'ამ ფრენაზე ფსონის დადება დასრულდა',avl_in:'ამ ფრენაზე უკვე დადე',casino_closed:'ეს თამაში ახლა დახურულია',payouts_closed:'ლარად გატანა ახლა დახურულია: ის აქციის დროს იხსნება',free_only:'პროგნოზი ახლა მხოლოდ უფასოა',bad_iban:'IBAN არასწორია',bad_holder:'ჩაწერე ანგარიშის მფლობელის სახელი და გვარი',payout_open:'ერთი განაცხადი უკვე ელოდება',budget_full:'ამ თვის გატანის ლიმიტი შევსებულია. სცადე მომავალ თვეში',note_needed:'დაწერე მიზეზი',not_pending:'ეს უკვე გადაწყვეტილია',own_post:'საკუთარ ფოტოს საჩუქარს ვერ გაუგზავნი',not_photo:'საჩუქარი მხოლოდ ფოტოს შეიძლება',bad_gift:'ეს საჩუქარი აღარ არსებობს',bonus_only:'პროგნოზი ახლა მხოლოდ უფასოა',already_on:'აქცია უკვე ჩართულია',too_new:'სტაროსტა რეგისტრაციიდან 3 დღის შემდეგ შეგიძლია გახდე',starosta_full:'ამ ჯგუფს უკვე ორი სტაროსტა ჰყავს',not_member:'ჯერ ჯგუფში გაწევრიანდი',rate_limit:'ძალიან ხშირად წერ. ცოტა ხანში სცადე',spam_duplicate:'ერთი და იგივე ტექსტი ბევრგან სპამს ჰგავს, ამიტომ შეჩერდა',spam_links:'ახალი ანგარიში ბმულებს ჯერ შეზღუდულად აზიარებს. სცადე მოგვიანებით',album_full:'ალბომში მაქსიმუმ 1000 ფოტოა',bad_role:'ამ როლის მინიჭება შეუძლებელია',not_enough_coins:'მონეტები არ გყოფნის',already_claimed:'დღევანდელი ბონუსი უკვე აიღე',adults_only:'ეს ნაწილი მხოლოდ 18+ მომხმარებლებისთვისაა',dating_off:'ჯერ ჩართე გაცნობის პროფილი',blocked:'ეს მომხმარებელი დაბლოკილია',dm_friends_only:'ამ ადამიანს მხოლოდ მეგობრები წერენ',minor_protected:'ამ ადამიანს ახლა ვერ დაუკავშირდები: მას მხოლოდ მეგობრები, ოჯახი და კლასელები ან კურსელები სწერენ',not_allowed:'ეს მოქმედება ახლა შეუძლებელია',too_young:'Peera-ზე რეგისტრაცია 13 წლიდანაა შესაძლებელი',staff_only:'მხოლოდ მოდერატორებისთვის',post_must_belong_to_your_page:'რეკლამა მხოლოდ შენი გვერდის პოსტზე შეიძლება'};
function errMsg(e){const m=String(e?.message||e||'');for(const k in ERR)if(m.includes(k))return ERR[k];if(/row-level security|permission denied/i.test(m))return 'ამის უფლება არ გაქვს';if(/duplicate key/i.test(m))return 'ეს უკვე არსებობს';if(/Failed to fetch|NetworkError/i.test(m))return 'ინტერნეტთან კავშირი არ არის';return 'შეცდომა: '+m.slice(0,120)}
async function q(p){const r=await p;if(r.error)throw r.error;return r.data}
async function rpc(fn,args){return q(sb.rpc(fn,args||{}))}

/* state */
const S={tab:'home',page:null,feed:'for',game:null,ptab:'posts',online:new Set(),unreadMsgs:0,unreadNotes:0};
const R={},A={},PG={};
let ME=null;
const PC=new Map();
const PCOLS='id,username,name,bio,city,hue,avatar_url,cover_url,privacy,dating,gender,is_business,verified,role,banned,rating,last_seen,created_at,nameday,nameday_label,surname';
/* people search leaves out whom the viewer may not reach (an adult and a pupil under 18 who do not know each other);
   if the check is not there, everybody stays */
/* whom this person may talk to and challenge in games: friends, family, the same class or course, or someone of the
   same age group (reachable_talk). Remembered ten minutes; when the check cannot be made nobody new is let through */
const RCH=new Map();
async function reachTalk(ids){ids=[...new Set((ids||[]).filter(u=>u&&typeof ME!=='undefined'&&ME&&u!==ME.id))];const now=Date.now(),need=ids.filter(u=>!(RCH.has(u)&&now-RCH.get(u).t<6e5));
 if(need.length){try{const ok=await q(sb.rpc('reachable_talk',{p_ids:need}));const s=new Set(Array.isArray(ok)?ok:need);need.forEach(u=>RCH.set(u,{v:s.has(u),t:now}))}catch(e){}}
 return new Set(ids.filter(u=>(typeof FRIENDS!=='undefined'&&FRIENDS.has(u))||(RCH.get(u)&&RCH.get(u).v)))}
async function reachOnly(ps){if(!ps||!ps.length)return ps;try{const ok=await q(sb.rpc('reachable',{p_ids:ps.map(p=>p.id)}));if(!Array.isArray(ok))return ps;const s=new Set(ok);return ps.filter(p=>p.id===ME.id||s.has(p.id)||(typeof FRIENDS!=='undefined'&&FRIENDS.has(p.id)))}catch(e){return ps}}
async function loadProfiles(ids){const need=[...new Set(ids.filter(Boolean))].filter(id=>!PC.has(id)&&id!==ME?.id);if(need.length){for(let i=0;i<need.length;i+=100){const d=await q(sb.from('profiles').select(PCOLS).in('id',need.slice(i,i+100)));d.forEach(p=>PC.set(p.id,p))}}}
const prof=id=>id&&ME&&id===ME.id?ME:PC.get(id)||{id,name:'მომხმარებელი',hue:200};
const pname=id=>prof(id).name;
function av(p,s=40){if(p==='me')p=ME;else if(typeof p==='string')p=prof(p);p=p||{};const st=`--s:${s}px;--h:${(p.hue??200)%360}`;
 return p.avatar_url?`<img class="av" style="${st}" src="${esc(p.avatar_url)}" alt="" loading="lazy">`:`<span class="av" style="${st}" aria-hidden="true">${esc((String(p.name||'?').trim()[0])||'?')}</span>`}
/* the drawn characters at the card tables: their faces are one strip of pictures */
const CASTI=['m1','m2','m3','m4','m5','f1','f2','f3','f4','f5'];
const castAv=(id,s)=>`<span class="av cav" style="--s:${s}px;background-position:${CASTI.indexOf(id)*100/9}% 0" aria-hidden="true"></span>`;
const avAny=(x,s)=>typeof x==='string'||x?.id?av(x,s):x&&CASTI.includes(x.cast)?castAv(x.cast,s):x&&/^https:/.test(String(x.u||''))?`<img class="av" style="--h:${Math.abs(Number(x.h)||200)%360};--s:${s}px" src="${esc(x.u)}" alt="" loading="lazy">`:`<span class="av" style="--h:${Math.abs(Number(x&&x.h)||200)%360};--s:${s}px" aria-hidden="true">${esc(String((x&&x.n)||'?').slice(0,1)||'?')}</span>`;
const vb=p=>(typeof p==='string'?prof(p):p)?.verified?`<span class="vb" title="ვერიფიცირებული" aria-label="ვერიფიცირებული">${ic('check')}</span>`:'';
const isOnline=id=>S.online.has(id);
const isStaff=()=>ME&&(ME.role==='admin'||ME.role==='moderator');
const age=bd=>{if(!bd)return null;const b=new Date(bd),n=new Date();let a=n.getFullYear()-b.getFullYear();if(n<new Date(n.getFullYear(),b.getMonth(),b.getDate()))a--;return a};
const isAdult=()=>(age(ME?.birthday)||0)>=18;

/* sheets */
let SHEET_TOK=0,SHEET_CB=null;
function sheet(html,cls='',onClose){if(SHEET_CB){const f=SHEET_CB;SHEET_CB=null;try{f()}catch(e){}}SHEET_TOK++;SHEET_CB=onClose||null;const s=$('#sheet');s.classList.remove('closing');s.innerHTML=`<div class="panel ${cls}" role="dialog" aria-modal="true">${html}</div>`;s.hidden=false;
 const f=$('input:not([type=file]):not([type=range]),textarea',s);if(f&&!/Mobi/.test(navigator.userAgent))f.focus();dragSheet($('.panel',s));staggerIn($$('.ph-body>*,.reasons>*,.svc>*,.gifts>*,.jchoice>*,.match>*',s).slice(0,10),35,80);navOpen('sheet')}
function closeSheet(nav){const s=$('#sheet');if(s.hidden)return;if(!nav)navKill('sheet');if(SHEET_CB){const f=SHEET_CB;SHEET_CB=null;try{f()}catch(e){}}const tok=++SHEET_TOK;if(RM()||!$('.panel',s)){s.hidden=true;s.innerHTML='';return}s.classList.add('closing');setTimeout(()=>{if(tok!==SHEET_TOK)return;s.hidden=true;s.innerHTML='';s.classList.remove('closing')},220)}
const head=(t,extra='')=>`<div class="ph-head"><h2>${t}</h2><span class="sp"></span>${extra}<button class="ibtn" data-a="close" aria-label="დახურვა">${ic('x')}</button></div>`;
A.close=()=>closeSheet();
function confirmSheet(title,text,okLabel,onOk,danger,inLayer){
 if(inLayer){layer(lhead(title)+`<div class="ph-body"><p>${text}</p></div><div class="ph-foot"><button class="btn ghost" data-a="closelayer">გაუქმება</button><span class="sp"></span><button class="btn${danger?' danger':''}" id="cfokl">${okLabel}</button></div>`);$('#cfokl').onclick=async()=>{const b=$('#cfokl');b.disabled=true;try{await onOk();closeLayer()}catch(e){toast(errMsg(e));b.disabled=false}};return}
 sheet(head(title)+`<div class="ph-body"><p>${text}</p></div><div class="ph-foot"><button class="btn ghost" data-a="close">გაუქმება</button><span class="sp"></span><button class="btn${danger?' danger':''}" id="cfok">${okLabel}</button></div>`,'short');$('#cfok').onclick=async()=>{const b=$('#cfok');b.disabled=true;try{await onOk();closeSheet()}catch(e){toast(errMsg(e));b.disabled=false}}}
const skel=(n=3)=>Array.from({length:n},()=>'<div class="skel"><span class="sk-av"></span><span class="sk-lines"><i></i><i></i><i style="width:60%"></i></span></div>').join('');
const empty=(t,sub='',btn='')=>`<div class="empty3"><h3>${t}</h3>${sub?`<p>${sub}</p>`:''}${btn}</div>`;

/* pages */
const pgHead=(t,extra='')=>`<div class="pghead"><button class="ibtn" data-a="back" aria-label="უკან">${ic('back')}</button><h2>${t}</h2>${extra}</div>`;
function openPage(id,arg,back,noPush){if(!PG[id])return;closeSheet(true);stopMedia();S.page={id,arg,back};view.className=PG[id].cls||'';const app=$('#app');app.classList.toggle('media',PG[id].cls==='is-clips');app.classList.remove('barhidden');view.scrollTop=0;
 if(!noPush)navStep();
 const r=PG[id].r(arg);if(typeof earnBar==='function')try{earnBar(id)}catch(e){}const d=S._dir||1;S._dir=0;enterView(28*d);return r}
const rp=()=>{if(S.page)return PG[S.page.id].r(S.page.arg)};
A.page=t=>openPage(t.dataset.p,t.dataset.arg);
/* the arrow in a page header does exactly what the phone's back gesture does */
A.back=()=>{stopMedia();if(NAV.ready&&NAV.cur>0){history.back();return}const b=S.page&&S.page.back;NAV.busy++;try{if(b){S._dir=-1;openPage(b[0],b[1],null,true)}else go(S.tab,-28)}finally{NAV.busy--}navReplace()};

/* back button: every step a person takes is one browser history entry, so the phone's back gesture undoes exactly one step.
   steps are tabs, pages and anything that opens on top (sheets, layers, the photo viewer, stories).
   anything new gets this for free as long as it opens through openPage, go, sheet, layer, openPV, openImage or openStory.
   a step that was already closed by hand is skipped; at the very start, back asks once more before leaving the site. */
const NAV={list:[],cur:-1,seq:0,busy:0,ready:false,boot:Math.random().toString(36).slice(2,9),next:null,adopt:null,expect:null,keep:false,exitAt:0,exitT:0,guarded:false};
const OVE={sheet:null,layer:null,pv:null,story:null,game:null};
const navOk=()=>!navigator.userActivation||navigator.userActivation.hasBeenActive;
const navBase=()=>S.page?{pg:S.page.id,arg:S.page.arg??null,back:S.page.back||null}:{tab:S.tab||'home'};
const sameBase=(a,b)=>!!a&&!!b&&(a.pg||b.pg?a.pg===b.pg&&String(a.arg??'')===String(b.arg??''):(a.tab||'home')===(b.tab||'home'));
const navUrl=b=>b.pg?'#'+b.pg+(b.arg!=null?'-'+b.arg:''):b.tab&&b.tab!=='home'?'#'+b.tab:location.pathname+location.search;
const navState=e=>({app:1,s:NAV.boot,id:e.id,base:e.base});
function navPush(ov){if(!NAV.ready||NAV.busy||!navOk())return null;clearTimeout(NAV.exitT);
 const e={id:++NAV.seq,base:navBase(),ov:ov||null,alive:true};NAV.list.length=NAV.cur+1;NAV.list.push(e);NAV.cur=NAV.list.length-1;
 try{history.pushState(navState(e),'',navUrl(e.base))}catch(x){}return e}
function navReplace(){const e=NAV.list[NAV.cur];if(!e)return;e.base=navBase();try{history.replaceState(navState(e),'',navUrl(e.base))}catch(x){}}
/* a tab or a page; going to the same place again does not add a step */
function navStep(){if(!NAV.ready||NAV.busy)return;const c=NAV.list[NAV.cur];if(c&&!c.ov&&sameBase(c.base,navBase()))navReplace();else navPush(null)}
/* sheets that can be drawn again (chats, a chat, notifications, comments, the menus) say how, so back returns to them after a page */
function navMark(key,reopen){NAV.next={key,reopen}}
function navOpen(type){const nx=NAV.next;NAV.next=null;
 if(NAV.adopt&&nx&&NAV.adopt.ov&&NAV.adopt.ov.type===type&&NAV.adopt.ov.key===nx.key){OVE[type]=NAV.adopt;NAV.adopt=null;return}
 if(NAV.busy)return;OVE[type]=navPush({type,key:nx?nx.key:'',reopen:nx?nx.reopen:null})}
/* closed by hand: its steps are done and back will not bring it again */
function navKill(type){if(NAV.busy||!NAV.ready)return;let i=NAV.cur;while(i>0&&NAV.list[i]&&NAV.list[i].ov)i--;for(let k=i+1;k<NAV.list.length;k++){const e=NAV.list[k];if(e.ov&&e.ov.type===type)e.alive=false}}
const OVS=[['layer',()=>!$('#layer').hidden,()=>closeLayer(true)],['pv',()=>{const p=$('#pv');return !!p&&!p.hidden},()=>closePV(true)],['story',()=>!$('#story').hidden,()=>closeStory(true)],['sheet',()=>!$('#sheet').hidden,()=>closeSheet(true)],['game',()=>S.tab==='games'&&!!S.game&&!S.page,()=>A.lobby()]];
const ovShown=type=>{const o=OVS.find(x=>x[0]===type);return !!o&&o[1]()};
/* close everything that belongs to a later step (or to no step) */
function navCloseAbove(j){let ch=false;for(const[type,shown,close]of OVS){if(!shown())continue;const i=OVE[type]?NAV.list.indexOf(OVE[type]):-1;if(j<0||i<0||i>j){close();ch=true}}return ch}
function navGoBase(b){S._dir=-1;if(b&&b.pg&&PG[b.pg])openPage(b.pg,b.arg??undefined,b.back||null,true);else go(b&&b.tab&&R[b.tab]?b.tab:'home',-28)}
/* step forward again without drawing anything: keeps a step above the start, so back never drops out of the site by itself */
function navForward(keep){const nx=NAV.list[NAV.cur+1];if(!nx)return;NAV.expect=nx.id;NAV.keep=!!keep;history.forward()}
function navInit(){NAV.list=[{id:++NAV.seq,base:navBase(),ov:null,alive:true}];NAV.cur=0;NAV.ready=true;try{history.replaceState(navState(NAV.list[0]),'',navUrl(NAV.list[0].base))}catch(x){}
 const evs=['pointerup','keydown','click'],g=()=>{if(NAV.guarded||!navOk())return;NAV.guarded=true;evs.forEach(k=>document.removeEventListener(k,g,true));if(NAV.list.length===1&&NAV.cur===0)navPush(null)};
 evs.forEach(k=>document.addEventListener(k,g,true))}
/* an in-sheet back arrow: when the sheet before this one is still there, step back to it */
function navBackTo(key){const p=NAV.list[NAV.cur-1],c=NAV.list[NAV.cur];if(NAV.ready&&p&&p.ov&&p.alive&&p.ov.key===key&&c&&c.ov){history.back();return true}return false}
function navPop(st){if(!NAV.ready)return;const j=st&&st.app&&st.s===NAV.boot?NAV.list.findIndex(x=>x.id===st.id):-1;
 if(NAV.expect!=null){const ex=NAV.expect,keep=NAV.keep;NAV.expect=null;NAV.keep=false;if(j>=0&&NAV.list[j].id===ex){NAV.cur=j;if(!keep){const e=NAV.list[j];e.base=navBase();e.ov=null;e.alive=false;try{history.replaceState(navState(e),'',navUrl(e.base))}catch(x){}}return}}
 if(j<0){if(Date.now()-NAV.exitAt<4000){history.back();return}
  NAV.busy++;try{navCloseAbove(-1);const b=st&&(st.base||(st.pg?{pg:st.pg,arg:st.arg}:st.tab?{tab:st.tab}:null));if(b){if(!sameBase(b,navBase()))navGoBase(b)}else if(!route(location.hash))go('home',-28)}finally{NAV.busy--}
  NAV.list=[{id:++NAV.seq,base:navBase(),ov:null,alive:true}];NAV.cur=0;navReplace();navPush(null);return}
 if(!$('#call').hidden){NAV.cur=j;navForward(true);return}
 const t=NAV.list[j];NAV.cur=j;clearTimeout(NAV.exitT);let changed=false;
 NAV.busy++;
 try{changed=navCloseAbove(j);
  if(!sameBase(t.base,navBase())){navGoBase(t.base);changed=true}
  if(t.ov&&t.alive&&t.ov.reopen&&!(OVE[t.ov.type]===t&&ovShown(t.ov.type))){NAV.adopt=t;setTimeout(()=>{if(NAV.adopt===t)NAV.adopt=null},5000);try{t.ov.reopen()}catch(x){}changed=true}
  if(j===0&&!changed&&(S.page||S.tab!=='home')){go('home',-28);changed=true}}
 finally{NAV.busy--}
 if(j===0){if(changed){navReplace();navForward();return}
  NAV.exitAt=Date.now();toast('გასასვლელად კიდევ ერთხელ დააჭირე „უკან“');NAV.exitT=setTimeout(()=>{if(NAV.cur===0)navForward()},2600);return}
 if(!changed)history.back()}
window.addEventListener('popstate',e=>{if(ME)navPop(e.state)});
let LIVE_T=null;function stopMedia(){if(LIVE_T){clearInterval(LIVE_T);LIVE_T=null}$$('video',view).forEach(v=>{try{v.pause()}catch(e){}});if(S.chanCleanup){try{S.chanCleanup()}catch(e){}S.chanCleanup=null}}

/* translation: detect locally, translate on request through the edge function */
const siteLang=()=>ME?.lang||'ka';
const TXT=[],TXI=new Map(),TR=new Map();
function txId(t){let i=TXI.get(t);if(i==null){i=TXT.push(t)-1;TXI.set(t,i)}return i}
const linkify=s=>esc(s).replace(/(^|\s)#([A-Za-z0-9_ა-ჿ]{2,40})/g,(m,a,t)=>`${a}<button class="hash" data-a="tag" data-t="${t.toLowerCase()}">#${t}</button>`).replace(/(^|\s)@([a-z0-9_.]{3,24})/g,(m,a,u)=>`${a}<button class="hash" data-a="uname" data-u="${u}">@${u}</button>`).replace(/https?:\/\/[^\s<]+/g,u=>{const h=ownHash(u);return h?`<a href="${u}" data-a="ilink" data-h="${h}">${u}</a>`:`<a href="${u}" target="_blank" rel="noopener nofollow ugc">${u}</a>`});
/* a link to the site itself (the new address, the old one, or wherever it runs) opens inside the app */
const OWNH=/^(www\.)?peera\.my$|^sufra-phi\.vercel\.app$/i;
function ownHash(u){try{const x=new URL(String(u).replace(/&amp;/g,'&'));return (OWNH.test(x.hostname)||x.host===location.host)&&/^#[a-z]+(-[^\s"'<>()]+)?$/.test(x.hash)?x.hash:''}catch(e){return ''}}
A.ilink=t=>{if(!route(t.dataset.h))window.open(t.href,'_blank','noopener')};
function tx(t,mode='post'){t=String(t||'');if(!t.trim())return '';const L=detect(t);
 if(L===siteLang())return mode==='bubble'?`<div class="bubble">${linkify(t)}</div>`:mode==='inline'?`<span>${linkify(t)}</span>`:`<p class="txt">${linkify(t)}</p>`;
 const i=txId(t),lab=L==='ka-lat'?'ქართულ ასოებზე გადაყვანა':'თარგმნა · '+(LANGS[L]||LANGS.xx).n;
 if(mode==='bubble')return `<div class="bubwrap txw" data-ti="${i}"><div class="bubble"><span class="tx">${linkify(t)}</span></div><button class="trb ic" data-a="tr" aria-label="${lab}" title="${lab}">${ic('globe')}</button></div>`;
 if(mode==='inline')return `<span class="txw inl" data-ti="${i}"><span class="tx">${linkify(t)}</span><button class="trb ic sm" data-a="tr" aria-label="${lab}" title="${lab}">${ic('globe')}</button></span>`;
 const short=L==='ka-lat'?'ქართული ასოებით':'თარგმნა';
 return `<div class="txw${mode==='media'?' onmedia':''}" data-ti="${i}"><p class="txt tx">${linkify(t)}</p><button class="trb" data-a="tr" data-l="${short}" aria-label="${lab}">${ic('globe')}<span>${short}</span></button></div>`}
async function translate(src,L){
 try{const{data,error}=await sb.functions.invoke('translate',{body:{text:src,source:L,target:siteLang()}});
  if(!error&&data&&data.text)return{text:data.text,meta:(L==='ka-lat'?'გადაყვანილია ქართულ ასოებზე':'თარგმნილია ავტომატურად')+' · ორიგინალი: '+((LANGS[L]&&L!=='xx')?LANGS[L].n:(data.source||'უცხო ენა'))}}catch(e){}
 if(L==='ka-lat')return{text:translit(src),meta:'გადაყვანილია ქართულ ასოებზე'};
 throw new Error('თარგმნა ახლა ვერ მოხერხდა. სცადე ცოტა ხანში')}
function setTrBtn(t,on){const s=$('span',t);if(s)s.textContent=on?'ორიგინალი':(t.dataset.l||'თარგმნა');t.setAttribute('aria-pressed',String(on))}
A.tr=async t=>{const w=t.closest('.txw'),i=+w.dataset.ti,src=TXT[i],el=$('.tx',w);if(!el)return;
 if(w.dataset.on){el.innerHTML=linkify(src);w.dataset.on='';const m=$('.trmeta',w);if(m)m.remove();setTrBtn(t,false);return}
 const done=r=>{el.textContent=r.text;w.dataset.on='1';const m=document.createElement('span');m.className='trmeta';m.textContent=r.meta;if(w.classList.contains('bubwrap'))$('.bubble',w).appendChild(m);else if(w.classList.contains('inl'))w.appendChild(m);else w.insertBefore(m,t);setTrBtn(t,true)};
 if(TR.has(i))return done(TR.get(i));
 t.setAttribute('aria-busy','true');const s=$('span',t);if(s)s.textContent='ითარგმნება…';
 try{const r=await translate(src,detect(src));TR.set(i,r);if(t.isConnected)done(r)}catch(e){toast(e.message);if(t.isConnected)setTrBtn(t,false)}finally{t.removeAttribute('aria-busy')}};

/* media: pick, edit, upload, record */
function pickFile(accept,opts={}){return new Promise(res=>{const i=document.createElement('input');i.type='file';i.accept=accept;if(opts.multiple)i.multiple=true;if(opts.capture)i.setAttribute('capture',opts.capture);i.hidden=true;document.body.appendChild(i);
 i.onchange=()=>{res(opts.multiple?[...i.files]:(i.files[0]||null));i.remove()};i.addEventListener('cancel',()=>{res(opts.multiple?[]:null);i.remove()});i.click()})}
const loadImg=src=>new Promise((res,rej)=>{const im=new Image();im.onload=()=>res(im);im.onerror=rej;im.src=src});
const upPath=ext=>`${ME.id}/${Date.now().toString(36)}-${Math.random().toString(36).slice(2,8)}.${ext}`;
/* the same upload, with a progress callback (big videos): straight to storage, as the client library does it */
async function uploadBlobP(blob,ext,onp,bucket='media'){let tok='';try{tok=(await sb.auth.getSession()).data.session?.access_token||''}catch(e){}if(!tok||!window.XMLHttpRequest||!window.FormData)return uploadBlob(blob,ext,bucket);
 const path=upPath(ext);return new Promise((res,rej)=>{const x=new window.XMLHttpRequest(),fd=new window.FormData();fd.append('cacheControl','31536000');fd.append('',blob,'file.'+ext);
  x.open('POST',`${SUPA_URL}/storage/v1/object/${bucket}/${path.split('/').map(encodeURIComponent).join('/')}`);x.setRequestHeader('Authorization','Bearer '+tok);x.setRequestHeader('apikey',SUPA_KEY);x.setRequestHeader('x-upsert','false');
  x.upload.onprogress=e=>{if(e.lengthComputable&&onp)onp(e.loaded/e.total)};
  x.onload=()=>{if(x.status>=200&&x.status<300){if(onp)onp(1);res(bucket==='media'?sb.storage.from('media').getPublicUrl(path).data.publicUrl:path)}else{let m='';try{m=JSON.parse(x.responseText).message}catch(e){}rej(new Error(m||('upload '+x.status)))}};
  x.onerror=()=>rej(new Error('Failed to fetch'));x.send(fd)})}
async function uploadBlob(blob,ext,bucket='media'){const path=upPath(ext);
 const{error}=await sb.storage.from(bucket).upload(path,blob,{contentType:blob.type||undefined,cacheControl:'31536000',upsert:false});if(error)throw error;
 return bucket==='media'?sb.storage.from('media').getPublicUrl(path).data.publicUrl:path}
/* small copies: lists load a ~1080px or ~480px copy, the viewer opens the full photo; videos get a poster frame */
async function scaledCopy(src,max,qual){const im=await loadImg(src);const W=im.naturalWidth||im.width,H=im.naturalHeight||im.height,sc=Math.min(1,max/Math.max(W,H));
 const c=document.createElement('canvas');c.width=Math.max(1,Math.round(W*sc));c.height=Math.max(1,Math.round(H*sc));c.getContext('2d').drawImage(im,0,0,c.width,c.height);
 return {b:await new Promise(r=>c.toBlob(r,'image/jpeg',qual)),w:W,h:H}}
/* the poster is a real frame: on phones (iOS above all) a video that has not played paints black, so it plays a moment first,
   and a frame that comes out black is tried again further in; if every try is black there is no poster and the video shows itself */
function videoPoster(blob,max=720){return new Promise(res=>{const v=document.createElement('video'),u=URL.createObjectURL(blob);let done=false,ts=[],k=0;
 const fin=x=>{if(done)return;done=true;clearTimeout(tm);try{v.pause()}catch(e){}URL.revokeObjectURL(u);v.removeAttribute('src');try{v.load()}catch(e){}res(x)},tm=setTimeout(()=>fin(null),12000);
 v.muted=true;v.defaultMuted=true;v.playsInline=true;v.setAttribute('playsinline','');v.setAttribute('muted','');v.preload='auto';
 const seek=()=>{if(k>=ts.length){fin(v.videoWidth?{b:null,w:v.videoWidth,h:v.videoHeight}:null);return}try{v.currentTime=ts[k++]}catch(e){fin(null)}};
 const blank=()=>{try{const c=document.createElement('canvas');c.width=c.height=24;const x=c.getContext('2d',{willReadFrequently:true});x.drawImage(v,0,0,24,24);const d=x.getImageData(0,0,24,24).data;let s=0,s2=0,n=0;
  for(let i=0;i<d.length;i+=4){const l=.3*d[i]+.59*d[i+1]+.11*d[i+2];s+=l;s2+=l*l;n++}const m=s/n,sd=Math.sqrt(Math.max(0,s2/n-m*m));return m<10&&sd<4}catch(e){return false}};
 const grab=()=>{if(done)return;if(blank()){seek();return}
  try{const sc=Math.min(1,max/Math.max(v.videoWidth,v.videoHeight)||1),c=document.createElement('canvas');c.width=Math.max(1,Math.round(v.videoWidth*sc));c.height=Math.max(1,Math.round(v.videoHeight*sc));c.getContext('2d').drawImage(v,0,0,c.width,c.height);c.toBlob(b=>fin(b?{b,w:v.videoWidth,h:v.videoHeight}:null),'image/jpeg',.8)}catch(e){fin(null)}};
 const frame=f=>{if(v.requestVideoFrameCallback){let ok=false;v.requestVideoFrameCallback(()=>{ok=true;f()});setTimeout(()=>{if(!ok)f()},400)}else setTimeout(f,80)};
 v.onloadedmetadata=()=>{const d=isFinite(v.duration)&&v.duration>0?v.duration:2;ts=[Math.min(.5,d/4),d*.3,d*.6].filter((t,i,a)=>t<d&&a.indexOf(t)===i)};
 let began=false;v.onloadeddata=()=>{if(began)return;began=true;const go=()=>{try{v.pause()}catch(e){}seek()},r=v.play();if(r&&r.then)r.then(()=>frame(go)).catch(go);else go()};
 v.onseeked=()=>frame(grab);v.onerror=()=>fin(null);v.src=u})}
async function uploadMedia(blob,type,onp){
 if(type==='video'){const m={url:await uploadBlobP(blob,extOf(blob),onp),type:'video'};if(blob._dur)m.d=Math.round(blob._dur*10)/10;
  try{const p=blob._poster||blob._w?{b:blob._poster,w:blob._w,h:blob._h}:await videoPoster(blob);if(p&&p.w){m.w=p.w;m.h=p.h}if(p&&p.b)m.poster=await uploadBlob(p.b,'jpg')}catch(e){}return m}
 const gif=blob.type==='image/gif',m={url:await uploadBlob(blob,gif?'gif':'jpg'),type:'image'};if(gif)return m;
 const src=URL.createObjectURL(blob);
 try{const md=await scaledCopy(src,1080,.82);m.w=md.w;m.h=md.h;const big=Math.max(md.w,md.h)>1200;
  const sm=await scaledCopy(src,480,.74);const[a,b]=await Promise.all([big&&md.b?uploadBlob(md.b,'jpg'):null,sm.b&&Math.max(md.w,md.h)>560?uploadBlob(sm.b,'jpg'):null]);if(a)m.md=a;if(b)m.sm=b}catch(e){}
 finally{URL.revokeObjectURL(src)}return m}
const safeU=u=>/^https?:\/\//.test(String(u||''))?String(u):'';
const mMd=m=>safeU(m.md)||m.url,mSm=m=>safeU(m.sm)||safeU(m.md)||m.url,mPoster=m=>safeU(m.poster);
const extOf=f=>{const m=((f.type||'').split('/')[1]||'').split(';')[0].trim();return({jpeg:'jpg','quicktime':'mov','x-m4a':'m4a','mpeg':'mp3','x-matroska':'mkv','3gpp':'3gp'})[m]||m.replace(/[^a-z0-9]/g,'').slice(0,5)||'bin'};
const FILTERS=[['none','ბუნებრივი',''],['warm','თბილი','sepia(.25) saturate(1.3) hue-rotate(-8deg)'],['cool','ცივი','saturate(1.1) hue-rotate(12deg) brightness(1.03)'],['bw','შავ-თეთრი','grayscale(1) contrast(1.1)'],['vintage','ვინტაჟი','sepia(.45) contrast(.95) brightness(1.05) saturate(.85)'],['vivid','კაშკაშა','saturate(1.6) contrast(1.08)'],['fade','მქრქალი','contrast(.85) brightness(1.1) saturate(.8)']];
const RATIOS=[['orig','ორიგინალი',0],['1','1:1',1],['45','4:5',.8],['169','16:9',16/9],['916','9:16',9/16]];
/* a second layer above sheets, for the photo editor and the voice recorder */
let LAYER_CB=null;
function layer(html,onClose){const el=$('#layer');if(LAYER_CB){const f=LAYER_CB;LAYER_CB=null;try{f()}catch(e){}}LAYER_CB=onClose||null;el.innerHTML=`<div class="panel" role="dialog" aria-modal="true">${html}</div>`;el.hidden=false;navOpen('layer');return el}
function closeLayer(nav){const el=$('#layer');if(el.hidden)return;if(!nav)navKill('layer');if(LAYER_CB){const f=LAYER_CB;LAYER_CB=null;try{f()}catch(e){}}el.hidden=true;el.innerHTML=''}
A.closelayer=()=>closeLayer();
const lhead=t=>`<div class="ph-head"><h2>${t}</h2><span class="sp"></span><button class="ibtn" data-a="closelayer" aria-label="დახურვა">${ic('x')}</button></div>`;
function editImage(file,opt={}){return new Promise(async resolve=>{let done=false;const fin=v=>{if(!done){done=true;resolve(v)}};
 let im;try{im=await loadImg(URL.createObjectURL(file))}catch(e){toast('ფოტო ვერ გაიხსნა');return fin(null)}
 const st={f:'none',r:opt.ratio||'orig',rot:0,b:100,max:opt.max||(ECO()?1080:1600)};const ratios=opt.ratios?RATIOS.filter(r=>opt.ratios.includes(r[0])):RATIOS;
 const L=layer(lhead(opt.title||'ფოტოს რედაქტირება')+`<div class="ph-body ed"><div class="edwrap"><canvas id="edc"></canvas></div>
  ${ratios.length>1?`<div class="chipsbar" role="group" aria-label="ჭრის ფორმა">${ratios.map(r=>`<button data-r="${r[0]}" aria-pressed="${st.r===r[0]}">${r[1]}</button>`).join('')}</div>`:''}
  <div class="chipsbar filt" role="group" aria-label="ფილტრი">${FILTERS.map(f=>`<button data-f="${f[0]}" aria-pressed="${st.f===f[0]}"><span class="fsw" style="filter:${f[2]||'none'}"></span>${f[1]}</button>`).join('')}</div>
  <label class="fld">სიკაშკაშე<input type="range" id="edb" min="60" max="140" value="100"></label></div>
  <div class="ph-foot"><button class="btn ghost" id="edrot">${ic('repost')}მობრუნება</button><span class="sp"></span><button class="btn" id="eddone">მზადაა</button></div>`,()=>fin(null));
 const c=$('#edc'),x=c.getContext('2d');
 const draw=()=>{const rot=st.rot%180!==0,W0=rot?im.height:im.width,H0=rot?im.width:im.height;const R_=RATIOS.find(r=>r[0]===st.r)[2]||W0/H0;
  let cw=W0,ch=W0/R_;if(ch>H0){ch=H0;cw=H0*R_}const sc=Math.min(1,st.max/Math.max(cw,ch));c.width=Math.round(cw*sc);c.height=Math.round(ch*sc);
  const fcss=(FILTERS.find(f=>f[0]===st.f)[2]+` brightness(${st.b/100})`).trim();x.filter=fcss;c.style.filter='none';
  x.save();x.translate(c.width/2,c.height/2);x.rotate(st.rot*Math.PI/180);const s2=sc;x.drawImage(im,-im.width*s2/2,-im.height*s2/2,im.width*s2,im.height*s2);x.restore();
  if(x.filter==='none'&&fcss!=='brightness(1)')c.style.filter=fcss};
 draw();
 $$('[data-r]',L).forEach(b=>b.onclick=()=>{st.r=b.dataset.r;$$('[data-r]',L).forEach(z=>z.setAttribute('aria-pressed',String(z===b)));draw()});
 $$('[data-f]',L).forEach(b=>b.onclick=()=>{st.f=b.dataset.f;$$('[data-f]',L).forEach(z=>z.setAttribute('aria-pressed',String(z===b)));draw()});
 $('#edb').oninput=e=>{st.b=+e.target.value;draw()};$('#edrot').onclick=()=>{st.rot=(st.rot+90)%360;draw()};
 $('#eddone').onclick=()=>{$('#eddone').disabled=true;const finish=b=>{done=true;LAYER_CB=null;closeLayer();resolve(b)};
  if(c.style.filter&&c.style.filter!=='none'){const c2=document.createElement('canvas');c2.width=c.width;c2.height=c.height;const x2=c2.getContext('2d');x2.drawImage(c,0,0);c2.toBlob(finish,'image/jpeg',.86)}else c.toBlob(finish,'image/jpeg',.86)}})}
async function pickImage(opt={}){const f=await pickFile('image/*',{capture:opt.capture});if(!f)return null;if(f.size>25e6){toast('ფოტო ძალიან დიდია (მაქს. 25 მბ)');return null}if(f.type==='image/gif')return f;return editImage(f,opt)}
async function pickVideo(opt={}){const f=await pickFile('video/*');if(!f)return null;if(f.size>400e6){toast('ვიდეო ძალიან დიდია (მაქს. 400 მბ)');return null}return vPrep(f,opt)}
/* before a video goes up, one screen shows what it is (length, size, sharpness, weight per second, format) and offers a
   lighter copy or the original. The lighter copy is made on the phone: the video plays once, visibly, on that screen
   (a phone hands over the pictures only of a video it is showing), each frame is drawn smaller and recorded with its
   sound. A copy that came out without pictures is never used. The chosen file carries its poster, size and length along */
const VQ={sd:{long:1280,vbr:2.5e6,l:'ჩვეულებრივი',p:'720p'},hd:{long:1920,vbr:5e6,l:'მაღალი',p:'1080p'}},VABR=128e3,VMAX=50e6,VDUR=300;
const mbOf=n=>(Math.round(n/1e5)/10).toLocaleString('ka-GE');
const tOf=s=>{s=Math.max(0,Math.round(s||0));return Math.floor(s/60)+':'+String(s%60).padStart(2,'0')};
const vSharp=(w,h)=>{const l=Math.max(w,h);return l>=3000?'4K':l>=1800?'1080p':l>=1200?'720p':l>=800?'480p':l?l+'p':''};
function vcType(){if(!window.MediaRecorder||!window.HTMLCanvasElement||!window.HTMLCanvasElement.prototype.captureStream||!(window.AudioContext||window.webkitAudioContext))return '';
 return ['video/mp4;codecs=avc1.42E01F,mp4a.40.2','video/mp4;codecs=avc1,mp4a.40.2','video/mp4','video/webm;codecs=vp9,opus','video/webm;codecs=vp8,opus','video/webm'].find(t=>{try{return MediaRecorder.isTypeSupported(t)}catch(e){return false}})||''}
/* what is inside: the box of an MP4 or MOV tells the video codec; HEVC and Dolby Vision do not play everywhere */
async function vSniff(f){try{const h=new Uint8Array(await f.slice(0,4096).arrayBuffer()),fc=(b,i)=>String.fromCharCode(b[i],b[i+1],b[i+2],b[i+3]);
 if(fc(h,4)==='ftyp'){let off=0,moov=null;for(let k=0;k<40&&off<f.size;k++){const b=new DataView(await f.slice(off,off+16).arrayBuffer());let sz=b.getUint32(0);const t=fc(new Uint8Array(b.buffer),4);
   if(sz===1&&b.byteLength>=16)sz=Number(b.getBigUint64(8));else if(sz===0)sz=f.size-off;if(t==='moov'){moov=[off,sz];break}if(sz<8)break;off+=sz}
  if(!moov)return {box:'mp4'};const s=new TextDecoder('latin1').decode(new Uint8Array(await f.slice(moov[0],moov[0]+Math.min(moov[1],4e6)).arrayBuffer()));
  return {box:'mp4',v:['dvh1','dvhe','hvc1','hev1','av01','vp09','avc1','avc3','mp4v'].find(x=>s.includes(x))||''}}
 if(h[0]===0x1a&&h[1]===0x45&&h[2]===0xdf&&h[3]===0xa3){const s=new TextDecoder('latin1').decode(h);return {box:'webm',v:['V_VP9','V_VP8','V_AV1','V_MPEG4/ISO/AVC'].find(x=>s.includes(x))||''}}}catch(e){}return {}}
const vCodec=x=>({hvc1:'HEVC',hev1:'HEVC',dvh1:'Dolby Vision',dvhe:'Dolby Vision',avc1:'H.264',avc3:'H.264',av01:'AV1',vp09:'VP9',V_VP9:'VP9',V_VP8:'VP8',V_AV1:'AV1','V_MPEG4/ISO/AVC':'H.264',mp4v:'MPEG-4'})[x]||'';
const vRare=x=>/^(hvc1|hev1|dvh1|dvhe|av01)$/.test(x||'');
/* storage takes MP4, MOV and WebM; 3GP and M4V are MP4 inside, MKV is WebM's parent */
const vMime=(f,sn)=>{const t=(f.type||'').split(';')[0].trim();if(/^video\/(mp4|quicktime|webm)$/.test(t))return t;if(/^video\/(3gpp2?|x-m4v)$/.test(t)||sn.box==='mp4')return 'video/mp4';if(t==='video/x-matroska'||sn.box==='webm')return 'video/webm';return ''};
/* a frame that is empty (nothing was drawn) or flat black */
function vBlank(c){try{const t=document.createElement('canvas');t.width=t.height=12;const x=t.getContext('2d',{willReadFrequently:true});x.drawImage(c,0,0,12,12);const d=x.getImageData(0,0,12,12).data;let s=0,s2=0,a=0,n=0;
 for(let i=0;i<d.length;i+=4){const l=.3*d[i]+.59*d[i+1]+.11*d[i+2];s+=l;s2+=l*l;a+=d[i+3];n++}const m=s/n;return a/n<16||(m<7&&Math.sqrt(Math.max(0,s2/n-m*m))<3)}catch(e){return false}}
/* a recorded WebM carries no length (or 0), so players show no time and some will not loop it: the real length is
   written into its Info part. The Segment around it has an unknown size in recordings; a known one is grown to match */
async function webmLen(blob,ms){try{const n=Math.min(blob.size,65536),h=new Uint8Array(await blob.slice(0,n).arrayBuffer()),dv=new DataView(h.buffer);
 const find=(id,from,to)=>{for(let i=from;i<=to-id.length;i++){let ok=true;for(let k=0;k<id.length;k++)if(h[i+k]!==id[k]){ok=false;break}if(ok)return i}return -1};
 const rd=i=>{let l=1,m=0x80;while(l<=8&&!(h[i]&m)){m>>=1;l++}let v=h[i]&(m-1),ones=v===m-1;for(let k=1;k<l;k++){v=v*256+h[i+k];if(h[i+k]!==255)ones=false}return {v,l,ones}};
 const si=find([0x18,0x53,0x80,0x67],0,Math.min(n,4096)),ii=find([0x15,0x49,0xA9,0x66],0,n);if(ii<0||si<0||si>ii)return blob;
 const S=rd(si+4),I=rd(ii+4),ds=ii+4+I.l,de=ds+I.v;if(de>n)return blob;
 const di=find([0x44,0x89],ds,de);
 if(di>=0){if(h[di+2]===0x88)dv.setFloat64(di+3,ms);else if(h[di+2]===0x84)dv.setFloat32(di+3,ms);else return blob;return new Blob([h,blob.slice(n)],{type:blob.type})}
 const el=new Uint8Array(11);el.set([0x44,0x89,0x88]);new DataView(el.buffer).setFloat64(3,ms);
 const vi=(v,len)=>{const b=new Uint8Array(len);b[0]=1<<(8-len);for(let k=len-1;k>=0;k--){b[k]|=v%256;v=Math.floor(v/256)}return b};
 const add=(8-I.l)+11,head=h.slice(0,ii);
 if(!S.ones){const nv=S.v+add;if(nv>=2**(7*S.l)-1)return blob;head.set(vi(nv,S.l),si+4)}
 return new Blob([head,h.slice(ii,ii+4),vi(I.v+11,8),h.slice(ds,de),el,h.slice(de),blob.slice(n)],{type:blob.type})}catch(e){}return blob}
function vPrep(f,opt={}){return new Promise(async res=>{const u=URL.createObjectURL(f),mt=vcType(),sn=await vSniff(f),st={k:null,q:'sd',w:0,h:0,d:0,ok:null,poster:null,busy:false};let done=false,run=null,tm=null;
 const fin=x=>{if(done)return;done=true;clearTimeout(tm);if(run)run.stop(true);const v=$('#vp_v');if(v){try{v.pause()}catch(e){}if(v._ac)try{v._ac.close()}catch(e){}v.removeAttribute('src');try{v.load()}catch(e){}}setTimeout(()=>URL.revokeObjectURL(u),800);res(x)};
 layer(lhead(opt.title||'ვიდეოს მომზადება')+`<div class="ph-body vprep"><div class="vpview"><video id="vp_v" src="${u}" muted playsinline autoplay loop preload="auto"></video><span class="vpwait" id="vp_w"><span class="spin"></span></span></div>
  <div class="vpinfo" id="vp_i"></div><p class="vpnote" id="vp_n" hidden></p><div class="vpopts" id="vp_o" role="radiogroup" aria-label="როგორ ავტვირთო"></div>
  <div class="vpprog" id="vp_p" hidden><div class="vcbar"><i id="vp_b"></i></div><p id="vp_t"></p></div></div>
  <div class="ph-foot"><button class="btn ghost" data-a="closelayer">გაუქმება</button><span class="sp"></span><button class="btn" id="vp_go" disabled>გაგრძელება</button></div>`,()=>fin(null));
 const v=$('#vp_v'),go=$('#vp_go');
 const rate=()=>st.d?f.size*8/st.d:0,est=q=>Math.min(f.size*.95,(VQ[q].vbr+VABR)*st.d/8);
 const cmpWhy=()=>!mt?'ამ ბრაუზერს შეკუმშვა არ შეუძლია':st.ok===false?'ეს ვიდეო აქ ვერ ირთვება, ამიტომ ვერ იკუმშება':!st.d||!isFinite(st.d)?'ხანგრძლივობა უცნობია, ამიტომ ვერ იკუმშება':st.d>VDUR?'5 წუთზე გრძელი ვიდეო ვერ იკუმშება':'';
 const origWhy=()=>!vMime(f,sn)?'ეს ფორმატი ორიგინალით ვერ აიტვირთება':f.size>VMAX?`${mbOf(f.size)} მბ-ია: ორიგინალით 50 მბ-მდე იტვირთება`:'';
 const heavy=()=>vRare(sn.v)||(f.size>6e6&&rate()>3.2e6)||(Math.max(st.w,st.h)>1400&&f.size>3e6);
 const draw=()=>{if(done)return;const L=Math.max(st.w,st.h),hd=L>VQ.sd.long*1.15,cw=cmpWhy(),ow=origWhy();if(!hd)st.q='sd';
  $('#vp_i').innerHTML=[st.d&&isFinite(st.d)?`${ic('clock')}${tOf(st.d)}`:'',st.w?`${ic('image')}${st.w}×${st.h}${vSharp(st.w,st.h)?' · '+vSharp(st.w,st.h):''}`:'',`${ic('folder')}${mbOf(f.size)} მბ`,rate()?`${ic('chart')}${(Math.round(rate()/1e5)/10).toLocaleString('ka-GE')} მბიტ/წმ`:'',vCodec(sn.v)?`${ic('clips')}${vCodec(sn.v)}`:''].filter(Boolean).map(x=>`<span>${x}</span>`).join('');
  if(st.busy)return;
  if(!st.w&&st.ok==null){$('#vp_o').innerHTML='<p class="vpload">ვიდეო იხსნება…</p>';go.disabled=true;return}
  const note=st.fail?'შეკუმშვა ამ ტელეფონზე ვერ მოხერხდა.'+(origWhy()?' სცადე უფრო მოკლე ვიდეო.':' შეგიძლია ორიგინალით ატვირთო.'):st.ok===false?'ეს ვიდეო ამ მოწყობილობაზე არ ირთვება, ამიტომ სხვებთანაც შეიძლება არ ჩაირთოს. თუ iPhone-ით გადაიღე: პარამეტრები → კამერა → ფორმატები → „ყველაზე თავსებადი“.'
   :vRare(sn.v)?`${vCodec(sn.v)} ფორმატი ზოგ ტელეფონზე და კომპიუტერზე არ ირთვება. შეკუმშული ასლი ყველგან იმუშავებს.`:rate()>8e6?'ეს ვიდეო ძალიან მძიმეა: სუსტ ინტერნეტზე ჩაჭედავს. შეკუმშული ასლი სწრაფად ჩაირთვება.':'';
  const n=$('#vp_n');n.textContent=note;n.hidden=!note;
  if(st.k==null||(st.k==='cmp'&&cw)||(st.k==='orig'&&ow))st.k=!cw&&(heavy()||ow)?'cmp':!ow?'orig':!cw?'cmp':'';
  const card=(k,why,body)=>`<div class="vpopt${why?' off':''}" role="radio" tabindex="${why?-1:0}" data-k="${k}" aria-checked="${st.k===k}" aria-disabled="${!!why}"><span class="vpr" aria-hidden="true"></span><span class="grow">${body}${why?`<small class="vpwhy">${why}</small>`:''}</span></div>`;
  $('#vp_o').innerHTML=card('cmp',cw,`<b>შეკუმშული${heavy()&&!cw?' <em>გირჩევ</em>':''}</b>${cw?'':`<small>≈ ${mbOf(est(st.q))} მბ · ${VQ[st.q].p} · სწრაფად იტვირთება და ყველა ტელეფონზე ირთვება</small>${hd?`<span class="seg flat vpq" role="group" aria-label="ხარისხი">${Object.entries(VQ).map(([q,Q])=>`<button type="button" data-q="${q}" aria-pressed="${st.q===q}">${Q.l} · ${Q.p}</button>`).join('')}</span>`:''}`}`)
   +card('orig',ow,`<b>ორიგინალი${!heavy()&&!ow?' <em>უკვე მსუბუქია</em>':''}</b>${ow?'':`<small>${mbOf(f.size)} მბ${vSharp(st.w,st.h)?' · '+vSharp(st.w,st.h):''} · სრული ხარისხი${vRare(sn.v)?', მაგრამ ყველგან არ ჩაირთვება':heavy()?', მაგრამ ნელა ჩაიტვირთება':''}</small>`}`);
  go.disabled=!st.k||st.busy;go.textContent=st.k===''?'ვერ აიტვირთება':'გაგრძელება';if(st.k==='')go.disabled=true};
 $('#vp_o').addEventListener('click',e=>{if(st.busy)return;const q=e.target.closest('[data-q]');if(q){st.q=q.dataset.q;st.k='cmp';draw();return}const o=e.target.closest('.vpopt');if(!o||o.classList.contains('off'))return;st.k=o.dataset.k;draw()});
 $('#vp_o').addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&e.target.classList.contains('vpopt')){e.preventDefault();e.target.click()}});
 const grab=()=>{if(st.poster||done||!v.videoWidth)return;try{const sc=Math.min(1,720/Math.max(v.videoWidth,v.videoHeight)),c=document.createElement('canvas');c.width=Math.max(1,Math.round(v.videoWidth*sc));c.height=Math.max(1,Math.round(v.videoHeight*sc));
  c.getContext('2d').drawImage(v,0,0,c.width,c.height);if(vBlank(c))return;st.poster='…';c.toBlob(b=>{st.poster=b||null},'image/jpeg',.82)}catch(e){}};
 v.addEventListener('loadedmetadata',()=>{st.w=v.videoWidth;st.h=v.videoHeight;st.d=isFinite(v.duration)?v.duration:0;draw()});
 v.addEventListener('playing',()=>{st.ok=true;clearTimeout(tm);$('#vp_w').hidden=true;draw()});
 v.addEventListener('timeupdate',()=>{if(!st.busy&&!st.poster&&v.currentTime>Math.min(.6,(st.d||2)/4))grab()});
 v.addEventListener('error',()=>{if(st.busy)return;st.ok=false;$('#vp_w').hidden=true;draw()});
 /* a phone that will not start a video by itself still shows it after a tap; one that cannot read it says so */
 tm=setTimeout(()=>{if(st.ok==null){if(v.readyState>=2||v.videoWidth){st.ok=true;$('#vp_w').hidden=true}else st.ok=false;draw()}},9000);
 v.addEventListener('click',()=>{if(!st.busy&&v.paused)v.play().catch(()=>{})});
 const meta=(file,how,w,h)=>{const p=st.poster instanceof Blob?st.poster:null;Object.assign(file,{_poster:p,_w:w||st.w||0,_h:h||st.h||0,_dur:st.d||0,_how:how});return file};
 const ui=(on)=>{st.busy=on;$('#vp_o').hidden=on;$('#vp_p').hidden=!on;go.disabled=false;go.textContent=on?'გაჩერება':'გაგრძელება';go.classList.toggle('ghost',on)};
 draw();
 go.onclick=()=>{if(st.busy){if(run)run.stop(true);run=null;ui(false);try{v.loop=true;v.muted=true;v.currentTime=0;v.play().catch(()=>{})}catch(e){}draw();return}
  if(st.k==='orig'){if(!st.poster)grab();const end=()=>{LAYER_CB=null;const m2=vMime(f,sn),typed=f.type===m2?f:new File([f],'video.'+(m2==='video/webm'?'webm':m2==='video/quicktime'?'mov':'mp4'),{type:m2});fin(meta(typed,'orig'));closeLayer()};if(st.poster==='…')setTimeout(end,300);else end();return}
  if(st.k!=='cmp')return;if(!st.poster)grab();st.fail=false;ui(true);$('#vp_b').style.width='0';$('#vp_t').textContent='მზადდება… 0%';
  try{run=vcRun(v,{w:st.w,h:st.h,d:st.d},mt,st.q,x=>{const b=$('#vp_b'),t=$('#vp_t');if(b)b.style.width=Math.round(x*100)+'%';if(t)t.textContent=`მზადდება… ${Math.round(x*100)}% · დარჩა ${tOf(st.d*(1-x))}`})}catch(e){run=null}
  const failed=()=>{run=null;ui(false);try{v.loop=true;v.muted=true;v.currentTime=0;v.play().catch(()=>{})}catch(e){}st.fail=true;if(!origWhy())st.k='orig';draw()};
  if(!run){failed();return}const me=run;
  run.out.then(async r=>{if(done||run!==me)return;if(!r||!r.blob||r.blob.size<20000||r.blob.size>=f.size*.95){failed();return}
   let b=r.blob;if(b.type.includes('webm'))b=await webmLen(b,st.d*1000);const ext=b.type.includes('mp4')?'mp4':'webm',out=new File([b],'video.'+ext,{type:b.type});
   toast(`შეიკუმშა: ${mbOf(f.size)} → ${mbOf(out.size)} მბ`);LAYER_CB=null;fin(meta(out,st.q,r.w,r.h));closeLayer()}).catch(()=>{if(!done&&run===me)failed()})}})}
/* plays the shown video once into a smaller canvas and records it with its sound; started inside the tap.
   MP4 first (H.264 where the phone has it). It counts the frames it really drew: a copy without pictures fails */
function vcRun(v,p,mt,q,onp){const Q=VQ[q]||VQ.sd,sc=Math.min(1,Q.long/Math.max(p.w,p.h)),cw=Math.max(2,Math.round(p.w*sc/2)*2),chh=Math.max(2,Math.round(p.h*sc/2)*2);
 const c=document.createElement('canvas');c.width=cw;c.height=chh;const x=c.getContext('2d'),stream=c.captureStream(30);
 const AC=window.AudioContext||window.webkitAudioContext,ac=v._ac||(v._ac=new AC()),src=v._src||(v._src=ac.createMediaElementSource(v)),dst=ac.createMediaStreamDestination();src.connect(dst);dst.stream.getAudioTracks().forEach(t=>stream.addTrack(t));
 const rec=new MediaRecorder(stream,{mimeType:mt,videoBitsPerSecond:Q.vbr,audioBitsPerSecond:VABR}),chunks=[];rec.ondataavailable=e=>{if(e.data&&e.data.size)chunks.push(e.data)};
 let stopped='',last=-1,frames=0,looks=0,dark=0,wd=0;
 const draw=()=>{if(stopped)return;if(v.currentTime!==last){last=v.currentTime;try{x.drawImage(v,0,0,cw,chh);frames++}catch(e){}onp(Math.min(1,v.currentTime/p.d))}if(v.requestVideoFrameCallback)v.requestVideoFrameCallback(draw);else requestAnimationFrame(draw)};
 const vis=()=>{if(stopped)return;try{if(document.hidden){v.pause();if(rec.state==='recording')rec.pause()}else{if(rec.state==='paused')rec.resume();v.play().catch(()=>{})}}catch(e){}};
 document.addEventListener('visibilitychange',vis);
 const out=new Promise((res,rej)=>{
  const end=why=>{if(stopped)return;stopped=why;clearInterval(wd);try{v.pause()}catch(e){}try{if(rec.state!=='inactive')rec.stop();else rec.onstop()}catch(e){rej(e)}};
  rec.onstop=()=>{document.removeEventListener('visibilitychange',vis);clearInterval(wd);try{src.disconnect(dst)}catch(e){}try{stream.getTracks().forEach(t=>t.stop())}catch(e){}
   const enough=frames>=Math.max(8,p.d*6)&&!(looks>=2&&dark===looks);res(stopped==='cancel'||stopped==='noframes'||!enough?null:{blob:new Blob(chunks,{type:mt.split(';')[0]}),w:cw,h:chh,frames})};
  rec.onerror=e=>rej(e.error||new Error('rec'));v.onended=()=>{if(stopped)return;onp(1);setTimeout(()=>end('end'),150)};
  /* every second one look at what was drawn; after two seconds of playing there must be real frames */
  let lastWd=-1,stall=0;
  wd=setInterval(()=>{if(stopped||document.hidden)return;if(v.error){end('noframes');return}
   stall=v.currentTime===lastWd?stall+1:0;lastWd=v.currentTime;if(stall>=10){end('noframes');return}
   if(v.paused)return;looks++;if(vBlank(c))dark++;if(v.currentTime>2.2&&frames<6)end('noframes')},1000);
  });
 v.loop=false;try{v.currentTime=0}catch(e){}v.muted=false;rec.start(1000);const pl=v.play();if(ac.state==='suspended')ac.resume().catch(()=>{});draw();
 return {out:Promise.all([out,pl]).then(a=>a[0]),stop(cancel){if(stopped)return;stopped=cancel?'cancel':'end';try{v.pause()}catch(e){}try{if(rec.state!=='inactive')rec.stop()}catch(e){}}}}
function recordVoice(){return new Promise(async resolve=>{let done=false,rec,stream,chunks=[],t0,tm;const fin=v=>{if(done)return;done=true;try{rec&&rec.state!=='inactive'&&rec.stop()}catch(e){}stream&&stream.getTracks().forEach(t=>t.stop());clearInterval(tm);resolve(v)};
 try{stream=await navigator.mediaDevices.getUserMedia({audio:true})}catch(e){toast('მიკროფონზე წვდომა არ არის');return resolve(null)}
 const mt=['audio/webm;codecs=opus','audio/webm','audio/mp4','audio/ogg'].find(m=>window.MediaRecorder&&MediaRecorder.isTypeSupported(m))||'';
 rec=new MediaRecorder(stream,mt?{mimeType:mt}:{});rec.ondataavailable=e=>e.data.size&&chunks.push(e.data);
 rec.onstop=()=>{if(done)return;const b=new Blob(chunks,{type:rec.mimeType||'audio/webm'});b.dur=Math.round((Date.now()-t0)/1000);done=true;stream.getTracks().forEach(t=>t.stop());clearInterval(tm);resolve(b)};
 layer(lhead('ხმოვანი შეტყობინება')+`<div class="ph-body"><div class="recbox"><span class="recdot"></span><b id="rect">0:00</b></div><p class="note">ილაპარაკე და შემდეგ დააჭირე „გაგზავნა“. მაქსიმუმ 2 წუთი.</p></div><div class="ph-foot"><button class="btn ghost" data-a="closelayer">გაუქმება</button><span class="sp"></span><button class="btn" id="recsend">${ic('send')}გაგზავნა</button></div>`,()=>{if(!done){chunks=[];fin(null)}});
 rec.start();t0=Date.now();tm=setInterval(()=>{const s=Math.round((Date.now()-t0)/1000);const e=$('#rect');if(e)e.textContent=Math.floor(s/60)+':'+String(s%60).padStart(2,'0');if(s>=120)$('#recsend')?.click()},250);
 $('#recsend').onclick=()=>{LAYER_CB=null;closeLayer();rec.stop()}})}
const mediaHTML=(m,cls='')=>m.type==='video'?`<video class="${cls}" src="${esc(m.url)}" controls playsinline preload="${ECO()?'none':'metadata'}"></video>`:m.type==='audio'?`<audio src="${esc(m.url)}" controls preload="metadata"></audio>`:`<img class="${cls}" src="${esc(m.url)}" alt="" loading="lazy">`;

/* economy mode: no autoplay, media on tap, smaller uploads */
const ECO=()=>!!S.eco;
S.eco=store.get('eco',null);if(S.eco===null){const c=navigator.connection;S.eco=!!(c&&(c.saveData||/2g/.test(c.effectiveType||'')))}
document.documentElement.classList.toggle('eco',!!S.eco);

/* link preview cards */
async function unfurl(url){try{const{data,error}=await sb.functions.invoke('unfurl',{body:{url}});if(error||!data||data.error||!data.title)return null;return data}catch(e){return null}}
const safeHref=u=>/^https?:\/\//i.test(String(u||''))?String(u):'#';
function linkCard(l,cls=''){if(!l||!l.url)return '';const img=l.image&&!ECO()?`<img src="${esc(l.image)}" alt="" loading="lazy" referrerpolicy="no-referrer" onerror="this.remove()">`:'';
 return `<a class="lcard2 ${cls}" href="${esc(safeHref(l.url))}" target="_blank" rel="noopener nofollow ugc">${img}<span class="lc-t"><small>${esc(l.site||'')}</small><b>${esc(l.title||l.url)}</b>${l.description?`<em>${esc(l.description)}</em>`:''}</span></a>`}

/* the "good idea" reaction. it is stored as 🍷 (the reaction lists in the database were made with it) and shown as a light bulb */
const IDEA='💡';
const rg=e=>e==='🍷'?IDEA:e;

/* what breaks on a phone reaches the admin panel (client_errors): each error once a visit, at most 8 a visit,
   only for someone signed in; network hiccups, aborted media and browser noise are left out */
const ERRS={seen:new Set(),n:0,v:((document.querySelector('script[src*="/js/core.js"]')||{}).src||'').replace(/^.*[?&]v=/,'').slice(0,20)};
const ERR_NOISE=/ResizeObserver loop|^Script error\.?$|AbortError|aborted|Failed to fetch|NetworkError|Load failed|network|NotAllowedError|play\(\) request|interrupted by a call to pause|Fetch is aborted|The operation was aborted|JWT expired|Refresh Token/i;
function errReport(msg,src,line,col,stack){try{
 if(typeof ME==='undefined'||!ME||!ME.id||ME.offline||ERRS.n>=8)return;msg=String(msg||'').slice(0,500);if(!msg||ERR_NOISE.test(msg))return;
 const k=msg+'|'+(src||'')+'|'+(line||0);if(ERRS.seen.has(k))return;ERRS.seen.add(k);ERRS.n++;
 sb.from('client_errors').insert({msg,src:String(src||'').replace(location.origin,'').slice(0,300),line:+line||null,col:+col||null,stack:String(stack||'').replace(new RegExp(location.origin.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),'g'),'').slice(0,2000),
  page:((location.hash||'#')+(typeof S!=='undefined'&&S.page?' · '+S.page.id:'')+(typeof S!=='undefined'&&S.game?' · '+S.game:'')).slice(0,200),ua:navigator.userAgent.slice(0,300),ver:ERRS.v}).then(()=>{},()=>{})}catch(e){}}
window.addEventListener('error',e=>{if(!e.error&&e.target&&e.target!==window)return;errReport(e.message,e.filename,e.lineno,e.colno,e.error&&e.error.stack)});
window.addEventListener('unhandledrejection',e=>{const r=e.reason;if(r&&r.code)return;errReport(r&&r.message||String(r),'promise',0,0,r&&r.stack)});
/* a programming error inside a button's action is reported too (a database refusal is not: it has a code) */
const errBug=(x,a)=>{if(x instanceof Error&&/^(TypeError|ReferenceError|SyntaxError|RangeError)$/.test(x.name))errReport(x.message,'action:'+a,0,0,x.stack)};
