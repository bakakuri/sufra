/* roulette and blackjack. With the 3D engine on, each table is a scene of its own (js/g3d-casino.js): the wheel turns and the
   ball runs round it and drops into a pocket; Nino deals at the lounge table. Without it they are drawn here, flat. The betting,
   the buttons and the result are the same either way; the ball's path is worked out here once, for both */
const csG3=()=>typeof g3Want==='function'&&g3Want();
const csG3Ready=()=>csG3()&&typeof G3W!=='undefined'&&G3W.ready&&typeof csG3Show==='function';
/* the 3D engine arrives after the page: the page draws again with it */
const csG3Kick=id=>{if(csG3()&&typeof g3On==='function'&&!g3On()&&typeof g3Load==='function')g3Load().then(()=>{if(S.page?.id===id&&PG[id].g3)PG[id].g3()}).catch(()=>{})};

/* ---------- roulette: European, one zero ---------- */
const RL_ORDER=[0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26];
const RL_RED=new Set([1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]);
const rlCol=n=>n===0?'g':RL_RED.has(n)?'r':'b';
const RL_A=360/37;
/* the chips: value, colour, the colour of their edge marks */
const RL_CHIPS=[[10,'#ECEDEF','#2F6BFF'],[25,'#1F9E5A','#fff'],[50,'#C8102E','#fff'],[100,'#1B1C22','#FFD35C'],[250,'#7B2FF7','#fff'],[500,'#E07A12','#fff'],[1000,'#F2C24E','#7A4A0C']];
const RLT={bets:{},last:null,undo:[],hist:[],chip:+store.get('rlchip',0)||25,busy:false,res:null,rot:0,spin:null,raf:0,lastT:0};
const rlKey=(t,v)=>t+':'+v;
const rlTot=()=>Object.values(RLT.bets).reduce((a,b)=>a+b,0);
const rlShort=v=>v>=1000?(v/1000).toFixed(v%1000?1:0)+'k':String(v);
const rlChipOf=v=>RL_CHIPS.slice().reverse().find(c=>v>=c[0])||RL_CHIPS[0];
const rlChipHTML=(v,cls='',st='')=>{const[,c,e]=rlChipOf(v);return `<i class="rl-chip ${cls}" style="--c:${c};--e:${e};${st}">${rlShort(v)}</i>`};

/* the ball over a spin (s from 0 to 1): its turn in the wheel's own frame (deg), how far out (1 the track, 0 the pocket), its hop.
   it runs the other way round on the track, slows, falls inward over the diamonds, bounces between the frets and settles */
function rlBall(s,P,D){const g=Math.pow(1-s,2.4),phi=P-D*g;let r=1,h=0;
 if(s>=.58&&s<.74){const u=(s-.58)/.16;r=1-u*u*(3-2*u)}else if(s>=.74){const v=(s-.74)/.26,b=Math.exp(-4.5*v)*Math.abs(Math.sin(v*17));r=.28*b;h=b}
 return{phi,r,h}}
/* where the wheel and ball are now; the 3D scene and the flat wheel both read this every frame */
function rlNow(now){const sp=RLT.spin;if(!sp)return{rot:RLT.rot,ball:RLT.ball||null,live:false};const s=Math.min(1,(now-sp.t0)/sp.T),rot=sp.rot0+sp.w*(now-sp.t0)/1000,b=rlBall(s,sp.P,sp.D);
 if(s>=.74){const k=Math.floor((s-.74)/.26*17/Math.PI);if(k!==sp.hk){sp.hk=k;if(b.h>.08)csSnd('ball',Math.min(1,b.h*1.4))}}else{const k=Math.floor((b.phi+rot)/RL_A);if(k!==sp.tk){sp.tk=k;if(s>.45&&s<.74)csSnd('tick',.5)}}
 if(s>=1){RLT.rot=rot;RLT.ball={phi:sp.P,r:0,h:0};RLT.spin=null;const done=sp.done;sp.done=null;if(done)setTimeout(done,0)}return{rot,ball:b,live:s<1}}
/* the flat wheel */
function rlWheel(){const P=(r,d)=>{const t=(d-90)*Math.PI/180;return `${(r*Math.cos(t)).toFixed(2)} ${(r*Math.sin(t)).toFixed(2)}`};
 return `<svg class="rl-wheel" viewBox="-130 -130 260 260" aria-hidden="true"><defs><radialGradient id="rlw" r=".5"><stop offset=".8" stop-color="#6A3410"/><stop offset=".93" stop-color="#3E1C06"/><stop offset="1" stop-color="#1E0C02"/></radialGradient>
 <radialGradient id="rlc" cx=".42" cy=".38" r=".7"><stop offset="0" stop-color="#A86A34"/><stop offset="1" stop-color="#3E1C06"/></radialGradient><linearGradient id="rlg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFF4C4"/><stop offset=".5" stop-color="#E9B44C"/><stop offset="1" stop-color="#8A5A12"/></linearGradient>
 <radialGradient id="rlb" cx=".35" cy=".3" r=".7"><stop offset="0" stop-color="#fff"/><stop offset=".7" stop-color="#D8DCE2"/><stop offset="1" stop-color="#8E959E"/></radialGradient></defs>
 <circle r="129" fill="url(#rlw)"/><circle r="121" fill="#2A1204"/><circle r="119" fill="none" stroke="url(#rlg)" stroke-width="2"/>
 ${[0,45,90,135,180,225,270,315].map(d=>`<path d="M${P(108,d-2)}L${P(112,d)}L${P(108,d+2)}L${P(104,d)}Z" fill="url(#rlg)"/>`).join('')}
 <g id="rl_rot" transform="rotate(${RLT.rot.toFixed(2)})">${RL_ORDER.map((n,i)=>{const d0=i*RL_A-RL_A/2,d1=i*RL_A+RL_A/2,c=rlCol(n);
  return `<path d="M${P(98,d0)}A98 98 0 0 1 ${P(98,d1)}L${P(64,d1)}A64 64 0 0 0 ${P(64,d0)}Z" fill="${c==='g'?'#0E8A4B':c==='r'?'#C8102E':'#16161A'}"/><path d="M${P(98,d0)}L${P(64,d0)}" stroke="url(#rlg)" stroke-width="1.1"/>
  <text transform="rotate(${(i*RL_A).toFixed(2)}) translate(0 -86)" text-anchor="middle" dominant-baseline="middle" font-size="10.5" font-weight="800" fill="#fff">${n}</text>`}).join('')}
  <circle r="98" fill="none" stroke="url(#rlg)" stroke-width="1.6"/><circle r="64" fill="url(#rlc)" stroke="url(#rlg)" stroke-width="1.6"/><circle r="74" fill="none" stroke="#000" stroke-opacity=".25" stroke-width="20"/>
  ${[0,90,180,270].map(d=>`<path d="M0 0L${P(42,d)}" stroke="url(#rlg)" stroke-width="5" stroke-linecap="round"/><circle cx="${P(44,d).split(' ')[0]}" cy="${P(44,d).split(' ')[1]}" r="4.5" fill="url(#rlg)"/>`).join('')}<circle r="15" fill="url(#rlg)"/><circle r="6" fill="#FFF7D6"/></g>
 <circle id="rl_ball" r="5.2" fill="url(#rlb)" style="display:none"/></svg>`}
function rl2DFrame(now){RLT.raf=0;const w=$('#rl_rot'),b=$('#rl_ball');if(!w)return;const st=rlNow(now);w.setAttribute('transform',`rotate(${st.rot.toFixed(2)})`);
 if(st.ball&&b){const R=64+12+st.ball.r*30,a=(st.ball.phi+st.rot-90)*Math.PI/180,o=st.ball.h*3;b.style.display='';b.setAttribute('cx',(Math.cos(a)*(R+o)).toFixed(2));b.setAttribute('cy',(Math.sin(a)*(R+o)).toFixed(2))}
 if(st.live)RLT.raf=requestAnimationFrame(rl2DFrame)}
function rlKickFrame(){if(csG3Ready()&&$('.rl-stage .g3')){if(typeof g3Need==='function')g3Need();return}if(!RLT.raf)RLT.raf=requestAnimationFrame(rl2DFrame)}

function rlCell(t,v,label,cls,name){const a=RLT.bets[rlKey(t,v)];return `<button type="button" class="rl-c ${cls||''}" data-a="rlbet" data-t="${t}" data-v="${v}" aria-label="${name||label||v}${a?`, ფსონი ${a}`:''}"><span>${label??v}</span>${a?rlChipHTML(a,'on'):''}</button>`}
const RL_OUT=[['low',0,'1–18'],['even',0,'ლუწი'],['red',0,''],['black',0,''],['odd',0,'კენტი'],['high',0,'19–36']];
function rlBoard(){let g='';for(let r=0;r<12;r++)for(let c=1;c<=3;c++){const n=r*3+c;g+=rlCell('n',n,String(n),'rl-'+rlCol(n))}
 return `<div class="rl-board" id="rl_board">${rlCell('n',0,'0','rl-g rl-zero')}<div class="rl-grid">${g}</div><div class="rl-cols">${[1,2,3].map(v=>rlCell('col',v,'2:1','rl-o',`${v}-ე სვეტი, 2:1`)).join('')}</div>
 <div class="rl-doz">${[1,2,3].map(v=>rlCell('dozen',v,['1–12','13–24','25–36'][v-1],'rl-o',['1–12','13–24','25–36'][v-1])).join('')}</div>
 <div class="rl-outs">${RL_OUT.map(([t,,l])=>rlCell(t,0,t==='red'?'<i class="rl-dia r"></i>':t==='black'?'<i class="rl-dia b"></i>':l,'rl-o rl-'+t,t==='red'?'წითელი':t==='black'?'შავი':l)).join('')}</div></div>`}
function rlChips(){const i=CSN.info||{},lo=i.min_bet||10,hi=i.max_bet||500,vs=RL_CHIPS.map(c=>c[0]).filter(v=>v<=hi);if(!vs.includes(RLT.chip))RLT.chip=vs.find(v=>v>=lo)||vs[0];
 return vs.map(v=>`<button type="button" class="rl-pick${v===RLT.chip?' on':''}" data-a="rlchip" data-v="${v}" aria-pressed="${v===RLT.chip}" aria-label="ჩიპი ${v}">${rlChipHTML(v)}</button>`).join('')}
const rlHist=()=>RLT.hist.slice(0,16).map((n,k)=>`<span class="rl-h rl-${rlCol(n)}${k?'':' new'}">${n}</span>`).join('')||'<small>ჯერ არ დაგიტრიალებია</small>';
PG.roulette={r(){RLT.spin=null;csPage('roulette','რულეტკა',rlDraw,{cls:'rl-pg'})},g3(){if($('.rl-stage'))rlStage()}};
function rlDraw(el,i){RLT.busy=false;
 el.innerHTML=`<div class="rl-stage" id="rl_st"><div class="rl-view" id="rl_view"></div><div class="rl-res" id="rl_res" aria-live="polite"></div><div class="rl-hist" id="rl_hist">${rlHist()}</div></div>
 <div class="rl-picks" role="group" aria-label="ჩიპი">${rlChips()}</div>
 ${rlBoard()}
 <div class="rl-bar"><div class="rl-tools"><button class="rl-tb" data-a="rlundo" aria-label="ბოლოს დადებულის მოხსნა">${ic('reply')}<small>უკან</small></button><button class="rl-tb" data-a="rlclear" aria-label="გასუფთავება">${ic('trash')}<small>მოხსნა</small></button><button class="rl-tb" data-a="rlagain" aria-label="იგივე ფსონი">${ic('turn')}<small>იგივე</small></button><button class="rl-tb" data-a="rldbl" aria-label="გაორმაგება"><b>×2</b><small>ორჯერ</small></button></div>
  <span class="rl-sum"><small>ჯამში</small><b id="rl_tot">${nf(rlTot())}</b></span><button class="rl-go" id="rl_go" data-a="rlspin">ტრიალი</button></div>
 ${csDayHTML(i)}`;
 rlStage();rlTools();
 rpc('casino_mine',{p_game:'roulette'}).then(rows=>{RLT.hist=(rows||[]).map(x=>x.d&&x.d.n).filter(n=>n!=null);const h=$('#rl_hist');if(h)h.innerHTML=rlHist();if(!RLT.ball&&RLT.hist.length){RLT.ball={phi:RL_ORDER.indexOf(RLT.hist[0])*RL_A,r:0,h:0};rlKickFrame()}}).catch(()=>{})}
/* the wheel: the 3D scene when it can be had, the flat one until then */
function rlStage(){const v=$('#rl_view');if(!v)return;if(csG3Ready()){v.className='rl-view is3d';if(!$('.g3',v))v.innerHTML='<div class="g3 g3-csrl"></div>';csG3Show('csrl');return}
 v.className='rl-view';if(!$('.rl-wheel',v))v.innerHTML=rlWheel();rlKickFrame();csG3Kick('roulette')}
function rlRefresh(){const b=$('#rl_board');if(b)b.outerHTML=rlBoard();const t=$('#rl_tot');if(t)t.textContent=nf(rlTot());rlTools()}
function rlTools(){const has=rlTot()>0,can=!!RLT.last&&!has;const set=(a,on)=>{const b=$(`[data-a="${a}"]`);if(b)b.disabled=!on||RLT.busy};set('rlundo',RLT.undo.length>0);set('rlclear',has);set('rlagain',can);set('rldbl',has);const g=$('#rl_go');if(g)g.disabled=RLT.busy}
A.rlchip=t=>{RLT.chip=+t.dataset.v;store.set('rlchip',RLT.chip);$$('.rl-pick').forEach(b=>{const on=+b.dataset.v===RLT.chip;b.classList.toggle('on',on);b.setAttribute('aria-pressed',String(on))});csSnd('chip',.5)};
const rlMax=()=>(CSN.info||{}).max_bet||500;
A.rlbet=t=>{if(RLT.busy)return;const k=rlKey(t.dataset.t,t.dataset.v);if(rlTot()+RLT.chip>rlMax()){toast(`ერთ ტრიალზე მაქსიმუმ ${nf(rlMax())} მონეტა`);return}
 RLT.bets[k]=(RLT.bets[k]||0)+RLT.chip;RLT.undo.push([k,RLT.chip]);$$('.rl-hit').forEach(x=>x.classList.remove('rl-hit'));csSnd('chip');gBuzz(6);rlRefresh()};
A.rlundo=()=>{if(RLT.busy)return;const u=RLT.undo.pop();if(!u)return;RLT.bets[u[0]]-=u[1];if(RLT.bets[u[0]]<=0)delete RLT.bets[u[0]];csSnd('chip',.4);rlRefresh()};
A.rlclear=()=>{if(RLT.busy)return;RLT.bets={};RLT.undo=[];rlRefresh()};
A.rlagain=()=>{if(RLT.busy||!RLT.last)return;const tot=Object.values(RLT.last).reduce((a,b)=>a+b,0);if(tot>rlMax()){toast(`ერთ ტრიალზე მაქსიმუმ ${nf(rlMax())} მონეტა`);return}RLT.bets={...RLT.last};RLT.undo=Object.entries(RLT.bets);csSnd('chip');rlRefresh()};
A.rldbl=()=>{if(RLT.busy)return;const tot=rlTot();if(tot*2>rlMax()){toast(`ერთ ტრიალზე მაქსიმუმ ${nf(rlMax())} მონეტა`);return}for(const k in RLT.bets){RLT.undo.push([k,RLT.bets[k]]);RLT.bets[k]*=2}csSnd('chip');rlRefresh()};
A.rlspin=async t=>{if(RLT.busy||RLT.spin)return;const tot=rlTot(),lo=(CSN.info||{}).min_bet||10;if(!tot){toast('ჯერ დადე ფსონი: შეეხე რიცხვს ან ველს');return}
 if(tot<lo){toast(`მინიმუმ ${nf(lo)} მონეტა`);return}if((ME.coins||0)<tot){toast('მონეტები არ გყოფნის');return}
 const bets=Object.entries(RLT.bets).map(([k,a])=>{const[t,v]=k.split(':');return {t,v:+v,a}});
 RLT.busy=true;rlTools();$('#rl_st').classList.add('busy');const res=$('#rl_res');res.className='rl-res';res.innerHTML='';$('#csp').scrollTo({top:0,behavior:RM()?'auto':'smooth'});
 let r;try{r=await rpc('roulette_spin',{p_bets:bets})}catch(e){RLT.busy=false;rlTools();$('#rl_st')?.classList.remove('busy');toast(errMsg(e));return}
 csBalShow(r.coins-r.win);RLT.last={...RLT.bets};
 const i=RL_ORDER.indexOf(r.n),T=RM()?400:7600,now=performance.now(),cur=rlNow(now);RLT.ball=null;
 /* the ball's turn ends on the pocket: P in the wheel's frame; D is how much it runs before, eight turns and a bit */
 RLT.spin={t0:now,T,rot0:cur.rot,w:RM()?0:34,P:i*RL_A,D:360*8+Math.random()*120,hk:-1,tk:null,done:()=>rlLanded(r,tot)};csSnd('reel',.4);rlKickFrame()};
function rlLanded(r,tot){RLT.busy=false;const st=$('#rl_st');if(!st)return;st.classList.remove('busy');csAfter(r.coins,r.bet);RLT.hist.unshift(r.n);$('#rl_hist').innerHTML=rlHist();
 const c=rlCol(r.n),res=$('#rl_res');res.className='rl-res show '+(r.win>0?'win':'lose');
 res.innerHTML=`<span class="rl-n rl-${c}">${r.n}</span><span class="rl-rt"><small>${c==='g'?'ნული':c==='r'?'წითელი':'შავი'}${r.n?` · ${r.n%2?'კენტი':'ლუწი'}`:''}</small><b>${r.win>0?`+${nf(r.win)}`:'ამჯერად არა'}</b></span>`;
 $$(`#rl_board [data-t="n"][data-v="${r.n}"]`).forEach(x=>x.classList.add('rl-hit'));
 csWin(r.coins,r.bet,r.win,$('#rl_res'));
 /* the chips leave the felt after a moment; the same bet is one tap away */
 setTimeout(()=>{if(!$('#rl_board')||RLT.busy)return;RLT.bets={};RLT.undo=[];rlRefresh();$$(`#rl_board [data-t="n"][data-v="${r.n}"]`).forEach(x=>x.classList.add('rl-hit'))},RM()?400:2600)}

/* ---------- blackjack: you against the dealer ---------- */
const BJ={r:null,busy:false,seen:{p:0,d:0,open:false},shown:null};
const BJ_SUIT={S:'♠',H:'♥',D:'♦',C:'♣'};
const BJ_END={bust:['გადააჭარბე 21-ს','lose'],dbj:['დილერს ბლექჯეკი აქვს','lose'],lose:['დილერმა მოიგო','lose'],bj:['ბლექჯეკი!','win'],dbust:['დილერმა გადააჭარბა','win'],win:['შენ მოიგე','win'],push:['ფრე: ფსონი დაგიბრუნდა','push']};
PG.bj={r(){csPage('bj','ბლექჯეკი',bjDraw,{cls:'bj-pg'})},g3(){if($('#bj_tbl'))bjStage()}};
function bjCard(c,i,o={}){const back=`<i class="bj-face bj-back"></i>`;if(!c)return `<span class="bj-card down${o.nw?' nw':''}" style="--i:${i}">${back}<i class="bj-face bj-front"></i></span>`;const rk=c.slice(0,-1),s=c.slice(-1),red=s==='H'||s==='D';
 return `<span class="bj-card${red?' red':''}${o.nw?' nw':''}${o.flip?' flip':''}" style="--i:${i}" aria-label="${rk}${BJ_SUIT[s]}"><i class="bj-face bj-front"><b>${rk}</b><em>${BJ_SUIT[s]}</em><strong>${/[JQK]/.test(rk)?rk:BJ_SUIT[s]}</strong><b class="br">${rk}</b></i>${back}</span>`}
async function bjDraw(el,i){BJ.r=null;BJ.busy=false;BJ.seen={p:0,d:0,open:false};
 el.innerHTML=`<div class="bj-tbl" id="bj_tbl"><div class="bj-view" id="bj_view"></div>
  <div class="bj-over"><span class="bj-tag" id="bj_dt" hidden><small>დილერი</small><b id="bj_dv"></b></span><div class="bj-msg" id="bj_msg" aria-live="polite"></div><span class="bj-tag me" id="bj_pt" hidden><small>შენ</small><b id="bj_pv"></b></span></div></div>
 <div class="bj-ctl" id="bj_ctl"></div>${csDayHTML(i)}
 <section class="cs-card"><h3>წესები მოკლედ</h3><p class="note">შეაგროვე 21-თან ახლოს, ოღონდ არ გადააჭარბო. სურათიანი კარტი 10-ია, ტუზი 1 ან 11. ბლექჯეკი (ტუზი და 10) იხდის 3:2-ს, მოგება 1:1-ს. დილერი 17-მდე იღებს. გაორმაგება პირველ ორ კარტზეა: ფსონი ორდება და ერთ კარტს იღებ.</p></section>`;
 bjStage();bjCtl();bjMsg('დადე ფსონი და დაარიგე');
 try{const o=await q(sb.from('casino_rounds').select('id,bet').eq('game','bj').eq('state','open').order('id',{ascending:false}).limit(1));if(o&&o[0]&&$('#bj_tbl')){BJ.r=await rpc('bj_deal',{p_bet:o[0].bet});bjShow(true)}}catch(e){}}
/* the table: the 3D lounge when it can be had, the flat felt until then */
function bjStage(){const v=$('#bj_view');if(!v)return;if(csG3Ready()){v.className='bj-view is3d';if(!$('.g3',v))v.innerHTML='<div class="g3 g3-csbj"></div>';$('#bj_tbl').classList.add('is3d');csG3Show('csbj');return}
 $('#bj_tbl').classList.remove('is3d');v.className='bj-view';if(!$('.bj-felt',v)){v.innerHTML=`<div class="bj-felt"><svg class="bj-arc" viewBox="0 0 300 80" aria-hidden="true"><path id="bjarc" d="M20 70Q150 -10 280 70" fill="none"/><text><textPath href="#bjarc" startOffset="50%" text-anchor="middle">ბლექჯეკი იხდის 3:2 · დილერი ჩერდება 17-ზე</textPath></text></svg>
  <i class="bj-shoe" aria-hidden="true"></i><div class="bj-hand d" id="bj_d"></div><div class="bj-hand p" id="bj_p"></div><div class="bj-spot" id="bj_spot"></div></div>`;BJ.seen={p:0,d:0,open:false}}bjFlat(true);csG3Kick('bj')}
function bjCtl(){const c=$('#bj_ctl');if(!c)return;const r=BJ.r,open=r&&r.state==='open';
 c.innerHTML=open?`<button class="bj-b" data-a="bjact" data-k="hit"><b>კიდევ</b><small>კარტი</small></button><button class="bj-b gold" data-a="bjact" data-k="stand"><b>გაჩერება</b><small>საკმარისია</small></button>${r.p.length===2&&(ME.coins||0)>=r.bet?`<button class="bj-b blue" data-a="bjact" data-k="double"><b>×2</b><small>გაორმაგება</small></button>`:''}`
  :`${csBetHTML('bj')}<button class="bj-deal" data-a="bjdeal">${r?'ახალი დარიგება':'დარიგება'}</button>`;
 c.querySelectorAll('button').forEach(b=>{if(!b.classList.contains('cs-step'))b.disabled=BJ.busy});c.classList.toggle('busy',BJ.busy)}
function bjMsg(html,cls){const m=$('#bj_msg');if(!m)return;m.className='bj-msg'+(cls?' '+cls:'');m.innerHTML=html}
/* the flat table follows the round: new cards fly from the shoe, the face-down one turns over at the end */
function bjFlat(resume){const r=BJ.r,P=$('#bj_p'),D=$('#bj_d'),sp=$('#bj_spot');if(!P||!D)return;if(!r){P.innerHTML='';D.innerHTML='';sp.innerHTML='';return}
 const open=r.state==='open',dc=open?[r.d[0],null]:r.d,S0=BJ.seen;
 P.innerHTML=r.p.map((c,k)=>bjCard(c,k,{nw:!resume&&k>=S0.p})).join('');
 D.innerHTML=dc.map((c,k)=>bjCard(c,k,{nw:!resume&&k>=S0.d,flip:!resume&&!open&&k===1&&S0.open})).join('');
 sp.innerHTML=`<span class="bj-stack">${bjChips(r.bet)}</span>${!open&&r.win>r.bet?`<span class="bj-stack won">${bjChips(r.win-r.bet)}</span>`:''}`}
const bjChips=v=>{const out=[];for(const[d]of RL_CHIPS.slice().reverse()){while(v>=d&&out.length<9){out.push(d);v-=d}}return out.reverse().map((d,k)=>rlChipHTML(d,'st','--k:'+k)).join('')};
function bjShow(resume){const r=BJ.r;if(!r||!$('#bj_tbl'))return;const open=r.state==='open';
 if(csG3Ready()&&$('#bj_view .g3'))csG3Show('csbj');else bjFlat(resume);
 if(!resume&&r.p.length>BJ.seen.p)csSnd(r.p.length-BJ.seen.p>1?'deal':'card');if(!resume&&!open&&BJ.seen.open)setTimeout(()=>csSnd('flip'),350);
 BJ.seen={p:r.p.length,d:open?1:r.d.length,open};
 const dt=$('#bj_dt'),pt=$('#bj_pt');dt.hidden=pt.hidden=false;$('#bj_pv').textContent=r.pv;$('#bj_dv').textContent=open?r.dv:r.dv;dt.classList.toggle('hid',open);
 pt.classList.toggle('bust',r.pv>21);pt.classList.toggle('bj',r.pv===21);
 if(open)bjMsg(r.dbl?'გაორმაგდა':'');
 else{const[t,k]=BJ_END[r.end]||['',''];bjMsg(`<b>${t}</b>${r.win>0&&r.end!=='push'?`<em>+${nf(r.win)}</em>`:''}`,k);
  if(k==='win')csWin(r.coins,r.bet,r.win,$('#bj_msg'));else{csTrack(r.bet,r.win);csBalTo(r.coins);setCoins(r.coins);if(k==='lose')csSnd('lose',.5)}}
 bjCtl()}
A.bjdeal=async()=>{if(BJ.busy)return;const bet=csBet('bj');if((ME.coins||0)<bet){toast('მონეტები არ გყოფნის');return}
 BJ.busy=true;BJ.r=null;BJ.seen={p:0,d:0,open:false};if(!csG3Ready())bjFlat();else csG3Show('csbj');bjMsg('');bjCtl();csSnd('chip');csBalShow((ME.coins||0)-bet);
 try{BJ.r=await rpc('bj_deal',{p_bet:bet});BJ.busy=false;csAfter(BJ.r.coins,bet);bjShow()}catch(e){BJ.busy=false;csBalShow(ME.coins||0);bjCtl();toast(errMsg(e))}};
A.bjact=async t=>{if(BJ.busy||!BJ.r)return;const k=t.dataset.k;BJ.busy=true;bjCtl();const before=BJ.r.bet;if(k==='double'){csSnd('chip');csBalShow(CSN.bal-before)}
 try{BJ.r=await rpc('bj_act',{p_round:BJ.r.id,p_act:k});BJ.busy=false;if(k==='double')csAfter(BJ.r.coins,before);bjShow()}catch(e){BJ.busy=false;bjCtl();toast(errMsg(e))}};
