/* coins: one balance in two parts. "Cash" coins come from activity while the admin's promotion runs and can later be
   paid out in lari (10,000 = 1 ₾); the rest are for spending (gifts, game styles). The server decides everything:
   the rules for every page, the limits, the promotion. Here: the coin page with today's progress, a small "+N"
   when coins arrive, a hint on each page while the promotion runs, and the admin's promotion tab. */
const CN={rules:null,my:null,t:0,tm:0};
/* rule page → name, icon, where it opens */
const CPAGE={home:['ფიდი','home','home'],chat:['შეტყობინებები','msg','chat'],stories:['ისტორიები','story','storyarch'],clips:['კლიპები','clips','clips'],
 groups:['ჯგუფები','users','groups'],friends:['მეგობრები','user','friends'],sport:['სპორტი','trophy','sport'],games:['თამაშები','dice','games'],
 recipes:['სამზარეულო','pot','recipes'],help:['დახმარება','help','help'],places:['ადგილები','pin','places'],albums:['ალბომები','image','albums'],
 events:['შეხვედრები','cal','events'],toasts:['სადღეგრძელოები','wine','toasts'],market:['ბაზრობა','store','market'],jobs:['ვაკანსიები','work','jobs'],
 rides:['მგზავრობა','route','rides'],tree:['ოჯახის ხე','tree','tree'],schedule:['ლექციების ცხრილი','school','schedule'],exams:['დავალებები','clock','exams'],me:['პროფილი','user','me']};
/* app page → the rules shown on it */
const PG2RULE={groups:'groups',group:'groups',friends:'friends',sport:'sport',fixture:'sport',recipes:'recipes',recipe:'recipes',help:'help',helpreq:'help',
 places:'places',place:'places',albums:'albums',album:'albums',events:'events',event:'events',toasts:'toasts',market:'market',jobs:'jobs',job:'jobs',
 rides:'rides',ride:'rides',tree:'tree',schedule:'schedule',exams:'exams',storyarch:'stories'};
const nf=n=>Number(n||0).toLocaleString('en-US');
const cgel=(n,rate)=>{const v=(n||0)/(rate||10000);return v>0&&v<0.01?v.toFixed(4):v.toFixed(2)};
const cDate=d=>d?`${d.getDate()} ${MONTHS[d.getMonth()]}`:'';

async function coinsLoad(force){if(!force&&CN.rules&&CN.my&&Date.now()-CN.t<60e3)return CN;
 const[rules,my]=await Promise.all([CN.rules&&!force?CN.rules:q(sb.from('coin_rules').select('action,page,label,hint,amount,every_n,day_cap,once,active,pos').order('pos')),rpc('my_coins')]);
 CN.rules=rules||[];CN.my=my||null;CN.t=Date.now();
 if(my){ME.coins_cash=my.cash;if(my.coins!=null&&my.coins!==ME.coins)setCoins(my.coins)}return CN}

/* coins arrive from anywhere (a grade on your photo, an accepted friend request): the history row changes, we look again */
function coinsInit(){if(!ME||ME.offline)return;coinsLoad().catch(()=>{});
 try{sb.channel('coins-'+ME.id).on('postgres_changes',{event:'*',schema:'public',table:'coin_log',filter:'user_id=eq.'+ME.id},()=>{clearTimeout(CN.tm);CN.tm=setTimeout(coinCheck,700)}).subscribe()}catch(e){}}
async function coinCheck(){const old=ME.coins||0;let my;try{my=await rpc('my_coins')}catch(e){return}if(!my)return;
 CN.my=my;CN.t=Date.now();ME.coins_cash=my.cash;const d=(my.coins||0)-old;if(d)setCoins(my.coins);if(d>0)coinPing(d);
 if(S.page?.id==='coins')drawCoins()}
function coinPing(n){const c=$('.coinchip'),r=c?c.getBoundingClientRect():null,b=document.createElement('span');b.className='coinping';b.setAttribute('aria-hidden','true');
 b.innerHTML=`+${nf(n)} ${ic('coin')}`;if(r&&r.width){b.style.left=(r.left+r.width/2)+'px';b.style.top=(r.bottom+4)+'px'}else{b.style.left='50%';b.style.top='calc(env(safe-area-inset-top) + 56px)'}
 document.body.appendChild(b);setTimeout(()=>b.remove(),1600)}

/* while the promotion runs, a page says what it pays */
function earnBar(id){const k=PG2RULE[id],m=CN.my;if(!k||!CN.rules||!m||!m.promo)return;const h=view.querySelector('.pghead');if(!h||view.querySelector('.earnbar'))return;
 const rs=CN.rules.filter(r=>r.page===k&&r.active&&r.amount>0).slice(0,3);if(!rs.length)return;const full=m.today>=m.daily_max;
 h.insertAdjacentHTML('afterend',`<button class="earnbar${full?' full':''}" data-a="page" data-p="coins" aria-label="მონეტების წესები">${ic('coin')}<span class="grow">${rs.map(r=>`${esc(r.label)} <b>+${r.amount}</b>`).join('<i>·</i>')}</span><small>${full?'დღის ლიმიტი შევსებულია':`დღეს ${nf(m.today)}/${nf(m.daily_max)}`}</small></button>`)}

PG.coins={r(){view.innerHTML=pgHead('მონეტები')+`<div id="cnb">${skel(3)}</div>`;
 coinsLoad(true).then(drawCoins).catch(e=>{const el=$('#cnb');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',esc(errMsg(e)),'<button class="btn" data-a="cretry">თავიდან</button>')})}};
function drawCoins(){const el=$('#cnb');if(!el||!CN.my)return;const m=CN.my,rate=m.rate||10000,all=m.coins||0,cash=Math.min(m.cash||0,all),bon=all-cash,min=m.min_out||10000;
 const by=m.by||{},done=new Set(m.done||[]),max=m.daily_max||150,today_=m.today||0;
 // the 7 days of the bonus: claimed today, carried on from yesterday, or starting again
 const yest=new Date(new Date(m.day+'T12:00:00Z').getTime()-864e5).toISOString().slice(0,10),got=m.last_bonus===m.day,cont=m.last_bonus===yest;
 const filled=got?(m.streak||0):cont?(m.streak||0)%7:0,next=got?0:filled+1;
 const until=m.until?new Date(m.until):null,left=until?Math.max(0,Math.ceil((until-Date.now())/864e5)):0;
 const groups=[];CN.rules.filter(r=>r.active&&r.amount>0&&r.page!=='coins').forEach(r=>{let g=groups.find(x=>x.k===r.page);if(!g){g={k:r.page,rs:[]};groups.push(g)}g.rs.push(r)});
 const row=r=>{const e=by[r.action]||0,isDone=r.once?done.has(r.action):r.day_cap>0&&e>=r.day_cap;
  const prog=r.once?(isDone?ic('check'):'ერთხელ'):r.day_cap>0?(isDone?ic('check'):`${e}/${r.day_cap}`):'';
  return `<div class="crrow${isDone?' full':''}"><span class="grow"><b>${esc(r.label)}</b>${r.hint?`<small>${esc(r.hint)}</small>`:''}</span><span class="crp">${prog}</span><em class="crc">+${r.amount}</em></div>`};
 const grp=(g,i)=>{const[t,icn]=CPAGE[g.k]||[g.k,'coin'],e=g.rs.reduce((a,r)=>a+(by[r.action]||0),0),cap=g.rs.reduce((a,r)=>a+(r.once?(done.has(r.action)?0:r.amount):r.day_cap||r.amount),0);
  return `<details class="crgrp"${i<2?' open':''}><summary>${ic(icn)}<b>${esc(t)}</b><span class="crsum">${e?`<em>+${e}</em> დღეს`:`${cap?'+'+cap+'-მდე':''}`}</span></summary><div class="crlist">${g.rs.map(row).join('')}
   <button class="btn sm ghost crgo" data-a="cngo" data-k="${g.k}">${esc(t)}: გადასვლა</button></div></details>`};
 el.innerHTML=`<section class="balance cbal"><span>შენი ბალანსი</span><b id="cbal">${nf(all)}</b>
  <div class="cparts"><div><small>ლარად გასატანი</small><b>${nf(cash)}</b><small>≈ ${cgel(cash,rate)} ₾</small></div><div><small>სახარჯი</small><b>${nf(bon)}</b><small>საჩუქრები, მაღაზია</small></div></div>
  <div class="cout"><div class="cbar" role="progressbar" aria-label="გატანამდე" aria-valuemin="0" aria-valuemax="${min}" aria-valuenow="${Math.min(cash,min)}"><i style="width:${Math.min(100,cash/min*100)}%"></i></div>
  <small>${cash>=min?`გასატანად მზადაა ${nf(cash)} მონეტა (${cgel(Math.floor(cash/100)*100,rate)} ₾).`:`ლარად გასატანად საჭიროა ${nf(min)} მონეტა (${cgel(min,rate)} ₾). დაგრჩა ${nf(min-cash)}.`}</small>
  <button class="btn cout-go${cash>=min?'':' dim'}" data-a="page" data-p="payout">${ic('card')}ლარად გატანა</button></div></section><div id="cpend"></div>
 <section class="cpromo${m.promo?' on':''}"><span class="cpico">${m.promo?'🎉':ic('clock')}</span><div><b>${m.promo?'აქცია მიმდინარეობს':'აქცია ახლა არ მიდის'}</b>
  <span>${m.promo?`აქტივობით მიღებული მონეტები ლარად გასატანი ხდება: ${nf(rate)} მონეტა = 1 ₾.${until?` ბოლო დღე: ${cDate(until)} (დარჩა ${left} დღე).`:''}`:'მონეტები მაინც გროვდება და იხარჯება საჩუქრებზე და სტილებზე. ლარად გასატანი ხდება მხოლოდ აქციის დროს მიღებული მონეტები.'}</span></div></section>
 <section class="cday"><div class="cdays" aria-label="7 დღე ზედიზედ: ${filled} დღე">${[1,2,3,4,5,6,7].map(i=>`<span class="${i<=filled?'on':''}${i===next?' next':''}${i===7?' big':''}">${i===7?'+15':'+5'}</span>`).join('')}</div>
  <button class="btn${got?' ghost':''}" data-a="bonus"${got?' disabled':''}>${got?'დღევანდელი ბონუსი აღებულია':`აიღე დღიური ბონუსი: +${next===7?15:5}`}</button>
  <p class="note">ყოველდღე +5. მე-7 დღეს ზედიზედ დამატებით +10.</p></section>
 <section class="ctoday"><div><b>დღეს გამოიმუშავე ${nf(today_)} / ${nf(max)}</b><span>${today_>=max?'დღის ლიმიტი შევსებულია. ხვალ ისევ.':'ყველა აქტივობა ერთად, ბონუსის გარდა'}</span></div><div class="cbar"><i style="width:${Math.min(100,today_/max*100)}%"></i></div></section>
 <h3 class="sec2">როგორ გამოიმუშავო</h3><p class="note" style="padding:0 16px 8px">თითქმის ყველა გვერდზე. წაშლილი ან დამალული პოსტის, კომენტარის და სხვა მონეტები 24 საათში უკან ბრუნდება.</p>
 <div class="crules">${groups.map(grp).join('')}</div>
 <h3 class="sec2">ისტორია</h3><div class="hist" id="chist">${skel(1)}</div>`;
 coinHist();coinPend()}
async function coinHist(){let rows=[];try{rows=await q(sb.from('coin_log').select('amount,label,created_at,cash,n').eq('user_id',ME.id).order('created_at',{ascending:false}).limit(40))}catch(e){}
 const el=$('#chist');if(!el)return;
 el.innerHTML=rows.map(r=>`<div><span>${esc(r.label)}${r.n>1?` <small class="cn">×${r.n}</small>`:''} <small class="muted">${ago(r.created_at)}</small>${r.cash?` <small class="ccash">${r.cash>0?'+':''}${nf(r.cash)} გასატანი</small>`:''}</span><span class="${r.amount>0?'plus':'minus'}">${r.amount>0?'+':''}${nf(r.amount)}</span></div>`).join('')||'<p class="muted">ჯერ ცარიელია.</p>'}
A.bonus=async t=>{t.disabled=true;try{const r=await rpc('daily_bonus'),b=r&&typeof r==='object'?r:{coins:r,got:5};ME.last_bonus=today();setCoins(b.coins);$('.coinchip')?.classList.remove('bonus');
 toast(`+${b.got||0} მონეტა${b.streak===7?' · 7 დღე ზედიზედ!':''}`);burst(t);if(b.streak===7)confetti();coinsLoad(true).then(drawCoins).catch(()=>{})}catch(e){t.disabled=false;toast(errMsg(e))}};
A.cretry=()=>PG.coins.r();
A.cngo=t=>{const k=(CPAGE[t.dataset.k]||[])[2];if(!k)return;if(k==='chat')return A.chats();if(['home','clips','games','me'].includes(k))return go(k);openPage(k)};

/* ---------- gifts on photos: the photo shows what it got, the dearest gift picks its frame ---------- */
const GCOST=e=>(GIFTS.find(g=>g[0]===e)||[0,0,0])[2];
/* 1 bouquet and up: a warm glow · 2 cup: gold · 3 diamond: a moving shine · 4 crown: gold that moves, and the crown on the photo */
const GTIERS=[[25000,4,'გვირგვინის ჩარჩო'],[10000,3,'ბრილიანტის ჩარჩო'],[5000,2,'ოქროს ჩარჩო'],[500,1,'თბილი ნათება']];
const giftTier=v=>(GTIERS.find(t=>(v||0)>=t[0])||[0,0])[1];
const giftTierCls=p=>{const t=giftTier(p.gift_top);return t?` gt gt${t}`:''};
function giftChip(p){const g=p.gifts||{},ks=Object.keys(g).filter(k=>g[k]>0).sort((a,b)=>GCOST(b)-GCOST(a));if(!ks.length)return '';
 const n=ks.reduce((a,k)=>a+g[k],0);
 return `${giftTier(p.gift_top)===4?'<span class="pgcrown" aria-hidden="true">👑</span>':''}<button class="pgchip" data-a="pgifts" data-pid="${p.id}" aria-label="საჩუქრები: ${n}">${ks.slice(0,3).map(k=>`<span>${k}${g[k]>1?`<i>${g[k]}</i>`:''}</span>`).join('')}${ks.length>3?`<em>+${ks.slice(3).reduce((a,k)=>a+g[k],0)}</em>`:''}</button>`}
/* after a gift: every copy of the post on screen (feed, profile, viewer) gets the new frame and gifts */
function giftPaint(id){const p=POSTS.get(id);if(!p)return;
 const paint=(box,media)=>{if(!box||!media)return;box.className=box.className.replace(/\s?gt\d?\b/g,'')+giftTierCls(p);$$('.pgchip,.pgcrown',media).forEach(x=>x.remove());media.insertAdjacentHTML('beforeend',giftChip(p))};
 $$(`.post[data-id="${id}"]`).forEach(a=>paint($('.pmw',a),$('.pmmedia',a)));
 const pv=$(`#pv [data-pv="${id}"] .pvframe`);if(pv)paint(pv,pv)}
A.pgift=t=>{const id=pidOf(t),p=POSTS.get(id);if(!p)return;const who=esc(String(pname(p.author)).split(' ')[0]);let pick=null;
 sheet(head('საჩუქარი ფოტოს')+`<div class="pgs"><p class="hint">${who} საჩუქრის ნახევარს მიიღებს მონეტებად. ძვირფასი საჩუქარი ფოტოს ჩარჩოს უცვლის.</p>
  <div class="gifts pggrid" role="radiogroup" aria-label="საჩუქარი">${GIFTS.map(g=>`<button type="button" class="gift${g[2]>(ME.coins||0)?' poor':''}" role="radio" aria-checked="false" data-g="${g[0]}" aria-label="${g[1]}, ${g[2]} მონეტა">${g[0]}<small>${g[1]}</small><b>${nf(g[2])}</b></button>`).join('')}</div>
  <p class="pgtier" id="pg_tier"></p>
  <div class="pgfoot"><span>ბალანსი<b>${nf(ME.coins)}</b></span><button class="btn" id="pg_go" disabled>აირჩიე საჩუქარი</button></div></div>`,'short');
 const go=$('#pg_go'),tier=$('#pg_tier');
 $$('.pggrid .gift').forEach(b=>b.onclick=()=>{pick=b.dataset.g;$$('.pggrid .gift').forEach(x=>x.setAttribute('aria-checked',String(x===b)));const c=GCOST(pick),short=c-(ME.coins||0),tr=GTIERS.find(x=>c>=x[0]);
  go.disabled=short>0;go.textContent=short>0?`აკლია ${nf(short)} მონეტა`:`გაგზავნა: ${pick} · ${nf(c)}`;
  tier.textContent=tr&&giftTier(p.gift_top)<tr[1]?`ფოტოს ექნება ${tr[2]}.`:''});
 go.onclick=async()=>{if(!pick)return;go.disabled=true;const c=GCOST(pick);
  try{const r=await rpc('post_gift',{p_post:id,p_emoji:pick});if(r){setCoins(r.coins);p.gifts=r.gifts||p.gifts;p.gift_top=r.gift_top||p.gift_top}closeSheet();giftPaint(id);toast(`${pick} გაიგზავნა`);if(c>=1000)confetti()}
  catch(e){go.disabled=false;toast(errMsg(e));if(/not_enough/.test(e.message||''))go.textContent='მონეტები არ გყოფნის'}}};
A.pgifts=async t=>{const id=pidOf(t),p=POSTS.get(id);const mine=p&&p.author===ME.id;
 sheet(head(mine?'შენი ფოტოს საჩუქრები':'ფოტოს საჩუქრები')+`<div id="pgl">${skel(2)}</div>`,'short');
 try{const rows=await rpc('post_gifts',{p_post:id})||[];await loadProfiles(rows.map(r=>r.u));const el=$('#pgl');if(!el)return;
  const sum=rows.reduce((a,r)=>a+(r.c||0),0);
  el.innerHTML=rows.length?`<p class="hint" style="padding:12px 16px 0">${rows.length} საჩუქარი · ${nf(sum)} მონეტის${mine?` · შენ მიიღე ${nf(Math.floor(sum/2))}`:''}</p><div class="list">${rows.map(r=>`<button class="row" data-a="user" data-u="${r.u}">${av(r.u,36)}<span class="grow"><b>${esc(pname(r.u))}</b><span class="sub">${ago(r.at)}</span></span><span class="pgem">${r.e}</span></button>`).join('')}</div>`
   :empty('საჩუქრები ჯერ არ არის','')}
 catch(e){const el=$('#pgl');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',esc(errMsg(e)))}};

/* ---------- admin: the promotion, what is owed in lari, the daily maximum, every rule ---------- */
async function admCoins(el){const[s,rules]=await Promise.all([rpc('admin_coin_stats'),q(sb.from('coin_rules').select('*').order('pos'))]);
 await loadProfiles((s.top||[]).map(x=>x.u));if(!el.isConnected)return;
 const c=s.cfg||{},rate=c.rate||10000,until=c.until?new Date(c.until):null,left=until?Math.max(0,Math.ceil((until-Date.now())/864e5)):0;
 const T=(v,l)=>`<div class="adtile"><b>${v}</b><span>${l}</span></div>`;
 el.innerHTML=`<section class="tourcard adsite adcp${s.promo?' on':''}"><h3>${s.promo?'🎉 აქცია მიმდინარეობს':'აქცია გამორთულია'}</h3>
  <p class="note">${s.promo?`ბოლო დღე: ${cDate(until)} ${until.getFullYear()} · დარჩა ${left} დღე. ამ დროს აქტივობით მიღებული მონეტები ლარად გასატანი ხდება (${nf(rate)} = 1 ₾).`:'ჩართვის შემდეგ აქტივობით მიღებული მონეტები ლარად გასატანი ხდება. აქციის გარეშე მონეტები მხოლოდ სახარჯად გროვდება.'}</p>
  <div class="frow"><label class="fld">ხანგრძლივობა<select id="acp_m">${[1,2,3,6,12].map(n=>`<option value="${n}">${n} თვე</option>`).join('')}</select></label></div>
  <div class="adquick">${s.promo?`<button class="btn" data-a="adcpromo" data-k="extend">${ic('plus')}თვეების დამატება</button><button class="btn ghost" data-a="adcpromo" data-k="stop">${ic('pause')}გაჩერება</button>`:`<button class="btn" data-a="adcpromo" data-k="start">${ic('play')}აქციის ჩართვა</button>`}</div></section>
 <h3 class="sec2">რამდენს გადაიხდი</h3><div class="adstats">${T(nf(s.cash),'გასატანი მონეტა ჯამში')}${T(cgel(s.cash,rate)+' ₾','ლარად')}${T(nf(s.today_cash),'გასატანი დღეს')}${T(nf(s.week_cash),'გასატანი 7 დღეში')}</div>
 <div class="adstats">${T(nf(s.today),'ყველა მონეტა დღეს')}${T(nf(s.earners),'გამომმუშავებელი დღეს')}${T(nf(s.coins),'მონეტა ყველასთან')}${T(nf(c.daily_max||150),'დღის მაქსიმუმი')}</div>
 ${(s.top||[]).length?`<h3 class="sec2">დღეს ყველაზე მეტი</h3><div class="list">${s.top.map(x=>`<button class="row" data-a="user" data-u="${x.u}">${av(x.u,32)}<span class="grow"><b>${esc(pname(x.u))}</b><span class="sub">${nf(x.c)} გასატანი</span></span><b>+${nf(x.n)}</b></button>`).join('')}</div>`:''}
 <section class="tourcard adsite"><h3>დღის მაქსიმუმი</h3><p class="note">ყველა აქტივობით ერთ ადამიანს დღეში მეტს ვერ გამოიმუშავებს. დღიური ბონუსი და ვერიფიკაცია ამაში არ ითვლება.</p>
  <div class="frow"><label class="fld">მონეტა დღეში<input id="acp_max" type="number" inputmode="numeric" min="10" max="5000" value="${c.daily_max||150}"></label><button class="btn" data-a="adcmax" style="align-self:flex-end">${ic('check')}შენახვა</button></div></section>
 <h3 class="sec2">წესები</h3><p class="note" style="padding:0 16px 8px">„დღეში“: ამ აქტივობით დღეში მაქსიმუმ რამდენი მონეტა (0 = შეზღუდვის გარეშე, მხოლოდ დღის მაქსიმუმი).</p>
 <div class="adrules">${(rules||[]).map(r=>`<div class="adrule" data-k="${esc(r.action)}"><span class="grow"><b>${esc(r.label)}</b><small>${esc((CPAGE[r.page]||['ბონუსი'])[0])}${r.hint?' · '+esc(r.hint):''}${r.every_n>1?` · ყოველ ${r.every_n}-ზე`:''}${r.once?' · ერთხელ':''}</small></span>
  <label>მონეტა<input class="field sq" type="number" inputmode="numeric" min="0" max="1000" data-f="amount" value="${r.amount}"></label><label>დღეში<input class="field sq" type="number" inputmode="numeric" min="0" max="5000" data-f="cap" value="${r.day_cap}"></label>
  <button type="button" class="switch" role="switch" data-a="adcsw" aria-checked="${!!r.active}" aria-label="${esc(r.label)}: ჩართულია"></button><button class="btn sm" data-a="adcrule">შენახვა</button></div>`).join('')}</div>`}
A.adcpromo=t=>{const k=t.dataset.k,mo=+($('#acp_m')?.value||1);
 const run=async()=>{const v=await rpc('admin_coin_promo',{p_do:k,p_months:mo});toast(k==='stop'?'აქცია გაჩერდა':k==='start'?'აქცია ჩაირთო':'თვეები დაემატა');if(v&&CN.my){CN.my.promo=!!v.promo;CN.my.until=v.until}adminTab()};
 if(k==='extend')return run().catch(e=>toast(errMsg(e)));
 confirmSheet(k==='start'?'აქციის ჩართვა':'აქციის გაჩერება',k==='start'?`${mo} თვის განმავლობაში აქტივობით მიღებული მონეტები ლარად გასატანი იქნება (${nf(10000)} მონეტა = 1 ₾). ამ თანხის გადახდა შენ მოგიწევს.`:'ამიერიდან მიღებული მონეტები ლარად გასატანი აღარ იქნება. უკვე დაგროვილი გასატანი მონეტები რჩება.',k==='start'?'ჩართვა':'გაჩერება',run,k==='stop')};
A.adcsw=t=>t.setAttribute('aria-checked',String(t.getAttribute('aria-checked')!=='true'));
A.adcrule=async t=>{const r=t.closest('.adrule'),v=f=>Math.floor(+r.querySelector(`[data-f="${f}"]`).value);
 try{await rpc('admin_coin_rule',{p_action:r.dataset.k,p_amount:v('amount'),p_day_cap:v('cap'),p_active:r.querySelector('.switch').getAttribute('aria-checked')==='true'});CN.rules=null;toast('შენახულია')}catch(e){toast(errMsg(e))}};
A.adcmax=async()=>{const n=Math.floor(+$('#acp_max').value);try{await rpc('admin_coin_max',{p_max:n});toast('შენახულია');adminTab()}catch(e){toast(errMsg(e))}};

/* ---------- paying out in lari: by hand, after the admin checks the request ---------- */
const POST_L={pending:['მოლოდინში','clock'],paid:['გადახდილია','check'],rejected:['უარყოფილია','x'],cancelled:['გაუქმებულია','x']};
/* a Georgian IBAN: GE, 2 check digits, 2 letters of the bank, 16 digits; the check digits must add up (mod 97), as on the server */
const ibanClean=s=>String(s||'').replace(/\s+/g,'').toUpperCase();
function ibanOk(s){s=ibanClean(s);if(!/^GE\d{2}[A-Z]{2}\d{16}$/.test(s))return false;const r=s.slice(4)+s.slice(0,4);let m=0;
 for(const ch of r){m=/[A-Z]/.test(ch)?(m*100+ch.charCodeAt(0)-55)%97:(m*10+ +ch)%97}return m===1}
const ibanFmt=s=>ibanClean(s).replace(/(.{4})/g,'$1 ').trim();
const ibanMask=s=>{const c=ibanClean(s);return c.slice(0,4)+' •••• '+c.slice(-4)};
const gelF=n=>Number(n||0).toFixed(2);
PG.payout={r(){view.innerHTML=pgHead('ლარად გატანა')+`<div id="pob">${skel(3)}</div>`;loadPayout()}};
async function loadPayout(){let d;try{d=await rpc('my_payouts')}catch(e){const el=$('#pob');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',esc(errMsg(e)),'<button class="btn" data-a="poretry">თავიდან</button>');return}
 const el=$('#pob');if(!el||!d)return;const rate=d.rate||10000,min=d.min_out||10000,cash=d.cash||0,list=d.list||[],open=list.find(x=>x.status==='pending'),last=list[0];
 const max=Math.floor(cash/100)*100,left=Math.max(0,30-(d.age_days||0));
 const reqs=[[d.adult,'18 წელი ან მეტი','დაბადების თარიღით პროფილში.',''],
  [d.verified,'ვერიფიცირებული პროფილი','ლურჯი ნიშანი: სელფი მოდერატორთან.',`<button class="btn sm" data-a="page" data-p="verify">ვერიფიკაცია</button>`],
  [d.old_enough,'Peera-ზე 30 დღე მაინც',d.old_enough?'':`დარჩა ${left} დღე.`,''],
  [cash>=min,`მინიმუმ ${nf(min)} გასატანი მონეტა`,cash>=min?'':`დაგრჩა ${nf(min-cash)}.`,'']];
 const ready=reqs.every(r=>r[0])&&!open&&d.not_banned!==false;
 el.innerHTML=`<section class="balance pobal"><span>ლარად გასატანი</span><b>${nf(cash)}</b><span>≈ ${gelF(cash/rate)} ₾ · ${nf(rate)} მონეტა = 1 ₾</span></section>
 ${open?`<section class="pocard open"><div class="pohead"><span class="postat s-pending">${ic('clock')}მოლოდინში</span><small>${ago(open.created_at)}</small></div>
  <b class="pogel">${gelF(open.gel)} ₾</b><span class="sub">${nf(open.coins)} მონეტა · ${esc(open.holder)} · ${ibanMask(open.iban)}</span>
  <p class="note">განაცხადს ადმინისტრატორი ამოწმებს და თანხას ხელით გადმორიცხავს. სანამ ელოდება, შეგიძლია გააუქმო და მონეტები დაგიბრუნდება.</p>
  <button class="btn ghost sm" data-a="pocancel" data-id="${open.id}">${ic('x')}განაცხადის გაუქმება</button></section>`:''}
 ${open&&reqs.every(r=>r[0])?'':`<section class="poreq"><h3>პირობები</h3>${reqs.map(([ok,t,h,b])=>`<div class="poreqr${ok?' ok':''}"><span class="pochk">${ic(ok?'check':'x')}</span><span class="grow"><b>${t}</b>${h&&!ok?`<small>${h}</small>`:''}</span>${!ok&&b?b:''}</div>`).join('')}</section>`}
 ${ready?`<form class="form pof" id="pof" novalidate><h3 class="sec2" style="padding:0">განაცხადი</h3>
  <label class="fld">რამდენი მონეტა<div class="poamt"><input class="field" id="po_n" type="number" inputmode="numeric" min="${min}" max="${max}" step="100" value="${max}"><button type="button" class="btn sm ghost" id="po_all">ყველა</button></div><small id="po_g" class="pohint"></small></label>
  <label class="fld">IBAN<input class="field" id="po_i" autocomplete="off" autocapitalize="characters" spellcheck="false" maxlength="34" placeholder="GE00 XX00 0000 0000 0000 00" value="${esc(last?ibanFmt(last.iban):'')}"><small id="po_ih" class="pohint">ქართული ბანკის ანგარიში, 22 სიმბოლო.</small></label>
  <label class="fld">მფლობელის სახელი და გვარი<input class="field" id="po_h" maxlength="80" autocomplete="name" placeholder="ისე, როგორც ბანკშია" value="${esc(last?last.holder:'')}"></label>
  <p class="note">მონეტები განაცხადისთანავე ჩამოგეჭრება და განაცხადს დაელოდება. თანხას ადმინისტრატორი ხელით გადმორიცხავს. თუ უარი ითქვა, მიზეზს შეტყობინებაში მიიღებ და მონეტები დაგიბრუნდება.</p>
  <button class="btn" id="po_go">${ic('send')}გატანის მოთხოვნა</button></form>`:''}
 ${list.length?`<h3 class="sec2">ჩემი განაცხადები</h3><div class="list polist">${list.map(x=>`<div class="row"><span class="postat s-${x.status}">${ic(POST_L[x.status][1])}</span><span class="grow"><b>${gelF(x.gel)} ₾ · ${nf(x.coins)}</b><span class="sub">${POST_L[x.status][0]} · ${ago(x.decided_at||x.created_at)}${x.note&&x.status==='rejected'?' · '+esc(x.note):''}</span></span></div>`).join('')}</div>`:''}`;
 const f=$('#pof');if(!f)return;const n=$('#po_n'),g=$('#po_g'),ib=$('#po_i'),ih=$('#po_ih');
 const upd=()=>{const v=Math.floor(+n.value||0);g.textContent=v>=min&&v<=max&&v%100===0?`= ${gelF(v/rate)} ₾`:v%100?'მრგვალი რიცხვი, 100-ის ჯერადი':`${nf(min)}-დან ${nf(max)}-მდე`;g.classList.toggle('bad',!(v>=min&&v<=max&&v%100===0))};
 const iupd=()=>{const c=ibanClean(ib.value);ih.classList.toggle('bad',c.length>=22&&!ibanOk(c));ih.textContent=!c?'ქართული ბანკის ანგარიში, 22 სიმბოლო.':ibanOk(c)?'IBAN სწორია':c.length<22?`${c.length}/22`:'IBAN არასწორია: შეამოწმე ციფრები'};
 n.oninput=upd;ib.oninput=iupd;ib.onblur=()=>{if(ibanOk(ib.value))ib.value=ibanFmt(ib.value)};$('#po_all').onclick=()=>{n.value=max;upd()};upd();iupd();
 f.onsubmit=e=>{e.preventDefault();const v=Math.floor(+n.value||0),iban=ibanClean(ib.value),h=$('#po_h').value.trim().replace(/\s+/g,' ');
  if(!(v>=min&&v<=max&&v%100===0)){toast(`ჩაწერე ${nf(min)}-დან ${nf(max)}-მდე, 100-ის ჯერადი`);n.focus();return}
  if(!ibanOk(iban)){toast('IBAN არასწორია');ib.focus();return}if(h.length<3){toast('ჩაწერე სახელი და გვარი');$('#po_h').focus();return}
  confirmSheet('გატანის დადასტურება',`${gelF(v/rate)} ₾ (${nf(v)} მონეტა) ჩაირიცხება ანგარიშზე ${esc(ibanFmt(iban))}, ${esc(h)}-ის სახელზე. მონეტები ახლავე ჩამოგეჭრება.`,'მოთხოვნა',async()=>{
   const r=await rpc('request_payout',{p_coins:v,p_iban:iban,p_holder:h});if(r&&r.coins!=null)setCoins(r.coins);toast('განაცხადი გაიგზავნა');loadPayout()})}}
A.poretry=()=>loadPayout();
A.pocancel=t=>confirmSheet('განაცხადის გაუქმება','მონეტები ბალანსზე დაგიბრუნდება.','გაუქმება',async()=>{const c=await rpc('cancel_payout',{p_id:+t.dataset.id});if(c!=null)setCoins(c);toast('განაცხადი გაუქმდა');loadPayout()},true);
/* the coin page shows a request that waits */
async function coinPend(){const el=$('#cpend');if(!el)return;let r=null;try{r=await q(sb.from('payouts').select('coins,gel,created_at').eq('status','pending').limit(1).maybeSingle())}catch(e){}
 if(!r||!$('#cpend'))return;el.innerHTML=`<button class="cpend" data-a="page" data-p="payout">${ic('clock')}<span class="grow"><b>გატანა მოლოდინში: ${gelF(r.gel)} ₾</b><small>${nf(r.coins)} მონეტა · ${ago(r.created_at)}</small></span>${ic('back')}</button>`}

/* ---------- admin: the requests, what helps decide, paid or rejected ---------- */
async function admPayouts(el){ADM.pst=ADM.pst||'pending';const d=await rpc('admin_payouts',{p_status:ADM.pst});await loadProfiles((d.list||[]).map(x=>x.u));if(!el.isConnected)return;
 const T=(v,l)=>`<div class="adtile"><b>${v}</b><span>${l}</span></div>`,days=t=>Math.floor((Date.now()-new Date(t))/864e5);
 el.innerHTML=`<div class="adstats">${T(nf(d.pending_n),'მოლოდინში')}${T(gelF(d.pending_gel)+' ₾','მოლოდინში, ლარი')}${T(gelF(d.month_paid)+' ₾','გადახდილი ამ თვეში')}${T(+d.budget?gelF(d.budget)+' ₾':'—','თვის ბიუჯეტი')}</div>
 <div class="chipsbar adtabs" role="group" aria-label="სტატუსი">${['pending','paid','rejected','cancelled'].map(k=>`<button data-a="adpost" data-k="${k}" aria-pressed="${ADM.pst===k}">${POST_L[k][0]}${k==='pending'&&d.pending_n?` <span class="badge">${d.pending_n}</span>`:''}</button>`).join('')}</div>
 ${(d.list||[]).length?`<div class="polist2">${d.list.map(x=>`<article class="pocard adpo" data-id="${x.id}"><div class="pohead"><button class="pouser" data-a="user" data-u="${x.u}">${av(x.u,36)}<span class="grow"><b>${esc(x.name||pname(x.u))}${x.verified?` <i class="vbs">${ic('check')}</i>`:''}</b><small>@${esc(x.username||'')} · Peera-ზე ${days(x.joined)} დღე</small></span></button><small>${ago(x.created_at)}</small></div>
  <b class="pogel">${gelF(x.gel)} ₾</b><span class="sub">${nf(x.coins)} მონეტა</span>
  <div class="pocopy"><span class="grow"><small>IBAN</small><code>${esc(ibanFmt(x.iban))}</code></span><button class="ibtn sm" data-a="adpocopy" data-v="${esc(x.iban)}" aria-label="IBAN-ის კოპირება">${ic('copy')}</button></div>
  <div class="pocopy"><span class="grow"><small>მფლობელი</small><b>${esc(x.holder)}</b></span><button class="ibtn sm" data-a="adpocopy" data-v="${esc(x.holder)}" aria-label="სახელის კოპირება">${ic('copy')}</button></div>
  <p class="pofacts">30 დღეში გასატანი: აქტივობით ${nf(x.act30)}, საჩუქრებით ${nf(x.gift30)} · ადრე გატანილი ${gelF(x.paid_before)} ₾ · ახლა ბალანსზე ${nf(x.cash_now)}</p>
  ${x.status==='pending'?`<div class="adquick"><button class="btn" data-a="adpopaid" data-id="${x.id}" data-g="${gelF(x.gel)}">${ic('check')}გადახდილია</button><button class="btn ghost" data-a="adporej" data-id="${x.id}">${ic('x')}უარყოფა</button></div>`
   :`<p class="pofacts"><span class="postat s-${x.status}">${ic(POST_L[x.status][1])}${POST_L[x.status][0]}</span> ${x.decided_at?ago(x.decided_at):''}${x.note?' · '+esc(x.note):''}</p>`}</article>`).join('')}</div>`
  :empty(ADM.pst==='pending'?'მოლოდინში არაფერია':'აქ ჯერ არაფერია','')}
 <section class="tourcard adsite"><h3>თვის ბიუჯეტი</h3><p class="note">რამდენ ლარს გადაიხდი თვეში მაქსიმუმ. როცა თვის განაცხადები ამას მიაღწევს, ახალი განაცხადი თვის ბოლომდე ვეღარ გაიგზავნება. 0 ნიშნავს, რომ ლიმიტი არ არის.</p>
  <div class="frow"><label class="fld">ლარი თვეში<input id="apo_b" type="number" inputmode="decimal" min="0" step="1" value="${+d.budget||0}"></label><button class="btn" data-a="adpobud" style="align-self:flex-end">${ic('check')}შენახვა</button></div></section>`}
A.adpost=t=>{ADM.pst=t.dataset.k;adminTab()};
A.adpocopy=async t=>{try{await navigator.clipboard.writeText(t.dataset.v);toast('დაკოპირდა')}catch(e){toast(t.dataset.v)}};
A.adpopaid=t=>{const id=+t.dataset.id;sheet(head(`გადახდილია: ${t.dataset.g} ₾`)+`<form class="ph-body form" id="apof"><label class="fld">გადარიცხვის ნომერი ან შენიშვნა (არასავალდებულო)<input id="apo_n" maxlength="200" placeholder="მაგ. TBC 123456"></label><p class="note">მომხმარებელი მიიღებს შეტყობინებას, რომ თანხა გადაირიცხა.</p><button class="btn">${ic('check')}დადასტურება</button></form>`,'short');
 $('#apof').onsubmit=async e=>{e.preventDefault();try{await rpc('admin_payout_decide',{p_id:id,p_status:'paid',p_note:$('#apo_n').value.trim()||null});closeSheet();toast('მონიშნულია გადახდილად');refreshStats();adminTab()}catch(err){toast(errMsg(err))}}};
A.adporej=t=>{const id=+t.dataset.id;sheet(head('გატანის უარყოფა')+`<form class="ph-body form" id="apor"><label class="fld">მიზეზი (მომხმარებელი ნახავს)<textarea id="apo_r" maxlength="200" rows="3" placeholder="მაგ. IBAN სხვის სახელზეა"></textarea></label><p class="note">მონეტები მომხმარებელს გასატან ბალანსზე დაუბრუნდება.</p><button class="btn danger">${ic('x')}უარყოფა</button></form>`,'short');
 $('#apor').onsubmit=async e=>{e.preventDefault();const r=$('#apo_r').value.trim();if(r.length<3){toast('დაწერე მიზეზი');return}try{await rpc('admin_payout_decide',{p_id:id,p_status:'rejected',p_note:r});closeSheet();toast('უარყოფილია, მონეტები დაბრუნდა');refreshStats();adminTab()}catch(err){toast(errMsg(err))}}};
A.adpobud=async()=>{const v=Math.max(0,+$('#apo_b').value||0);try{await rpc('admin_coin_budget',{p_gel:v});toast('შენახულია');adminTab()}catch(e){toast(errMsg(e))}};
