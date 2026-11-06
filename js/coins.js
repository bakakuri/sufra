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
  <div class="cparts"><div><small>ლარად გასატანი</small><b>${nf(cash)}</b><small>≈ ${cgel(cash,rate)} ₾</small></div><div><small>სახარჯი</small><b>${nf(bon)}</b><small>საჩუქრები, სტილები</small></div></div>
  <div class="cout"><div class="cbar" role="progressbar" aria-label="გატანამდე" aria-valuemin="0" aria-valuemax="${min}" aria-valuenow="${Math.min(cash,min)}"><i style="width:${Math.min(100,cash/min*100)}%"></i></div>
  <small>${cash>=min?`გასატანად მზადაა ${nf(cash)} მონეტა. გატანის ფორმა მალე დაემატება.`:`ლარად გასატანად საჭიროა ${nf(min)} მონეტა (${cgel(min,rate)} ₾). დაგრჩა ${nf(min-cash)}.`}</small></div></section>
 <section class="cpromo${m.promo?' on':''}"><span class="cpico">${m.promo?'🎉':ic('clock')}</span><div><b>${m.promo?'აქცია მიმდინარეობს':'აქცია ახლა არ მიდის'}</b>
  <span>${m.promo?`აქტივობით მიღებული მონეტები ლარად გასატანი ხდება: ${nf(rate)} მონეტა = 1 ₾.${until?` ბოლო დღე: ${cDate(until)} (დარჩა ${left} დღე).`:''}`:'მონეტები მაინც გროვდება და იხარჯება საჩუქრებზე და სტილებზე. ლარად გასატანი ხდება მხოლოდ აქციის დროს მიღებული მონეტები.'}</span></div></section>
 <section class="cday"><div class="cdays" aria-label="7 დღე ზედიზედ: ${filled} დღე">${[1,2,3,4,5,6,7].map(i=>`<span class="${i<=filled?'on':''}${i===next?' next':''}${i===7?' big':''}">${i===7?'+15':'+5'}</span>`).join('')}</div>
  <button class="btn${got?' ghost':''}" data-a="bonus"${got?' disabled':''}>${got?'დღევანდელი ბონუსი აღებულია':`აიღე დღიური ბონუსი: +${next===7?15:5}`}</button>
  <p class="note">ყოველდღე +5. მე-7 დღეს ზედიზედ დამატებით +10.</p></section>
 <section class="ctoday"><div><b>დღეს გამოიმუშავე ${nf(today_)} / ${nf(max)}</b><span>${today_>=max?'დღის ლიმიტი შევსებულია. ხვალ ისევ.':'ყველა აქტივობა ერთად, ბონუსის გარდა'}</span></div><div class="cbar"><i style="width:${Math.min(100,today_/max*100)}%"></i></div></section>
 <h3 class="sec2">როგორ გამოიმუშავო</h3><p class="note" style="padding:0 16px 8px">თითქმის ყველა გვერდზე. წაშლილი ან დამალული პოსტის, კომენტარის და სხვა მონეტები 24 საათში უკან ბრუნდება.</p>
 <div class="crules">${groups.map(grp).join('')}</div>
 <h3 class="sec2">ისტორია</h3><div class="hist" id="chist">${skel(1)}</div>`;
 coinHist()}
async function coinHist(){let rows=[];try{rows=await q(sb.from('coin_log').select('amount,label,created_at,cash,n').eq('user_id',ME.id).order('created_at',{ascending:false}).limit(40))}catch(e){}
 const el=$('#chist');if(!el)return;
 el.innerHTML=rows.map(r=>`<div><span>${esc(r.label)}${r.n>1?` <small class="cn">×${r.n}</small>`:''} <small class="muted">${ago(r.created_at)}</small>${r.cash?` <small class="ccash">${r.cash>0?'+':''}${nf(r.cash)} გასატანი</small>`:''}</span><span class="${r.amount>0?'plus':'minus'}">${r.amount>0?'+':''}${nf(r.amount)}</span></div>`).join('')||'<p class="muted">ჯერ ცარიელია.</p>'}
A.bonus=async t=>{t.disabled=true;try{const r=await rpc('daily_bonus'),b=r&&typeof r==='object'?r:{coins:r,got:5};ME.last_bonus=today();setCoins(b.coins);$('.coinchip')?.classList.remove('bonus');
 toast(`+${b.got||0} მონეტა${b.streak===7?' · 7 დღე ზედიზედ!':''}`);burst(t);if(b.streak===7)confetti();coinsLoad(true).then(drawCoins).catch(()=>{})}catch(e){t.disabled=false;toast(errMsg(e))}};
A.cretry=()=>PG.coins.r();
A.cngo=t=>{const k=(CPAGE[t.dataset.k]||[])[2];if(!k)return;if(k==='chat')return A.chats();if(['home','clips','games','me'].includes(k))return go(k);openPage(k)};

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
