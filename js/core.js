/* სუფრა · core: client, helpers, state, sheets, pages, translation, media */
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
const ERR={not_enough_coins:'მონეტები არ გყოფნის',already_claimed:'დღევანდელი ბონუსი უკვე აიღე',adults_only:'ეს ნაწილი მხოლოდ 18+ მომხმარებლებისთვისაა',dating_off:'ჯერ ჩართე გაცნობის პროფილი',blocked:'ეს მომხმარებელი დაბლოკილია',dm_friends_only:'ამ ადამიანს მხოლოდ მეგობრები წერენ',not_allowed:'ეს მოქმედება ახლა შეუძლებელია',too_young:'სუფრაზე რეგისტრაცია 13 წლიდანაა შესაძლებელი',staff_only:'მხოლოდ მოდერატორებისთვის',post_must_belong_to_your_page:'რეკლამა მხოლოდ შენი გვერდის პოსტზე შეიძლება'};
function errMsg(e){const m=String(e?.message||e||'');for(const k in ERR)if(m.includes(k))return ERR[k];if(/row-level security|permission denied/i.test(m))return 'ამის უფლება არ გაქვს';if(/duplicate key/i.test(m))return 'ეს უკვე არსებობს';if(/Failed to fetch|NetworkError/i.test(m))return 'ინტერნეტთან კავშირი არ არის';return 'შეცდომა: '+m.slice(0,120)}
async function q(p){const r=await p;if(r.error)throw r.error;return r.data}
async function rpc(fn,args){return q(sb.rpc(fn,args||{}))}

/* state */
const S={tab:'home',page:null,feed:'for',game:null,ptab:'posts',online:new Set(),unreadMsgs:0,unreadNotes:0};
const R={},A={},PG={};
let ME=null;
const PC=new Map();
const PCOLS='id,username,name,bio,city,hue,avatar_url,cover_url,privacy,dating,gender,is_business,verified,role,banned,rating,last_seen,created_at,nameday,nameday_label,surname';
async function loadProfiles(ids){const need=[...new Set(ids.filter(Boolean))].filter(id=>!PC.has(id)&&id!==ME?.id);if(need.length){for(let i=0;i<need.length;i+=100){const d=await q(sb.from('profiles').select(PCOLS).in('id',need.slice(i,i+100)));d.forEach(p=>PC.set(p.id,p))}}}
const prof=id=>id&&ME&&id===ME.id?ME:PC.get(id)||{id,name:'მომხმარებელი',hue:200};
const pname=id=>prof(id).name;
function av(p,s=40){if(p==='me')p=ME;else if(typeof p==='string')p=prof(p);p=p||{};const st=`--s:${s}px;--h:${(p.hue??200)%360}`;
 return p.avatar_url?`<img class="av" style="${st}" src="${esc(p.avatar_url)}" alt="" loading="lazy">`:`<span class="av" style="${st}" aria-hidden="true">${esc((String(p.name||'?').trim()[0])||'?')}</span>`}
const avAny=(x,s)=>typeof x==='string'||x?.id?av(x,s):`<span class="av" style="--h:${Math.abs(Number(x&&x.h)||200)%360};--s:${s}px" aria-hidden="true">${esc(String((x&&x.n)||'?').slice(0,1)||'?')}</span>`;
const vb=p=>(typeof p==='string'?prof(p):p)?.verified?`<span class="vb" title="ვერიფიცირებული" aria-label="ვერიფიცირებული">${ic('check')}</span>`:'';
const isOnline=id=>S.online.has(id);
const isStaff=()=>ME&&(ME.role==='admin'||ME.role==='moderator');
const age=bd=>{if(!bd)return null;const b=new Date(bd),n=new Date();let a=n.getFullYear()-b.getFullYear();if(n<new Date(n.getFullYear(),b.getMonth(),b.getDate()))a--;return a};
const isAdult=()=>(age(ME?.birthday)||0)>=18;

/* sheets */
let SHEET_TOK=0,SHEET_CB=null;
function sheet(html,cls='',onClose){if(SHEET_CB){const f=SHEET_CB;SHEET_CB=null;try{f()}catch(e){}}SHEET_TOK++;SHEET_CB=onClose||null;const s=$('#sheet');s.classList.remove('closing');s.innerHTML=`<div class="panel ${cls}" role="dialog" aria-modal="true">${html}</div>`;s.hidden=false;
 const f=$('input:not([type=file]):not([type=range]),textarea',s);if(f&&!/Mobi/.test(navigator.userAgent))f.focus();dragSheet($('.panel',s));staggerIn($$('.ph-body>*,.reasons>*,.svc>*,.gifts>*,.jchoice>*,.match>*',s).slice(0,10),35,80)}
function closeSheet(){const s=$('#sheet');if(s.hidden)return;if(SHEET_CB){const f=SHEET_CB;SHEET_CB=null;try{f()}catch(e){}}const tok=++SHEET_TOK;if(RM()||!$('.panel',s)){s.hidden=true;s.innerHTML='';return}s.classList.add('closing');setTimeout(()=>{if(tok!==SHEET_TOK)return;s.hidden=true;s.innerHTML='';s.classList.remove('closing')},220)}
const head=(t,extra='')=>`<div class="ph-head"><h2>${t}</h2><span class="sp"></span>${extra}<button class="ibtn" data-a="close" aria-label="დახურვა">${ic('x')}</button></div>`;
A.close=()=>closeSheet();
function confirmSheet(title,text,okLabel,onOk,danger,inLayer){
 if(inLayer){layer(lhead(title)+`<div class="ph-body"><p>${text}</p></div><div class="ph-foot"><button class="btn ghost" data-a="closelayer">გაუქმება</button><span class="sp"></span><button class="btn${danger?' danger':''}" id="cfokl">${okLabel}</button></div>`);$('#cfokl').onclick=async()=>{const b=$('#cfokl');b.disabled=true;try{await onOk();closeLayer()}catch(e){toast(errMsg(e));b.disabled=false}};return}
 sheet(head(title)+`<div class="ph-body"><p>${text}</p></div><div class="ph-foot"><button class="btn ghost" data-a="close">გაუქმება</button><span class="sp"></span><button class="btn${danger?' danger':''}" id="cfok">${okLabel}</button></div>`,'short');$('#cfok').onclick=async()=>{const b=$('#cfok');b.disabled=true;try{await onOk();closeSheet()}catch(e){toast(errMsg(e));b.disabled=false}}}
const skel=(n=3)=>Array.from({length:n},()=>'<div class="skel"><span class="sk-av"></span><span class="sk-lines"><i></i><i></i><i style="width:60%"></i></span></div>').join('');
const empty=(t,sub='',btn='')=>`<div class="empty3"><h3>${t}</h3>${sub?`<p>${sub}</p>`:''}${btn}</div>`;

/* pages */
const pgHead=(t,extra='')=>`<div class="pghead"><button class="ibtn" data-a="back" aria-label="უკან">${ic('back')}</button><h2>${t}</h2>${extra}</div>`;
function openPage(id,arg,back,noPush){if(!PG[id])return;closeSheet();stopMedia();S.page={id,arg,back};view.className=PG[id].cls||'';const app=$('#app');app.classList.toggle('media',PG[id].cls==='is-clips');app.classList.remove('barhidden');view.scrollTop=0;
 if(!noPush)try{history.pushState({pg:id,arg},'','#'+id+(arg!=null?'-'+arg:''))}catch(e){}
 const r=PG[id].r(arg);const d=S._dir||1;S._dir=0;enterView(28*d);return r}
const rp=()=>{if(S.page)return PG[S.page.id].r(S.page.arg)};
A.page=t=>openPage(t.dataset.p,t.dataset.arg);
A.back=()=>{const b=S.page&&S.page.back;stopMedia();if(b){S._dir=-1;openPage(b[0],b[1],null,true)}else go(S.tab,-28)};
let LIVE_T=null;function stopMedia(){if(LIVE_T){clearInterval(LIVE_T);LIVE_T=null}$$('video',view).forEach(v=>{try{v.pause()}catch(e){}});if(S.chanCleanup){try{S.chanCleanup()}catch(e){}S.chanCleanup=null}}

/* translation: detect locally, translate on request through the edge function */
const siteLang=()=>ME?.lang||'ka';
const TXT=[],TXI=new Map(),TR=new Map();
function txId(t){let i=TXI.get(t);if(i==null){i=TXT.push(t)-1;TXI.set(t,i)}return i}
const linkify=s=>esc(s).replace(/(^|\s)#([A-Za-z0-9_ა-ჿ]{2,40})/g,(m,a,t)=>`${a}<button class="hash" data-a="tag" data-t="${t.toLowerCase()}">#${t}</button>`).replace(/(^|\s)@([a-z0-9_.]{3,24})/g,(m,a,u)=>`${a}<button class="hash" data-a="uname" data-u="${u}">@${u}</button>`).replace(/https?:\/\/[^\s<]+/g,u=>`<a href="${u}" target="_blank" rel="noopener nofollow ugc">${u}</a>`);
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
async function uploadBlob(blob,ext,bucket='media'){const path=`${ME.id}/${Date.now().toString(36)}-${Math.random().toString(36).slice(2,8)}.${ext}`;
 const{error}=await sb.storage.from(bucket).upload(path,blob,{contentType:blob.type||undefined,cacheControl:'31536000',upsert:false});if(error)throw error;
 return bucket==='media'?sb.storage.from('media').getPublicUrl(path).data.publicUrl:path}
/* small copies: lists load a ~1080px or ~480px copy, the viewer opens the full photo; videos get a poster frame */
async function scaledCopy(src,max,qual){const im=await loadImg(src);const W=im.naturalWidth||im.width,H=im.naturalHeight||im.height,sc=Math.min(1,max/Math.max(W,H));
 const c=document.createElement('canvas');c.width=Math.max(1,Math.round(W*sc));c.height=Math.max(1,Math.round(H*sc));c.getContext('2d').drawImage(im,0,0,c.width,c.height);
 return {b:await new Promise(r=>c.toBlob(r,'image/jpeg',qual)),w:W,h:H}}
function videoPoster(blob,max=720){return new Promise(res=>{const v=document.createElement('video'),u=URL.createObjectURL(blob);let done=false;
 const fin=x=>{if(done)return;done=true;clearTimeout(tm);URL.revokeObjectURL(u);v.removeAttribute('src');res(x)},tm=setTimeout(()=>fin(null),8000);
 v.muted=true;v.playsInline=true;v.preload='auto';
 v.onloadeddata=()=>{try{v.currentTime=Math.min(.5,(v.duration||1)/4)}catch(e){fin(null)}};
 v.onseeked=()=>{try{const sc=Math.min(1,max/Math.max(v.videoWidth,v.videoHeight)||1),c=document.createElement('canvas');c.width=Math.max(1,Math.round(v.videoWidth*sc));c.height=Math.max(1,Math.round(v.videoHeight*sc));c.getContext('2d').drawImage(v,0,0,c.width,c.height);c.toBlob(b=>fin(b?{b,w:v.videoWidth,h:v.videoHeight}:null),'image/jpeg',.78)}catch(e){fin(null)}};
 v.onerror=()=>fin(null);v.src=u})}
async function uploadMedia(blob,type){
 if(type==='video'){const m={url:await uploadBlob(blob,extOf(blob)),type:'video'};try{const p=await videoPoster(blob);if(p&&p.b){m.poster=await uploadBlob(p.b,'jpg');m.w=p.w;m.h=p.h}}catch(e){}return m}
 const gif=blob.type==='image/gif',m={url:await uploadBlob(blob,gif?'gif':'jpg'),type:'image'};if(gif)return m;
 const src=URL.createObjectURL(blob);
 try{const md=await scaledCopy(src,1080,.82);m.w=md.w;m.h=md.h;const big=Math.max(md.w,md.h)>1200;
  const sm=await scaledCopy(src,480,.74);const[a,b]=await Promise.all([big&&md.b?uploadBlob(md.b,'jpg'):null,sm.b&&Math.max(md.w,md.h)>560?uploadBlob(sm.b,'jpg'):null]);if(a)m.md=a;if(b)m.sm=b}catch(e){}
 finally{URL.revokeObjectURL(src)}return m}
const safeU=u=>/^https?:\/\//.test(String(u||''))?String(u):'';
const mMd=m=>safeU(m.md)||m.url,mSm=m=>safeU(m.sm)||safeU(m.md)||m.url,mPoster=m=>safeU(m.poster);
const extOf=f=>{const m=(f.type||'').split('/')[1]||'';return({jpeg:'jpg','quicktime':'mov','x-m4a':'m4a','mpeg':'mp3'})[m]||m.replace(/[^a-z0-9]/g,'').slice(0,5)||'bin'};
const FILTERS=[['none','ბუნებრივი',''],['warm','თბილი','sepia(.25) saturate(1.3) hue-rotate(-8deg)'],['cool','ცივი','saturate(1.1) hue-rotate(12deg) brightness(1.03)'],['bw','შავ-თეთრი','grayscale(1) contrast(1.1)'],['vintage','ვინტაჟი','sepia(.45) contrast(.95) brightness(1.05) saturate(.85)'],['vivid','კაშკაშა','saturate(1.6) contrast(1.08)'],['fade','მქრქალი','contrast(.85) brightness(1.1) saturate(.8)']];
const RATIOS=[['orig','ორიგინალი',0],['1','1:1',1],['45','4:5',.8],['169','16:9',16/9],['916','9:16',9/16]];
/* a second layer above sheets, for the photo editor and the voice recorder */
let LAYER_CB=null;
function layer(html,onClose){const el=$('#layer');if(LAYER_CB){const f=LAYER_CB;LAYER_CB=null;try{f()}catch(e){}}LAYER_CB=onClose||null;el.innerHTML=`<div class="panel" role="dialog" aria-modal="true">${html}</div>`;el.hidden=false;return el}
function closeLayer(){const el=$('#layer');if(el.hidden)return;if(LAYER_CB){const f=LAYER_CB;LAYER_CB=null;try{f()}catch(e){}}el.hidden=true;el.innerHTML=''}
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
async function pickVideo(){const f=await pickFile('video/*');if(!f)return null;if(f.size>50e6){toast('ვიდეო 50 მბ-ზე ნაკლები უნდა იყოს');return null}return f}
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

/* the kantsi (drinking horn) reaction, stored as 🍷 */
const KANTSI='<svg class="kantsi" viewBox="0 0 32 32" aria-label="ყანწი" role="img"><path d="M5 9c5 1 14 1 22-3-1 7-5 15-12 19-2 1-4 1-5-1-2-4-3-9-5-15z" fill="#C98A12"/><path d="M5 9c5 1 14 1 22-3" fill="none" stroke="#7A4B07" stroke-width="1.6" stroke-linecap="round"/><path d="M7 12c4 .6 11 .3 18-2.6" fill="none" stroke="#FFE3A3" stroke-width="1.2" opacity=".8"/><path d="M10 24c1 2 3 2 5 1" fill="none" stroke="#7A4B07" stroke-width="1.4" stroke-linecap="round"/><path d="M8 8.6c4 .5 11 .4 17-2.4l1 1c-6 3.2-13 3.4-18 2.6z" fill="#A8164A"/></svg>';
const rg=e=>e==='🍷'?KANTSI:e;
