/* settings, coins, verification, push, install, rules, privacy, export, delete */
function setCoins(n){if(!ME||n==null||isNaN(n))return;const old=ME.coins||0;ME.coins=n;
 $$('.coinv').forEach(c=>{animNum(c,old,n);const ch=c.closest('.cwal');if(ch){ch.classList.remove('bump');void ch.offsetWidth;ch.classList.add('bump')}})}
/* settings: one short page of groups. Each group opens its own page, so one back comes straight back here */
const chev=()=>`<span class="chev" aria-hidden="true">${ic('back')}</span>`;
const sIc=(i,c)=>`<span class="sic"${c?` style="--c:${c}"`:''}>${ic(i)}</span>`;
const sLink=(a,i,c,label,sub,extra='')=>`<button class="srow" data-a="${a}"${extra}>${sIc(i,c)}<span class="grow"><span>${label}</span>${sub?`<small>${sub}</small>`:''}</span>${chev()}</button>`;
const sPage=(p,i,c,label,sub)=>sLink('page',i,c,label,sub,` data-p="${p}"`);
const sSwitch=(a,k,label,sub,on)=>`<div class="srow"><span class="grow"><span>${label}</span>${sub?`<small>${sub}</small>`:''}</span><button class="switch" role="switch" aria-checked="${!!on}" data-a="${a}"${k?` data-k="${k}"`:''} aria-label="${label}"></button></div>`;
const sw=(k,label,sub)=>sSwitch('tog',k,label,sub,!!ME.privacy?.[k]);
const segSet=(k,label,opts)=>`<div class="srow wrap"><span class="grow"><span>${label}</span></span><div class="seg flat" role="group" aria-label="${label}">${opts.map(([v,l])=>`<button data-a="pset" data-k="${k}" data-v="${v}" aria-pressed="${(ME.privacy?.[k]||'all')===v}">${l}</button>`).join('')}</div></div>`;
const sGroup=(t,body)=>`<section class="sgrp">${t?`<h3>${t}</h3>`:''}<div class="sbox">${body}</div></section>`;
const ZL={1:'ჩვეულებრივი','1.1':'დიდი','1.2':'უფრო დიდი'};
function notifShort(push){const n=notifCfg(),off=NCATS.filter(c=>n.off[c[0]]).length;return [push?'Push ჩართულია':'Push გამორთულია',off?`${off} ტიპი გამორთულია`:'',n.quiet.on?'ღამით ჩუმად':''].filter(Boolean).join(' · ')}
function privSummary(){const p=ME.privacy||{};return [p.online===false?'ონლაინ სტატუსი დამალულია':'ონლაინ სტატუსი ჩანს',p.dm==='friends'?'მოგწერენ მეგობრები':'მოგწერს ყველა',BLOCKED.size?`${BLOCKED.size} დაბლოკილი`:''].filter(Boolean).join(' · ')}
function appSummary(){const a=A11Y();return ['ტექსტი: '+(ZL[a.z]||ZL[1]),S.eco?'ეკონომიური რეჟიმი':'',a.hc?'მაღალი კონტრასტი':''].filter(Boolean).join(' · ')}
PG.settings={r(){const p=ME,push=store.get('push',false);view.innerHTML=pgHead('პარამეტრები')+`<div class="sets">
 <button class="setme" data-a="editprofile">${av('me',56)}<span class="grow"><b>${esc(p.name)}${vb(p)}</b><small>${[p.username?'@'+esc(p.username):'',esc(S.email||'')].filter(Boolean).join(' · ')}</small><em>პროფილის რედაქტირება</em></span>${chev()}</button>
 ${sGroup('ანგარიში',sPage('verify','shield','var(--super)','ვერიფიკაცია',p.verified?'დადასტურებულია ✓':'მიიღე ლურჯი ნიშანი ერთი სელფით')
  +sPage('edu','school','var(--vine)','განათლება','სკოლა, კლასი, უნივერსიტეტი, კურსი')
  +sPage('coins','coin','var(--gold)','მონეტები','ბალანსი: '+(p.coins??0))
  +(isAdult()?sLink('datesettings','heart','var(--nope)','გაცნობის პროფილი',p.dating?'ჩართულია':'გამორთულია'):''))}
 ${sGroup('პარამეტრები',sPage('notifset','bell','var(--wine)','შეტყობინებები',notifShort(push))
  +sPage('setprivacy','lock','var(--vine)','კონფიდენციალურობა',privSummary())
  +sPage('setapp','eye','var(--super)','ეკრანი და აპი',appSummary()))}
 ${isStaff()?sGroup('',sPage('admin','shield','var(--gold)','ადმინ პანელი','საჩივრები, ვერიფიკაცია, რეკლამა')):''}
 ${sGroup('წესები და მონაცემები',sLink('rules','flag','var(--muted)','საზოგადოების წესები')+sLink('privacy','lock','var(--muted)','კონფიდენციალურობის პოლიტიკა')+sLink('exportdata','download','var(--muted)','ჩემი მონაცემების ჩამოტვირთვა','ყველაფერი ერთ ფაილში'))}
 ${sGroup('',`<button class="srow" data-a="signout">${sIc('logout','var(--nope)')}<span class="grow"><span>გასვლა</span>${S.email?`<small>${esc(S.email)}</small>`:''}</span></button>`)}
 <button class="sdel" data-a="delaccount">${ic('trash')}ანგარიშის წაშლა</button></div>`}};
PG.setprivacy={r(){const pr=ME.privacy||{};view.innerHTML=pgHead('კონფიდენციალურობა')+`<div class="sets">
 ${ME.birthday&&!isAdult()?`<p class="hint kusafe">${ic('lock')}<span>18 წლამდე ხარ, ამიტომ დაცვა ჩართულია: უცნობ ზრდასრულებს არ შეუძლიათ მოგწერონ, მეგობრობა გთხოვონ, საჩუქარი გამოგიგზავნონ ან ძებნაში გიპოვონ. შენთან კავშირი აქვთ მეგობრებს, ოჯახის წევრებს და კლასელებს ან კურსელებს.</span></p>`:''}
 ${sGroup('ვინ რას ხედავს',sSwitch('onlinetog','','ონლაინ სტატუსი','სხვები ხედავენ, როცა ონლაინ ხარ',pr.online!==false)
  +sSwitch('readtog','','„ნანახია“ და „წერს…“','გამორთვისას სხვები ვერ ნახავენ, რომ წაიკითხე ან წერ. შენც ვერ დაინახავ მათსას',pr.read!==false)
  +sw('guest','უხილავი სტუმარი','სხვის პროფილს ისე ნახავ, რომ მის სტუმრებში არ გამოჩნდე'))}
 ${sGroup('ვინ დამიკავშირდეს',segSet('dm','ვინ მომწეროს',[['all','ყველამ'],['friends','მეგობრებმა']])+segSet('chal','ვინ გამომიწვიოს თამაშში',[['all','ყველამ'],['friends','მეგობრებმა'],['none','არავინ']]))}
 ${sGroup('ისტორიები',sPage('close','star','var(--gold)','ახლო მეგობრები','ვინ ნახავს „ახლო მეგობრების“ ისტორიებს'))}
 ${sGroup('დაბლოკილები',`<div id="blk">${BLOCKED.size?'<p class="sempty">იტვირთება…</p>':'<p class="sempty">დაბლოკილი არავინ გყავს.</p>'}</div>`)}</div>`;
 if(BLOCKED.size)loadProfiles([...BLOCKED]).then(()=>{const el=$('#blk');if(el)el.innerHTML=[...BLOCKED].map(id=>`<div class="srow">${av(id,36)}<span class="grow"><span>${esc(pname(id))}</span></span><button class="btn sm ghost" data-a="unblock" data-u="${id}">განბლოკვა</button></div>`).join('')})}};
PG.setapp={r(){const a=A11Y();view.innerHTML=pgHead('ეკრანი და აპი')+`<div class="sets">
 ${sGroup('კითხვა',`<div class="srow wrap"><span class="grow"><span>ტექსტის ზომა</span><small>ზრდის ყველაფერს: ტექსტს, ღილაკებს, ფოტოებს</small></span><div class="seg flat" role="group" aria-label="ტექსტის ზომა">${[[1,'ჩვეულებრივი'],[1.1,'დიდი'],[1.2,'უფრო დიდი']].map(([v,l])=>`<button data-a="a11yz" data-v="${v}" aria-pressed="${+a.z===v}" style="font-size:${13*v}px">${l}</button>`).join('')}</div></div>`
  +sSwitch('a11yhc','','მაღალი კონტრასტი','უფრო მუქი ტექსტი და მკაფიო საზღვრები',!!a.hc))}
 <p class="snote">პოსტის ხმამაღლა მოსასმენად: პოსტთან „…“ → „მოსმენა“.</p>
 ${sGroup('ინტერნეტი და ვიდეო',sSwitch('ecotog','','ეკონომიური რეჟიმი','სუსტი ინტერნეტისთვის: ფოტო და ვიდეო შეხებით იტვირთება, კლიპები თავისით არ ირთვება, ატვირთვა უფრო მსუბუქია',!!S.eco)
  +sSwitch('vautotog','','ვიდეოს ავტოჩართვა','ფიდზე ვიდეო უხმოდ ირთვება, როცა ეკრანზე გამოჩნდება',store.get('vauto',true)!==false))}
 ${sGroup('აპი',sLink('install','download','var(--wine)','ტელეფონზე დაყენება','Peera აპივით მთავარ ეკრანზე')
  +`<div class="srow">${sIc('globe','var(--super)')}<span class="grow"><span>ენა: ქართული</span><small>თარგმნის ღილაკი სხვა ენაზე დაწერილს ქართულად თარგმნის. სხვა ენები მალე დაემატება</small></span></div>`)}</div>`}};
async function savePrivacy(){try{await q(sb.from('profiles').update({privacy:ME.privacy}).eq('id',ME.id))}catch(e){toast(errMsg(e))}}
A.tog=t=>{const k=t.dataset.k;ME.privacy=Object.assign({},ME.privacy,{[k]:!ME.privacy?.[k]});t.setAttribute('aria-checked',String(!!ME.privacy[k]));savePrivacy();if(k==='online')netPresence()};
/* the online status is shown unless it was switched off, so the switch starts on */
A.onlinetog=t=>{const on=ME.privacy?.online===false;ME.privacy=Object.assign({},ME.privacy,{online:on});t.setAttribute('aria-checked',String(on));savePrivacy();netPresence();toast(on?'ონლაინ სტატუსი ჩანს':'ონლაინ სტატუსი დამალულია')};
A.readtog=t=>{const on=ME.privacy?.read===false;ME.privacy=Object.assign({},ME.privacy,{read:on});t.setAttribute('aria-checked',String(on));savePrivacy();toast(on?'„ნანახია“ ჩაირთო':'„ნანახია“ გამოირთო')};
/* notification settings: categories and quiet hours */
/* bigger text and high contrast, kept on this device */
const A11Y=()=>Object.assign({z:1,hc:false},store.get('a11y',{}));
function applyA11y(){const a=A11Y(),r=document.documentElement,z=[1,1.1,1.2].includes(+a.z)?+a.z:1;r.style.setProperty('--z',z);r.style.zoom=z===1?'':z;r.classList.toggle('zoomed',z!==1);r.classList.toggle('hc',!!a.hc)}
applyA11y();
A.a11yz=t=>{store.set('a11y',Object.assign(A11Y(),{z:+t.dataset.v}));applyA11y();$$('[data-a="a11yz"]').forEach(b=>b.setAttribute('aria-pressed',String(b===t)))};
A.a11yhc=t=>{const on=!A11Y().hc;store.set('a11y',Object.assign(A11Y(),{hc:on}));applyA11y();t.setAttribute('aria-checked',String(on))};
const NCATS=[['study','book','ლექციები და გამოცდები','შეხსენება ლექციამდე 15 წუთით ადრე, გამოცდამდე წინა საღამოს და იმ დილით, ჯგუფის ახალი ვადები'],['reactions','heart','მოწონებები და რეაქციები','პოსტზე, კომენტარზე, მესიჯზე, ისტორიაზე, რეპოსტები'],['comments','comment','კომენტარები, პასუხები, ხსენებები','როცა @სახელით მოგიხსენიებენ'],['friends','users','მეგობრობა და ოჯახის ხე','მოთხოვნები და დადასტურება'],['messages','msg','მესიჯები','მხოლოდ push ითიშება, მესიჯები ჩატში მაინც მოვა'],['celebrations','gift','ანგელოზის და დაბადების დღეები','მეგობრების დღესასწაულები'],['live','live','ლაივები','როცა მეგობარი ეთერში გადის'],['rooms','video','სასწავლო ოთახისა და დისკუსიის მოსაწვევები',''],['help','help','დახმარების თხოვნები ახლოს','დონორი, მოხალისე, დაკარგული ცხოველი'],['dating','heart','გაცნობა','წყვილები და სუპერ მოწონებები'],['gifts','gift','საჩუქრები',''],['sport','trophy','მატჩები და პროგნოზები',''],['deals','pin','მგზავრობა და ვაკანსიები','ჯავშნები და გამოხმაურებები'],['groups','users','ჯგუფები','მოთხოვნები, დასამტკიცებელი პოსტები'],['events','cal','ღონისძიებები და ალბომები','მოწვევები, შეხსენებები, ახალი ფოტოები'],['promo','mega','სიახლეები და რეკლამა','Peera-ს გუნდის შეტყობინებები ყველასთვის']];
const notifCfg=()=>{const n=ME.notif&&typeof ME.notif==='object'?ME.notif:{};return {off:Object.assign({},n.off||{}),quiet:Object.assign({on:false,from:23,to:8},n.quiet||{})}};
function notifSummary(){const n=notifCfg(),off=NCATS.filter(c=>n.off[c[0]]).length;return [off?`${off} ტიპი გამორთულია`:'ყველა ჩართულია',n.quiet.on?`ღამის საათები ${String(n.quiet.from).padStart(2,'0')}:00–${String(n.quiet.to).padStart(2,'0')}:00`:''].filter(Boolean).join(' · ')}
async function saveNotif(n){const tz=(()=>{try{const z=Intl.DateTimeFormat().resolvedOptions().timeZone;return /^[A-Za-z_]+(\/[A-Za-z0-9_+-]+){0,2}$/.test(z||'')?z:'Asia/Tbilisi'}catch(e){return 'Asia/Tbilisi'}})();
 n.quiet.tz=tz;ME.notif=n;try{await q(sb.from('profiles').update({notif:n}).eq('id',ME.id))}catch(e){toast(errMsg(e))}}
const hourOpts=v=>Array.from({length:24},(_,h)=>`<option value="${h}"${+v===h?' selected':''}>${String(h).padStart(2,'0')}:00</option>`).join('');
PG.notifset={r(){const n=notifCfg(),push=store.get('push',false);view.innerHTML=pgHead('შეტყობინებები')+`<div class="sets">
 ${sGroup('ტელეფონზე',sSwitch('pushtog','','Push შეტყობინებები','მოწონებები, კომენტარები, მესიჯები, ზარები, როცა აპი დახურულია',push))}
 ${sGroup('ღამის საათები',`<div class="srow">${sIc('clock')}<span class="grow"><span>არ შემაწუხო</span><small>ამ საათებში ტელეფონზე push არ მოვა. შეტყობინებები მაინც შეგროვდება და დილით ნახავ</small></span><button class="switch" role="switch" aria-checked="${!!n.quiet.on}" data-a="nquiet" aria-label="ღამის საათები"></button></div>
  <div class="nqhours" id="nqh"${n.quiet.on?'':' hidden'}><div class="frow"><label class="fld">დან<select id="nq_f">${hourOpts(n.quiet.from)}</select></label><label class="fld">მდე<select id="nq_t">${hourOpts(n.quiet.to)}</select></label></div><p class="note" id="nqs"${n.quiet.on?'':' hidden'}></p></div>`)}
 ${sGroup('რა შეტყობინებები მივიღო',NCATS.filter(c=>c[0]!=='dating'||isAdult()).map(([k,i,l,sub])=>`<div class="srow">${sIc(i)}<span class="grow"><span>${l}</span>${sub?`<small>${sub}</small>`:''}</span><button class="switch" role="switch" aria-checked="${!n.off[k]}" data-a="ncat" data-k="${k}" aria-label="${l}"></button></div>`).join(''))}
 <p class="snote">გამორთული ტიპის შეტყობინება აღარ მოვა: არც შეტყობინებების სიაში, არც ტელეფონზე. სისტემური შეტყობინებები (ვერიფიკაცია, რეკლამა, დახმარების პასუხები) ყოველთვის მოდის.</p></div>`;
 const qs=()=>{const c=notifCfg(),el=$('#nqs');if(el)el.textContent=+c.quiet.from===+c.quiet.to?'დასაწყისი და დასასრული ერთნაირია, ამიტომ არაფერი ჩუმდება.':`ყოველდღე ${String(c.quiet.from).padStart(2,'0')}:00-დან ${String(c.quiet.to).padStart(2,'0')}:00-მდე push ჩუმადაა.`};qs();
 const hs=()=>{const c=notifCfg();c.quiet.from=+$('#nq_f').value;c.quiet.to=+$('#nq_t').value;saveNotif(c).then(qs);qs()};$('#nq_f').onchange=hs;$('#nq_t').onchange=hs}};
A.ncat=t=>{const c=notifCfg(),k=t.dataset.k,on=!!c.off[k];if(on)delete c.off[k];else c.off[k]=true;t.setAttribute('aria-checked',String(on));saveNotif(c)};
A.nquiet=t=>{const c=notifCfg();c.quiet.on=!c.quiet.on;t.setAttribute('aria-checked',String(c.quiet.on));$('#nqh').hidden=!c.quiet.on;$('#nqs').hidden=!c.quiet.on;saveNotif(c).then(()=>{const el=$('#nqs');if(el&&c.quiet.on)el.textContent=`ყოველდღე ${String(c.quiet.from).padStart(2,'0')}:00-დან ${String(c.quiet.to).padStart(2,'0')}:00-მდე push ჩუმადაა.`})};
A.pset=t=>{ME.privacy=Object.assign({},ME.privacy,{[t.dataset.k]:t.dataset.v});$$(`[data-a="pset"][data-k="${t.dataset.k}"]`).forEach(b=>b.setAttribute('aria-pressed',String(b===t)));savePrivacy()};
A.vautotog=t=>{const on=store.get('vauto',true)===false;store.set('vauto',on);t.setAttribute('aria-checked',String(on));if(!on)$$('.pmi video').forEach(v=>{try{v.pause()}catch(e){}});toast(on?'ვიდეო თავისით ჩაირთვება':'ვიდეო ჩაირთვება შეხებით')};
A.ecotog=t=>{S.eco=!S.eco;store.set('eco',S.eco);document.documentElement.classList.toggle('eco',S.eco);t.setAttribute('aria-checked',String(S.eco));toast(S.eco?'ეკონომიური რეჟიმი ჩართულია':'ეკონომიური რეჟიმი გამორთულია')};
const urlB64=s=>{const p='='.repeat((4-s.length%4)%4),b=atob((s+p).replace(/-/g,'+').replace(/_/g,'/'));return Uint8Array.from([...b].map(c=>c.charCodeAt(0)))};
async function enablePush(){if(!('serviceWorker' in navigator)||!('PushManager' in window)){toast(/iPhone|iPad/.test(navigator.userAgent)?'iPhone-ზე ჯერ დაამატე Peera მთავარ ეკრანზე (გაზიარება → „Add to Home Screen“)':'ამ ბრაუზერს push შეტყობინებები არ აქვს');return false}
 const perm=await Notification.requestPermission();if(perm!=='granted'){toast('შეტყობინებები ბრაუზერში დაბლოკილია. ჩართე საიტის პარამეტრებში');return false}
 const reg=await navigator.serviceWorker.ready,key=await rpc('vapid_public_key');let sub=await reg.pushManager.getSubscription();if(!sub)sub=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:urlB64(key)});
 const j=sub.toJSON();await sb.from('push_subs').delete().eq('endpoint',j.endpoint);await q(sb.from('push_subs').insert({user_id:ME.id,endpoint:j.endpoint,p256dh:j.keys.p256dh,auth:j.keys.auth}));store.set('push',true);toast('შეტყობინებები ჩართულია');return true}
async function disablePush(){try{const reg=await navigator.serviceWorker.ready,sub=await reg.pushManager.getSubscription();if(sub){await sb.from('push_subs').delete().eq('endpoint',sub.endpoint);await sub.unsubscribe()}}catch(e){}store.set('push',false);toast('შეტყობინებები გამორთულია')}
A.pushtog=async t=>{const on=t.getAttribute('aria-checked')==='true';t.disabled=true;try{const ok=on?(await disablePush(),false):await enablePush();t.setAttribute('aria-checked',String(!!ok))}catch(e){toast(errMsg(e))}t.disabled=false};
A.install=async()=>{if(S.installEvt){S.installEvt.prompt();const r=await S.installEvt.userChoice;if(r.outcome==='accepted')toast('Peera დაყენდა');S.installEvt=null;return}
 if(window.matchMedia('(display-mode: standalone)').matches){toast('Peera უკვე დაყენებულია');return}
 sheet(head('ტელეფონზე დაყენება')+`<div class="ph-body"><p><b>iPhone / iPad (Safari):</b> დააჭირე გაზიარების ღილაკს და აირჩიე „Add to Home Screen“ (მთავარ ეკრანზე დამატება).</p><p><b>Android (Chrome):</b> მენიუ ⋮ → „Install app“ ან „Add to Home screen“.</p><p><b>კომპიუტერი (Chrome, Edge):</b> მისამართის ველის მარჯვნივ დაყენების ღილაკი.</p></div>`,'short')};
PG.verify={async r(){view.innerHTML=pgHead('ვერიფიკაცია')+`<div id="vb">${skel(1)}</div>`;let last=null;try{last=await q(sb.from('verification_requests').select('status,created_at').eq('user_id',ME.id).order('created_at',{ascending:false}).limit(1).maybeSingle())}catch(e){}
 const el=$('#vb');if(!el)return;
 if(ME.verified)el.innerHTML=`<div class="vcard"><span class="vb" style="width:48px;height:48px">${ic('check')}</span><h3>პროფილი ვერიფიცირებულია</h3><p class="muted">შენს სახელთან ლურჯი ნიშანი ჩანს.</p></div>`;
 else if(last?.status==='pending')el.innerHTML=`<div class="vcard"><h3>განაცხადი განხილვაშია</h3><p class="muted">მოდერატორი შეადარებს სელფის შენს პროფილის ფოტოს. შედეგს შეტყობინებით მიიღებ.</p></div>`;
 else el.innerHTML=`<div class="vcard"><h3>დაადასტურე, რომ ფოტოებზე შენ ხარ</h3>${last?.status==='rejected'?'<p class="aerr">წინა განაცხადი ვერ დადასტურდა. სცადე ახალი, მკაფიო სელფით.</p>':''}<p class="muted">ლურჯი ნიშანი ჩანს პოსტებთან, მესიჯებში და გაცნობის ბარათზე.${ME.avatar_url?'':' ჯერ დაამატე პროფილის ფოტო, რომ მოდერატორმა შეადაროს.'}</p>
  <div class="pose"><span aria-hidden="true">✌️</span><div><b>პოზა: აწიე ორი თითი</b><br><span class="muted" style="font-size:13px">სახე კარგად უნდა ჩანდეს, სათვალის და ქუდის გარეშე.</span></div></div>
  <img class="selfie" id="sfp" alt="შენი სელფი" hidden><div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn" id="sfi">${ic('user')}სელფის გადაღება</button><button class="btn ghost" id="sfs" disabled>გაგზავნა</button></div>
  <p class="note">სელფი ინახება დახურულ საცავში. მას მხოლოდ მოდერატორი ხედავს და მხოლოდ ვერიფიკაციისთვის.</p></div>`;
 let blob=null;const sfi=$('#sfi');if(sfi)sfi.onclick=async()=>{const f=await pickFile('image/*',{capture:'user'});if(!f)return;blob=await shrink(f,1200);const im=$('#sfp');im.src=URL.createObjectURL(blob);im.hidden=false;$('#sfs').disabled=false};
 const sfs=$('#sfs');if(sfs)sfs.onclick=async()=>{sfs.disabled=true;sfs.textContent='იგზავნება…';try{const path=await uploadBlob(blob,'jpg','verify');await q(sb.from('verification_requests').insert({user_id:ME.id,selfie_url:path}));toast('გაიგზავნა');rp()}catch(e){toast(errMsg(e));sfs.disabled=false;sfs.textContent='გაგზავნა'}}}};
A.exportdata=async()=>{toast('ვამზადებ ფაილს…');try{const[me,posts,comments,listings,events,friends,coins,gifts,payouts]=await Promise.all([rpc('my_profile'),q(sb.from('posts').select('id,body,media,poll,tags,created_at').eq('author',ME.id)),q(sb.from('comments').select('id,post_id,body,created_at').eq('author',ME.id)),q(sb.from('listings').select('*').eq('seller',ME.id)),q(sb.from('events').select('*').eq('host',ME.id)),q(sb.from('friendships').select('*').or(`requester.eq.${ME.id},addressee.eq.${ME.id}`)),q(sb.from('coin_log').select('*').eq('user_id',ME.id)),q(sb.from('gifts').select('*').or(`sender.eq.${ME.id},recipient.eq.${ME.id}`)),q(sb.from('payouts').select('*').eq('user_id',ME.id)).catch(()=>[])]);
 const blob=new Blob([JSON.stringify({exported_at:new Date().toISOString(),profile:me,posts,comments,listings,events,friendships:friends,coin_log:coins,gifts,payouts},null,2)],{type:'application/json'});const a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='peera-data.json';document.body.appendChild(a);a.click();a.remove()}catch(e){toast(errMsg(e))}};
A.delaccount=()=>{sheet(head('ანგარიშის წაშლა')+`<div class="ph-body"><p>წაიშლება შენი პროფილი, პოსტები, კომენტარები, მესიჯები, განცხადებები და ატვირთული ფაილები. ამას ვეღარ დააბრუნებ.</p><label class="fld">დასადასტურებლად ჩაწერე: წაშლა<input id="delc" autocomplete="off"></label></div><div class="ph-foot"><button class="btn ghost" data-a="close">გაუქმება</button><span class="sp"></span><button class="btn danger" id="delok" disabled>სამუდამოდ წაშლა</button></div>`,'short');
 $('#delc').oninput=e=>{$('#delok').disabled=e.target.value.trim()!=='წაშლა'};$('#delok').onclick=async()=>{$('#delok').disabled=true;try{const{data,error}=await sb.functions.invoke('account',{body:{action:'delete'}});if(error||!data?.ok)throw error||new Error(data?.error||'failed');await sb.auth.signOut().catch(()=>{});toast('ანგარიში წაიშალა');setTimeout(()=>location.reload(),1200)}catch(e){toast(errMsg(e));$('#delok').disabled=false}}};
const RULES=`<h3>ვინ შეიძლება იყოს Peera-ზე</h3><p>რეგისტრაცია 13 წლიდანაა შესაძლებელი. გაცნობის ნაწილი მხოლოდ 18 წელს გადაცილებულებისთვისაა. ერთი ადამიანი, ერთი ნამდვილი ანგარიში.</p>
<h3>პატივისცემა</h3><p>აკრძალულია შეურაცხყოფა, მუქარა, შევიწროება, სიძულვილის ენა ეროვნების, რელიგიის, სქესის, ორიენტაციის, შეზღუდული შესაძლებლობის ან სხვა ნიშნით, და სხვისი დაცინვა.</p>
<h3>უსაფრთხოება</h3><p>აკრძალულია ძალადობის პროპაგანდა, თვითდაზიანების წახალისება, იარაღით ან ნარკოტიკით ვაჭრობა და ნებისმიერი შინაარსი, რომელიც არასრულწლოვანს ზიანს აყენებს. ასეთ შემთხვევაში ანგარიში დაუყოვნებლივ იბლოკება.</p>
<h3>შინაარსი</h3><p>არ გამოაქვეყნო შიშველი ან სექსუალური შინაარსი, სხვისი პირადი ინფორმაცია მისი თანხმობის გარეშე, სხვისი ნამუშევარი ნებართვის გარეშე, სპამი და თაღლითური შეთავაზებები.</p>
<h3>ბაზრობა და რეკლამა</h3><p>ბაზრობაზე იყიდება მხოლოდ კანონიერი ნივთები. რეკლამა მოდერაციას გადის. ფული წინასწარ არავის გადაურიცხო.</p>
<h3>საჩივარი და შედეგები</h3><p>ყველაფერზე შეგიძლია საჩივრის გაგზავნა. მოდერატორი შეიძლება დამალოს შინაარსი ან შეზღუდოს ანგარიში. დაბლოკვით ნებისმიერ ადამიანს მოიშორებ შენი სივრციდან.</p>`;
const PRIVACY=`<h3>რა მონაცემებს ვაგროვებთ</h3><p>ანგარიშისთვის: ელფოსტა და პაროლის დაცული ჰეში. პროფილისთვის: სახელი, მომხმარებლის სახელი, ფოტო, ბიო, ქალაქი და დაბადების თარიღი (ის სხვებს არ უჩანთ, მხოლოდ ასაკის შესამოწმებლად გამოიყენება). შენი შინაარსი: პოსტები, კომენტარები, მესიჯები, ფაილები, რეაქციები, განცხადებები და ღონისძიებები. გაცნობაში: სქესი, ვის ეძებ და ინტერესები, თუ თავად ჩართავ.</p>
<h3>რისთვის</h3><p>სერვისის მუშაობისთვის, უსაფრთხოებისთვის და მოდერაციისთვის. შენს მონაცემებს არ ვყიდით და მესამე მხარეს სარეკლამოდ არ ვაძლევთ.</p>
<h3>სად ინახება</h3><p>მონაცემები ინახება Supabase-ის სერვერებზე ევროკავშირში (ირლანდია), საიტი კი Vercel-ის ინფრასტრუქტურაზე მუშაობს. როცა თარგმნის ღილაკს დააჭერ, ის ტექსტი თარგმნის სერვისს ეგზავნება. ზარები პირდაპირ მოწყობილობებს შორის მიდის და არ ინახება.</p>
<h3>ვინ ხედავს</h3><p>პოსტებს და პროფილს Peera-ს რეგისტრირებული მომხმარებლები ხედავენ, მესიჯებს მხოლოდ საუბრის მონაწილეები, დახურული ჯგუფის პოსტებს მხოლოდ წევრები. მოდერატორი ხედავს საჩივრებს და ვერიფიკაციის სელფებს.</p>
<h3>შენი უფლებები</h3><p>საქართველოს „პერსონალურ მონაცემთა დაცვის შესახებ“ კანონის და GDPR-ის მიხედვით შეგიძლია მოითხოვო მონაცემების ნახვა, გასწორება და წაშლა. პარამეტრებში ჩამოტვირთავ შენს მონაცემებს და სამუდამოდ წაშლი ანგარიშს.</p>
<h3>ქუქი-ფაილები</h3><p>ვიყენებთ მხოლოდ აუცილებელ ლოკალურ საცავს, რომ შესული დარჩე და პარამეტრები დაიმახსოვროს. სარეკლამო თვალთვალი არ არის.</p>`;
A.rules=()=>sheet(head('საზოგადოების წესები')+`<div class="ph-body doc">${RULES}</div>`);
A.privacy=()=>sheet(head('კონფიდენციალურობის პოლიტიკა')+`<div class="ph-body doc">${PRIVACY}</div>`);
