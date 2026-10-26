/* ---------- domino with friends: four at one table, in two pairs ----------
   the partner sits across, as in the game against the computer; empty seats are played by bots.
   it runs on the same tables as online joker: the host's app deals and keeps the rules, everyone else sends moves,
   a hand is readable only by its owner and the host, and someone who is away gets an automatic move */
const DMO={};
function dmoReset(){Object.assign(DMO,{id:null,t:null,st:null,seat:-1,hand:[],dn:-1,ch:null,E:null,q:Promise.resolve(),tm:null,tick:null,here:new Set(),looks:{},hostHere:true,res:false,wait:false,wt:null,err:0,sel:null,lineN:null,
 ctx:{mode:'online',gk:'domino',finAt:0,cined:0},resHide:0,resSnd:0,resDn:null,wasMine:false})}
dmoReset();
const DMO_TT=45;
const dmoIsHost=()=>!!DMO.t&&!!ME&&DMO.t.host===ME.id;
const dmoHere=id=>!!S.page&&S.page.id==='dmtable'&&+S.page.arg===id&&DMO.id===id;
const dmoBot=p=>DMN[p]||DMN[1];
const dmoName=p=>{const u=DMO.t&&DMO.t.seats[p];if(u)return u===ME.id?'შენ':pname(u);const b=DMO.st&&DMO.st.bots&&DMO.st.bots[p];return b?b+' (ბოტი)':'ცარიელი'};
const dmoShort=p=>{const u=DMO.t&&DMO.t.seats[p];if(u)return u===ME.id?'შენ':String(pname(u)).split(' ')[0];return (DMO.st&&DMO.st.bots&&DMO.st.bots[p])||'–'};
const dmoAv=(p,s)=>{const u=DMO.t&&DMO.t.seats[p];if(u)return av(u,s);const b=DMO.st&&DMO.st.bots&&DMO.st.bots[p];return b?avAny({n:b,h:(DMN.find(x=>x&&x.n===b)||{h:150}).h},s):`<span class="av jkempty" style="--s:${s}px" aria-hidden="true">+</span>`};
/* who sits in a seat, for the people around the 3D table */
function dmoWho(p){const u=DMO.t&&DMO.t.seats[p];if(u){const pr=typeof PC!=='undefined'&&PC.get(u);return{n:u===ME.id?ME.name:(pr&&pr.name)||'მოთამაშე',h:pr&&pr.hue,k:u,lk:(DMO.looks&&DMO.looks[u])||(pr&&pr.look)||null}}
 const b=(DMO.st&&DMO.st.bots&&DMO.st.bots[p])||dmoBot(p).n,d=DMN.find(x=>x&&x.n===b)||dmoBot(p);return{n:b,h:d.h,k:'d:'+b}}
const dmoTiles=a=>(Array.isArray(a)?a:[]).filter(x=>Array.isArray(x)&&x.length===2).map(x=>[Math.max(0,Math.min(6,+x[0]|0)),Math.max(0,Math.min(6,+x[1]|0))]).sort((x,y)=>x[0]-y[0]||x[1]-y[1]);

PG.dmtable={r(id){id=+id;view.innerHTML=pgHead('დომინო ონლაინ',`<button class="ibtn" data-a="dmoshare" aria-label="ბმულის გაზიარება">${ic('share')}</button>${gTools()}`)+`<div class="view-pad game dmo" id="dmo">${skel(2)}</div>`;dmoOpen(id)}};

function dmoStop(){clearTimeout(DMO.tm);clearTimeout(DMO.wt);clearInterval(DMO.tick);if(DMO.ch){try{DMO.ch.untrack()}catch(e){}sb.removeChannel(DMO.ch)}dmoReset()}
/* a table link can point to either game: each page hands the other's tables over, in the same step */
function dmoSwap(pg,id){NAV.busy++;try{openPage(pg,id,null,true)}finally{NAV.busy--}navReplace()}

async function dmoOpen(id){dmoStop();DMO.id=id;S.chanCleanup=()=>{dmoStop();fsExit()};fsEnter();g3Intro('dmo');let t=null;
 try{t=await q(sb.from('jk_tables').select('*').eq('id',id).maybeSingle())}catch(e){}
 if(!dmoHere(id))return;const el=$('#dmo');
 if(t&&t.status!=='closed'&&!(t.state&&t.state.g==='domino')){dmoSwap('jktable',id);return}
 if(!t||t.status==='closed'){el.innerHTML=empty('ეს მაგიდა აღარ არსებობს','ახალი მაგიდის გასაშლელად თამაშებში აირჩიე „მეგობრების მაგიდა“','<button class="btn" data-a="dmonew">ახალი მაგიდა</button>');return}
 DMO.t=t;DMO.st=t.state;DMO.seat=t.seats.indexOf(ME.id);
 await loadProfiles(t.seats.filter(Boolean));
 if(!dmoHere(id))return;
 if(t.status==='play'&&dmoIsHost()){try{await dmoResume()}catch(e){toast(errMsg(e))}}
 else if(t.status!=='wait'&&DMO.seat>=0)await dmoFetchHand();
 if(!dmoHere(id))return;
 const ch=sb.channel('dmo-'+id,{config:{presence:{key:ME.id}}});
 ch.on('postgres_changes',{event:'UPDATE',schema:'public',table:'jk_tables',filter:'id=eq.'+id},pl=>dmoTable(pl.new))
  .on('broadcast',{event:'rx'},({payload:d})=>{if(!d||!GRX[+d.i]||!dmoHere(id))return;const s=+d.seat;if(!(s>=0&&s<4)||s===DMO.seat||Date.now()-((DMO.rxAt||{})[s]||0)<900)return;(DMO.rxAt=DMO.rxAt||{})[s]=Date.now();const r=(s-(DMO.seat>=0?DMO.seat:0)+4)%4;gRxShow(r?'r'+r:'me',+d.i)})
  .on('postgres_changes',{event:'*',schema:'public',table:'jk_hands',filter:'table_id=eq.'+id},pl=>{const r=pl.new;if(!r||dmoIsHost()||r.seat!==DMO.seat||r.user_id!==ME.id)return;DMO.hand=dmoTiles(r.cards);DMO.wait=false;dmoDraw()});
 if(dmoIsHost())ch.on('postgres_changes',{event:'INSERT',schema:'public',table:'jk_moves',filter:'table_id=eq.'+id},pl=>dmoMove(pl.new));
 ch.on('presence',{event:'sync'},()=>{const ps=ch.presenceState();DMO.here=new Set(Object.keys(ps));DMO.looks={};for(const k in ps){const e=(ps[k]||[]).find(x=>x&&x.lk);if(e)DMO.looks[k]=lkClean(e.lk)}DMO.hostHere=!!DMO.t&&DMO.here.has(DMO.t.host);if(dmoIsHost()&&DMO.E)dmoNext();dmoDraw()})
  .subscribe(s=>{if(s==='SUBSCRIBED')ch.track({at:Date.now(),lk:myLook()}).catch(()=>{})});
 DMO.ch=ch;DMO.tick=setInterval(dmoCount,1000);
 dmoDraw();dmoResult()}

/* someone joined, the host published a step, or the table was closed */
function dmoTable(r){if(!r||r.id!==DMO.id||!DMO.t)return;
 if(dmoIsHost()){DMO.t.seats=r.seats;if(DMO.t.status==='wait')DMO.t.status=r.status}
 else{const was=DMO.st&&DMO.st.cur;DMO.t=r;DMO.st=r.state;DMO.seat=r.seats.indexOf(ME.id);if(!DMO.st||DMO.st.cur!==was||DMO.st.cur!==DMO.seat){DMO.wait=false;clearTimeout(DMO.wt)}}
 loadProfiles(r.seats.filter(Boolean)).then(async()=>{if(!dmoIsHost())await dmoSync();dmoDraw();dmoResult()})}
async function dmoSync(){const s=DMO.st;if(DMO.seat<0||!s||!s.counts)return;if(s.dn!==DMO.dn||s.counts[DMO.seat]!==DMO.hand.length)await dmoFetchHand()}
async function dmoFetchHand(){const id=DMO.id,seat=DMO.seat;if(seat<0)return;DMO.dn=DMO.st&&DMO.st.dn!=null?DMO.st.dn:-1;
 try{const r=await q(sb.from('jk_hands').select('cards').eq('table_id',id).eq('seat',seat).maybeSingle());if(DMO.id===id&&DMO.seat===seat)DMO.hand=dmoTiles(r&&r.cards)}catch(e){}dmoDraw()}

/* ---------- the host's engine: the rules and bots of the game against the computer, on absolute seats, with nothing drawn ---------- */
function dmoEngine(){const E=Object.create(DM);
 return Object.assign(E,{np:4,baz:[],ctx:{lvl:3},sel:null,render(){},step(){},
  next(){this.cur=(this.cur+1)%4},
  endRound(kind,p){const pip=x=>this.hands[x].reduce((a,t)=>a+dmPip(t),0),tp=[pip(0)+pip(2),pip(1)+pip(3)];let win,pts;
   if(kind==='domino'){win=p%2;pts=tp[1-win]}else{win=tp[0]<tp[1]?0:tp[1]<tp[0]?1:-1;pts=win<0?0:tp[1-win]}
   if(win>=0)this.score[win]+=pts;
   this.lead=kind==='domino'?p:win>=0?[win,win+2].sort((a,b)=>pip(a)-pip(b))[0]:((this.lead??0)+1)%4;
   this.res={kind,win,pts,by:p,pips:[0,1,2,3].map(pip)};this.hist.push({win,pts,kind});this.cur=-1;
   this.phase=this.score.some(x=>x>=DM_TO)?'over':'roundover'}})}
function dmoBegin(){const t=DMO.t,prev=DMO.E,bots=[null,null,null,null];t.seats.forEach((u,i)=>{if(!u)bots[i]=dmoBot(i).n});
 const E=DMO.E=dmoEngine();Object.assign(E,{score:[0,0],pts:[0,0,0,0],round:0,lead:null,hist:[],bots,dn:prev?prev.dn:(DMO.st&&DMO.st.dn)||0,mv:prev?prev.mv:(DMO.st&&DMO.st.mv)||0});
 E.deal();E.dn++;dmoPub(true,true)}
function dmoRoundNext(){const E=DMO.E;if(E&&E.phase==='roundover'&&dmoIsHost()){E.deal();E.dn++;dmoPub(true)}}
/* write the hands that changed, then the public state; everyone reads their hand after the state */
function dmoPub(hs,start){const E=DMO.E;if(!E)return;const u=E.phase==='play'&&E.cur>=0?DMO.t.seats[E.cur]:null;
 E.dl=u&&E.moves(E.cur).length?Date.now()+(u===ME.id||DMO.here.has(u)?DMO_TT*1000:3000):0;
 const st={g:'domino',phase:E.phase,round:E.round,cur:E.cur,root:E.root,L:E.L,R:E.R,last:E.last,first:E.first,firstT:E.firstT,passes:E.passes,miss:E.miss.map(x=>[...x]),score:E.score,lead:E.lead,res:E.res,hist:E.hist,bots:E.bots,dn:E.dn,counts:E.hands.map(h=>h.length),mv:E.mv,dl:E.dl};
 DMO.st=JSON.parse(JSON.stringify(st));const status=E.phase==='over'?'over':'play';DMO.t.status=status;
 const seats=hs===true?[0,1,2,3]:hs||[],id=DMO.id,rows=seats.map(p=>({table_id:id,seat:p,user_id:DMO.t.seats[p]||null,cards:E.hands[p]}));
 const pay={state:st,status,updated_at:new Date().toISOString()};if(start)pay.seats=DMO.t.seats;
 DMO.q=DMO.q.then(async()=>{if(rows.length)await q(sb.from('jk_hands').upsert(rows,{onConflict:'table_id,seat'}));await q(sb.from('jk_tables').update(pay).eq('id',id));DMO.err=0})
  .catch(e=>{if(DMO.id===id&&!DMO.err++)toast('კავშირი შეფერხდა: '+errMsg(e))});
 if(DMO.seat>=0){DMO.hand=E.hands[DMO.seat].map(x=>x.slice());DMO.dn=E.dn}
 dmoDraw();dmoNext();dmoResult()}
/* the next step: a bot plays, someone with nothing to play passes, a person away for long gets an automatic move */
function dmoNext(){const E=DMO.E;clearTimeout(DMO.tm);if(!E||!dmoIsHost())return;
 if(E.phase==='roundover'){DMO.tm=setTimeout(dmoRoundNext,4200);return}
 if(E.phase!=='play'||E.cur<0)return;
 const p=E.cur,u=DMO.t.seats[p];let ms;
 if(!u)ms=950;else if(!E.moves(p).length)ms=1400;else{ms=E.dl?Math.max(0,E.dl-Date.now()):DMO_TT*1000;if(u!==ME.id&&!DMO.here.has(u))ms=Math.min(ms,3000)}
 DMO.tm=setTimeout(()=>dmoAuto(p),ms)}
function dmoAuto(p){const E=DMO.E;if(!E||E.phase!=='play'||E.cur!==p||!dmoIsHost())return;
 if(DMO.t.seats[p]===ME.id&&E.moves(p).length)toast('დრო ამოიწურა, სვლა ავტომატურად გაკეთდა');
 const m=E.bot(p);if(m){const x=E.hands[p][m.i];dmoApply(p,{k:'put',t:[x[0],x[1]],s:m.s})}else dmoApply(p,{k:'pass'})}
function dmoApply(p,m){const E=DMO.E;if(!E||!m||E.phase!=='play'||p!==E.cur)return false;
 if(m.k==='put'){const a=Array.isArray(m.t)?m.t:[],i=E.hands[p].findIndex(x=>x[0]===a[0]&&x[1]===a[1]||x[0]===a[1]&&x[1]===a[0]);if(i<0||!['L','R','root'].includes(m.s)||!E.places(E.hands[p][i]).includes(m.s))return false;E.put(p,i,m.s)}
 else if(m.k==='pass'){if(E.moves(p).length)return false;E.pass(p)}
 else return false;
 dmoPub([p]);return true}
/* a move from a friend counts only from the person in that seat, for this deal, on their turn */
function dmoMove(m){const E=DMO.E;if(!E||!m||m.table_id!==DMO.id||m.id<=E.mv)return false;E.mv=m.id;
 if(DMO.t.seats[m.seat]!==m.user_id)return false;const mv=m.move||{};if(mv.d!==E.dn)return false;return dmoApply(m.seat,mv)}
/* the host came back: rebuild the game from the table and catch up on moves made meanwhile */
async function dmoResume(){const t=DMO.t,s=t.state;if(!s||!s.phase){dmoBegin();return}
 const rows=await q(sb.from('jk_hands').select('seat,cards').eq('table_id',t.id));
 const E=DMO.E=dmoEngine();Object.assign(E,{phase:s.phase,round:s.round||1,cur:s.cur,root:s.root||null,L:s.L||[],R:s.R||[],last:s.last||null,first:!!s.first,firstT:s.firstT||null,passes:s.passes||0,
  miss:(s.miss||[[],[],[],[]]).map(a=>new Set(a)),score:s.score||[0,0],pts:[0,0,0,0],lead:s.lead??null,res:s.res||null,hist:s.hist||[],bots:s.bots||[null,null,null,null],dn:s.dn||0,mv:s.mv||0,hands:[[],[],[],[]]});
 (rows||[]).forEach(r=>{if(r.seat>=0&&r.seat<4)E.hands[r.seat]=dmoTiles(r.cards)});
 let ok=false;if(E.phase==='play')try{const ms=await q(sb.from('jk_moves').select('*').eq('table_id',t.id).gt('id',E.mv).order('id').limit(50));for(const m of ms)if(dmoMove(m))ok=true}catch(e){}
 if(!ok)dmoPub()}

/* ---------- what this screen shows: the table turned so that I sit at the bottom ---------- */
function dmoView(){const s=DMO.st||{},me=DMO.seat,base=me>=0?me:0,rel=a=>a==null||a<0?a:(a-base+4)%4,ent=x=>Object.assign({},x,{by:rel(x.by)}),V=Object.create(DM);
 return Object.assign(V,{np:4,baz:[],round:s.round||0,phase:s.phase||'play',root:s.root?{t:s.root.t,by:rel(s.root.by)}:null,L:(s.L||[]).map(ent),R:(s.R||[]).map(ent),first:!!s.first,firstT:s.firstT||null,
  cur:s.cur>=0?rel(s.cur):-1,last:s.last?Object.assign({},s.last,{p:rel(s.last.p)}):null,sel:DMO.sel,ctx:DMO.ctx,
  hands:[0,1,2,3].map(r=>r===0&&me>=0?DMO.hand:Array.from({length:((s.counts||[])[(r+base)%4])||0},()=>[0,0]))})}

/* ---------- moves from this screen ---------- */
async function dmoSend(mv){const s=DMO.st;if(!s||DMO.seat<0||s.cur!==DMO.seat||DMO.wait)return;DMO.sel=null;
 if(dmoIsHost()){if(!dmoApply(DMO.seat,mv))toast('ეს სვლა არ გამოდის');return}
 mv.d=s.dn;DMO.wait=true;if(mv.k==='put'){const i=DMO.hand.findIndex(x=>x[0]===mv.t[0]&&x[1]===mv.t[1]);if(i>=0)DMO.hand.splice(i,1)}dmoDraw();
 clearTimeout(DMO.wt);DMO.wt=setTimeout(()=>{if(DMO.wait){DMO.wait=false;dmoFetchHand()}},9000);
 try{await q(sb.from('jk_moves').insert({table_id:DMO.id,seat:DMO.seat,user_id:ME.id,move:mv}))}catch(e){DMO.wait=false;toast(errMsg(e));dmoFetchHand()}}
const dmoMine=()=>{const s=DMO.st;return !!s&&s.phase==='play'&&DMO.seat>=0&&s.cur===DMO.seat&&!DMO.wait};
A.dmot=t=>{if(!dmoMine())return;const V=dmoView(),i=+t.dataset.i,x=DMO.hand[i];if(!x)return;const pl=V.places(x);if(!pl.length){DMO.sel=null;dmoDraw();return}
 if(pl.length===1){dmoSend({k:'put',t:x.slice(),s:pl[0]});return}DMO.sel=DMO.sel===i?null:i;dmoDraw()};
A.dmoend=t=>{if(!dmoMine()||DMO.sel==null)return;const V=dmoView(),x=DMO.hand[DMO.sel],e=t.dataset.e;if(!x||!V.places(x).includes(e))return;dmoSend({k:'put',t:x.slice(),s:e})};
A.dmoagain=()=>{if(dmoIsHost()&&DMO.st&&DMO.st.phase==='over'){clearTimeout(DMO.tm);DMO.ctx.finAt=0;DMO.ctx.cined=0;dmoBegin()}};

/* ---------- the table before the game ---------- */
async function dmoNew(){const r=await q(sb.from('jk_tables').insert({host:ME.id,len:'quick',seats:[ME.id,null,null,null],state:{g:'domino'}}).select('id').single());return r.id}
A.dmonew=async()=>{closeSheet();try{const id=await dmoNew();openPage('dmtable',id)}catch(e){toast(errMsg(e))}};
/* friends are asked in a message, with a button that brings them to the table */
A.dmoinvite=()=>{if(!DMO.t)return;const id=DMO.id;friendPicker('მოწვევა დომინოზე','მოწვევა',async sel=>{let n=0;for(const u of[...sel].slice(0,10)){try{const c=await rpc('start_dm',{other:u});await q(sb.from('messages').insert({conv_id:c,sender:ME.id,body:'🎲 დომინო: მაგიდა გავშალე, შემოდი!',media:{game:{gt:'domino',tbl:id}}}));n++}catch(e){}}
 closeSheet();toast(n?`მოწვევა გაეგზავნა: ${n}`:'მოწვევა ვერ გაიგზავნა')},new Set(DMO.t.seats.filter(Boolean)))};
A.dmoshare=()=>{if(DMO.id)shareLink(location.origin+'/#dmtable-'+DMO.id,'დომინო სუფრაზე: შემოდი, ერთი ადგილი გელოდება')};
A.dmojoin=async()=>{try{const seat=await rpc('jk_join',{p_table:DMO.id});DMO.seat=seat;if(DMO.t)DMO.t.seats[seat]=ME.id;dmoDraw()}catch(e){toast(e&&String(e.message||'').includes('album_full')?'მაგიდა უკვე სავსეა':errMsg(e))}};
A.dmoleave=async()=>{try{await rpc('jk_leave',{p_table:DMO.id});if(DMO.t&&DMO.seat>=0)DMO.t.seats[DMO.seat]=null;DMO.seat=-1;dmoDraw()}catch(e){toast(errMsg(e))}};
/* the host moves the guests round the table, so a friend can be a partner or an opponent */
A.dmorot=async()=>{if(!dmoIsHost()||DMO.t.status!=='wait')return;let s=DMO.t.seats.slice();try{const r=await q(sb.from('jk_tables').select('seats,status').eq('id',DMO.id).single());if(r.status!=='wait')return;s=r.seats.slice()}catch(e){}
 if(!s.slice(1).some(Boolean))return;s=[s[0],s[3],s[1],s[2]];DMO.t.seats=s;dmoDraw();try{await q(sb.from('jk_tables').update({seats:s,updated_at:new Date().toISOString()}).eq('id',DMO.id))}catch(e){toast(errMsg(e))}};
A.dmostart=async()=>{if(!dmoIsHost()||DMO.t.status!=='wait')return;
 try{const r=await q(sb.from('jk_tables').select('seats').eq('id',DMO.id).single());DMO.t.seats=r.seats}catch(e){}
 await loadProfiles(DMO.t.seats.filter(Boolean));DMO.t.status='play';dmoBegin()};
A.dmoclose=()=>{if(!dmoIsHost())return;confirmSheet('მაგიდის დახურვა','თამაში ყველასთვის დასრულდება.','დახურვა',async()=>{const id=DMO.id;await q(sb.from('jk_tables').update({status:'closed',updated_at:new Date().toISOString()}).eq('id',id));clearTimeout(DMO.tm);DMO.E=null;if(DMO.t)DMO.t.status='closed';dmoDraw()},true)};

/* ---------- drawing ---------- */
function dmoWaitHTML(){const t=DMO.t,host=dmoIsHost(),free=t.seats.some(x=>!x),mine=DMO.seat>=0;
 const seat=p=>{const u=t.seats[p];return `<div class="jkseat${u?'':' free'}">${u?av(u,46):'<span class="av jkempty" style="--s:46px" aria-hidden="true">+</span>'}<b>${u?esc(u===ME.id?'შენ':pname(u)):'ცარიელი'}</b><small>${u===t.host?'მასპინძელი':u?'მზადაა':'ბოტი ითამაშებს'}</small></div>`};
 const acts=host?`<div class="jkacts"><button class="btn" data-a="dmostart">${ic('play')}დაწყება</button><button class="btn ghost" data-a="dmoinvite">${ic('users')}მეგობრების მოწვევა</button>${t.seats.slice(1).some(Boolean)?`<button class="btn ghost sm" data-a="dmorot">${ic('turn')}წყვილების გადასმა</button>`:''}<button class="btn ghost sm" data-a="dmoclose">მაგიდის დახურვა</button></div>`
  :mine?`<p class="hint">მასპინძელი მალე დაიწყებს.</p><div class="jkacts"><button class="btn ghost sm" data-a="dmoleave">მაგიდიდან ადგომა</button></div>`
  :free?`<div class="jkacts"><button class="btn" data-a="dmojoin">მაგიდასთან დაჯდომა</button></div>`:'<p class="hint">მაგიდა სავსეა.</p>';
 return `<section class="tourcard jkwait"><h3>დომინო ოთხ კაცზე</h3><p class="note">${host?'მოიწვიე მეგობრები. ცარიელ ადგილებზე ბოტები ჩაჯდებიან, ასე რომ, ორნიც შეგიძლიათ ითამაშოთ.':'მეგობარმა დომინოს მაგიდა გაშალა. ცარიელ ადგილებზე ბოტები ითამაშებენ.'} ${DM_TO} ქულამდე, წყვილებში: პარტნიორი პირდაპირ გიზის.</p>
  <div class="dmteams"><div><h4 class="gvh">პირველი წყვილი</h4><div class="jkseats two">${seat(0)}${seat(2)}</div></div><div><h4 class="gvh">მეორე წყვილი</h4><div class="jkseats two">${seat(1)}${seat(3)}</div></div></div>${acts}</section>`}
const dmoTeam=(w,me)=>me>=0?(w===me%2?'თქვენ':'მეტოქეებმა'):(w===0?'პირველმა წყვილმა':'მეორე წყვილმა');
function dmoStatus(){const s=DMO.st,me=DMO.seat;if(!s||!s.phase)return '';
 if(!dmoIsHost()&&!DMO.hostHere&&DMO.t.status==='play')return 'მასპინძელი გავიდა. თამაში გაგრძელდება, როცა დაბრუნდება';
 if(s.phase==='over'){const w=s.score[0]>s.score[1]?0:1;return me>=0?(w===me%2?'მოიგეთ! 🎉':'ამჯერად მეტოქეებმა მოიგეს'):dmoTeam(w,-1)+' მოიგო'}
 if(s.phase==='roundover'){const r=s.res||{};return (r.kind==='block'?'თამაში ჩაიკეტა. ':'')+(r.win<0||r.win==null?'ფრე, ქულები არავის დაეწერა':`${dmoTeam(r.win,me)} წაიღეს: +${r.pts}`)}
 const l=s.last,pre=l&&l.pass&&l.p!==me?esc(dmoShort(l.p))+': პასი. ':'';
 if(DMO.wait)return 'იგზავნება…';
 if(me>=0&&s.cur===me){const sec=s.dl?Math.max(0,Math.round((s.dl-Date.now())/1000)):0,tm=sec&&sec<=DMO_TT?` · ${sec} წმ`:'';
  if(!dmoView().moves(0).length)return pre+'შესაფერისი ქვა არ გაქვს, პასი';return pre+(DMO.sel!=null?'აირჩიე, რომელ ბოლოს მიუდო':s.root?'შენი სვლაა':'იწყებ შენ. დადე '+(s.firstT?s.firstT.join('-'):'ექვს-ექვსი'))+tm}
 return pre+esc(dmoName(s.cur))+' ფიქრობს…'+(!s.root&&s.first&&s.firstT?` (${s.firstT.join('-')} მასთანაა)`:'')}
function dmoCount(){const s=DMO.st;if(!s||!s.dl||!dmoHere(DMO.id))return;const el=$('#dmo .status');if(el)el.textContent=dmoStatus()}
function dmoDraw(){const el=$('#dmo');if(!el||!DMO.t||!dmoHere(DMO.id))return;const t=DMO.t;
 const plain=h=>{el.className='view-pad game dmo';el.removeAttribute('data-g');el.innerHTML=h};
 if(t.status==='closed'){plain(empty('მაგიდა დაიხურა','მასპინძელმა თამაში დაასრულა.','<button class="btn" data-a="dmonew">ახალი მაგიდა</button>'));return}
 if(t.status==='wait'){plain(dmoWaitHTML());return}
 const s=DMO.st;if(!s||!s.phase){plain('<p class="hint">მასპინძელი ქვებს არიგებს…</p>');return}
 if(s.dn!==DMO.resDn){DMO.resDn=s.dn;DMO.resHide=0;DMO.resSnd=0;DMO.sel=null}
 const c=DMO.ctx;c.mode=DMO.seat>=0?'online':'netwatch';if(s.phase==='over'){if(!c.finAt)c.finAt=performance.now()}else{c.finAt=0;c.cined=0}
 const g3=g3Want(),me=DMO.seat,base=me>=0?me:0,us=me>=0?me%2:0,host=dmoIsHost(),live=s.phase==='play',V=dmoView();
 const myTurn=dmoMine(),ok=new Set(myTurn?V.moves(0).map(m=>m.i):[]);if(DMO.sel!=null&&!ok.has(DMO.sel))DMO.sel=null;V.sel=DMO.sel;
 const seat=(r,pos)=>{const p=(base+r)%4,u=t.seats[p];return `<div class="seat ${pos}${s.cur===p&&live?' turn':''}"${u?` data-vu="${u}"`:''}>${dmoAv(p,36)}<b>${esc(dmoName(p))}</b><span class="bt">${((s.counts||[])[p])||0} ქვა${r===2&&me>=0?' · პარტნიორი':''}</span></div>`};
 const line=V.line();if(!g3On()&&line.length!==DMO.lineN&&DMO.lineN!=null)gSnd('tile');DMO.lineN=line.length;
 const chain=line.map(x=>dmTile(x.t,x.root?'root':'')).join('');
 const hand=me>=0?DMO.hand.map((x,i)=>dmTile(x,(DMO.sel===i?'sel':'')+(ok.has(i)?' ok':''),` data-a="dmot" data-i="${i}"${ok.has(i)?'':' disabled'}`)).join(''):'';
 const e=V.ends(),order=[0,1,2,3].map(r=>(base+r)%4);let panel='';
 if(myTurn&&DMO.sel!=null&&e)panel=`<div class="dmends" role="group" aria-label="რომელ ბოლოს"><button class="btn ghost" data-a="dmoend" data-e="L">${ic('back')}მარცხნივ · ${e[0]}</button><button class="btn ghost" data-a="dmoend" data-e="R">მარჯვნივ · ${e[1]}<span class="flipx">${ic('back')}</span></button></div>`;
 if(s.phase==='roundover'&&s.res&&s.res.pips)panel=`<div class="sheet-tbl"><table><thead><tr><th></th>${order.map(p=>`<th>${esc(dmoShort(p))}</th>`).join('')}</tr></thead><tbody><tr><td>დარჩა ქულა</td>${order.map(p=>`<td>${+s.res.pips[p]||0}</td>`).join('')}</tr></tbody></table></div>`;
 if(s.phase==='over')panel=host?'<div class="jkacts"><button class="btn" data-a="dmoagain">ახალი პარტია იმავე მაგიდაზე</button><button class="btn ghost sm" data-a="dmoclose">მაგიდის დახურვა</button></div>':'<p class="hint">მასპინძელს შეუძლია ახალი პარტიის დაწყება.</p>';
 let res='';if(s.phase==='over'){const sc=s.score,win=me>=0&&sc[us]>sc[1-us];
  res=gResBox(DMO,{title:me<0?'თამაში დასრულდა':win?'მოიგეთ!':'წააგეთ',sub:me<0?dmoStatus():win?`შენ და ${esc(dmoShort((me+2)%4))} ${DM_TO} ქულა პირველებმა დააგროვეთ`:`მეტოქეებმა ${DM_TO} ქულა პირველებმა დააგროვეს`,kind:win?'win':'lose',
   more:`<div class="gendt"><span><b>${me>=0?'ჩვენ':'I წყვილი'}</b>${sc[us]}</span><span><b>${me>=0?'მეტოქეები':'II წყვილი'}</b>${sc[1-us]}</span></div>`,
   again:host?'<button class="btn gold" data-a="dmoagain">ახალი პარტია</button>':'',share:win?gShareBtn('domino',`მეგობრებთან, ${sc[us]}:${sc[1-us]}`):'',leave:'<button class="btn ghost" data-a="back">მაგიდიდან გასვლა</button>'})}
 const sc=s.score||[0,0],info=`<div class="ginfo"><span class="gscore" aria-label="ანგარიში: ${me>=0?'ჩვენ':'I წყვილი'} ${sc[us]}, ${me>=0?'მეტოქეები':'II წყვილი'} ${sc[1-us]}"><span>${me>=0?'ჩვენ':'I'}</span><b>${sc[us]}</b><i>:</i><b>${sc[1-us]}</b><span>${me>=0?'მეტოქეები':'II'}</span></span><span>ხელი ${s.round||1}, ${DM_TO} ქულამდე</span></div>`;
 const stage=`<div class="jt dmtab${g3?' g3jt':''}">${seat(2,'top')}${seat(1,'left')}${seat(3,'right')}<div class="trick dmchain${g3?' g3sr':''}" aria-label="მაგიდა">${chain||'<span class="muted">მაგიდა ცარიელია</span>'}</div>${g3?`<div class="g3 g3-domino${G3W.ready?'':' loading'}">${g3Rv()}${G3W.ready?'':'<span class="g3load" aria-hidden="true"></span>'}</div>`:''}</div>`;
 const turn=myTurn&&ok.size>0;gTurnSnd(DMO,turn);
 const mine=me>=0?`<div class="pl me${turn?' turn':''}" data-vu="${ME.id}"><span class="plav">${av('me',34)}</span><span class="pln"><b>${esc(ME.name)}</b><span class="muted">შენ და ${esc(dmoShort((me+2)%4))} ერთ წყვილში ხართ</span></span></div><div class="dmhand${g3?' g3sr':''}" aria-label="შენი ქვები">${hand}</div>`
  :`<div class="pl"><span class="muted">შენ უყურებ. ქვები მხოლოდ მოთამაშეებს უჩანთ.</span></div>`;
 const st=dmoStatus()+(turn&&g3&&DMO.sel==null&&s.root?' · შეეხე ქვას ან გადაათრიე':'');
 const Pp=gShellParts({stage,mid:stage,top:gTop('დომინო ონლაინ',null,'back')+info,bot:`${mine}<div class="status${turn?' mine':''}" role="status">${st}</div>${panel}`,res});
 el.className='view-pad game dmo gx'+(Pp.w?' is3d':'');el.dataset.g='domino';el.innerHTML=Pp.html;g3After('dmo')}
/* the result counts once per person per game, like a game against the computer */
function dmoResult(){const s=DMO.st;if(s&&s.phase!=='over')DMO.res=false;if(!s||s.phase!=='over'||DMO.seat<0||DMO.res)return;DMO.res=true;const k='dmores-'+DMO.id+'-'+s.dn;
 try{if(localStorage.getItem(k))return;localStorage.setItem(k,'1')}catch(e){}
 const us=DMO.seat%2;gameResult('domino',s.score[us]>s.score[1-us])}
