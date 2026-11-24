/* games, casino and the admin panel come only when first needed (they are about 40% of all the code): the games tab, a game page,
   a game started from a chat, a challenge or a notification, the admin panel, or an action of theirs touched before they came.
   What everyone needs stays in the first load: the game list and lobby presence (online friends, challenges), game messages
   in chats, cups. The files come in their old order, one after another, from the same version as the page */
const GLZ={files:['games-engines','domino','cards2','games-modes','loto','egg','joker-online','joker-more','domino-online','gvoice','games-side','corr','gstudy','glive','gquest','ghub','casino','cs-slot','cs-table','cs-fast','gaccess','glock'],p:null,ready:false,adm:null};
const GLZ_PG=['admin','aviator','bj','career','corrs','dmtable','gkind','jktable','jklobby','jktop','lotable','mines','plinko','replay','roulette','slot','fleece','batumi'];
function glScripts(files){const v=(($('script[src*="/js/core.js"]')||{}).src||'').split('v=')[1]||'';
 return new Promise((res,rej)=>{let left=files.length,bad=false;
  for(const f of files){const s=document.createElement('script');s.src=`/js/${f}.js${v?'?v='+v:''}`;s.async=false;
   s.onload=()=>{if(!bad&&!--left)res()};s.onerror=()=>{if(bad)return;bad=true;rej(new Error('load '+f))};document.head.appendChild(s)}})}
function glLoad(){if(GLZ.ready)return Promise.resolve();if(GLZ.p)return GLZ.p;
 GLZ.p=glScripts(GLZ.files).then(()=>{GLZ.ready=true;try{if(typeof gCtlApply==='function')gCtlApply()}catch(e){}},e=>{GLZ.p=null;throw e});return GLZ.p}
/* the admin panel: for the admin only, after the games (its games tab uses them) */
function glAdmin(){if(PG.admin)return Promise.resolve();if(GLZ.adm)return GLZ.adm;GLZ.adm=glLoad().then(()=>glScripts(['admin'])).catch(e=>{GLZ.adm=null;throw e});return GLZ.adm}
/* on a good connection the games come a few seconds after the start anyway, in the background, so the tab opens at once */
function glPrefetch(){try{const c=navigator.connection;if(c&&(c.saveData||/(^|-)2g$/.test(c.effectiveType||'')))return}catch(e){}
 const go2=()=>{if(!GLZ.ready&&!GLZ.p)glLoad().catch(()=>{})};if(window.requestIdleCallback)window.requestIdleCallback(go2,{timeout:8000});else setTimeout(go2,2500)}
/* while they come: a spinner where the screen will be; if they cannot come, a way to try again */
function glWait(then,where){const el=where||view;GLZ.retry=()=>glWait(then,where);if(el&&!GLZ.ready)el.innerHTML='<div class="view-pad glz" aria-busy="true"><span class="spin" aria-label="იტვირთება"></span></div>';
 return glLoad().then(then).catch(()=>{if(el)el.innerHTML=`<div class="view-pad">${empty('ვერ ჩაიტვირთა','შეამოწმე ინტერნეტი და სცადე ისევ.','<button class="btn" data-a="glzretry">თავიდან ცდა</button>')}</div>`})}
A.glzretry=()=>{const f=GLZ.retry;GLZ.retry=null;if(f)f();else go(S.tab||'home')};
/* the games tab, as the app's (games_tab.dart): one big card for backgammon and Joker, a card for each, a table with
   friends. Only these two, as in the app; a game being played still shows itself here */
function ghBoard(){const W=210,H=96,m=H*.08,bar=W*.06,fw=(W-2*m-bar)/2,fh=H-2*m,tw=fw/6,th=fh*.42,r=tw*.42;let p='';
 for(let sd=0;sd<2;sd++){const L=m+sd*(fw+bar);p+=`<rect x="${L}" y="${m}" width="${fw}" height="${fh}" rx="${H*.03}" fill="#F2E3C2"/>`;
  for(let i=0;i<6;i++){const x=L+i*tw;p+=`<path d="M${x} ${m}h${tw}l${-tw/2} ${th}z" fill="${i%2?'#203A2C':'#B3261E'}"/><path d="M${x} ${m+fh}h${tw}l${-tw/2} ${-th}z" fill="${i%2?'#B3261E':'#203A2C'}"/>`}}
 const st=(sd,pt,top,n,wh)=>{const cx=m+sd*(fw+bar)+pt*tw+tw/2;for(let k=0;k<n;k++){const cy=top?m+r+k*r*1.9:m+fh-r-k*r*1.9;p+=`<circle cx="${cx}" cy="${cy+r*.18}" r="${r}" fill="#0004"/><circle cx="${cx}" cy="${cy}" r="${r}" fill="${wh?'#FDFBF6':'#2A2A2E'}"/><circle cx="${cx}" cy="${cy}" r="${r*.62}" fill="none" stroke="${wh?'#D9CFBF':'#55555C'}" stroke-width="${r*.14}"/>`}};
 st(0,0,1,3,1);st(0,4,0,2,0);st(1,1,1,2,0);st(1,5,0,3,1);st(1,3,0,1,0);
 return `<svg class="gh-board" viewBox="0 0 ${W} ${H}" aria-hidden="true"><defs><linearGradient id="ghw"><stop offset="0" stop-color="#A0582A"/><stop offset=".5" stop-color="#6B3413"/><stop offset="1" stop-color="#8C4A20"/></linearGradient></defs><rect y="${H*.05}" width="${W}" height="${H}" rx="${H*.08}" fill="#0005"/><rect width="${W}" height="${H}" rx="${H*.08}" fill="url(#ghw)"/>${p}</svg>`}
const GH_PIP={1:[[.5,.5]],2:[[.27,.27],[.73,.73]],3:[[.27,.27],[.5,.5],[.73,.73]],5:[[.27,.27],[.73,.27],[.5,.5],[.27,.73],[.73,.73]],6:[[.27,.25],[.73,.25],[.27,.5],[.73,.5],[.27,.75],[.73,.75]]};
const ghDie=(n,rot)=>`<svg class="gh-die" style="transform:rotate(${rot}rad)" viewBox="0 0 1 1" aria-hidden="true"><rect width="1" height="1" rx=".22" fill="#FFFDF8"/>${(GH_PIP[n]||[]).map(([x,y])=>`<circle cx="${x}" cy="${y}" r=".09" fill="${n===1?'#B3261E':'#1F1612'}"/>`).join('')}</svg>`;
const ghDice=(a,b)=>`<span class="gh-dice">${ghDie(a,-.25)}${ghDie(b,.2)}</span>`;
const ghCard=(t,c,i)=>`<span class="gh-pc" style="--r:${(i-1.5)*17}deg"><b style="color:${c}">${t}</b></span>`;
function gamesHome(){view.innerHTML=`<div class="view-pad gh">
 <h2 class="gh-t">${barIc('games',true)}თამაშები</h2>
 <div class="gh-hero"><div class="gh-art"><img src="/icons/g/table.webp" alt="" decoding="async"><span class="gh-tilt">${ghBoard()}</span>${ghDice(6,3)}</div>
  <div class="gh-tx"><b>ონლაინ ნარდი და ჯოკერი</b><small>ითამაშე&nbsp; • &nbsp;გაერთე&nbsp; • &nbsp;დაუკავშირდი</small><button class="gh-pill big" data-a="page" data-p="gnardi">თამაშის დაწყება${ic('arrow')}</button></div></div>
 <div class="gh-two"><button class="gh-card" data-a="page" data-p="gnardi"><span class="gh-cart"><span class="gh-tilt sm">${ghBoard()}</span>${ghDice(5,2)}</span><b>ითამაშე<br>ნარდი</b><span class="gh-pill">დაწყება</span></button>
  <button class="gh-card" data-a="ghjoker"><span class="gh-cart cards">${[['A♠','#1F1612'],['K♥','#C0262D'],['Q♦','#C0262D'],['★','#6D4AE8']].map((x,i)=>ghCard(x[0],x[1],i)).join('')}</span><b>გამოსცადე<br>ჯოკერი</b><span class="gh-pill">დაწყება</span></button></div>
 <button class="gh-friends" data-a="page" data-p="jklobby"><span class="gh-fi">${barIc('friends',true)}</span><span class="grow"><b>დაუკავშირდი მეგობრებს</b><small>ერთად უფრო სახალისოა!</small></span>${ic('chev')}</button></div>`}
A.ghjoker=()=>startGame('joker');
{const r0=R.games;R.games=function(...a){if(!S.game){gamesHome();return}if(!GLZ.ready){glWait(()=>{if(S.tab==='games'&&!S.page)R.games(...a)});return}return r0.apply(this,a)}}
/* backgammon's own page, as the app's: who is here to play now, or one of four people at the computer */
PG.gnardi={r(){view.innerHTML=pgHead('ნარდი')+`<div class="view-pad gnp" id="gnp">${skel(3)}</div>`;glWait(gnDraw,$('#gnp'))}};
function gnDraw(){const el=$('#gnp');if(!el)return;const lv=bLvl('nardi'),peers=(NET.peers||[]).filter(p=>!BLOCKED.has(p.id));
 el.innerHTML=`<section><h3 class="gnh">ონლაინ</h3><p class="hint">ითამაშე მათთან, ვინც ახლა აქაა (საიტზეც და აპშიც).</p>
  ${peers.length?`<div class="gnon">${peers.map(p=>`<button class="gnper" data-a="netsend" data-u="${p.id}" data-g="nardi">${av(p.id,44)}<b>${esc(pname(p.id))}</b><span class="btn sm">გამოწვევა</span></button>`).join('')}</div>`:`<div class="gnempty">ახლა სხვა ონლაინ არავინაა. როცა მეგობარი შემოვა, აქ გამოჩნდება.</div>`}</section>
 <section><h3 class="gnh">კომპიუტერთან</h3><p class="hint">ოთხი მოთამაშე, სუსტიდან ძლიერამდე. აირჩიე და დაიწყე.</p>
  <div class="gnbots">${BOTC.slice(1).map((c,i)=>`<button class="gnbot${lv===i+1?' on':''}" data-a="gnbot" data-v="${i+1}" aria-pressed="${lv===i+1}">${avAny(botAv(c),56)}<span class="grow"><b>${esc(c.n)} <i class="gnst">${'★'.repeat(i+1)}<s>${'★'.repeat(3-i)}</s></i></b><small>${esc(c.d)}</small></span>${lv===i+1?ic('check'):''}</button>`).join('')}</div>
  <button class="btn wide gnplay" data-a="gnplay">${ic('play')}თამაშის დაწყება</button></section>`}
A.gnbot=t=>{const m=Object.assign({},store.get('blv',{})||{});m.nardi=+t.dataset.v;store.set('blv',m);gnDraw()};
A.gnplay=()=>{const sv=typeof gSaved==='function'&&gSaved('nardi');startGame('nardi',null,sv)};
/* the games button in the tab bar and the side menu (the hub of game kinds) */
function gOpenHub(){if(GLZ.ready&&typeof gHub==='function'){gHub();return}glLoad().then(()=>{if(typeof gHub==='function')gHub()}).catch(()=>toast('თამაშები ვერ ჩაიტვირთა. შეამოწმე ინტერნეტი'))}
/* a game started from anywhere: a chat card, a challenge, a notification */
{const sg=startGame;startGame=function(...a){if(typeof GAMES_ON!=='undefined'&&!GAMES_ON.has(a[0])){toast('ეს თამაში აღარ არის. ითამაშე ნარდი ან ჯოკერი');go('games');return}if(!GLZ.ready){glWait(()=>startGame(...a));return}return sg.apply(this,a)}}
/* a page of theirs: a game table, the casino, the admin panel */
{const op=openPage;openPage=function(id,...a){if(typeof SITE_OFF!=='undefined'&&SITE_OFF.has(id)){go(/^(shop|cups?)/.test(id)?'home':'games');return}if(!PG[id]&&GLZ_PG.includes(id)){if(id==='admin'){glAdmin().then(()=>openPage(id,...a)).catch(()=>toast('ვერ ჩაიტვირთა. შეამოწმე ინტერნეტი'));return}if(!GLZ.ready){glWait(()=>openPage(id,...a));return}}return op.call(this,id,...a)}}
