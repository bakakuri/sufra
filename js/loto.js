/* ---------- lotto (ლოტო): tickets of 3 rows and 9 columns, 15 numbers each, numbers 1 to 90 drawn from a bag ----------
   the caller draws a barrel every few seconds and says the number; you mark it on your tickets. the first to fill a row
   (or a whole ticket, in the long game) calls ლოტო and wins. against the computer's players, or with friends at a table */
const LOTO_NICK={1:'კოლი',11:'ჯოხები',22:'იხვები',33:'კაკლები',44:'სკამები',55:'ხელთათმანები',66:'ჩამოკიდებული',69:'ზევით-ქვევით',77:'ნაჯახები',88:'ბებიის სათვალე',90:'ბაბუა'};
const KA1=['','ერთი','ორი','სამი','ოთხი','ხუთი','ექვსი','შვიდი','რვა','ცხრა','ათი','თერთმეტი','თორმეტი','ცამეტი','თოთხმეტი','თხუთმეტი','თექვსმეტი','ჩვიდმეტი','თვრამეტი','ცხრამეტი'];
const KA20=['','ოც','ორმოც','სამოც','ოთხმოც'];
/* Georgian counts in twenties: 47 is ორმოცდაშვიდი, two twenties and seven */
function numKa(n){if(n<20)return KA1[n];const t=Math.floor(n/20),r=n%20;if(!r)return KA20[t]+'ი';return KA20[t]+'და'+KA1[r]}
/* a ticket: each row has five numbers, every column at least one; column c holds c·10 to c·10+9 (1–9 and 80–90 at the ends) */
function lotoTicket(rng){for(let tries=0;tries<500;tries++){
  const rows=[0,1,2].map(()=>{const c=[...Array(9).keys()];for(let i=8;i>0;i--){const j=Math.floor(rng()*(i+1));[c[i],c[j]]=[c[j],c[i]]}return c.slice(0,5)});
  const cnt=Array(9).fill(0);rows.forEach(r=>r.forEach(c=>cnt[c]++));if(cnt.some(x=>!x))continue;
  const g=[0,1,2].map(()=>Array(9).fill(0));
  for(let c=0;c<9;c++){const lo=c?c*10:1,hi=c===8?90:c*10+9,pool=[];for(let v=lo;v<=hi;v++)pool.push(v);for(let i=pool.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[pool[i],pool[j]]=[pool[j],pool[i]]}
   const take=pool.slice(0,cnt[c]).sort((a,b)=>a-b);let k=0;for(let r=0;r<3;r++)if(rows[r].includes(c))g[r][c]=take[k++]}
  return g}return null}
const lotoBag=rng=>{const b=[];for(let v=1;v<=90;v++)b.push(v);for(let i=89;i>0;i--){const j=Math.floor(rng()*(i+1));[b[i],b[j]]=[b[j],b[i]]}return b};
const lotoNums=g=>g.flat().filter(Boolean);
/* how many numbers still missing: in the best row (short game) or in the whole ticket (long game) */
function lotoLeft(g,has,mode){if(mode==='full')return lotoNums(g).filter(v=>!has(v)).length;return Math.min(...g.map(r=>r.filter(v=>v&&!has(v)).length))}
function lotoDone(g,has,mode){return lotoLeft(g,has,mode)===0}
const lotoSpeed=()=>{const v=store.get('lotosp','mid');return{slow:5200,mid:3600,fast:2300}[v]?v:'mid'};
const LOTO_SP={slow:5200,mid:3600,fast:2300};
const lotoOpt=()=>{const o=store.get('lotoopt',null)||{};return{n:[1,2,3].includes(o.n)?o.n:2,mode:o.mode==='full'?'full':'row',auto:!!o.auto}};
/* the caller's voice: the phone's own Georgian voice when it has one */
const LOTOV={v:undefined};
function lotoVoice(){if(LOTOV.v!==undefined)return LOTOV.v;try{const vs=window.speechSynthesis.getVoices();if(!vs.length)return null;LOTOV.v=vs.find(v=>/^ka/i.test(v.lang))||null}catch(e){LOTOV.v=null}return LOTOV.v}
const lotoSayOn=()=>store.get('lotosay',true)!==false;
function lotoSay(n){if(!lotoSayOn()||typeof window.speechSynthesis==='undefined')return;const v=lotoVoice();if(!v)return;try{window.speechSynthesis.cancel();const u=new window.SpeechSynthesisUtterance((LOTO_NICK[n]?LOTO_NICK[n]+', ':'')+numKa(n));u.voice=v;u.lang=v.lang;u.rate=.95;window.speechSynthesis.speak(u)}catch(e){}}
try{if(typeof window.speechSynthesis!=='undefined')window.speechSynthesis.addEventListener('voiceschanged',()=>{LOTOV.v=undefined})}catch(e){}

/* the screen, shared by the game against the computer and the table with friends */
function lotoTixHTML(T,has,cur,act,mode){return T.map((t,ti)=>{const left=lotoLeft(t.g,v=>t.m.has(v),mode);
 return `<div class="ltix${left===0?' done':''}" aria-label="ბილეთი ${ti+1}"><div class="ltg">${t.g.map((row,r)=>row.map((v,c)=>v?`<button class="lc${t.m.has(v)?' on':''}${v===cur&&!t.m.has(v)?' now':''}" data-a="${act}" data-t="${ti}" data-v="${v}" aria-label="${v}${t.m.has(v)?', მონიშნულია':''}" aria-pressed="${t.m.has(v)}">${v}</button>`:'<span class="lc e" aria-hidden="true"></span>').join('')).join('')}</div>
  <small class="ltl">${left===0?'სრულია!':left===1?'ერთი აკლია!':`აკლია ${left}`}</small></div>`}).join('')}
function lotoBarrelHTML(cur,drawn){const last=drawn.slice(-6,-1).reverse();
 return `<div class="lbar">${cur?`<div class="lkeg" aria-live="polite"><b>${cur}</b><small>${numKa(cur)}${LOTO_NICK[cur]?` · ${LOTO_NICK[cur]}`:''}</small></div>`:'<div class="lkeg wait"><b>?</b><small>ტომარა მზადაა</small></div>'}
  <div class="llast">${last.map(v=>`<span>${v}</span>`).join('')}</div><button class="btn ghost sm" data-a="lotoboard">${ic('grid')}${drawn.length}/90</button></div>`}
function lotoBoardOpen(drawn){const D=new Set(drawn);sheet(head('ამოსული რიცხვები')+`<div class="ph-body"><div class="l90">${Array.from({length:90},(_,i)=>`<span${D.has(i+1)?' class="on"':''}>${i+1}</span>`).join('')}</div><p class="note">ამოვიდა ${drawn.length} რიცხვი 90-დან.</p></div>`,'short')}

const LOTO=GAME.loto={title:'ლოტო',
 start(){this.tk=(this.tk||0)+1;clearTimeout(this.tm);this.phase='setup';this.score=this.score||[0,0,0,0]},
 nm(p){return p===0?ME.name:cPlayers[p].n},
 begin(){const o=lotoOpt(),rng=Math.random;this.opt=o;this.tk++;clearTimeout(this.tm);this.bag=lotoBag(rng);this.drawn=[];this.cur=null;this.win=null;this.paused=false;
  this.tix=[];for(let k=0;k<o.n;k++)this.tix.push({p:0,g:lotoTicket(rng),m:new Set()});for(const p of[1,2,3])for(let k=0;k<(p===2?2:1);k++)this.tix.push({p,g:lotoTicket(rng),m:new Set()});
  this.phase='play';this.render();this.tick(1600)},
 later(fn,ms){const tk=this.tk;clearTimeout(this.tm);this.tm=setTimeout(()=>{if(tk===this.tk&&S.game==='loto'&&!S.page)fn()},ms)},
 tick(ms){this.later(()=>this.draw(),ms??LOTO_SP[lotoSpeed()])},
 draw(){if(this.phase!=='play'||this.paused||this.win)return;if(!this.bag.length){this.phase='over';this.render();return}
  const v=this.bag.pop();this.drawn.push(v);this.cur=v;if(typeof gSnd==='function')gSnd('wood',.8);lotoSay(v);
  /* the computer's players mark at once and call when done */
  for(const t of this.tix)if(t.p&&lotoNums(t.g).includes(v))t.m.add(v);
  if(this.opt.auto)for(const t of this.tix)if(!t.p&&lotoNums(t.g).includes(v))t.m.add(v);
  const bot=this.tix.find(t=>t.p&&lotoDone(t.g,x=>t.m.has(x),this.opt.mode)),meDone=this.mineDone();
  if(this.opt.auto&&meDone>=0){const tk=this.tk;setTimeout(()=>{if(tk===this.tk)this.claim(0,meDone)},500)}
  if(bot){const tk=this.tk,lv=bLvl('loto');setTimeout(()=>{if(tk===this.tk&&!this.win&&this.phase==='play')this.claim(bot.p,this.tix.indexOf(bot))},[0,1900,1300,900,600][lv])}
  this.render();this.tick()},
 mineDone(){return this.tix.findIndex(t=>!t.p&&lotoDone(t.g,x=>t.m.has(x),this.opt.mode))},
 claim(p,ti){const t=this.tix[ti];if(this.win||!t||t.p!==p)return false;const D=new Set(this.drawn);if(!lotoDone(t.g,x=>t.m.has(x)&&D.has(x),this.opt.mode))return false;
  this.win={p,ti};this.phase='over';clearTimeout(this.tm);this.score[p]++;this.ctx.finAt=performance.now();if(p===0)gameResult('loto',true);
  if(typeof gSnd==='function')gSnd(p===0?'win':'lose');this.render();return true},
 mark(ti,v){const t=this.tix[ti];if(!t||t.p||this.phase!=='play')return;if(t.m.has(v)){t.m.delete(v);this.render();return}
  if(!this.drawn.includes(v)){toast(v+' ჯერ არ ამოსულა');return}t.m.add(v);if(typeof gSnd==='function')gSnd('soft',.7);this.render()},
 save(){return null},
 render(){if(S.tab!=='games'||S.game!=='loto'||S.page)return;const top=gTop('ლოტო',null);
  if(this.phase==='setup'){const o=lotoOpt(),sp=lotoSpeed(),seg=(a,v,cur,t)=>`<button data-a="${a}" data-v="${v}" aria-pressed="${String(v)===String(cur)}">${t}</button>`;
   view.innerHTML=gShell('loto',{top,center:`<section class="setupc lset"><h3>ლოტო</h3><p class="note">მეწამულ ტომარაში 90 კასრია. წამყვანი თითოს ამოიღებს და ხმამაღლა იტყვის, შენ კი ბილეთზე მონიშნავ. ვინც პირველი შეავსებს ${o.mode==='full'?'მთელ ბილეთს':'ერთ ხაზს'}, ის იგებს. სამი ბოტი შენთან ერთად თამაშობს.</p>
    <b class="lsh">ბილეთები</b><div class="seg">${[1,2,3].map(n=>seg('lotoset','n:'+n,'n:'+o.n,n)).join('')}</div>
    <b class="lsh">რა იგებს</b><div class="seg">${seg('lotoset','mode:row','mode:'+o.mode,'ერთი ხაზი')}${seg('lotoset','mode:full','mode:'+o.mode,'მთელი ბილეთი')}</div>
    <b class="lsh">სისწრაფე</b><div class="seg">${seg('lotoset','sp:slow','sp:'+sp,'ნელა')}${seg('lotoset','sp:mid','sp:'+sp,'საშუალოდ')}${seg('lotoset','sp:fast','sp:'+sp,'სწრაფად')}</div>
    <label class="lchk"><input type="checkbox" data-a="lotoauto"${o.auto?' checked':''}> თავისით მონიშვნა (რიცხვი ბილეთზე თვითონ აღინიშნება)</label>
    <div class="jkacts"><button class="btn gold" data-a="lotogo">${ic('play')}დაწყება</button></div>
    <div class="jkonline"><div><b>მეგობრებთან ონლაინ</b><p class="note">გაშალე მაგიდა, მოიწვიე მეგობრები და ისაუბრეთ მიკროფონით. ცარიელ ადგილებზე ბოტები ითამაშებენ.</p></div><button class="btn ghost" data-a="lotnew">${ic('users')}მაგიდის გაშლა</button></div></section>`,bot:''});return}
  const mode=this.opt.mode,D=new Set(this.drawn),mine=this.tix.filter(t=>!t.p),meDone=this.mineDone();
  const ppl=[1,2,3].map(p=>{const ts=this.tix.filter(t=>t.p===p),left=Math.min(...ts.map(t=>lotoLeft(t.g,x=>t.m.has(x),mode)));return `<span class="lpl${left<=1?' hot':''}${this.win&&this.win.p===p?' won':''}">${avAny(cPlayers[p],28)}<b>${esc(this.nm(p))}</b><small>${this.win&&this.win.p===p?'ლოტო!':left===0?'ავსებს…':left===1?'ერთი აკლია!':`აკლია ${left}`}</small></span>`}).join('');
  const info=`<div class="ginfo"><span>${mode==='full'?'მთელი ბილეთი':'ერთი ხაზი'}</span><span>ამოვიდა ${this.drawn.length}/90</span><span class="gscore"><span>მოგებები</span><b>${this.score[0]}</b></span></div>`;
  const tixMine=this.tix.map((t,i)=>({t,i})).filter(x=>!x.t.p);
  const tixH=tixMine.map(({t,i})=>lotoTixHTML([t],null,this.cur,'lotom',mode).replace(/data-t="0"/g,`data-t="${i}"`)).join('');
  let res='';if(this.phase==='over'){const w=this.win,me=w&&w.p===0;res=gResBox(this,{title:!w?'ტომარა დაცარიელდა':me?'ლოტო! მოიგე!':esc(this.nm(w.p))+'მ მოიგო',sub:w?`${this.drawn.length} რიცხვზე, ${mode==='full'?'მთელი ბილეთი':'ერთი ხაზი'}`:'არავინ შეავსო',kind:me?'win':'lose',
   more:`<div class="gendt">${[0,1,2,3].map(p=>`<span><b>${esc(p?this.nm(p):'შენ')}</b>${this.score[p]}</span>`).join('')}</div>`,again:'<button class="btn gold" data-a="lotoagain">კიდევ ერთი</button>',share:me?gShareBtn('loto',`${this.drawn.length} რიცხვზე`):''})}
  const claim=this.phase==='play'&&meDone>=0&&!this.opt.auto;
  view.innerHTML=gShell('loto',{top:top+info,center:`<div class="lroom">${lotoBarrelHTML(this.cur,this.drawn)}<div class="lpls">${ppl}</div><div class="ltixs">${tixH}</div></div>`,
   bot:`<div class="jkacts lacts">${claim?`<button class="btn gold lclaim" data-a="lotoclaim" data-t="${meDone}">ლოტო!</button>`:''}${this.phase==='play'?`<button class="btn ghost sm" data-a="lotopause">${ic(this.paused?'play':'pause')}${this.paused?'გაგრძელება':'პაუზა'}</button>`:''}</div>`,res})}};
A.lotoset=t=>{const[k,v]=String(t.dataset.v).split(':'),o=lotoOpt();if(k==='n')o.n=+v;if(k==='mode')o.mode=v;if(k==='sp'){store.set('lotosp',v);LOTO.render();return}store.set('lotoopt',o);LOTO.render()};
A.lotoauto=t=>{const o=lotoOpt();o.auto=!!t.checked;store.set('lotoopt',o)};
A.lotogo=()=>LOTO.begin();
A.lotoagain=()=>{LOTO.resHide=0;LOTO.resSnd=0;LOTO.ctx.finAt=0;LOTO.begin()};
A.lotom=t=>LOTO.mark(+t.dataset.t,+t.dataset.v);
A.lotoclaim=t=>{if(!LOTO.claim(0,+t.dataset.t))toast('ჯერ ყველა რიცხვი არ არის მონიშნული')};
A.lotopause=()=>{LOTO.paused=!LOTO.paused;if(!LOTO.paused)LOTO.tick(900);else clearTimeout(LOTO.tm);LOTO.render()};
A.lotoboard=()=>{if(S.page&&S.page.id==='lotable'){lotoBoardOpen(LOT.drawn());return}lotoBoardOpen(LOTO.drawn||[])};
A.lotosay=t=>{const on=!lotoSayOn();store.set('lotosay',on);gSwFlip(t,on);if(on&&!lotoVoice())toast('ამ ტელეფონს ქართული ხმა არ აქვს: რიცხვი ეკრანზე დიდად ჩანს')};

/* ---------- lotto with friends ----------
   on the same shared tables as joker and domino. the host's app draws the barrels and keeps the state; everyone's tickets
   come from the table's seed, so each phone can show and check all of them. a call (ლოტო) goes to the host, who checks it
   against the numbers drawn. empty seats get a computer player that calls the moment it is full */
const LOT={};
function lotReset(){Object.assign(LOT,{id:null,t:null,st:null,seat:-1,ch:null,tm:null,here:new Set(),looks:{},hostHere:true,marks:{},res:false,resHide:0,resSnd:0,ctx:{mode:'online',gk:'loto',finAt:0},q:Promise.resolve(),err:0,rx:{}})}
lotReset();
const lotIsHost=()=>!!LOT.t&&!!ME&&LOT.t.host===ME.id;
const lotHere=id=>!!S.page&&S.page.id==='lotable'&&+S.page.arg===id&&LOT.id===id;
/* the bag is drawn from its end, as in the game against the computer */
const lotDrawn=s=>{if(!s||!s.seed)return[];const b=lotoBag(jdRng(s.seed));return b.slice(90-Math.max(0,Math.min(90,s.n|0))).reverse()};
LOT.drawn=()=>lotDrawn(LOT.st);
/* every seat's tickets, the same on every phone */
function lotTix(s){if(!s||!s.seed)return[];const rng=jdRng(s.seed^0x5bd1e995),out=[];for(let p=0;p<4;p++)for(let k=0;k<(s.tn||2);k++)out.push({p,g:lotoTicket(rng)});return out}
const lotName=p=>{const u=LOT.t&&LOT.t.seats[p];if(u)return u===ME.id?'შენ':pname(u);return (cPlayers[p]||cPlayers[1]).n+' (ბოტი)'};
PG.lotable={r(id){id=+id;view.innerHTML=pgHead('ლოტო ონლაინ',`<button class="ibtn" data-a="lotshare" aria-label="ბმულის გაზიარება">${ic('share')}</button>${gTools()}`)+`<div class="view-pad game lot" id="lot">${skel(2)}</div>`;lotOpen(id)}};
function lotStop(){clearTimeout(LOT.tm);if(LOT.ch){try{LOT.ch.untrack()}catch(e){}sb.removeChannel(LOT.ch)}lotReset()}
async function lotOpen(id){lotStop();LOT.id=id;S.chanCleanup=()=>{lotStop();fsExit()};fsEnter();let t=null;
 try{t=await q(sb.from('jk_tables').select('*').eq('id',id).maybeSingle())}catch(e){}
 if(!lotHere(id))return;const el=$('#lot');
 if(t&&t.status!=='closed'&&!(t.state&&t.state.g==='loto')){dmoSwap(t.state&&t.state.g==='domino'?'dmtable':'jktable',id);return}
 if(!t||t.status==='closed'){el.innerHTML=empty('ეს მაგიდა აღარ არსებობს','ახალი მაგიდის გასაშლელად თამაშებში აირჩიე ლოტო','<button class="btn" data-a="lotnew">ახალი მაგიდა</button>');return}
 LOT.t=t;LOT.st=t.state;LOT.seat=t.seats.indexOf(ME.id);LOT.marks=store.get('lotm:'+id,{})||{};
 await loadProfiles(t.seats.filter(Boolean));if(!lotHere(id))return;
 const ch=sb.channel('lot-'+id,{config:{presence:{key:ME.id}}});
 ch.on('postgres_changes',{event:'UPDATE',schema:'public',table:'jk_tables',filter:'id=eq.'+id},pl=>lotTable(pl.new))
  .on('broadcast',{event:'rx'},({payload:d})=>{if(!d||!GRX[+d.i]||!lotHere(id))return;toast(`${esc(String(lotName(+d.seat)).split(' ')[0])}: ${GRX[+d.i][0]}`)});
 if(lotIsHost())ch.on('postgres_changes',{event:'INSERT',schema:'public',table:'jk_moves',filter:'table_id=eq.'+id},pl=>lotMove(pl.new));
 ch.on('presence',{event:'sync'},()=>{const ps=ch.presenceState();LOT.here=new Set(Object.keys(ps));LOT.hostHere=!!LOT.t&&LOT.here.has(LOT.t.host);lotDraw()})
  .subscribe(s=>{if(s==='SUBSCRIBED')ch.track({at:Date.now(),lk:myLook()}).catch(()=>{})});
 LOT.ch=ch;if(lotIsHost()&&t.status==='play')lotNext();lotDraw()}
function lotTable(r){if(!r||r.id!==LOT.id||!LOT.t)return;const was=LOT.st&&LOT.st.n;
 if(lotIsHost()){LOT.t.seats=r.seats;if(LOT.t.status==='wait')LOT.t.status=r.status}else{LOT.t=r;LOT.st=r.state;LOT.seat=r.seats.indexOf(ME.id)}
 const s=LOT.st;if(s&&s.n!==was&&s.n>0){const v=lotDrawn(s)[s.n-1];if(v&&!lotIsHost()){if(typeof gSnd==='function')gSnd('wood',.8);lotoSay(v)}}
 loadProfiles(r.seats.filter(Boolean)).then(()=>{lotDraw();lotResult()})}
/* the host: a barrel every few seconds, a check of every call, the computer's seats call when full */
function lotPub(start){const s=LOT.st,id=LOT.id,status=s.win?'over':'play';LOT.t.status=status;LOT.t.state=s;const pay={state:s,status,updated_at:new Date().toISOString()};if(start)pay.seats=LOT.t.seats;
 LOT.q=LOT.q.then(()=>q(sb.from('jk_tables').update(pay).eq('id',id))).then(()=>{LOT.err=0}).catch(e=>{if(LOT.id===id&&!LOT.err++)toast('კავშირი შეფერხდა: '+errMsg(e))});lotDraw();lotResult()}
function lotNext(){clearTimeout(LOT.tm);const s=LOT.st;if(!lotIsHost()||!s||s.win||s.n>=90)return;const id=LOT.id;
 LOT.tm=setTimeout(()=>{if(LOT.id!==id||!lotIsHost()||LOT.st.win)return;LOT.st=Object.assign({},LOT.st,{n:LOT.st.n+1});const v=lotDrawn(LOT.st)[LOT.st.n-1];if(typeof gSnd==='function')gSnd('wood',.8);lotoSay(v);
  /* the computer's seats call when one of their tickets is full */
  const D=new Set(lotDrawn(LOT.st)),T=lotTix(LOT.st),bt=T.findIndex(x=>!LOT.t.seats[x.p]&&lotoDone(x.g,y=>D.has(y),LOT.st.mode));
  if(bt>=0)setTimeout(()=>{if(LOT.id===id&&!LOT.st.win)lotWin(T[bt].p,bt)},1100);
  lotPub();lotNext()},LOT_SP(s))}
const LOT_SP=s=>LOTO_SP[s.sp]||LOTO_SP.mid;
function lotWin(p,ti){const s=LOT.st;if(s.win)return false;const T=lotTix(s),t=T[ti],D=new Set(lotDrawn(s));if(!t||t.p!==p||!lotoDone(t.g,y=>D.has(y),s.mode))return false;
 LOT.st=Object.assign({},s,{win:{p,ti,n:s.n},score:(s.score||[0,0,0,0]).map((x,i)=>i===p?x+1:x)});clearTimeout(LOT.tm);lotPub();return true}
function lotMove(m){if(!m||m.table_id!==LOT.id||!LOT.st)return;if(LOT.t.seats[m.seat]!==m.user_id)return;const mv=m.move||{};if(mv.k==='claim'&&mv.r===LOT.st.r)lotWin(m.seat,+mv.ti)}
/* marks are kept on the phone for each round; with "by itself" on, every number drawn counts as marked */
const lotMarked=i=>lotoOpt().auto?new Set(lotDrawn(LOT.st)):new Set(LOT.marks[(LOT.st&&LOT.st.r)+':'+i]||[]);
async function lotClaim(ti){const s=LOT.st;if(!s||LOT.seat<0||s.win)return;
 if(lotIsHost()){if(!lotWin(LOT.seat,ti))toast('ბილეთი ჯერ არ არის სრული');return}
 try{await q(sb.from('jk_moves').insert({table_id:LOT.id,seat:LOT.seat,user_id:ME.id,move:{k:'claim',ti,r:s.r}}));toast('ლოტო! წამყვანი ამოწმებს…')}catch(e){toast(errMsg(e))}}
A.lotm=t=>{const s=LOT.st;if(!s||s.win||LOT.seat<0)return;const ti=+t.dataset.t,v=+t.dataset.v,T=lotTix(s);if(!T[ti]||T[ti].p!==LOT.seat)return;const k=s.r+':'+ti,m=new Set(LOT.marks[k]||[]);
 if(m.has(v))m.delete(v);else{if(!lotDrawn(s).includes(v)){toast(v+' ჯერ არ ამოსულა');return}m.add(v);if(typeof gSnd==='function')gSnd('soft',.7)}LOT.marks[k]=[...m];store.set('lotm:'+LOT.id,LOT.marks);lotDraw()};
A.lotclaim=t=>lotClaim(+t.dataset.t);
async function lotNewTable(){const r=await q(sb.from('jk_tables').insert({host:ME.id,len:'quick',seats:[ME.id,null,null,null],state:{g:'loto'}}).select('id').single());return r.id}
A.lotnew=async()=>{closeSheet();try{openPage('lotable',await lotNewTable())}catch(e){toast(errMsg(e))}};
A.lotshare=()=>{if(LOT.id)shareLink(location.origin+'/#lotable-'+LOT.id,'ლოტო სუფრაზე: შემოდი, ბილეთი გელოდება')};
A.lotjoin=async()=>{try{const seat=await rpc('jk_join',{p_table:LOT.id});LOT.seat=seat;if(LOT.t)LOT.t.seats[seat]=ME.id;lotDraw()}catch(e){toast(e&&String(e.message||'').includes('album_full')?'მაგიდა უკვე სავსეა':errMsg(e))}};
A.lotleave=async()=>{try{await rpc('jk_leave',{p_table:LOT.id});if(LOT.t&&LOT.seat>=0)LOT.t.seats[LOT.seat]=null;LOT.seat=-1;lotDraw()}catch(e){toast(errMsg(e))}};
A.lotinvite=()=>{if(!LOT.t)return;const id=LOT.id;friendPicker('მოწვევა ლოტოზე','მოწვევა',async sel=>{let n=0;for(const u of[...sel].slice(0,10)){try{const c=await rpc('start_dm',{other:u});await q(sb.from('messages').insert({conv_id:c,sender:ME.id,body:'🎱 ლოტო: მაგიდა გავშალე, შემოდი!',media:{game:{gt:'loto',tbl:id}}}));n++}catch(e){}}
 closeSheet();toast(n?`მოწვევა გაეგზავნა: ${n}`:'მოწვევა ვერ გაიგზავნა')},new Set(LOT.t.seats.filter(Boolean)))};
/* the host starts a round: a fresh seed, the options picked in the game against the computer */
A.lotstart=async()=>{if(!lotIsHost()||!LOT.t)return;try{const r=await q(sb.from('jk_tables').select('seats').eq('id',LOT.id).single());LOT.t.seats=r.seats}catch(e){}
 const o=lotoOpt(),prev=LOT.st||{};LOT.st={g:'loto',seed:(Math.random()*4294967295)>>>0||7,n:0,r:(prev.r||0)+1,tn:o.n,mode:o.mode,sp:lotoSpeed(),win:null,score:prev.score||[0,0,0,0]};
 await loadProfiles(LOT.t.seats.filter(Boolean));LOT.ctx.finAt=0;LOT.resHide=0;LOT.resSnd=0;lotPub(true);lotNext()};
A.lotclose=()=>{if(!lotIsHost())return;confirmSheet('მაგიდის დახურვა','თამაში ყველასთვის დასრულდება.','დახურვა',async()=>{await q(sb.from('jk_tables').update({status:'closed',updated_at:new Date().toISOString()}).eq('id',LOT.id));clearTimeout(LOT.tm);if(LOT.t)LOT.t.status='closed';lotDraw()},true)};
function lotResult(){const s=LOT.st;if(!s||!s.win){LOT.res=false;return}if(LOT.res||LOT.seat<0)return;LOT.res=true;LOT.ctx.finAt=performance.now();const k='lotres-'+LOT.id+'-'+s.r;try{if(localStorage.getItem(k))return;localStorage.setItem(k,'1')}catch(e){}if(s.win.p===LOT.seat)gameResult('loto',true)}
function lotDraw(){const el=$('#lot');if(!el||!LOT.t||!lotHere(LOT.id))return;const t=LOT.t,s=LOT.st,host=lotIsHost(),me=LOT.seat;
 const plain=h=>{el.className='view-pad game lot';el.innerHTML=h};
 if(t.status==='closed'){plain(empty('მაგიდა დაიხურა','მასპინძელმა თამაში დაასრულა.','<button class="btn" data-a="lotnew">ახალი მაგიდა</button>'));return}
 if(t.status==='wait'||!s||!s.seed){const seat=p=>{const u=t.seats[p];return `<div class="jkseat${u?'':' free'}">${u?av(u,46):'<span class="av jkempty" style="--s:46px" aria-hidden="true">+</span>'}<b>${u?esc(u===ME.id?'შენ':pname(u)):'ცარიელი'}</b><small>${u===t.host?'მასპინძელი':u?'მზადაა':'ბოტი ითამაშებს'}</small></div>`};
  const o=lotoOpt();plain(`<section class="tourcard jkwait"><h3>ლოტო მეგობრებთან</h3><p class="note">${host?`ბარაბანს შენ ატრიალებ: ${o.n} ბილეთი თითოს, ${o.mode==='full'?'მთელი ბილეთი':'ერთი ხაზი'}, ${({slow:'ნელა',mid:'საშუალოდ',fast:'სწრაფად'})[lotoSpeed()]}. ამის შეცვლა ბოტებთან ლოტოს ეკრანზეა.`:'მეგობარმა ლოტოს მაგიდა გაშალა.'} ცარიელ ადგილებზე ბოტები ითამაშებენ.</p><div class="jkseats">${[0,1,2,3].map(seat).join('')}</div>
   ${host?`<div class="jkacts"><button class="btn" data-a="lotstart">${ic('play')}დაწყება</button><button class="btn ghost" data-a="lotinvite">${ic('users')}მეგობრების მოწვევა</button><button class="btn ghost sm" data-a="lotclose">მაგიდის დახურვა</button></div>`:me>=0?'<p class="hint">მასპინძელი მალე დაიწყებს.</p><div class="jkacts"><button class="btn ghost sm" data-a="lotleave">მაგიდიდან ადგომა</button></div>':t.seats.some(x=>!x)?'<div class="jkacts"><button class="btn" data-a="lotjoin">მაგიდასთან დაჯდომა</button></div>':'<p class="hint">მაგიდა სავსეა.</p>'}</section>`);return}
 const D=lotDrawn(s),cur=D[D.length-1]||null,T=lotTix(s),mode=s.mode,mineT=T.map((x,i)=>({x,i})).filter(o=>o.x.p===me);
 const ppl=[0,1,2,3].filter(p=>p!==me).map(p=>{const ts=T.filter(x=>x.p===p),Ds=new Set(D),left=Math.min(...ts.map(x=>lotoLeft(x.g,y=>Ds.has(y),mode)));const u=t.seats[p];
  return `<span class="lpl${left<=1?' hot':''}${s.win&&s.win.p===p?' won':''}"${u?` data-vu="${u}"`:''}>${u?av(u,28):avAny(cPlayers[p]||cPlayers[1],28)}<b>${esc(String(lotName(p)).split(' ')[0])}</b><small>${s.win&&s.win.p===p?'ლოტო!':left===1?'ერთი აკლია!':`აკლია ${left}`}</small></span>`}).join('');
 const tixH=mineT.map(({x,i})=>{const m=lotMarked(i);return lotoTixHTML([{g:x.g,m}],null,cur,'lotm',mode).replace(/data-t="0"/g,`data-t="${i}"`)}).join('');
 const done=mineT.find(({x,i})=>lotoDone(x.g,y=>lotMarked(i).has(y),mode));
 const info=`<div class="ginfo"><span>${mode==='full'?'მთელი ბილეთი':'ერთი ხაზი'}</span><span>ამოვიდა ${D.length}/90</span>${!host&&!LOT.hostHere?'<span>მასპინძელი გავიდა, ბარაბანი გაჩერდა</span>':''}</div>`;
 let res='';if(s.win){const w=s.win.p,mine=w===me;res=gResBox(LOT,{title:mine?'ლოტო! მოიგე!':esc(lotName(w))+' იგებს',sub:`${s.win.n} რიცხვზე`,kind:mine?'win':'lose',more:`<div class="gendt">${[0,1,2,3].map(p=>`<span><b>${esc(String(lotName(p)).split(' ')[0])}</b>${(s.score||[])[p]||0}</span>`).join('')}</div>`,
  again:host?'<button class="btn gold" data-a="lotstart">კიდევ ერთი</button>':'',share:mine?gShareBtn('loto','მეგობრებთან'):'',leave:'<button class="btn ghost" data-a="back">მაგიდიდან გასვლა</button>'})}
 const P=gShellParts({top:gTop('ლოტო ონლაინ',null,'back')+info,center:`<div class="lroom">${lotoBarrelHTML(cur,D)}<div class="lpls">${ppl}</div><div class="ltixs">${me>=0?tixH:'<p class="note">შენ უყურებ. ბილეთები მოთამაშეებს აქვთ.</p>'}</div></div>`,
  bot:`<div class="jkacts lacts">${done&&!s.win&&!lotoOpt().auto?`<button class="btn gold lclaim" data-a="lotclaim" data-t="${done.i}">ლოტო!</button>`:''}</div>`,res});
 if(done&&!s.win&&lotoOpt().auto&&!LOT.autoC){LOT.autoC=1;setTimeout(()=>{LOT.autoC=0;lotClaim(done.i)},400)}
 el.className='view-pad game lot gx';el.dataset.g='loto';el.innerHTML=P.html}
