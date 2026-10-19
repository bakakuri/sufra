/* what the admin controls for everyone: a banner, sections switched off, sponsored posts in the feed and sponsored stories */

/* sections the admin can switch off: the pages that belong to each one */
const FEATS=[['rooms','ვირტუალური სუფრა, ბირჟა, ლაივი',['rooms','room']],['places','ადგილები',['places','place','placenew']],['sport','მატჩები და პროგნოზები',['sport','fixture']],['help','დახმარება',['help','helpnew','helpreq']],['rides','ერთად წავიდეთ',['rides','ridenew','ride']],['jobs','ვაკანსიები და CV',['jobs','jobnew','job','myjobs','cv']],['market','ბაზრობა',['market','mknew']],['events','ღონისძიებები',['events','event','evnew']],['albums','ალბომები',['albums','album']],['groups','ჯგუფები',['groups','group']],['pages','არხები და გვერდები',['pages','pagev']],['toasts','სადღეგრძელოები',['toasts']],['recipes','სამზარეულო',['recipes','recipe']],['tree','ოჯახის ხე',['tree','surname']],['namedays','სახელის დღეები და კალენდარი',['namedays','calendar']],['clips','კლიპები',[]],['date','გაცნობა',[]],['games','თამაშები',['tour','jktable']]];
const FEAT_OF={};FEATS.forEach(([k,,pgs])=>pgs.forEach(p=>{FEAT_OF[p]=k}));
const CREATE_FEAT={croom:'rooms',cbirja:'rooms',clive:'rooms',cevent:'events',clisting:'market',cgroup:'groups',cpage:'pages',cplace:'places',chelp:'help',ctoast:'toasts',cride:'rides',cjob:'jobs',crecipe:'recipes',cclip:'clips'};
let APPSET={banner:null,features:{off:[]}};
const featOff=k=>!!k&&(APPSET.features.off||[]).includes(k);
const isAdm=()=>!!ME&&ME.role==='admin';
/* the admin still sees everything, so a switched-off section can be checked before it comes back */
const pageOk=p=>isAdm()||!featOff(FEAT_OF[p]);
const tabOk=t=>isAdm()||!featOff(t);
const createOk=a=>isAdm()||!featOff(CREATE_FEAT[a]);
async function loadAppSettings(){try{const rows=await q(sb.from('app_settings').select('key,value'));const m=Object.fromEntries(rows.map(r=>[r.key,r.value]));APPSET={banner:m.banner||null,features:Object.assign({off:[]},m.features||{})}}catch(e){}applyAppSettings()}
function applyAppSettings(){try{renderTabs();renderSide();moveInd(S.tab);markSide()}catch(e){}if(!S.page&&S.tab&&!tabOk(S.tab))go('home');drawBanner()}
const offView=label=>empty('დროებით გამორთულია',`„${esc(label)}“ ადმინისტრაციამ დროებით გამორთო. მალე დაბრუნდება.`,'<button class="btn" data-a="home">მთავარზე</button>');
for(const[k,label,pgs]of FEATS){
 for(const id of pgs){const pg=PG[id];if(!pg)continue;const r=pg.r;pg.r=function(arg){if(!pageOk(id)){view.innerHTML=pgHead(esc(label))+offView(label);return}return r.call(this,arg)}}
 if(['clips','date','games'].includes(k)&&R[k]){const r=R[k];R[k]=function(...a){if(!tabOk(k)){view.className='';view.innerHTML=`<div class="view-pad">${offView(label)}</div>`;return}return r.apply(this,a)}}}

/* a banner on top of the home page; closing it hides that text only */
const hashStr=s=>{let h=0;for(const c of String(s))h=(h*31+c.charCodeAt(0))|0;return String(h>>>0)};
function drawBanner(){const el=$('#annc');if(!el)return;const b=APPSET.banner;const key=b&&b.on&&b.text?'bn'+hashStr(b.text+(b.link||'')):'';let hid=false;try{hid=!!key&&localStorage.getItem('annc')===key}catch(e){}
 if(!key||hid){el.innerHTML='';return}const tone=['warn','fest'].includes(b.tone)?b.tone:'info';
 el.innerHTML=`<div class="annc t-${tone}" role="status"><span class="anic">${ic(tone==='warn'?'flag':tone==='fest'?'gift':'mega')}</span><span class="grow">${esc(b.text)}</span>${b.link?`<button class="btn sm" data-a="annclink">${esc(b.cta||'ნახვა')}</button>`:''}<button class="ibtn sm" data-a="anncx" aria-label="დახურვა">${ic('x')}</button></div>`}
A.annclink=()=>{const b=APPSET.banner;if(b&&b.link)openLink(b.link)};
A.anncx=()=>{const b=APPSET.banner;if(!b)return;try{localStorage.setItem('annc','bn'+hashStr(b.text+(b.link||'')))}catch(e){}drawBanner()};
/* links from the admin: a place inside the site (#recipes, #event-5) or an outside https address */
function openLink(l){l=String(l||'');if(/^#[a-z]/.test(l)){if(!route(l))toast('ბმული ვერ გაიხსნა');return}if(/^https:\/\//.test(l))window.open(l,'_blank','noopener')}

/* sponsored posts and stories */
let PROMOS={at:0,post:[],story:[]};const PROMO_HIT=new Set();
const PSEL='id,kind,brand,brand_url,title,body,media_url,media_type,w,h,link,cta,every,starts_at,ends_at,active,reach,clicks,created_at';
const promoLive=p=>p.active&&new Date(p.starts_at)<=new Date()&&(!p.ends_at||new Date(p.ends_at)>new Date());
const promoHidden=id=>{try{return(JSON.parse(localStorage.getItem('promoHide')||'[]')).includes(id)}catch(e){return false}};
const promoSeenSet=()=>{try{return new Set(JSON.parse(localStorage.getItem('promoSeen')||'[]'))}catch(e){return new Set()}};
function markPromoSeen(id){try{const s=promoSeenSet();s.add(id);localStorage.setItem('promoSeen',JSON.stringify([...s].slice(-200)))}catch(e){}}
async function loadPromos(force){if(!force&&Date.now()-PROMOS.at<120000)return PROMOS;
 try{const rows=(await q(sb.from('promos').select(PSEL).order('created_at',{ascending:false}).limit(30))).filter(p=>promoLive(p)&&!promoHidden(p.id));PROMOS={at:Date.now(),post:rows.filter(p=>p.kind==='post'),story:rows.filter(p=>p.kind==='story')}}catch(e){}return PROMOS}
const promoById=id=>[...PROMOS.post,...PROMOS.story,...(typeof ADM!=='undefined'&&ADM.promos||[])].find(p=>p.id===id);
function promoSeen(id){if(PROMO_HIT.has(id))return;PROMO_HIT.add(id);sb.rpc('promo_hit',{p_promo:id,p_click:false}).then(()=>{},()=>{})}
const promoAv=(p,s)=>avAny({n:p.brand,u:p.brand_url,h:330},s);
function promoHTML(p){const ar=p.w>0&&p.h>0?boxRatio({w:p.w,h:p.h}):1;
 return `<article class="post pc promo" data-promo="${p.id}"><div class="pchead"><span class="pwho">${promoAv(p,38)}</span><span class="pwt"><span class="pwn"><b>${esc(p.brand)}</b><span class="ptag ad">რეკლამა</span></span><span class="pwtime">სპონსორი</span></span><button class="ibtn sm" data-a="promomore" data-id="${p.id}" aria-label="მეტი">${ic('more')}</button></div>
  ${p.title?`<h3 class="prt">${esc(p.title)}</h3>`:''}${p.body?`<div class="pdesc"><div class="txt">${tx(p.body)}</div></div>`:''}
  ${p.media_url?`<button class="prm" data-a="promogo" data-id="${p.id}" style="--ar:${ar}" aria-label="${esc(p.title||p.brand)}">${p.media_type==='video'?`<video src="${esc(p.media_url)}" muted playsinline loop autoplay preload="metadata"></video>`:`<img src="${esc(p.media_url)}" alt="" loading="lazy">`}</button>`:''}
  ${p.link?`<button class="prcta" data-a="promogo" data-id="${p.id}"><span>${esc(p.cta||'გაიგე მეტი')}</span>${ic('back')}</button>`:'<span class="prpad"></span>'}</article>`}
A.promogo=t=>{const id=+t.dataset.id,p=promoById(id);if(!p)return;const prev=t.dataset.prev||t.closest('.prev');if(prev)closeSheet(true);if(promoLive(p)&&!prev)sb.rpc('promo_hit',{p_promo:id,p_click:true}).then(()=>{},()=>{});
 if(!$('#story').hidden)closeStory();if(p.link)openLink(p.link);else if(p.media_url&&p.media_type!=='video')openImage(p.media_url,{})};
A.promomore=t=>{const id=+t.dataset.id;sheet(head('რეკლამა')+`<p class="hint" style="padding:12px 16px 0">ამ რეკლამას სუფრის გუნდი აჩვენებს. თუ არ გაინტერესებს, დამალე და აღარ გამოჩნდება.</p><div class="reasons"><button data-a="promohide" data-id="${id}">${ic('eye')}რეკლამის დამალვა</button>${isAdm()?`<button data-a="page" data-p="admin" data-arg="promo">${ic('shield')}რეკლამის მართვა</button>`:''}</div>`,'short')};
A.promohide=t=>{const id=+t.dataset.id;try{const a=JSON.parse(localStorage.getItem('promoHide')||'[]');a.push(id);localStorage.setItem('promoHide',JSON.stringify(a.slice(-200)))}catch(e){}
 PROMOS.post=PROMOS.post.filter(p=>p.id!==id);PROMOS.story=PROMOS.story.filter(p=>p.id!==id);closeSheet();$$(`.promo[data-promo="${id}"]`).forEach(e=>e.remove());toast('რეკლამა დაიმალა')};
/* sponsored stories go into the ring right after your own */
async function promoStories(){try{const ps=(await loadPromos()).story;if(!ps.length)return [];const seen=promoSeenSet();
 return ps.map(p=>({a:'promo:'+p.id,promo:p,seen:seen.has(p.id),list:[{id:'p'+p.id,media_url:p.media_url,media_type:p.media_type,created_at:p.starts_at,promo:p}]}))}catch(e){return []}}
const promoRing=(s,i)=>`<button class="story" data-a="story" data-i="${i}" role="listitem" aria-label="რეკლამა: ${esc(s.promo.brand)}"><span class="ring ad${s.seen?' seen':''}">${promoAv(s.promo,58)}<i class="adtag">რეკლამა</i></span><span>${esc(s.promo.brand)}</span></button>`;
