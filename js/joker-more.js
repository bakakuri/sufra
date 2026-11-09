/* joker, the comforts around the game: the hand in a sensible order, the single possible move made by itself,
   the joker's call close to the card (one movement: press the joker, slide onto the call, let go),
   a look back at the hand just played, trick by trick, and this phone's joker statistics.
   For the game against the computer and the table with friends alike */

/* ---------- the hand in order ----------
   trump first, then the other suits with their colours taking turns (black, red, black…), high to low within a suit,
   the jokers in front. Or as before: always the same order of suits, low to high. Or by strength across the suits */
const JKSORTN={trump:'კოზირი წინ',suit:'ფრებად',rank:'ძალით'},JKSORTD={trump:'კოზირი წინ, დანარჩენი ფრები ფერების მონაცვლეობით, თითოეულში უმაღლესიდან',suit:'ფრებად, ყოველთვის ერთი რიგით (ყვავი, ჯვარი, გული, აგური), დაბლიდან',rank:'ძალით: უმაღლესიდან, ფრის მიუხედავად'};
const jSortSet=()=>{const v=store.get('jksort','trump');return JKSORTN[v]?v:'trump'};
const JRED={h:1,d:1};
function jSuitOrder(h,trump){const have=SUITS.filter(s=>h.some(c=>!c.j&&c.s===s)),out=[];if(trump&&have.includes(trump))out.push(trump);
 let rest=have.filter(s=>s!==trump);while(rest.length){const last=out[out.length-1],k=rest.findIndex(s=>last==null||!!JRED[s]!==!!JRED[last]),pick=rest[k<0?0:k];out.push(pick);rest=rest.filter(s=>s!==pick)}return out}
function jSortHand(h,trump){if(!Array.isArray(h)||h.length<2)return h;const m=jSortSet();
 if(m==='suit')return sortHand(h);
 if(m==='rank')return h.sort((a,b)=>(b.j?99:b.r)-(a.j?99:a.r)||(a.j?a.j:SUITS.indexOf(a.s))-(b.j?b.j:SUITS.indexOf(b.s)));
 const ord=jSuitOrder(h,trump);return h.sort((a,b)=>(a.j?-10+a.j:ord.indexOf(a.s)*20+(14-a.r))-(b.j?-10+b.j:ord.indexOf(b.s)*20+(14-b.r)))}
A.jksortm=()=>{const cur=jSortSet();navMark('jksortm',()=>A.jksortm());sheet(head('კარტების დალაგება')+`<div class="gmenu">${Object.keys(JKSORTN).map(k=>`<button data-a="jksortset" data-v="${k}"${k===cur?' aria-pressed="true"':''}>${ic(k===cur?'check':'cards')}<span><b>${JKSORTN[k]}</b><br><small class="muted">${JKSORTD[k]}</small></span></button>`).join('')}</div>`,'short')};
A.jksortset=t=>{store.set('jksort',JKSORTN[t.dataset.v]?t.dataset.v:'trump');closeSheet();gRedraw()};

/* ---------- the only possible move, made by itself ----------
   one card that may be played (not a joker: that needs its call), or one number the dealer may say. A short pause first, so it is seen */
const jAuto1On=()=>store.get('jkauto1',true)!==false;
A.jkauto1=t=>{const on=!jAuto1On();store.set('jkauto1',on);gSwFlip(t,on);if(on)gRedraw()};
const jOnlyBid=(n,f)=>{const o=[];for(let v=0;v<=n;v++)if(v!==f)o.push(v);return o.length===1?o[0]:null};
function jAuto1Note(){const el=$('.gx .status');if(el){el.classList.remove('g3sr');el.textContent='ერთადერთი შესაძლო სვლაა, თავისით კეთდება…'}}
function jAuto1(G){if(!jAuto1On()||G!==JK||G.cur!==0||G.win!=null||!G.hands)return;let key=null,go=null;
 if(G.phase==='play'){const L=G.legal(0);if(L.length===1&&!L[0].j){const c=L[0];key='p'+G.tk+':'+G.h+':'+G.hands[0].length+':'+G.trick.length;go=()=>{if(G.phase==='play'&&G.cur===0&&G.win==null&&G.hands[0].includes(c)&&G.legal(0).length===1)G.playCard(0,c)}}}
 else if(G.phase==='bid'&&G.bids[0]===null){const v=jOnlyBid(G.n,G.forbidden(0));if(v!=null){key='b'+G.tk+':'+G.h;go=()=>{if(G.phase==='bid'&&G.cur===0&&G.bids[0]===null)G.bid(0,v)}}}
 if(!key)return;if(G.a1!==key){G.a1=key;G.later(go,950)}jAuto1Note()}
function joAuto1(){const s=JO.st,me=JO.seat;if(!jAuto1On()||!s||me<0||s.cur!==me||s.win!=null||JO.wait)return;let key=null,go=null;
 if(s.phase==='play'){const L=JK.legal.call({hands:{[me]:JO.hand},trick:s.trick||[],trump:s.trump},me);if(L.length===1&&!L[0].j){const c=L[0];key='p'+JO.id+':'+s.deal+':'+JO.hand.length+':'+(s.trick||[]).length;
  go=()=>{const t=JO.st;if(t&&t.phase==='play'&&t.cur===me&&t.win==null&&!JO.wait&&JO.hand.some(x=>joSame(x,c)))joSend({k:'card',c:{s:c.s,r:c.r}})}}}
 else if(s.phase==='bid'&&s.bids&&s.bids[me]==null){const v=jOnlyBid(s.n,JK.forbidden.call({dealer:s.dealer,n:s.n,bids:s.bids},me));if(v!=null){key='b'+JO.id+':'+s.deal;go=()=>{const t=JO.st;if(t&&t.phase==='bid'&&t.cur===me&&!JO.wait)joSend({k:'bid',v})}}}
 if(!key)return;if(JO.a1!==key){JO.a1=key;clearTimeout(JO.a1t);JO.a1t=setTimeout(go,950)}jAuto1Note()}

/* ---------- the joker's call, at the card ----------
   a small panel just over the card (over the hand in 3D) with the calls as big buttons. A touch on the joker opens it, a touch on a call plays.
   Or in one movement: press the joker, slide onto the call, let go. Back closes it, as any sheet */
const jPickOpen=()=>!!$('#sheet .panel.jkpick');
function jkJokerPick(lead,a,from){const el=from&&from.nodeType===1?from:null;
 const sb=m=>SUITS.map(s=>`<button class="jpsu${isRed(s)?' red':''}" data-a="${a}" data-m="${m}" data-s="${s}" aria-label="${m==='hi'?'მაღალი':'წაიღოს'}, ${SN[s]}">${SY[s]}</button>`).join('');
 const html=lead?`<div class="jpk lead" role="group" aria-label="ჯოკერის თქმა"><div class="jprow"><span class="jpl"><b>მაღალი</b><small>ვითხოვ უმაღლესს, ვიღებ</small></span><span class="jps">${sb('hi')}</span></div>
   <div class="jprow"><span class="jpl"><b>წაიღოს</b><small>ამ ფრის უმაღლესმა</small></span><span class="jps">${sb('lo')}</span></div></div>`
  :`<div class="jpk" role="group" aria-label="ჯოკერის თქმა"><button class="jpb hi" data-a="${a}" data-m="hi"><b>მაღალი</b><small>წაიღებს ხელს</small></button><button class="jpb lo" data-a="${a}" data-m="lo"><b>დაბალი</b><small>არ წაიღებს</small></button></div>`;
 sheet(html,'jkpick gclear');const p=$('#sheet .panel.jkpick');if(!p)return;
 /* over the card, centred on it, kept on the screen; without a card (3D), over the middle of the hand */
 const W=p.offsetWidth,H=p.offsetHeight,vw=innerWidth,vh=innerHeight,r=el?el.getBoundingClientRect():null;
 const x=Math.max(8,Math.min(vw-W-8,(r?r.left+r.width/2:vw/2)-W/2)),y=Math.max(8,(r?r.top:vh*.72)-H-12);p.style.left=x+'px';p.style.top=y+'px'}
/* one movement: pressing a joker that may be played and sliding up opens the calls; letting go on one plays it */
const JPK={id:null,x:0,y:0,open:false,on:null};
document.addEventListener('pointerdown',e=>{const b=e.target.closest&&e.target.closest('.gx .hand button.card.jk:not([disabled])');if(!b)return;JPK.id=e.pointerId;JPK.x=e.clientX;JPK.y=e.clientY;JPK.open=false;JPK.on=null;JPK.b=b},true);
document.addEventListener('pointermove',e=>{if(JPK.id!==e.pointerId)return;
 if(!JPK.open){if(JPK.y-e.clientY<14&&Math.abs(e.clientX-JPK.x)<24)return;JPK.open=true;const b=JPK.b;if(b&&b.isConnected)b.click();if(!jPickOpen()){JPK.id=null;return}}
 const t=document.elementFromPoint(e.clientX,e.clientY),o=t&&t.closest&&t.closest('#sheet .panel.jkpick [data-a]');if(o!==JPK.on){if(JPK.on)JPK.on.classList.remove('on');JPK.on=o;if(o){o.classList.add('on');try{navigator.vibrate&&GS.on&&navigator.vibrate(8)}catch(x){}}}},true);
const jpkUp=e=>{if(JPK.id!==e.pointerId)return;JPK.id=null;const o=JPK.on;JPK.on=null;if(o){o.classList.remove('on');if(e.type==='pointerup'){const a=o.dataset.a;if(A[a])A[a](o)}}};
document.addEventListener('pointerup',jpkUp,true);document.addEventListener('pointercancel',jpkUp,true);

/* ---------- the hand just played, trick by trick ----------
   R = {n, trump, dealer, bids, taken, tricks:[{t:[{p,card,jm,js}], w}], hand (its line in the score sheet), prem} */
function jRevHTML(R,nm,base){if(!R)return '<p class="note">ჯერ არცერთი ხელი არ დასრულებულა.</p>';const P=[0,1,2,3].map(k=>(base+k)%4),h=R.hand,pr=R.prem;
 const sum=P.map(p=>{const b=R.bids&&R.bids[p],t=R.taken&&R.taken[p],x=h?h.p[p]+(pr?pr.p[p]:0):null,ok=b===t,kh=b>0&&t===0;
  return `<div class="jrv-p${p===base?' me':''}"><b>${esc(nm(p))}${p===R.dealer?' <i class="jdl" title="დამრიგებელი">დ</i>':''}</b><span>თქვა ${b===0?'პასი':b??'—'} · წაიღო ${t??'—'}</span>${x!=null?`<span class="jres ${ok?'ok':kh?'kh':'no'}">${ok?'✓':'✗'} ${x>0?'+':x<0?'−':''}${Math.abs(x)}</span>`:''}</div>`}).join('');
 const tr=(R.tricks||[]).map((T,k)=>T?`<li class="jrv-t"><em>${k+1}</em><span class="jrv-cs">${T.t.map(e=>`<span class="jrv-c${e.p===T.w?' w':''}${e.p===base?' me':''}">${jCardHTML(e.card)}<small>${esc(String(nm(e.p)).split(' ')[0])}</small>${e.card.j?`<i>${jmTxt(e)}</i>`:''}</span>`).join('')}</span><span class="jrv-w">${esc(String(nm(T.w)).split(' ')[0])}</span></li>`:`<li class="jrv-t miss"><em>${k+1}</em><span class="note">ეს ხელი ამ ეკრანზე არ ჩანდა</span></li>`).join('');
 return `<p class="note jrv-h">${R.n} კარტი · ${R.trump?`კოზირი <b style="color:${suitInk(R.trump)}">${SY[R.trump]} ${SN[R.trump]}</b>`:'უკოზირო'}</p><div class="jrv-sum">${sum}</div>
  ${tr?`<h4 class="gvh">ხელები, ჩამოსვლის რიგით</h4><ol class="jrv-ts">${tr}</ol><p class="note">ოქროსფერი ჩარჩო: ვინც ხელი წაიღო.</p>`:'<p class="note">ამ ხელის სვლები ამ ეკრანზე არ ჩანდა.</p>'}`}
function jRevOpen(R,nm,base,key){navMark(key,()=>jRevOpen(R,nm,base,key));
 sheet(head('ხელის მიმოხილვა')+`<div class="ph-body">${jRevHTML(R,nm,base)}</div>`,'jrvp',()=>{if(JK.revWait&&JK.phase==='handover'){JK.revWait=0;JK.later(()=>JK.nextHand(),500)}})}
A.jrev=()=>jRevOpen(JK.rev,p=>p===0?'შენ':JK.nm(p),0,'jrev');
A.jkorev=()=>jRevOpen(JO.rev,p=>p===JO.seat?'შენ':joShort(p),JO.seat>=0?JO.seat:0,'jkorev');
/* the buttons under the final result: the last hand, and the statistics */
const jEndBtns=rv=>`<div class="jkacts jend">${rv?`<button class="btn ghost sm" data-a="${rv}">${ic('cards')}ბოლო ხელი</button>`:''}<button class="btn ghost sm" data-a="jstat">${ic('chart')}სტატისტიკა</button></div>`;
/* online: each screen keeps the tricks of the deal as it sees them, and the review of the hand once it ends */
function joTrk(s){if(!s||s.deal==null)return;if(!JO.trk||JO.trk.deal!==s.deal)JO.trk={deal:s.deal,list:[]};const T=JO.trk;T.n=s.n;T.trump=s.trump;T.dealer=s.dealer;if(s.bids)T.bids=s.bids.slice();
 if(s.trick&&s.trick.length===4&&s.win!=null&&s.taken){const i=s.taken.reduce((a,x)=>a+(x||0),0)-1;if(i>=0)T.list[i]={t:s.trick.map(e=>Object.assign({},e)),w:s.win}}
 if((s.phase==='handover'||s.phase==='over')&&s.hist&&s.hist.length&&(!JO.rev||JO.rev.deal!==s.deal)){const{hand,prem}=jLast(s.hist);
  const n=s.n||0,list=Array.from({length:n},(_,i)=>T.list[i]||null);JO.rev={deal:s.deal,n,trump:T.trump,dealer:T.dealer,bids:(T.bids||s.bids||[]).slice(),taken:(s.taken||[]).slice(),tricks:list.some(Boolean)?list:[],hand,prem};
  if(JO.seat>=0)jkStatHandOnce('jkst-'+JO.id+'-'+s.deal,JO.rev,JO.seat)}}

/* ---------- statistics, kept on this phone ----------
   games, wins, places, hands, bids made exactly, ხიშტი, premiums, the best and the average score; against the computer and online */
const JKST0=()=>({g:0,w:0,pl:[0,0,0,0],h:0,ex:0,kh:0,pr:0,best:null,sum:0,bot:0,on:0,bids:0,took:0});
const jkStat=()=>{const v=store.get('jkstat',null);return v&&typeof v==='object'?Object.assign(JKST0(),v):JKST0()};
function jkStatHand(R,me){if(!R||!R.hand)return;const S0=jkStat(),b=R.bids[me],t=R.taken[me];S0.h++;if(b===t)S0.ex++;if(b>0&&t===0)S0.kh++;if(R.prem&&R.prem.p[me]>0)S0.pr++;S0.bids+=b||0;S0.took+=t||0;store.set('jkstat',S0)}
function jkStatHandOnce(k,R,me){try{if(localStorage.getItem(k))return;localStorage.setItem(k,'1')}catch(e){}jkStatHand(R,me)}
function jkStatGame(score,me,online){const S0=jkStat(),x=score[me],place=score.filter(v=>v>x).length;S0.g++;if(place===0)S0.w++;S0.pl[Math.min(3,place)]++;S0.sum+=x;S0.best=S0.best==null?x:Math.max(S0.best,x);if(online)S0.on++;else S0.bot++;store.set('jkstat',S0)}
function jkStatHTML(){const s=jkStat();if(!s.g&&!s.h)return '<p class="note">ჯერ ცარიელია. ითამაშე ჯოკერი ბოტებთან ან მეგობრებთან და აქ გამოჩნდება, როგორ თამაშობ.</p>';
 const pct=(a,b)=>b?Math.round(a/b*100)+'%':'—',avgPl=s.g?(s.pl.reduce((a,n,i)=>a+n*(i+1),0)/s.g).toFixed(1):'—',mx=Math.max(1,...s.pl);
 const tile=(v,t)=>`<div class="jst-t"><b>${v}</b><span>${t}</span></div>`;
 return `<div class="jst-g">${tile(s.g,'თამაში')}${tile(s.g?`${s.w} <small>${pct(s.w,s.g)}</small>`:'—','მოგება')}${tile(avgPl,'საშუალო ადგილი')}${tile(pct(s.ex,s.h),'ზუსტი ნათქვამი')}${tile(s.kh,'ხიშტი')}${tile(s.pr,'სექციის პრემია')}${tile(s.best??'—','საუკეთესო ქულა')}${tile(s.g?Math.round(s.sum/s.g):'—','საშუალო ქულა')}</div>
  ${s.g?`<h4 class="gvh">ადგილები</h4><div class="jst-pl">${s.pl.map((n,i)=>`<div class="jst-b"><span class="jst-bar" style="--h:${(n/mx*100).toFixed(0)}%"><i></i></span><b>${n}</b><small>${i+1}-ლი</small></div>`).join('')}</div>`:''}
  <p class="note">${s.h} ხელი${s.h?`, ნათქვამი საშუალოდ ${(s.bids/s.h).toFixed(1)}, წაღებული ${(s.took/s.h).toFixed(1)}`:''}. ${s.bot} თამაში ბოტებთან, ${s.on} ონლაინ. ითვლება ამ ტელეფონზე.</p>
  <div class="jkacts"><button class="btn ghost sm" data-a="jstatreset">${ic('turn')}თავიდან დათვლა</button></div>`}
A.jstat=()=>{navMark('jstat',()=>A.jstat());sheet(head('ჯოკერის სტატისტიკა')+`<div class="ph-body jst">${jkStatHTML()}</div>`,'short')};
A.jstatreset=()=>confirmSheet('სტატისტიკის განულება','ჯოკერის სტატისტიკა ამ ტელეფონზე თავიდან დაითვლება.','განულება',()=>{store.set('jkstat',null);A.jstat()},true);
