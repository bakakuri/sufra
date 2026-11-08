/* casino on coins: the Georgian slot, roulette, blackjack and the aviator. Only adults play. The server decides every
   result and keeps the limits (casino_info); this file only shows them. Each game is a page, so "back" leaves it;
   an unfinished blackjack hand or a plane still in the air comes back when the page opens again */
const CSN={info:null,t:0};
async function csInfo(force){if(!force&&CSN.info&&Date.now()-CSN.t<2e4)return CSN.info;CSN.info=await rpc('casino_info');CSN.t=Date.now();return CSN.info}
/* the bet: steps between the admin's limits, remembered per game */
const CS_STEPS=[10,20,25,50,100,150,200,250,300,400,500,750,1000,1500,2000,2500,5000,10000];
function csSteps(){const i=CSN.info||{},lo=i.min_bet||10,hi=i.max_bet||500,s=CS_STEPS.filter(v=>v>lo&&v<hi);return [lo,...s,hi]}
function csBet(g){const s=csSteps(),v=+store.get('csbet_'+g,0)||s[Math.min(3,s.length-1)];return s.reduce((a,b)=>Math.abs(b-v)<Math.abs(a-v)?b:a,s[0])}
function csBetHTML(g){return `<div class="cs-bet" data-g="${g}"><button type="button" class="cs-step" data-a="csstep" data-d="-1" aria-label="ფსონის შემცირება">−</button><span class="cs-bv"><small>ფსონი</small><b id="csb_${g}">${nf(csBet(g))}</b></span><button type="button" class="cs-step" data-a="csstep" data-d="1" aria-label="ფსონის გაზრდა">+</button></div>`}
A.csstep=t=>{const w=t.closest('.cs-bet'),g=w.dataset.g;if(w.closest('.busy'))return;const s=csSteps(),i=s.indexOf(csBet(g)),n=s[Math.max(0,Math.min(s.length-1,i+(+t.dataset.d)))];
 store.set('csbet_'+g,n);const el=$('#csb_'+g);if(el)el.textContent=nf(n);if(g==='aviator')avIdle()};
function csBalHTML(i){return `<div class="cs-bal"><span>${ic('coin')}<b id="cs_bal">${nf(ME.coins)}</b></span><small id="cs_day">დღეს დადებული ${nf(i.today)} / ${nf(i.day_bets)}</small></div>`}
function csAfter(coins,bet){setCoins(coins);if(CSN.info)CSN.info.today=(CSN.info.today||0)+(bet||0);const b=$('#cs_bal');if(b)b.textContent=nf(coins);const d=$('#cs_day');if(d&&CSN.info)d.textContent=`დღეს დადებული ${nf(CSN.info.today)} / ${nf(CSN.info.day_bets)}`}
/* a game page: 18+, open, then the game draws itself */
function csPage(g,title,draw){view.innerHTML=pgHead(title,`<button class="ibtn" data-a="csrules" data-g="${g}" aria-label="წესები">${ic('help')}</button>`)+`<div class="cs-pg cs-${g}" id="csp">${skel(2)}</div>`;
 csInfo(true).then(i=>{const el=$('#csp');if(!el||S.page?.id!==g)return;
  if(!i.adult){el.innerHTML=empty('ეს თამაში 18 წლიდანაა','');return}
  if(!i.on||(i.games||{})[g]===false){el.innerHTML=empty('ეს თამაში ახლა დახურულია','ადმინისტრატორმა დროებით გამორთო.');return}
  draw(el,i)}).catch(e=>{const el=$('#csp');if(el)el.innerHTML=empty('ვერ ჩაიტვირთა',esc(errMsg(e)),`<button class="btn" data-a="csretry" data-g="${g}">თავიდან</button>`)})}
A.csretry=t=>PG[t.dataset.g].r();

/* ---------- the Georgian slot: three reels, one line ---------- */
const SLOTSYM={grape:'ყურძენი',church:'ჩურჩხელა',khach:'ხაჭაპური',wine:'ღვინო',kantsi:'ყანწი',seven:'შვიდიანი'};
const SLOTPAY=[['seven',250],['kantsi',90],['wine',45],['khach',22],['church',14],['grape',9]];
const SLOTK=Object.keys(SLOTSYM);
function slotSym(k){const S='<svg viewBox="0 0 64 64" aria-hidden="true">';switch(k){
 case 'grape':return S+`<path d="M32 8v9" stroke="#7A5230" stroke-width="3" stroke-linecap="round"/><path d="M33 12c3-6 10-8 16-6-2 6-8 9-15 8z" fill="#5DBB46"/>${[[15,22],[26,22],[37,22],[48,22],[20.5,32],[31.5,32],[42.5,32],[26,42],[37,42],[31.5,52]].map(([x,y])=>`<circle cx="${x}" cy="${y}" r="6.2" fill="#7B2FA8"/><circle cx="${x-2}" cy="${y-2}" r="1.8" fill="#fff" opacity=".55"/>`).join('')}</svg>`;
 case 'church':return S+`<path d="M32 4v8" stroke="#C9A36A" stroke-width="2"/><circle cx="32" cy="5" r="3" fill="none" stroke="#C9A36A" stroke-width="2"/>${[14,21,28,35,42,49,56].map((y,i)=>`<ellipse cx="${32+(i%2?1:-1)}" cy="${y}" rx="9" ry="5" fill="${i%2?'#9A2E2E':'#A8393A'}"/>`).join('')}<path d="M25 14v40" stroke="#fff" stroke-opacity=".25" stroke-width="2.5" stroke-linecap="round"/></svg>`;
 case 'khach':return S+`<path d="M3 34Q14 14 32 13Q50 14 61 34Q50 54 32 55Q14 54 3 34z" fill="#C97A2B"/><path d="M6 34Q16 17 32 16.5Q48 17 58 34Q48 51 32 51.5Q16 51 6 34z" fill="#E9A848"/><path d="M14 34Q22 23 32 22.5Q42 23 50 34Q42 45 32 45.5Q22 45 14 34z" fill="#FFE08A"/><circle cx="23" cy="25" r="1.6" fill="#B5651D"/><circle cx="44" cy="44" r="1.6" fill="#B5651D"/><circle cx="32" cy="34" r="6" fill="#FF9F0A"/><circle cx="32" cy="34" r="6" fill="none" stroke="#FFD34D" stroke-width="2"/><circle cx="30" cy="32" r="1.8" fill="#fff" opacity=".7"/><rect x="38" y="27" width="7" height="5" rx="1.4" fill="#FFF4C2" transform="rotate(18 41.5 29.5)"/></svg>`;
 case 'wine':return S+`<path d="M19 8h26q2 22-13 28Q17 30 19 8z" fill="#ffffff" fill-opacity=".22" stroke="#DCE6EF" stroke-width="2"/><path d="M20.5 17h23q-.5 14-11.5 17.5Q21 31 20.5 17z" fill="#9B1B30"/><path d="M23 19q1 9 6 12" stroke="#fff" stroke-opacity=".45" stroke-width="2" fill="none" stroke-linecap="round"/><rect x="30.8" y="36" width="2.4" height="15" fill="#DCE6EF"/><ellipse cx="32" cy="53" rx="11" ry="3.2" fill="#DCE6EF"/></svg>`;
 case 'kantsi':return S+`<path d="M8 52Q12 25 45 12L54 26Q27 32 16 54z" fill="#7A4A22"/><path d="M8 52Q12 25 45 12L48 17Q18 29 12 53z" fill="#A86B36"/><path d="M45 12L54 26" stroke="#E5E7EB" stroke-width="5" stroke-linecap="round"/><path d="M24 25l6 9M33 20l5 8" stroke="#D1D5DB" stroke-width="3"/><circle cx="10" cy="53" r="3.2" fill="#D1D5DB"/></svg>`;
 default:return S+`<text x="32" y="53" text-anchor="middle" font-size="54" font-weight="900" font-family="Arial Black,Arial,sans-serif" fill="#E0243B" stroke="#FFD66B" stroke-width="3" paint-order="stroke">7</text></svg>`}}
const slotCell=k=>`<span class="sl-sym" data-k="${k}">${slotSym(k)}</span>`;
const slotRand=()=>SLOTK[Math.floor(Math.random()*SLOTK.length)];
const SL={vis:null,busy:false};
PG.slot={r(){csPage('slot','ქართული სლოტი',slotDraw)}};
function slotDraw(el,i){SL.vis=SL.vis||[0,1,2].map(()=>[slotRand(),slotRand(),slotRand()]);SL.busy=false;
 el.innerHTML=`<div class="cs-stage sl-stage"><div class="sl-machine"><div class="sl-top"><b>ქართული სლოტი</b><span class="sl-bulbs" aria-hidden="true">${Array.from({length:11},(_,k)=>`<i style="--d:${k*.12}s"></i>`).join('')}</span></div>
  <div class="sl-win" id="sl_win" aria-live="polite">დაატრიალე და შეაგროვე ერთნაირები</div>
  <div class="sl-reels" id="sl_reels">${SL.vis.map(v=>`<div class="sl-reel"><div class="sl-strip">${v.map(slotCell).join('')}</div></div>`).join('')}<span class="sl-line" aria-hidden="true"></span></div>
  <div class="sl-ctl">${csBetHTML('slot')}<button class="sl-go" id="sl_go" data-a="slspin" aria-label="დატრიალება"><span>ტრიალი</span></button></div></div></div>
 ${csBalHTML(i)}
 <section class="cs-card"><h3>ანაზღაურება</h3><div class="sl-pay">${SLOTPAY.map(([k,m])=>`<div><span class="sl-p3">${slotSym(k)}${slotSym(k)}${slotSym(k)}</span><b>${m}×</b></div>`).join('')}
  <div><span class="sl-p3">${slotSym('grape')}${slotSym('grape')}<em>?</em></span><b>1×</b></div></div><p class="note">ითვლება შუა ხაზი, მარცხნიდან. პირველი ორი ერთნაირი ფსონს გიბრუნებს.</p></section>`}
A.slspin=async()=>{if(SL.busy)return;const bet=csBet('slot');if((ME.coins||0)<bet){toast('მონეტები არ გყოფნის');return}
 const st=$('.sl-stage'),w=$('#sl_win');SL.busy=true;st.classList.add('busy');st.classList.remove('won','big');w.textContent='…';
 let r;try{r=await rpc('slot_spin',{p_bet:bet})}catch(e){SL.busy=false;st.classList.remove('busy');w.textContent='დაატრიალე და შეაგროვე ერთნაირები';toast(errMsg(e));return}
 const bal=$('#cs_bal');if(bal)bal.textContent=nf(r.coins-r.win);
 const reels=$$('.sl-reel'),h=reels[0].getBoundingClientRect().height/3,rm=RM();
 await Promise.all(reels.map((reel,k)=>{const strip=$('.sl-strip',reel),fill=Array.from({length:rm?0:10+k*5},slotRand),fin=[slotRand(),r.r[k],slotRand()],all=[...SL.vis[k],...fill,...fin];
  strip.innerHTML=all.map(slotCell).join('');SL.vis[k]=fin;const dist=(all.length-3)*h;
  if(rm){strip.innerHTML=fin.map(slotCell).join('');return Promise.resolve()}
  const an=strip.animate([{transform:'translateY(0)',filter:'blur(0)'},{transform:`translateY(${-dist*.6}px)`,filter:'blur(2px)',offset:.55},{transform:`translateY(${-dist}px)`,filter:'blur(0)'}],{duration:900+k*420,easing:'cubic-bezier(.2,.6,.25,1.03)',fill:'forwards'});
  return an.finished.then(()=>{strip.innerHTML=fin.map(slotCell).join('');an.cancel()}).catch(()=>{})}));
 if(!$('#sl_reels'))return;
 SL.busy=false;st.classList.remove('busy');csAfter(r.coins,bet);
 if(r.win>0){const n=r.mult>=9?3:2;st.classList.add('won');if(r.mult>=20)st.classList.add('big');
  reels.forEach((reel,k)=>{if(k<n)$$('.sl-sym',reel)[1]?.classList.add('hit')});
  w.innerHTML=`<b>+${nf(r.win)}</b> · ${r.mult}×`;if(r.mult>=20&&typeof confetti==='function')confetti()}
 else w.textContent='ამჯერად არა. კიდევ ერთხელ?'};

/* ---------- roulette: European, one zero ---------- */
const RL_ORDER=[0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26];
const RL_RED=new Set([1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]);
const rlCol=n=>n===0?'g':RL_RED.has(n)?'r':'b';
const RLT={bets:{},hist:[],chip:+store.get('rlchip',0)||25,rot:0,busy:false};
/* outside bets in pairs, one pair a column: 1–18 over 19–36, even over odd, red over black */
const RL_OUT=[['low',0,'1–18'],['high',0,'19–36'],['even',0,'ლუწი'],['odd',0,'კენტი'],['red',0,''],['black',0,'']];
function rlWheel(){const a=360/37,P=(r,d)=>{const t=(d-90)*Math.PI/180;return `${(r*Math.cos(t)).toFixed(2)} ${(r*Math.sin(t)).toFixed(2)}`};
 return `<svg class="rl-wheel" viewBox="-130 -130 260 260" aria-hidden="true"><circle r="128" fill="#5A2C0C"/><circle r="121" fill="none" stroke="#E9B44C" stroke-width="3"/>
 <g id="rl_rot" style="transform:rotate(${RLT.rot}deg)">${RL_ORDER.map((n,i)=>{const d0=i*a-a/2,d1=i*a+a/2,c=rlCol(n);
  return `<path d="M${P(118,d0)}A118 118 0 0 1 ${P(118,d1)}L${P(80,d1)}A80 80 0 0 0 ${P(80,d0)}Z" fill="${c==='g'?'#0E8A4B':c==='r'?'#C8102E':'#16161A'}" stroke="#E9B44C" stroke-width=".6"/>
  <text transform="rotate(${i*a}) translate(0 -101)" text-anchor="middle" dominant-baseline="middle" font-size="11" font-weight="800" fill="#fff">${n}</text>`}).join('')}
 <circle r="80" fill="#7A3E12"/><circle r="64" fill="#5A2C0C"/>${[0,90,180,270].map(d=>`<path d="M0 0L${P(46,d)}" stroke="#E9B44C" stroke-width="5" stroke-linecap="round"/>`).join('')}<circle r="14" fill="#E9B44C"/><circle r="6" fill="#FFF0B8"/></g>
 <circle cx="0" cy="-90" r="6.5" fill="#fff" stroke="#999" stroke-width=".8" class="rl-ball"/><path d="M-8 -133L8 -133L0 -119Z" fill="#E9B44C"/></svg>`}
const rlKey=(t,v)=>t+':'+v;
const rlTot=()=>Object.values(RLT.bets).reduce((a,b)=>a+b,0);
const rlShort=v=>v>=1000?(v/1000).toFixed(v%1000?1:0)+'k':v;
function rlCell(t,v,label,cls,name){const a=RLT.bets[rlKey(t,v)];return `<button type="button" class="rl-c ${cls||''}" data-a="rlbet" data-t="${t}" data-v="${v}" aria-label="${name||label||v}${a?`, ფსონი ${a}`:''}">${label??v}${a?`<i class="rl-chip">${rlShort(a)}</i>`:''}</button>`}
function rlBoard(){let g='';for(let r=0;r<12;r++)for(let c=1;c<=3;c++){const n=r*3+c;g+=rlCell('n',n,String(n),'rl-'+rlCol(n))}
 return `<div class="rl-board" id="rl_board">${rlCell('n',0,'0','rl-g rl-zero')}<div class="rl-grid">${g}</div><div class="rl-cols">${[1,2,3].map(v=>rlCell('col',v,'2:1','rl-o',`${v}-ე სვეტი, 2:1`)).join('')}</div>
 <div class="rl-doz">${[1,2,3].map(v=>rlCell('dozen',v,['1–12','13–24','25–36'][v-1],'rl-o',['1–12','13–24','25–36'][v-1])).join('')}</div>
 <div class="rl-outs">${RL_OUT.map(([t,,l])=>rlCell(t,0,t==='red'?'<span class="rl-dia r"></span>':t==='black'?'<span class="rl-dia b"></span>':l,'rl-o rl-'+t,t==='red'?'წითელი':t==='black'?'შავი':l)).join('')}</div></div>`}
function rlChips(){const i=CSN.info||{},lo=i.min_bet||10,hi=i.max_bet||500,vs=[10,25,50,100,250,500,1000].filter(v=>v<=hi);if(!vs.includes(RLT.chip))RLT.chip=vs.find(v=>v>=lo)||vs[0];
 return vs.map(v=>`<button type="button" class="rl-pick${v===RLT.chip?' on':''}" data-a="rlchip" data-v="${v}" aria-pressed="${v===RLT.chip}">${rlShort(v)}</button>`).join('')}
const rlHist=()=>RLT.hist.slice(0,14).map(n=>`<span class="rl-h rl-${rlCol(n)}">${n}</span>`).join('')||'<small class="muted">ჯერ არ დაგიტრიალებია</small>';
PG.roulette={r(){csPage('roulette','რულეტკა',rlDraw)}};
function rlDraw(el,i){RLT.busy=false;
 el.innerHTML=`<div class="cs-stage rl-stage"><div class="rl-wrap">${rlWheel()}</div><div class="rl-res" id="rl_res" aria-live="polite">დადე ფსონები და დაატრიალე</div><div class="rl-hist" id="rl_hist">${rlHist()}</div></div>
 ${csBalHTML(i)}
 <div class="rl-tools"><div class="rl-picks" role="group" aria-label="ჩიპი">${rlChips()}</div></div>
 ${rlBoard()}
 <div class="rl-bar"><button class="btn ghost sm" data-a="rlclear">${ic('trash')}გასუფთავება</button><span class="grow"><small>ჯამში</small><b id="rl_tot">${nf(rlTot())}</b></span><button class="btn gold" id="rl_go" data-a="rlspin">ტრიალი</button></div>`;
 rpc('casino_mine',{p_game:'roulette'}).then(rows=>{RLT.hist=(rows||[]).map(x=>x.d&&x.d.n).filter(n=>n!=null);const h=$('#rl_hist');if(h)h.innerHTML=rlHist()}).catch(()=>{})}
function rlRefresh(){const b=$('#rl_board');if(b)b.outerHTML=rlBoard();const t=$('#rl_tot');if(t)t.textContent=nf(rlTot())}
A.rlchip=t=>{RLT.chip=+t.dataset.v;store.set('rlchip',RLT.chip);$$('.rl-pick').forEach(b=>{const on=+b.dataset.v===RLT.chip;b.classList.toggle('on',on);b.setAttribute('aria-pressed',String(on))})};
A.rlbet=t=>{if(RLT.busy)return;const k=rlKey(t.dataset.t,t.dataset.v),hi=(CSN.info||{}).max_bet||500;
 if(rlTot()+RLT.chip>hi){toast(`ერთ ტრიალზე მაქსიმუმ ${nf(hi)} მონეტა`);return}RLT.bets[k]=(RLT.bets[k]||0)+RLT.chip;$$('.rl-hit').forEach(x=>x.classList.remove('rl-hit'));rlRefresh()};
A.rlclear=()=>{if(RLT.busy)return;RLT.bets={};rlRefresh()};
A.rlspin=async t=>{if(RLT.busy)return;const tot=rlTot(),lo=(CSN.info||{}).min_bet||10;if(!tot){toast('ჯერ დადე ფსონი: შეეხე რიცხვს ან ველს');return}
 if(tot<lo){toast(`მინიმუმ ${nf(lo)} მონეტა`);return}if((ME.coins||0)<tot){toast('მონეტები არ გყოფნის');return}
 const bets=Object.entries(RLT.bets).map(([k,a])=>{const[t,v]=k.split(':');return {t,v:+v,a}});
 RLT.busy=true;t.disabled=true;$('.rl-stage').classList.add('busy');const res=$('#rl_res');res.className='rl-res';res.textContent='ბურთი ტრიალებს…';view.scrollTo({top:0,behavior:RM()?'auto':'smooth'});
 let r;try{r=await rpc('roulette_spin',{p_bets:bets})}catch(e){RLT.busy=false;t.disabled=false;$('.rl-stage')?.classList.remove('busy');res.textContent='დადე ფსონები და დაატრიალე';toast(errMsg(e));return}
 const bal=$('#cs_bal');if(bal)bal.textContent=nf(r.coins-r.win);
 const a=360/37,idx=RL_ORDER.indexOf(r.n),target=((-idx*a)%360+360)%360,cur=((RLT.rot%360)+360)%360;RLT.rot=RLT.rot+(RM()?0:360*5)+((target-cur+360)%360);
 const g=$('#rl_rot');if(g){g.style.transition=RM()?'none':'transform 4.6s cubic-bezier(.12,.72,.14,1)';g.style.transform=`rotate(${RLT.rot}deg)`}
 await new Promise(ok=>setTimeout(ok,RM()?60:4700));
 RLT.busy=false;if(!$('#rl_res'))return;t.disabled=false;$('.rl-stage').classList.remove('busy');csAfter(r.coins,r.bet);RLT.hist.unshift(r.n);$('#rl_hist').innerHTML=rlHist();
 const c=rlCol(r.n);res.className='rl-res show '+(r.win>0?'win':'lose');
 res.innerHTML=`<span class="rl-n rl-${c}">${r.n}</span><span>${c==='g'?'ნული':c==='r'?'წითელი':'შავი'}</span><b>${r.win>0?`+${nf(r.win)}`:'წააგე'}</b>`;
 $$(`#rl_board [data-t="n"][data-v="${r.n}"]`).forEach(x=>x.classList.add('rl-hit'));if(r.win>=r.bet*10&&typeof confetti==='function')confetti()};

/* ---------- blackjack: you against the dealer ---------- */
const BJ={r:null,busy:false,seen:{p:0,d:0}};
const BJ_SUIT={S:'♠',H:'♥',D:'♦',C:'♣'};
function bjCard(c,i,isNew){if(!c)return `<span class="bj-card back${isNew?' new':''}" style="--i:${i}"></span>`;const rk=c.slice(0,-1),s=c.slice(-1),red=s==='H'||s==='D';
 return `<span class="bj-card${red?' red':''}${isNew?' new':''}" style="--i:${i}" aria-label="${rk}${BJ_SUIT[s]}"><b>${rk}</b><i>${BJ_SUIT[s]}</i><b class="br">${rk}</b></span>`}
const BJ_END={bust:['გადააჭარბე 21-ს','lose'],dbj:['დილერს ბლექჯეკი აქვს','lose'],lose:['დილერმა მოიგო','lose'],bj:['ბლექჯეკი!','win'],dbust:['დილერმა გადააჭარბა','win'],win:['შენ მოიგე','win'],push:['ფრე: ფსონი დაგიბრუნდა','push']};
PG.bj={r(){csPage('bj','ბლექჯეკი',bjDraw)}};
async function bjDraw(el,i){BJ.r=null;BJ.busy=false;BJ.seen={p:0,d:0};
 el.innerHTML=`<div class="cs-stage bj-stage"><div class="bj-side"><small>დილერი <b id="bj_dv"></b></small><div class="bj-hand" id="bj_d"></div></div>
  <div class="bj-msg" id="bj_msg" aria-live="polite">დადე ფსონი და დაარიგე</div>
  <div class="bj-side"><div class="bj-hand" id="bj_p"></div><small>შენ <b id="bj_pv"></b></small></div><div class="bj-ctl" id="bj_ctl"></div></div>${csBalHTML(i)}
  <section class="cs-card"><h3>წესები მოკლედ</h3><p class="note">შეაგროვე 21-თან ახლოს, ოღონდ არ გადააჭარბო. სურათიანი კარტი 10-ია, ტუზი 1 ან 11. ბლექჯეკი (ტუზი და 10) იხდის 3:2-ს, მოგება 1:1-ს. დილერი 17-მდე იღებს. გაორმაგება პირველ ორ კარტზეა: ფსონი ორდება და ერთ კარტს იღებ.</p></section>`;
 bjCtl();
 try{const o=await q(sb.from('casino_rounds').select('id,bet').eq('game','bj').eq('state','open').order('id',{ascending:false}).limit(1));if(o&&o[0]&&$('#bj_p')){BJ.r=await rpc('bj_deal',{p_bet:o[0].bet});bjShow(true)}}catch(e){}}
function bjCtl(){const c=$('#bj_ctl');if(!c)return;const r=BJ.r,open=r&&r.state==='open';
 c.innerHTML=open?`<button class="btn bj-b" data-a="bjact" data-k="hit">კიდევ</button><button class="btn bj-b gold" data-a="bjact" data-k="stand">გაჩერება</button>${r.p.length===2&&(ME.coins||0)>=r.bet?`<button class="btn bj-b ghost" data-a="bjact" data-k="double">გაორმაგება</button>`:''}`
  :`${csBetHTML('bj')}<button class="btn gold bj-deal" data-a="bjdeal">${r?'ახალი დარიგება':'დარიგება'}</button>`;
 c.querySelectorAll('button').forEach(b=>b.disabled=BJ.busy)}
function bjShow(resume){const r=BJ.r;if(!r||!$('#bj_p'))return;const open=r.state==='open',dc=open?[r.d[0],null]:r.d;
 $('#bj_p').innerHTML=r.p.map((c,k)=>bjCard(c,k,!resume&&k>=BJ.seen.p)).join('');
 $('#bj_d').innerHTML=dc.map((c,k)=>bjCard(c,k,!resume&&(k>=BJ.seen.d||(!open&&k===1&&BJ.seen.open)))).join('');
 BJ.seen={p:r.p.length,d:dc.length,open};
 $('#bj_pv').textContent=r.pv;$('#bj_dv').textContent=open?r.dv+' + ?':r.dv;
 const m=$('#bj_msg'),st=$('.bj-stage');st.classList.remove('win','lose','push');
 if(open){m.textContent=r.dbl?'გაორმაგდა':'კიდევ თუ გაჩერდები?'}
 else{const[t,k]=BJ_END[r.end]||['',''];st.classList.add(k);m.innerHTML=`<b>${t}</b>${r.win>0&&r.end!=='push'?` <em>+${nf(r.win)}</em>`:''}`;if(r.end==='bj'&&typeof confetti==='function')confetti()}
 bjCtl()}
A.bjdeal=async()=>{if(BJ.busy)return;const bet=csBet('bj');if((ME.coins||0)<bet){toast('მონეტები არ გყოფნის');return}
 BJ.busy=true;bjCtl();try{BJ.r=await rpc('bj_deal',{p_bet:bet});BJ.seen={p:0,d:0};
  BJ.busy=false;bjShow();csAfter(BJ.r.coins,bet)}catch(e){BJ.busy=false;bjCtl();toast(errMsg(e))}};
A.bjact=async t=>{if(BJ.busy||!BJ.r)return;const k=t.dataset.k;BJ.busy=true;bjCtl();const before=BJ.r.bet;
 try{BJ.r=await rpc('bj_act',{p_round:BJ.r.id,p_act:k});BJ.busy=false;bjShow();csAfter(BJ.r.coins,k==='double'?before:0)}catch(e){BJ.busy=false;bjCtl();toast(errMsg(e))}};

/* ---------- the aviator: the plane climbs, cash out before it flies away ---------- */
const AV={r:null,off:0,raf:0,poll:0,hist:[],ticking:false,end:0};
const AV_AUTO=[1.2,1.5,2,3,5,10,20,50,100];
const avAuto=()=>{const v=+store.get('avauto',2);return AV_AUTO.includes(v)?v:2};
const avAutoOn=()=>!!store.get('avautoon',false);
const avM=()=>{const r=AV.r;if(!r)return 1;return Math.exp(r.k*Math.max(0,Date.now()/1000+AV.off-r.t0))};
const avCls=m=>m>=10?'hi':m>=2?'mid':'lo';
PG.aviator={r(){csPage('aviator','ავიატორი',avDraw)}};
async function avDraw(el,i){avStop();AV.r=null;
 el.innerHTML=`<div class="cs-stage av-stage" id="av_st"><canvas id="av_cv" aria-hidden="true"></canvas><div class="av-m" id="av_m" aria-live="polite"><b>1.00×</b><small>დადე ფსონი და გაუშვი</small></div></div>
 <div class="av-hist" id="av_hist"></div>${csBalHTML(i)}
 <div class="av-ctl"><div class="av-row">${csBetHTML('aviator')}<div class="av-auto"><button type="button" class="switch" role="switch" data-a="avautosw" aria-checked="${avAutoOn()}" aria-label="ავტომატურად აღება"></button><span><small>ავტომატურად</small><span class="av-av"><button type="button" class="cs-step sm" data-a="avautostep" data-d="-1" aria-label="ნაკლები">−</button><b id="av_auto">${avAuto().toFixed(2)}×</b><button type="button" class="cs-step sm" data-a="avautostep" data-d="1" aria-label="მეტი">+</button></span></span></div></div>
 <button class="av-go" id="av_go" data-a="avgo"></button></div>
 <section class="cs-card"><h3>როგორ ითამაშო</h3><p class="note">თვითმფრინავი აფრინდება და კოეფიციენტი იზრდება. დააჭირე „აიღე“, სანამ გაფრინდება: მიიღებ ფსონს გამრავლებულს იმ კოეფიციენტზე. თუ ადრე გაფრინდა, ფსონი იკარგება. „ავტომატურად“ თავად აიღებს მითითებულ კოეფიციენტზე.</p></section>`;
 avIdle();avPaint();
 rpc('casino_mine',{p_game:'aviator'}).then(rows=>{AV.hist=(rows||[]).map(x=>x.d&&x.d.crash).filter(Boolean).map(Number);avHist()}).catch(()=>{});
 try{const o=await q(sb.from('casino_rounds').select('id').eq('game','aviator').eq('state','open').order('id',{ascending:false}).limit(1));
  if(o&&o[0]&&$('#av_cv')){const r=await rpc('av_tick',{p_round:o[0].id});avTake(r)}}catch(e){}}
function avHist(){const h=$('#av_hist');if(h)h.innerHTML=AV.hist.slice(0,16).map(m=>`<span class="av-p ${avCls(m)}">${m.toFixed(2)}×</span>`).join('')}
function avIdle(){const b=$('#av_go');if(!b||AV.r&&AV.r.state==='open')return;b.className='av-go';b.disabled=false;b.innerHTML=`<b>ფსონი</b><small>${nf(csBet('aviator'))} მონეტა</small>`}
A.avautosw=t=>{const on=t.getAttribute('aria-checked')!=='true';t.setAttribute('aria-checked',String(on));store.set('avautoon',on)};
A.avautostep=t=>{const i=AV_AUTO.indexOf(avAuto()),n=AV_AUTO[Math.max(0,Math.min(AV_AUTO.length-1,i+(+t.dataset.d)))];store.set('avauto',n);$('#av_auto').textContent=n.toFixed(2)+'×'};
A.avgo=async t=>{if(t.disabled)return;
 if(AV.r&&AV.r.state==='open'){t.disabled=true;try{avTake(await rpc('av_cashout',{p_round:AV.r.id}))}catch(e){t.disabled=false;toast(errMsg(e))}return}
 const bet=csBet('aviator');if((ME.coins||0)<bet){toast('მონეტები არ გყოფნის');return}
 t.disabled=true;try{const r=await rpc('av_start',{p_bet:bet,p_auto:avAutoOn()?avAuto():null});csAfter(r.coins,r.state==='open'&&r.bet===bet?bet:0);avTake(r)}catch(e){t.disabled=false;toast(errMsg(e))}};
/* a round from the server: in the air, or over */
function avTake(r){if(!r)return;AV.r=r;AV.off=(r.now||Date.now()/1000)-Date.now()/1000;const b=$('#av_go');if(!b)return;
 if(r.state==='open'){$('#av_st').classList.remove('gone','won');b.disabled=false;b.className='av-go out';avLoop();clearInterval(AV.poll);AV.poll=setInterval(avPoll,350);return}
 avStop();const crash=+r.crash||1,m=r.m!=null?+r.m:null;AV.end=Date.now();AV.hist.unshift(crash);avHist();
 $('#av_st').classList.add('gone');if(m)$('#av_st').classList.add('won');
 $('#av_m').innerHTML=`<b>${crash.toFixed(2)}×</b><small>${m?`აიღე ${m.toFixed(2)}×-ზე · +${nf(r.win)}`:'გაფრინდა'}</small>`;
 if(r.coins!=null){setCoins(r.coins);const bl=$('#cs_bal');if(bl)bl.textContent=nf(r.coins)}
 avPaint(crash,true);b.disabled=true;b.className='av-go';b.innerHTML=m?`<b>აიღე</b><small>+${nf(r.win)} მონეტა</small>`:'<b>გაფრინდა</b><small>ფსონი დაიკარგა</small>';setTimeout(()=>{if($('#av_go')&&!(AV.r&&AV.r.state==='open')){AV.r=null;avIdle()}},1400)}
async function avPoll(){if(!AV.r||AV.r.state!=='open'||AV.ticking)return;if(S.page?.id!=='aviator'){avStop();return}AV.ticking=true;
 try{const r=await rpc('av_tick',{p_round:AV.r.id});if(r.state!=='open')avTake(r)}catch(e){}AV.ticking=false}
function avStop(){cancelAnimationFrame(AV.raf);clearInterval(AV.poll);AV.raf=0}
function avLoop(){cancelAnimationFrame(AV.raf);const step=()=>{if(!AV.r||AV.r.state!=='open'||!$('#av_cv')){AV.raf=0;return}
 const m=avM(),b=$('#av_go');$('#av_m').innerHTML=`<b>${m.toFixed(2)}×</b><small>${AV.r.auto?`ავტომატურად ${(+AV.r.auto).toFixed(2)}×-ზე`:'აიღე, სანამ გაფრინდება'}</small>`;
 if(b&&!b.disabled)b.innerHTML=`<b>აიღე</b><small>${nf(Math.floor(AV.r.bet*m))} მონეტა</small>`;
 if(AV.r.auto&&m>=+AV.r.auto)avPoll();avPaint(m);AV.raf=requestAnimationFrame(step)};step()}
/* the sky: the curve so far, the plane at its head */
function avPaint(m,gone){const cv=$('#av_cv');if(!cv)return;const dpr=Math.min(2,window.devicePixelRatio||1),W=cv.clientWidth,H=cv.clientHeight;if(!W||!H)return;
 if(cv.width!==Math.round(W*dpr)){cv.width=Math.round(W*dpr);cv.height=Math.round(H*dpr)}const x=cv.getContext('2d');x.setTransform(dpr,0,0,dpr,0,0);x.clearRect(0,0,W,H);
 const k=0.11,cur=m||1,t=Math.log(cur)/k,tmax=Math.max(7,t*1.12),mmax=Math.max(1.8,1+(cur-1)*1.18),pad=22;
 const X=s=>pad+s/tmax*(W-pad*2),Y=v=>H-pad-(v-1)/(mmax-1)*(H-pad*2.4);
 x.strokeStyle='rgba(255,255,255,.07)';x.lineWidth=1;x.font='600 10px system-ui,sans-serif';x.fillStyle='rgba(255,255,255,.35)';
 const stepM=mmax>20?10:mmax>6?2:mmax>3?1:.5;for(let v=1+stepM;v<mmax;v+=stepM){const yy=Y(v);x.beginPath();x.moveTo(pad,yy);x.lineTo(W-pad,yy);x.stroke();x.fillText(v.toFixed(v%1?1:0)+'×',4,yy-3)}
 if(!m){drawPlane(x,X(0)+18,Y(1)-10,-.25,1);return}
 const pts=[];for(let i=0;i<=60;i++){const s=t*i/60;pts.push([X(s),Y(Math.exp(k*s))])}
 const gr=x.createLinearGradient(0,0,0,H);gr.addColorStop(0,gone?'rgba(150,150,170,.35)':'rgba(255,59,92,.45)');gr.addColorStop(1,'rgba(255,59,92,0)');
 x.beginPath();x.moveTo(pts[0][0],Y(1));pts.forEach(p=>x.lineTo(p[0],p[1]));x.lineTo(pts[60][0],Y(1));x.closePath();x.fillStyle=gr;x.fill();
 x.beginPath();pts.forEach((p,i)=>i?x.lineTo(p[0],p[1]):x.moveTo(p[0],p[1]));x.strokeStyle=gone?'#8E8EA8':'#FF3B5C';x.lineWidth=4;x.lineCap='round';x.stroke();
 const[a,b]=pts[60],[c,d]=pts[58],ang=Math.atan2(b-d,a-c);
 if(gone){const f=Math.min(1,(Date.now()-AV.end)/600);if(f<1)requestAnimationFrame(()=>avPaint(m,true));drawPlane(x,a+f*W*.5,b-f*H*.6,ang,1-f*.3,f)}else drawPlane(x,a,b,ang,1)}
function drawPlane(x,px,py,ang,sc,fade){x.save();x.translate(px,py);x.rotate(ang);x.scale(1.6*sc,1.6*sc);x.globalAlpha=1-(fade||0);
 x.fillStyle='#C8102E';[['M-2,-2.5','L-9,-17','L-3.5,-17','L7,-2.5'],['M-2,2.5','L-9,17','L-3.5,17','L7,2.5'],['M-15,-2','L-20,-8','L-17,-8','L-11,-2'],['M-15,2','L-20,8','L-17,8','L-11,2']].forEach(p=>{x.beginPath();p.forEach(s=>{const[m,v]=[s[0],s.slice(1).split(',').map(Number)];m==='M'?x.moveTo(...v):x.lineTo(...v)});x.closePath();x.fill()});
 x.fillStyle='#FF4D6A';x.beginPath();x.moveTo(-18,-2.4);x.lineTo(10,-3.2);x.quadraticCurveTo(19,0,10,3.2);x.lineTo(-18,2.4);x.closePath();x.fill();x.restore()}

/* ---------- rules ---------- */
const CS_RULES={slot:['ქართული სლოტი','სამი ბარაბანი, ერთი ხაზი შუაში. სამი ერთნაირი სიმბოლო იხდის ცხრილის მიხედვით (9×-დან 250×-მდე), პირველი ორი ერთნაირი ფსონს გიბრუნებს.'],
 roulette:['რულეტკა','ევროპული ბორბალი, ერთი ნულით. რიცხვზე ფსონი იხდის 35:1-ს, ათეულები და სვეტები 2:1-ს, წითელი/შავი, ლუწი/კენტი, 1–18/19–36 1:1-ს. ნულზე მხოლოდ ნულზე დადებული იგებს.'],
 bj:['ბლექჯეკი','შეაგროვე 21-თან ახლოს. ბლექჯეკი 3:2, მოგება 1:1, ფრეზე ფსონი ბრუნდება. დილერი 17-მდე იღებს. გაორმაგება პირველ ორ კარტზეა. ხელის გაყოფა არ არის.'],
 aviator:['ავიატორი','კოეფიციენტი იზრდება, სანამ თვითმფრინავი გაფრინდება. აიღე დროზე და ფსონი გამრავლდება. რამდენზე გაფრინდება, სერვერი წინასწარ წყვეტს და არავინ იცის.']};
A.csrules=t=>{const g=t.dataset.g,[n,d]=CS_RULES[g]||['',''],i=CSN.info||{};
 sheet(head(n)+`<div class="ph-body cs-rules"><p>${d}</p><p class="hint">ფსონი: ${nf(i.min_bet||10)}–${nf(i.max_bet||500)} მონეტა · ერთი მოგება მაქსიმუმ ${nf(i.max_win||100000)} · დღეში ჯამში ${nf(i.day_bets||20000)} მონეტის ფსონი.</p><p class="hint">შედეგს სერვერი წყვეტს შემთხვევითი რიცხვით. თამაში მხოლოდ 18 წლიდანაა. ითამაშე იმდენით, რისი დაკარგვაც არ გეწყინება.</p></div>`,'short')};

/* ---------- admin: the casino tab ---------- */
const CS_GN={slot:'სლოტი',roulette:'რულეტკა',bj:'ბლექჯეკი',aviator:'ავიატორი'};
async function admCasino(el){const s=await rpc('admin_casino_stats');const top=s.top||[];await loadProfiles(top.map(x=>x.u));if(!el.isConnected)return;
 const c=s.cfg||{},gs=c.games||{},G=s.games||{},pct=(w,b)=>b?Math.round(w/b*1000)/10+'%':'—';
 const sum=k=>Object.values(G).reduce((a,g)=>a+(+g[k]||0),0);
 el.innerHTML=`<section class="tourcard adsite"><div class="frow" style="align-items:center"><span class="grow"><h3 style="margin:0">კაზინო</h3><small class="muted">${c.on?'ჩართულია: 18+ მომხმარებლები თამაშობენ':'გამორთულია: თამაშის გვერდებზე „დახურულია“ წერია'}</small></span>
  <button type="button" class="switch" role="switch" data-a="adcsnsw" data-k="on" aria-checked="${!!c.on}" aria-label="კაზინო ჩართულია"></button></div>
  <div class="cs-adg">${Object.keys(CS_GN).map(k=>`<label class="cs-adt"><span>${CS_GN[k]}</span><button type="button" class="switch" role="switch" data-a="adcsnsw" data-k="${k}" aria-checked="${gs[k]!==false}" aria-label="${CS_GN[k]} ჩართულია"></button></label>`).join('')}</div></section>
 <h3 class="sec2">დღეს</h3><div class="adstats"><div class="adtile"><b>${nf(sum('d_bet'))}</b><span>დაიდო</span></div><div class="adtile"><b>${nf(sum('d_win'))}</b><span>მოიგეს</span></div><div class="adtile"><b>${nf(sum('d_bet')-sum('d_win'))}</b><span>კაზინოს დარჩა</span></div><div class="adtile"><b>${nf(sum('d_n'))}</b><span>რაუნდი</span></div></div>
 <div class="list cs-adl">${Object.keys(CS_GN).map(k=>{const g=G[k]||{};return `<div class="row"><span class="grow"><b>${CS_GN[k]}</b><span class="sub">დღეს: ${nf(g.d_n||0)} რაუნდი, ${nf(g.d_ppl||0)} მოთამაშე, დაიდო ${nf(g.d_bet||0)}, მოიგეს ${nf(g.d_win||0)}</span><span class="sub">7 დღე: დაიდო ${nf(g.w_bet||0)}, მოიგეს ${nf(g.w_win||0)} · დაბრუნდა ${pct(g.w_win||0,g.w_bet||0)}</span></span></div>`}).join('')}</div>
 ${top.length?`<h3 class="sec2">დღეს ყველაზე მეტი მოიგეს</h3><div class="list">${top.map(x=>`<button class="row" data-a="user" data-u="${x.u}">${av(x.u,32)}<span class="grow"><b>${esc(pname(x.u))}</b><span class="sub">${nf(x.n)} რაუნდი</span></span><b class="${x.net>=0?'plus':'minus'}">${x.net>=0?'+':''}${nf(x.net)}</b></button>`).join('')}</div>`:''}
 <section class="tourcard adsite"><h3>ლიმიტები</h3><p class="note">მონეტებში. 10,000 მონეტა = 1 ₾.</p>
  <div class="cs-adf">${[['min_bet','მინიმალური ფსონი',10],['max_bet','მაქსიმალური ფსონი',500],['max_win','ერთი მოგება მაქსიმუმ',100000],['day_bets','დღეში ფსონები ერთ ადამიანზე',20000]].map(([k,l,d])=>`<label class="fld">${l}<input id="acs_${k}" type="number" inputmode="numeric" min="1" value="${c[k]??d}"></label>`).join('')}</div>
  <button class="btn" data-a="adcsnsave">${ic('check')}შენახვა</button></section>`}
A.adcsnsw=async t=>{const k=t.dataset.k,on=t.getAttribute('aria-checked')!=='true';t.setAttribute('aria-checked',String(on));
 try{await rpc('admin_casino_set',{p_cfg:k==='on'?{on}:{games:{[k]:on}}});CSN.info=null;toast(on?'ჩაირთო':'გამოირთო');adminTab()}catch(e){t.setAttribute('aria-checked',String(!on));toast(errMsg(e))}};
A.adcsnsave=async()=>{const v={};for(const k of ['min_bet','max_bet','max_win','day_bets']){const n=Math.floor(+$('#acs_'+k).value);if(!(n>=1)){toast('ჩაწერე დადებითი რიცხვი');return}v[k]=n}
 if(v.min_bet>v.max_bet){toast('მინიმალური ფსონი მაქსიმალურზე მეტია');return}
 try{await rpc('admin_casino_set',{p_cfg:v});CSN.info=null;toast('შენახულია');adminTab()}catch(e){toast(errMsg(e))}};
