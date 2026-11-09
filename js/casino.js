/* casino on coins: the shell every casino game shares. Each game is a full-screen page like the board games: its own top bar
   (back, name, balance, sound, rules) and the game below it. Only adults play. The server decides every result and keeps the
   limits (casino_info); the pages show them, play the sounds and the wins, and remind of the time after half an hour.
   The games are in js/cs-slot.js (slots), js/cs-table.js (roulette, blackjack) and js/cs-fast.js (aviator, mines, plinko);
   the 3D tables are in js/g3d-casino.js, which comes with the 3D engine */
const CSN={info:null,t:0,fs:0,bal:0};
async function csInfo(force){if(!force&&CSN.info&&Date.now()-CSN.t<2e4)return CSN.info;CSN.info=await rpc('casino_info');CSN.t=Date.now();return CSN.info}
/* a game the server knows (its migration is in): new games stay hidden until then */
/* small canvas helpers (the 3D engine has its own, but it is not always here) */
const csCv=(w,h)=>{const c=document.createElement('canvas');c.width=w;c.height=h;return c};
const csRR=(x,X,Y,w,h,r)=>{x.beginPath();if(x.roundRect)x.roundRect(X,Y,w,h,r);else x.rect(X,Y,w,h)};
const csHas=g=>!!(CSN.info&&CSN.info.games&&Object.prototype.hasOwnProperty.call(CSN.info.games,g));

/* ---------- sounds of the casino, made like the rest (js/gsound.js) ---------- */
Object.assign(GSND,{
 chip:(x,t,v)=>{gsTone(x,t,{f:1900,f2:1300,type:'triangle',peak:.1*v,dec:.04});gsNoise(x,t,{f:5200,q:3,peak:.24*v,dec:.03});gsTone(x,t+.034,{f:2500,f2:1800,type:'triangle',peak:.05*v,dec:.03})},
 coin:(x,t,v)=>{const f=2500+Math.random()*900;gsTone(x,t,{f,peak:.07*v,dec:.24});gsTone(x,t,{f:f*1.51,peak:.035*v,dec:.16})},
 reel:(x,t,v)=>{for(let k=0;k<7;k++)gsNoise(x,t+k*.05,{f:1300+k*70,q:5,peak:.06*v,dec:.025})},
 stop:(x,t,v)=>{gsTone(x,t,{f:160,f2:70,peak:.32*v,dec:.12});gsNoise(x,t,{f:900,q:1.2,peak:.2*v,dec:.06})},
 tick:(x,t,v)=>gsNoise(x,t,{f:4300,q:6,peak:.13*v,dec:.018}),
 tease:(x,t,v)=>{gsTone(x,t,{f:330,f2:990,type:'triangle',a:.06,peak:.05*v,dec:1.3});gsTone(x,t,{f:495,f2:1485,a:.06,peak:.025*v,dec:1.3})},
 big:(x,t,v)=>{[523,659,784,1047,784,1047,1319,1568].forEach((f,k)=>{gsTone(x,t+k*.09,{f,type:'triangle',peak:.13*v,dec:.3});gsTone(x,t+k*.09,{f:f/2,peak:.05*v,dec:.25})});
  [1047,1319,1568].forEach(f=>gsTone(x,t+.8,{f,type:'triangle',peak:.08*v,dec:1.4}));gsNoise(x,t+.8,{f:7000,q:.5,type:'highpass',a:.05,peak:.06*v,dec:1.2})},
 cash:(x,t,v)=>{gsNoise(x,t,{f:3000,q:.8,peak:.2*v,dec:.06});[1760,2637].forEach((f,k)=>gsTone(x,t+.05+k*.08,{f,peak:.09*v,dec:.4}))},
 fly:(x,t,v)=>{gsTone(x,t,{f:150,f2:420,type:'triangle',a:.1,peak:.05*v,dec:1.3});gsNoise(x,t,{f:600,q:.7,type:'lowpass',a:.2,peak:.08*v,dec:1.1})},
 crash:(x,t,v)=>{gsTone(x,t,{f:700,f2:110,type:'triangle',peak:.09*v,dec:.6});gsNoise(x,t,{f:500,q:.5,type:'lowpass',a:.01,peak:.3*v,dec:.5})},
 flip:(x,t,v)=>gsNoise(x,t,{f:2600,q:.9,type:'highpass',a:.01,peak:.17*v,dec:.09,rate:1.1}),
 gem:(x,t,v)=>[1568,2093,2637].forEach((f,k)=>gsTone(x,t+k*.05,{f,peak:.07*v,dec:.3})),
 boom:(x,t,v)=>{gsNoise(x,t,{f:280,q:.6,type:'lowpass',a:.005,peak:.6*v,dec:.7});gsTone(x,t,{f:95,f2:38,peak:.4*v,dec:.55})},
 peg:(x,t,v)=>gsTone(x,t,{f:1300+Math.random()*600,peak:.045*v,dec:.06}),
 ball:(x,t,v)=>{gsTone(x,t,{f:2100,f2:1500,type:'triangle',peak:.05*v,dec:.05});gsNoise(x,t,{f:3600,q:4,peak:.12*v,dec:.025})}});
const csSnd=(k,v)=>{if(typeof gSnd==='function')gSnd(k,v)};
A.cssnd=()=>{A.gsnd();$$('[data-a="cssnd"]').forEach(b=>{b.setAttribute('aria-pressed',String(GS.on));b.innerHTML=ic(GS.on?'vol':'mute')})};

/* ---------- the bet: steps between the admin's limits, remembered per game ---------- */
const CS_STEPS=[10,20,25,50,100,150,200,250,300,400,500,750,1000,1500,2000,2500,5000,10000];
function csSteps(){const i=CSN.info||{},lo=i.min_bet||10,hi=i.max_bet||500,s=CS_STEPS.filter(v=>v>lo&&v<hi);return [lo,...s,hi]}
function csBet(g){const s=csSteps(),v=+store.get('csbet_'+g,0)||s[Math.min(3,s.length-1)];return s.reduce((a,b)=>Math.abs(b-v)<Math.abs(a-v)?b:a,s[0])}
function csBetHTML(g){return `<div class="cs-bet" data-g="${g}"><button type="button" class="cs-step" data-a="csstep" data-d="-1" aria-label="ფსონის შემცირება">−</button><span class="cs-bv"><small>ფსონი</small><b id="csb_${g}">${nf(csBet(g))}</b></span><button type="button" class="cs-step" data-a="csstep" data-d="1" aria-label="ფსონის გაზრდა">+</button></div>`}
A.csstep=t=>{const w=t.closest('.cs-bet'),g=w.dataset.g;if(w.closest('.busy')||w.classList.contains('off'))return;const s=csSteps(),i=s.indexOf(csBet(g)),n=s[Math.max(0,Math.min(s.length-1,i+(+t.dataset.d)))];
 store.set('csbet_'+g,n);const el=$('#csb_'+g);if(el)el.textContent=nf(n);csSnd('chip',.6);const f=CS_ONBET[g];if(f)f(n)};
const CS_ONBET={};
const csDayHTML=i=>`<small class="cs-day" id="cs_day">დღეს დადებული ${nf(i.today)} / ${nf(i.day_bets)}</small>`;

/* ---------- the balance in the top bar: it counts to its new value; coins fly into it ---------- */
function csBalShow(v){CSN.bal=v;const b=$('#cs_bal');if(b)b.textContent=nf(v)}
function csBalTo(v,ms=600){const b=$('#cs_bal'),from=CSN.bal;CSN.bal=v;if(!b)return;if(RM()||from===v||!ms){b.textContent=nf(v);return}const t0=performance.now();
 const step=now=>{const k=Math.min(1,(now-t0)/ms),e=1-Math.pow(1-k,3);b.textContent=nf(Math.round(from+(v-from)*e));if(k<1&&b.isConnected)requestAnimationFrame(step)};requestAnimationFrame(step)}
/* after a round: the balance and how much was bet today */
function csAfter(coins,bet){setCoins(coins);if(CSN.info)CSN.info.today=(CSN.info.today||0)+(bet||0);const d=$('#cs_day');if(d&&CSN.info)d.textContent=`დღეს დადებული ${nf(CSN.info.today)} / ${nf(CSN.info.day_bets)}`}
function csBump(){const w=$('#cs_balw');if(!w)return;w.classList.remove('bump');void w.offsetWidth;w.classList.add('bump')}
const csPt=f=>{if(!f)return null;if(f.getBoundingClientRect){const r=f.getBoundingClientRect();return{x:r.left+r.width/2,y:r.top+r.height/2}}return f};
/* coins fly from where the win happened to the balance; each one that lands rings and bumps it */
function csFly(n,from){const to=$('#cs_balw'),lay=$('.csx'),a=csPt(from);if(!to||!lay||!a||RM())return;const b=csPt(to),k=Math.max(5,Math.min(18,n));
 for(let i=0;i<k;i++){const c=document.createElement('i');c.className='csx-fc';lay.appendChild(c);const jx=(Math.random()-.5)*90,jy=(Math.random()-.5)*50,mx=(a.x+b.x)/2+(Math.random()-.5)*160,my=Math.min(a.y,b.y)-40-Math.random()*90;
  const an=c.animate([{transform:`translate(${a.x+jx-11}px,${a.y+jy-11}px) scale(.4)`,opacity:0},{transform:`translate(${a.x+jx-11}px,${a.y+jy-11}px) scale(1)`,opacity:1,offset:.12},{transform:`translate(${mx-11}px,${my-11}px) scale(1.15)`,offset:.55},{transform:`translate(${b.x-11}px,${b.y-11}px) scale(.55)`,opacity:.9}],
   {duration:820+Math.random()*260,delay:i*55,easing:'cubic-bezier(.45,0,.3,1)',fill:'backwards'});
  an.onfinish=()=>{c.remove();csBump();csSnd('coin',.45)};an.oncancel=()=>c.remove()}}

/* the coin, drawn once for the fountains */
let CS_COIN=null;
function csCoin(){if(CS_COIN)return CS_COIN;const c=document.createElement('canvas');c.width=c.height=64;const x=c.getContext('2d'),g=x.createRadialGradient(24,20,4,32,32,32);
 g.addColorStop(0,'#FFF7D1');g.addColorStop(.35,'#FFD35C');g.addColorStop(.8,'#E39312');g.addColorStop(1,'#9C5A08');x.fillStyle=g;x.beginPath();x.arc(32,32,30,0,Math.PI*2);x.fill();
 x.lineWidth=3;x.strokeStyle='rgba(255,243,200,.7)';x.beginPath();x.arc(32,32,23,0,Math.PI*2);x.stroke();x.fillStyle='rgba(150,84,6,.75)';x.font='900 30px system-ui,sans-serif';x.textAlign='center';x.textBaseline='middle';x.fillText('P',32,34);
 return CS_COIN=c}
/* a fountain of coins on a canvas laid over the page: they rise, spin and fall */
function csFountain(cv,ms,rate){const x=cv.getContext('2d'),dpr=Math.min(2,window.devicePixelRatio||1),P=[],img=csCoin(),t0=performance.now();let last=t0,raf=0,spawn=0;
 const fit=()=>{cv.width=cv.clientWidth*dpr;cv.height=cv.clientHeight*dpr};fit();
 const step=now=>{const W=cv.clientWidth,H=cv.clientHeight,dt=Math.min(.05,(now-last)/1000);last=now;if(!cv.isConnected)return;
  if(now-t0<ms){spawn+=dt*rate;while(spawn>=1){spawn--;P.push({x:W/2+(Math.random()-.5)*W*.3,y:H+20,vx:(Math.random()-.5)*W*.9,vy:-(H*.9+Math.random()*H*.7),r:Math.random()*6,w:6+Math.random()*10,s:14+Math.random()*14})}}
  x.setTransform(dpr,0,0,dpr,0,0);x.clearRect(0,0,W,H);
  for(let i=P.length-1;i>=0;i--){const p=P[i];p.vy+=H*1.25*dt;p.x+=p.vx*dt;p.y+=p.vy*dt;p.r+=p.w*dt;if(p.y>H+40&&p.vy>0){P.splice(i,1);continue}
   const sx=Math.cos(p.r);x.save();x.translate(p.x,p.y);x.scale(Math.abs(sx)<.08?.08:sx,1);x.drawImage(img,-p.s,-p.s,p.s*2,p.s*2);x.restore()}
  if(P.length||now-t0<ms)raf=requestAnimationFrame(step)};raf=requestAnimationFrame(step);return()=>cancelAnimationFrame(raf)}

/* a big win: rays, the tier's name, the sum counting up, a fountain of coins. A tap skips the count, a second one closes */
function csBig(win,bet){return new Promise(ok=>{const lay=$('.csx');if(!lay||RM()){ok();return}const m=win/bet,T=m>=100?['ეპიკური მოგება!','epic']:m>=50?['მეგა მოგება!','mega']:['დიდი მოგება!','big'];
 const d=document.createElement('div');d.className='csx-big '+T[1];d.setAttribute('role','status');
 d.innerHTML=`<i class="csx-rays" aria-hidden="true"></i><canvas aria-hidden="true"></canvas><div class="csx-bt"><b>${T[0]}</b><strong>0</strong><small>${(Math.round(m*100)/100)}× ფსონი</small><em>შეეხე გასაგრძელებლად</em></div>`;
 lay.appendChild(d);const num=$('strong',d),dur=Math.min(5200,1800+Math.log10(m)*1400),stop=csFountain($('canvas',d),dur+600,m>=50?42:28);csSnd('big');gBuzz([40,60,40,60,120]);
 let done=false,closed=false,t0=performance.now(),tk=0;const fin=()=>{if(done)return;done=true;num.textContent=nf(win);d.classList.add('done');setTimeout(close,2200)};
 const close=()=>{if(closed)return;closed=true;stop();d.classList.add('out');setTimeout(()=>{d.remove();ok()},320)};
 const step=now=>{if(done||!d.isConnected)return;const k=Math.min(1,(now-t0)/dur),e=1-Math.pow(1-k,2.2);num.textContent=nf(Math.round(win*e));if(now-tk>90){tk=now;csSnd('coin',.35)}if(k>=1)fin();else requestAnimationFrame(step)};
 requestAnimationFrame(step);d.addEventListener('click',()=>{if(!done)fin();else close()})})}

/* ---------- time: after every half hour of play, a word about how long it has been and how it went ---------- */
function csTrack(bet,win){const now=Date.now();let s=store.get('cssess',null);if(!s||now-s.last>15*60e3)s={t0:now,last:now,bet:0,win:0,n:0,w:0};
 s.last=now;s.bet+=bet||0;s.win+=win||0;s.n++;const mins=Math.floor((now-s.t0)/60e3);let say=false;if(mins>=30*(s.w+1)){s.w=Math.floor(mins/30);say=true}store.set('cssess',s);if(say)setTimeout(()=>csTime(s,mins),1600)}
function csTime(s,mins){if(!$('.csx'))return;const net=s.win-s.bet;
 sheet(head('ცოტა შესვენება?')+`<div class="ph-body cs-time"><p>უკვე <b>${mins} წუთია</b> თამაშობ, ${nf(s.n)} რაუნდი.</p><div class="cs-tn"><span><small>დადე</small><b>${nf(s.bet)}</b></span><span><small>მოიგე</small><b>${nf(s.win)}</b></span><span class="${net>=0?'plus':'minus'}"><small>შედეგი</small><b>${net>=0?'+':''}${nf(net)}</b></span></div>
  <p class="hint">ითამაშე იმდენით, რისი დაკარგვაც არ გეწყინება.</p><div class="frow"><button class="btn ghost grow" data-a="csrest">შესვენება</button><button class="btn gold grow" data-a="csgoon">გაგრძელება</button></div></div>`,'short')}
A.csgoon=()=>closeSheet();
A.csrest=()=>{closeSheet();setTimeout(()=>A.back(),60)};

/* ---------- a result: the session count, the sound, the coins and, for a big one, the big win ---------- */
async function csWin(coins,bet,win,from){csTrack(bet,win);if(win>0){if(win>=bet*15)await csBig(win,bet);else{gBuzz(win>bet?[20,40,30]:15);csSnd(win>bet?'win':'cash',win>bet?.8:.7)}
  csFly(Math.round(4+Math.log2(1+win/bet)*3),from);setTimeout(()=>csBalTo(coins,700),RM()?0:650)}else csBalTo(coins,300);setCoins(coins)}

/* ---------- a page: full screen, the bar on top, the game below. 18+, open, then the game draws itself ---------- */
function csTop(g,title){return `<div class="csx-top"><button class="csx-ib" data-a="back" aria-label="უკან">${ic('back')}</button><b class="csx-t">${title}</b>
 <span class="csx-bal" id="cs_balw" aria-label="ბალანსი"><i class="csx-c" aria-hidden="true"></i><b id="cs_bal">${nf(ME.coins||0)}</b></span>
 <button class="csx-ib" data-a="cssnd" aria-pressed="${GS.on}" aria-label="ხმა">${ic(GS.on?'vol':'mute')}</button><button class="csx-ib" data-a="csrules" data-g="${g}" aria-label="წესები">${ic('help')}</button></div>`}
function csPage(g,title,draw,o={}){CSN.bal=ME.coins||0;
 view.innerHTML=`<div class="view-pad game gx csx cs-${g}${o.cls?' '+o.cls:''}" data-g="cs-${g}"><div class="csx-bg" aria-hidden="true">${o.bg||''}</div>${o.stage||''}<div class="ghud top csx-head">${csTop(g,title)}</div><div class="csx-main" id="csp"><div class="csx-load"><span class="spin"></span></div></div><div class="ghud bot csx-hb" aria-hidden="true"></div></div>`;
 if(!CSN.fs&&store.get('gfs',true)&&typeof fsEnter==='function'){CSN.fs=1;fsEnter()}
 csInfo(true).then(i=>{const el=$('#csp');if(!el||S.page?.id!==g)return;
  if(!i.adult){el.innerHTML=csMsg('ეს თამაში 18 წლიდანაა','');return}
  if(!i.on||(i.games||{})[g]===false||o.need&&!csHas(o.need)){el.innerHTML=csMsg('ეს თამაში ახლა დახურულია','ადმინისტრატორმა დროებით გამორთო.');return}
  if(i.coins!=null){setCoins(i.coins);csBalShow(i.coins)}draw(el,i)}).catch(e=>{const el=$('#csp');if(el)el.innerHTML=csMsg('ვერ ჩაიტვირთა',esc(errMsg(e)),`<button class="btn gold" data-a="csretry" data-g="${g}">თავიდან</button>`)})}
const csMsg=(t,s,btn='')=>`<div class="csx-msg"><h3>${t}</h3>${s?`<p>${s}</p>`:''}${btn}</div>`;
A.csretry=t=>PG[t.dataset.g].r();
/* leaving a casino page leaves the browser's fullscreen too (unless a board game holds it) */
{const sm=stopMedia;stopMedia=function(){sm();if(CSN.fs){CSN.fs=0;if(typeof GFS!=='undefined'&&GFS.native&&!S.game)fsExit()}}}

/* ---------- rules ---------- */
const CS_RULES={slot:['ქართული სლოტი','სამი ბარაბანი, ერთი ხაზი შუაში. სამი ერთნაირი სიმბოლო იხდის ცხრილის მიხედვით (9×-დან 250×-მდე), პირველი ორი ერთნაირი ფსონს გიბრუნებს.'],
 fleece:['ოქროს საწმისი','ხუთი ბარაბანი, სამი რიგი, 10 ხაზი. ხაზი მარცხნიდან ითვლება, მინიმუმ სამი ერთნაირით. საწმისი (Wild) ნებისმიერ სიმბოლოს ცვლის. სამი ან მეტი არგო სადმე ეკრანზე: 8 უფასო ტრიალი, მოგებები ორმაგდება.'],
 batumi:['ბათუმის ღამე','ხუთი ბარაბანი, სამი რიგი, 10 ხაზი. ხაზი მარცხნიდან ითვლება, მინიმუმ სამი ერთნაირით. შუქურა (Wild) ნებისმიერ სიმბოლოს ცვლის. სამი ან მეტი ალი და ნინო: 10 უფასო ტრიალი, მოგებები ორმაგდება.'],
 roulette:['რულეტკა','ევროპული ბორბალი, ერთი ნულით. რიცხვზე ფსონი იხდის 35:1-ს, ათეულები და სვეტები 2:1-ს, წითელი/შავი, ლუწი/კენტი, 1–18/19–36 1:1-ს. ნულზე მხოლოდ ნულზე დადებული იგებს.'],
 bj:['ბლექჯეკი','შეაგროვე 21-თან ახლოს. ბლექჯეკი 3:2, მოგება 1:1, ფრეზე ფსონი ბრუნდება. დილერი 17-მდე იღებს. გაორმაგება პირველ ორ კარტზეა. ხელის გაყოფა არ არის.'],
 avl:['ავიატორი','ყველა ერთ თვითმფრინავზე ფრენს: ფსონი აფრენამდე იდება, „აიღე“ ფრენისას. კოეფიციენტი იზრდება, სანამ თვითმფრინავი გაფრინდება. რამდენზე გაფრინდება, სერვერი წინასწარ წყვეტს და არავინ იცის.'],
 aviator:['ავიატორი','კოეფიციენტი იზრდება, სანამ თვითმფრინავი გაფრინდება. აიღე დროზე და ფსონი გამრავლდება. რამდენზე გაფრინდება, სერვერი წინასწარ წყვეტს და არავინ იცის.'],
 mines:['ნაღმები','ველზე 25 უჯრაა, მათ შორის ნაღმები. ყოველი გახსნილი ბრილიანტი კოეფიციენტს ზრდის. აიღე ნებისმიერ დროს. ნაღმი თუ გახსენი, ფსონი იკარგება. რაც მეტი ნაღმია, მით მაღალია კოეფიციენტი.'],
 plinko:['პლინკო','ბურთი ლურსმნებს შორის ეცემა და ქვემოთ ერთ-ერთ უჯრაში ვარდება. უჯრის კოეფიციენტზე მრავლდება ფსონი. რისკი ცვლის კოეფიციენტებს: დაბალზე ხშირად, მაგრამ ცოტას იგებ, მაღალზე იშვიათად, მაგრამ ბევრს.']};
A.csrules=t=>{const g=t.dataset.g,[n,d]=CS_RULES[g]||['',''],i=CSN.info||{};
 sheet(head(n)+`<div class="ph-body cs-rules"><p>${d}</p><p class="hint">ფსონი: ${nf(i.min_bet||10)}–${nf(i.max_bet||500)} მონეტა · ერთი მოგება მაქსიმუმ ${nf(i.max_win||100000)} · დღეში ჯამში ${nf(i.day_bets||20000)} მონეტის ფსონი.</p><p class="hint">შედეგს სერვერი წყვეტს შემთხვევითი რიცხვით. თამაში მხოლოდ 18 წლიდანაა. ითამაშე იმდენით, რისი დაკარგვაც არ გეწყინება.</p></div>`,'short')};

/* ---------- admin: the casino tab ---------- */
const CS_GN={slot:'ქართული სლოტი',fleece:'ოქროს საწმისი',batumi:'ბათუმის ღამე',roulette:'რულეტკა',bj:'ბლექჯეკი',aviator:'ავიატორი',avl:'ავიატორი ერთად',mines:'ნაღმები',plinko:'პლინკო'};
async function admCasino(el){const s=await rpc('admin_casino_stats');const top=s.top||[];await loadProfiles(top.map(x=>x.u));if(!el.isConnected)return;
 const c=s.cfg||{},gs=c.games||{},G=s.games||{},pct=(w,b)=>b?Math.round(w/b*1000)/10+'%':'—',ks=Object.keys(CS_GN).filter(k=>k in gs||k in G);
 const sum=k=>Object.values(G).reduce((a,g)=>a+(+g[k]||0),0);
 el.innerHTML=`<section class="tourcard adsite"><div class="frow" style="align-items:center"><span class="grow"><h3 style="margin:0">კაზინო</h3><small class="muted">${c.on?'ჩართულია: 18+ მომხმარებლები თამაშობენ':'გამორთულია: თამაშის გვერდებზე „დახურულია“ წერია'}</small></span>
  <button type="button" class="switch" role="switch" data-a="adcsnsw" data-k="on" aria-checked="${!!c.on}" aria-label="კაზინო ჩართულია"></button></div>
  <div class="cs-adg">${ks.map(k=>`<label class="cs-adt"><span>${CS_GN[k]}</span><button type="button" class="switch" role="switch" data-a="adcsnsw" data-k="${k}" aria-checked="${gs[k]!==false}" aria-label="${CS_GN[k]} ჩართულია"></button></label>`).join('')}</div></section>
 <h3 class="sec2">დღეს</h3><div class="adstats"><div class="adtile"><b>${nf(sum('d_bet'))}</b><span>დაიდო</span></div><div class="adtile"><b>${nf(sum('d_win'))}</b><span>მოიგეს</span></div><div class="adtile"><b>${nf(sum('d_bet')-sum('d_win'))}</b><span>კაზინოს დარჩა</span></div><div class="adtile"><b>${nf(sum('d_n'))}</b><span>რაუნდი</span></div></div>
 <div class="list cs-adl">${ks.map(k=>{const g=G[k]||{};return `<div class="row"><span class="grow"><b>${CS_GN[k]}</b><span class="sub">დღეს: ${nf(g.d_n||0)} რაუნდი, ${nf(g.d_ppl||0)} მოთამაშე, დაიდო ${nf(g.d_bet||0)}, მოიგეს ${nf(g.d_win||0)}</span><span class="sub">7 დღე: დაიდო ${nf(g.w_bet||0)}, მოიგეს ${nf(g.w_win||0)} · დაბრუნდა ${pct(g.w_win||0,g.w_bet||0)}</span></span></div>`}).join('')}</div>
 ${top.length?`<h3 class="sec2">დღეს ყველაზე მეტი მოიგეს</h3><div class="list">${top.map(x=>`<button class="row" data-a="user" data-u="${x.u}">${av(x.u,32)}<span class="grow"><b>${esc(pname(x.u))}</b><span class="sub">${nf(x.n)} რაუნდი</span></span><b class="${x.net>=0?'plus':'minus'}">${x.net>=0?'+':''}${nf(x.net)}</b></button>`).join('')}</div>`:''}
 <section class="tourcard adsite"><h3>ლიმიტები</h3><p class="note">მონეტებში. 10,000 მონეტა = 1 ₾.</p>
  <div class="cs-adf">${[['min_bet','მინიმალური ფსონი',10],['max_bet','მაქსიმალური ფსონი',500],['max_win','ერთი მოგება მაქსიმუმ',100000],['day_bets','დღეში ფსონები ერთ ადამიანზე',20000]].map(([k,l,d])=>`<label class="fld">${l}<input id="acs_${k}" type="number" inputmode="numeric" min="1" value="${c[k]??d}"></label>`).join('')}</div>
  <button class="btn" data-a="adcsnsave">${ic('check')}შენახვა</button></section>`}
/* a single game here is the same switch as in the games tab (js/admin.js admGameSet), so the two never disagree */
A.adcsnsw=async t=>{const k=t.dataset.k,on=t.getAttribute('aria-checked')!=='true';t.setAttribute('aria-checked',String(on));
 try{if(k==='on')await rpc('admin_casino_set',{p_cfg:{on}});else await admGameSet(k==='avl'?'aviator':k,on);CSN.info=null;toast(on?'ჩაირთო':'გამოირთო');adminTab()}catch(e){t.setAttribute('aria-checked',String(!on));toast(errMsg(e))}};
A.adcsnsave=async()=>{const v={};for(const k of ['min_bet','max_bet','max_win','day_bets']){const n=Math.floor(+$('#acs_'+k).value);if(!(n>=1)){toast('ჩაწერე დადებითი რიცხვი');return}v[k]=n}
 if(v.min_bet>v.max_bet){toast('მინიმალური ფსონი მაქსიმალურზე მეტია');return}
 try{await rpc('admin_casino_set',{p_cfg:v});CSN.info=null;toast('შენახულია');adminTab()}catch(e){toast(errMsg(e))}};
