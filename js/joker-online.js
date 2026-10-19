/* online joker with friends: the host's app deals and keeps the rules, everyone else sends moves.
   empty seats are played by bots. a hand is stored so that only its owner and the host can read it.
   a person who left the table (or is silent for a minute) gets an automatic move, so nobody waits forever */
const JO={};
function joReset(){Object.assign(JO,{id:null,t:null,st:null,seat:-1,hand:[],deal:-1,ch:null,E:null,q:Promise.resolve(),tm:null,tw:null,tick:null,here:new Set(),hostHere:true,pj:null,res:false,wait:false,wt:null,err:0})}
joReset();
const JO_TURN=60;
const joSame=(a,b)=>!!a&&!!b&&(a.j?a.j===b.j:!b.j&&a.s===b.s&&a.r===b.r);
const joIsHost=()=>!!JO.t&&!!ME&&JO.t.host===ME.id;
const joHere=id=>!!S.page&&S.page.id==='jktable'&&+S.page.arg===id&&JO.id===id;
const joBotHue=n=>[20,200,120][JK_BOTS.indexOf(n)]??160;
const joName=p=>{const u=JO.t&&JO.t.seats[p];if(u)return u===ME.id?'შენ':pname(u);const b=JO.st&&JO.st.bots&&JO.st.bots[p];return b?b+' (ბოტი)':'ცარიელი'};
const joShort=p=>{const u=JO.t&&JO.t.seats[p];if(u)return u===ME.id?'შენ':String(pname(u)).split(' ')[0];return (JO.st&&JO.st.bots&&JO.st.bots[p])||'–'};
const joAv=(p,s)=>{const u=JO.t&&JO.t.seats[p];if(u)return av(u,s);const b=JO.st&&JO.st.bots&&JO.st.bots[p];return b?avAny({n:b,h:joBotHue(b)},s):`<span class="av jkempty" style="--s:${s}px" aria-hidden="true">+</span>`};

PG.jktable={r(id){id=+id;view.innerHTML=pgHead('ჯოკერი ონლაინ',`<button class="ibtn" data-a="jkoshare" aria-label="ბმულის გაზიარება">${ic('share')}</button>${gTools()}`)+`<div class="view-pad game jko" id="jko">${skel(2)}</div>`;joOpen(id)}};


function joStop(){clearTimeout(JO.tm);clearTimeout(JO.tw);clearTimeout(JO.wt);clearInterval(JO.tick);if(JO.ch){try{JO.ch.untrack()}catch(e){}sb.removeChannel(JO.ch)}joReset()}

async function joOpen(id){joStop();JO.id=id;S.chanCleanup=()=>{joStop();fsExit()};fsEnter();g3Intro('jko');let t=null;
 try{t=await q(sb.from('jk_tables').select('*').eq('id',id).maybeSingle())}catch(e){}
 if(!joHere(id))return;const el=$('#jko');
 if(!t||t.status==='closed'){el.innerHTML=empty('ეს მაგიდა აღარ არსებობს','ახალი მაგიდის გასაშლელად თამაშებში აირჩიე ჯოკერი და „მეგობრებთან ონლაინ“','<button class="btn" data-a="jkonew">ახალი მაგიდა</button>');return}
 JO.t=t;JO.st=t.state;JO.seat=t.seats.indexOf(ME.id);
 await loadProfiles(t.seats.filter(Boolean));
 if(!joHere(id))return;
 if(t.status==='play'&&joIsHost()){try{await joResume()}catch(e){toast(errMsg(e))}}
 else if(t.status!=='wait'&&JO.seat>=0)await joFetchHand();
 if(!joHere(id))return;
 const ch=sb.channel('jk-'+id,{config:{presence:{key:ME.id}}});
 ch.on('postgres_changes',{event:'UPDATE',schema:'public',table:'jk_tables',filter:'id=eq.'+id},pl=>joTable(pl.new))
  .on('postgres_changes',{event:'*',schema:'public',table:'jk_hands',filter:'table_id=eq.'+id},pl=>{const r=pl.new;if(!r||joIsHost()||r.seat!==JO.seat||r.user_id!==ME.id)return;JO.hand=sortHand((r.cards||[]).slice());JO.wait=false;joDraw()});
 if(joIsHost())ch.on('postgres_changes',{event:'INSERT',schema:'public',table:'jk_moves',filter:'table_id=eq.'+id},pl=>joMove(pl.new));
 ch.on('presence',{event:'sync'},()=>{const ps=ch.presenceState();JO.here=new Set(Object.keys(ps));JO.hostHere=!!JO.t&&JO.here.has(JO.t.host);if(joIsHost()&&JO.E)joNext();else joDraw()})
  .subscribe(s=>{if(s==='SUBSCRIBED')ch.track({at:Date.now()}).catch(()=>{})});
 JO.ch=ch;JO.tick=setInterval(joCount,1000);
 joDraw();joResult()}

/* someone joined, the host published a step, or the table was closed */
function joTable(r){if(!r||r.id!==JO.id||!JO.t)return;
 if(joIsHost()){JO.t.seats=r.seats;if(JO.t.status==='wait'){JO.t.len=r.len;JO.t.status=r.status}}
 else{const was=JO.st&&JO.st.cur;JO.t=r;JO.st=r.state;JO.seat=r.seats.indexOf(ME.id);if(!JO.st||JO.st.cur!==was||JO.st.cur!==JO.seat){JO.wait=false;clearTimeout(JO.wt)}}
 loadProfiles(r.seats.filter(Boolean)).then(async()=>{if(!joIsHost())await joSync();joDraw();joResult()})}
async function joSync(){const s=JO.st;if(JO.seat<0||!s||!s.counts)return;if(s.deal!==JO.deal||s.counts[JO.seat]!==JO.hand.length)await joFetchHand()}
async function joFetchHand(){const id=JO.id,seat=JO.seat;if(seat<0)return;JO.deal=JO.st?JO.st.deal:-1;
 try{const r=await q(sb.from('jk_hands').select('cards').eq('table_id',id).eq('seat',seat).maybeSingle());if(JO.id===id&&JO.seat===seat)JO.hand=sortHand(((r&&r.cards)||[]).slice())}catch(e){}joDraw()}

/* ---------- the host's engine: the same rules and bots as the game against the computer ---------- */
const joEngine=()=>({legal:JK.legal,winner:JK.winner,val:JK.val,forbidden:JK.forbidden,botBid:JK.botBid,botPlay:JK.botPlay,botTrump:JK.botTrump,pts:JK.pts});
function joBegin(){const t=JO.t,bots=[null,null,null,null],prev=JO.E;let bi=0;t.seats.forEach((u,i)=>{if(!u)bots[i]=JK_BOTS[bi++]});
 const E=JO.E=joEngine();Object.assign(E,{len:t.len,h:0,score:[0,0,0,0],hist:[],dealer:Math.floor(Math.random()*4),bots,deal:prev?prev.deal:(JO.st&&JO.st.deal)||0,mv:prev?prev.mv:(JO.st&&JO.st.mv)||0});
 joDeal(true,true)}
function joDeal(adv,start){const E=JO.E;const n=JSEQ[E.len][E.h];E.n=n;if(adv)E.dealer=(E.dealer+1)%4;const d=shuffle(jDeck());
 E.first3=[0,1,2,3].map(i=>d.slice(i*n,i*n+3));E.hands=[0,1,2,3].map(i=>sortHand(d.slice(i*n,(i+1)*n)));
 E.bids=[null,null,null,null];E.taken=[0,0,0,0];E.trick=[];E.win=null;E.cur=(E.dealer+1)%4;E.deal=(E.deal||0)+1;
 if(n<9){const tc=d[4*n];E.trumpCard=tc;E.trump=tc.j?null:tc.s;E.phase='bid'}else{E.trumpCard=null;E.trump=null;E.phase='trump'}
 joPub(true,start)}
const joVis=p=>{const E=JO.E;return E.phase==='trump'?E.first3[p]:E.hands[p]};
const joHuman=p=>!!JO.t.seats[p];
function joDelay(){const E=JO.E;if(!E||E.win!=null||E.cur<0||!['trump','bid','play'].includes(E.phase))return 0;const u=JO.t.seats[E.cur];if(!u)return E.phase==='play'?850:800;return u===ME.id||JO.here.has(u)?JO_TURN*1000:3000}
/* write the hands that changed, then the public state; the order matters, everyone reads their hand after the state */
function joPub(hs,start){const E=JO.E;if(!E)return;
 E.dl=E.cur>=0&&joHuman(E.cur)&&E.win==null&&['trump','bid','play'].includes(E.phase)?Date.now()+joDelay():0;
 const st={phase:E.phase,len:E.len,h:E.h,n:E.n,dealer:E.dealer,cur:E.cur,bids:E.bids,taken:E.taken,trick:E.trick,win:E.win,score:E.score,hist:E.hist,trump:E.trump,trumpCard:E.trumpCard,bots:E.bots,deal:E.deal,counts:[0,1,2,3].map(p=>joVis(p).length),mv:E.mv,dl:E.dl};
 JO.st=JSON.parse(JSON.stringify(st));const status=E.phase==='over'?'over':'play';JO.t.status=status;
 const seats=hs===true?[0,1,2,3]:hs||[],id=JO.id,rows=seats.map(p=>({table_id:id,seat:p,user_id:JO.t.seats[p]||null,cards:joVis(p)}));
 const pay={state:st,status,updated_at:new Date().toISOString()};if(start)pay.seats=JO.t.seats;
 JO.q=JO.q.then(async()=>{if(rows.length)await q(sb.from('jk_hands').upsert(rows,{onConflict:'table_id,seat'}));await q(sb.from('jk_tables').update(pay).eq('id',id));JO.err=0})
  .catch(e=>{if(JO.id===id&&!JO.err++)toast('კავშირი შეფერხდა: '+errMsg(e))});
 if(JO.seat>=0)JO.hand=joVis(JO.seat);
 joDraw();joNext();joResult()}
function joNext(){const E=JO.E;clearTimeout(JO.tm);if(!E||!joIsHost())return;
 if(E.phase==='handover'){JO.tm=setTimeout(joHandNext,8000);joDraw();return}
 if(E.phase==='over'||E.cur<0||E.win!=null)return;
 const p=E.cur,u=JO.t.seats[p];let ms=joDelay();
 if(u&&E.dl)ms=Math.max(0,E.dl-Date.now());if(u&&u!==ME.id&&!JO.here.has(u))ms=Math.min(ms,3000);
 JO.tm=setTimeout(()=>joAuto(p),ms);joDraw()}
function joAuto(p){const E=JO.E;if(!E||E.cur!==p||E.win!=null||!joIsHost())return;
 if(joHuman(p)&&JO.t.seats[p]===ME.id)toast('დრო ამოიწურა, სვლა ავტომატურად გაკეთდა');
 if(E.phase==='trump')joApply(p,{k:'trump',s:E.botTrump(p)});
 else if(E.phase==='bid')joApply(p,{k:'bid',v:E.botBid(p)});
 else if(E.phase==='play'){const m=E.botPlay(p);joApply(p,{k:'card',c:m.c,jm:m.jm,js:m.js})}}
function joApply(p,m){const E=JO.E;if(!E||!m||p!==E.cur||E.win!=null)return false;
 if(E.phase==='trump'&&m.k==='trump'){E.trump=SUITS.includes(m.s)?m.s:null;E.phase='bid';E.cur=(E.dealer+1)%4;joPub(true);return true}
 if(E.phase==='bid'&&m.k==='bid'){const v=Math.floor(Number(m.v));if(!(v>=0&&v<=E.n)||v===E.forbidden(p))return false;E.bids[p]=v;
  if(E.bids.every(x=>x!==null)){E.phase='play';E.cur=(E.dealer+1)%4}else E.cur=(p+1)%4;joPub();return true}
 if(E.phase==='play'&&m.k==='card'){const h=E.hands[p],c=h.find(x=>joSame(x,m.c));if(!c||!E.legal(p).includes(c))return false;
  const lead=!E.trick.length;h.splice(h.indexOf(c),1);
  E.trick.push({p,card:c,jm:c.j?(m.jm==='lo'?'lo':'hi'):null,js:c.j&&lead?(SUITS.includes(m.js)?m.js:SUITS[Math.floor(Math.random()*4)]):null});
  if(E.trick.length<4){E.cur=(p+1)%4;joPub([p]);return true}
  const w=E.winner();E.taken[w]++;E.win=w;E.cur=-1;joPub([p]);
  clearTimeout(JO.tw);JO.tw=setTimeout(()=>{if(JO.E!==E)return;E.trick=[];E.win=null;if(!E.hands.some(x=>x.length)){joEndHand();return}E.cur=w;joPub()},1700);return true}
 return false}
function joEndHand(){const E=JO.E;jScore(E);E.cur=-1;E.phase=E.h>=JSEQ[E.len].length?'over':'handover';joPub()}
function joHandNext(){const E=JO.E;if(E&&E.phase==='handover'&&joIsHost())joDeal(true)}
/* a move from a friend: it counts only from the person sitting in that seat, for this deal, when it is their turn */
function joMove(m){const E=JO.E;if(!E||!m||m.table_id!==JO.id||m.id<=E.mv)return false;E.mv=m.id;
 if(JO.t.seats[m.seat]!==m.user_id)return false;const mv=m.move||{};if(mv.d!==E.deal)return false;return joApply(m.seat,mv)}
/* the host came back: rebuild the game from the table and catch up on moves made meanwhile */
async function joResume(){const t=JO.t,s=t.state;if(!s){joBegin();return}
 const rows=await q(sb.from('jk_hands').select('seat,cards').eq('table_id',t.id));
 const E=JO.E=joEngine();Object.assign(E,{len:s.len,h:s.h,n:s.n,dealer:s.dealer,cur:s.cur,bids:s.bids,taken:s.taken,trick:s.trick||[],win:s.win,score:s.score,hist:s.hist||[],trump:s.trump,trumpCard:s.trumpCard,bots:s.bots,deal:s.deal,mv:s.mv||0,phase:s.phase,hands:[[],[],[],[]],first3:[[],[],[],[]]});
 rows.forEach(r=>{E.hands[r.seat]=sortHand((r.cards||[]).slice())});
 if(E.phase==='trump'){joDeal(false);return}
 if(E.win!=null){const w=E.win;E.trick=[];E.win=null;if(!E.hands.some(x=>x.length)){joEndHand();return}E.cur=w}
 let ok=false;try{const ms=await q(sb.from('jk_moves').select('*').eq('table_id',t.id).gt('id',E.mv).order('id').limit(50));for(const m of ms)if(joMove(m))ok=true}catch(e){}
 if(!ok)joPub()}

/* ---------- moves from this screen ---------- */
async function joSend(mv){const s=JO.st;if(!s||JO.seat<0||s.cur!==JO.seat||JO.wait)return;
 if(joIsHost()){if(!joApply(JO.seat,mv))toast('ეს სვლა არ გამოდის');return}
 mv.d=s.deal;JO.wait=true;if(mv.k==='card'){const i=JO.hand.findIndex(c=>joSame(c,mv.c));if(i>=0)JO.hand.splice(i,1)}joDraw();
 clearTimeout(JO.wt);JO.wt=setTimeout(()=>{if(JO.wait){JO.wait=false;joFetchHand()}},9000);
 try{await q(sb.from('jk_moves').insert({table_id:JO.id,seat:JO.seat,user_id:ME.id,move:mv}))}catch(e){JO.wait=false;toast(errMsg(e));joFetchHand()}}
A.jkobid=t=>joSend({k:'bid',v:+t.dataset.v});
A.jkotrump=t=>joSend({k:'trump',s:t.dataset.s||null});
A.jkocard=t=>{const s=JO.st,c=JO.hand[+t.dataset.i];if(!s||!c||s.phase!=='play'||s.cur!==JO.seat||JO.wait||s.win!=null)return;if(!JK.legal.call({hands:{[JO.seat]:JO.hand},trick:s.trick,trump:s.trump},JO.seat).includes(c))return;
 if(!c.j){joSend({k:'card',c:{s:c.s,r:c.r}});return}JO.pj=c;jkJokerSheet(!s.trick.length,'jkoj')};
A.jkoj=t=>{closeSheet();const c=JO.pj;JO.pj=null;if(c)joSend({k:'card',c:{j:c.j},jm:t.dataset.m,js:t.dataset.s||null})};
A.jkonext=()=>{if(joIsHost())joHandNext()};
A.jkoagain=()=>{if(joIsHost()&&JO.st&&JO.st.phase==='over'){clearTimeout(JO.tm);joBegin()}};

/* ---------- the table before the game ---------- */
A.jkonew=async()=>{try{const r=await q(sb.from('jk_tables').insert({host:ME.id,len:'quick',seats:[ME.id,null,null,null]}).select('id').single());openPage('jktable',r.id)}catch(e){toast(errMsg(e))}};
A.jkolen=async t=>{if(!joIsHost()||JO.t.status!=='wait')return;const len=t.dataset.m==='full'?'full':'quick';JO.t.len=len;joDraw();try{await q(sb.from('jk_tables').update({len,updated_at:new Date().toISOString()}).eq('id',JO.id))}catch(e){toast(errMsg(e))}};
A.jkoinvite=()=>{if(!JO.t)return;friendPicker('მოწვევა ჯოკერზე','მოწვევა',async sel=>{const n=await rpc('jk_invite',{p_table:JO.id,p_users:sel});closeSheet();toast(n?`მოწვევა გაეგზავნა: ${n}`:'მოწვევა ვერ გაიგზავნა')},new Set(JO.t.seats.filter(Boolean)))};
A.jkoshare=()=>{if(JO.id)shareLink(location.origin+'/#jktable-'+JO.id,'ჯოკერი სუფრაზე: შემოდი, ერთი ადგილი გელოდება')};
A.jkojoin=async()=>{try{const seat=await rpc('jk_join',{p_table:JO.id});JO.seat=seat;if(JO.t)JO.t.seats[seat]=ME.id;joDraw()}catch(e){toast(e&&String(e.message||'').includes('album_full')?'მაგიდა უკვე სავსეა':errMsg(e))}};
A.jkoleave=async()=>{try{await rpc('jk_leave',{p_table:JO.id});if(JO.t&&JO.seat>=0)JO.t.seats[JO.seat]=null;JO.seat=-1;joDraw()}catch(e){toast(errMsg(e))}};
A.jkostart=async()=>{if(!joIsHost()||JO.t.status!=='wait')return;
 try{const r=await q(sb.from('jk_tables').select('seats,len').eq('id',JO.id).single());JO.t.seats=r.seats;JO.t.len=r.len}catch(e){}
 await loadProfiles(JO.t.seats.filter(Boolean));JO.t.status='play';joBegin()};
A.jkoclose=()=>{if(!joIsHost())return;confirmSheet('მაგიდის დახურვა','თამაში ყველასთვის დასრულდება.','დახურვა',async()=>{const id=JO.id;await q(sb.from('jk_tables').update({status:'closed',updated_at:new Date().toISOString()}).eq('id',id));clearTimeout(JO.tm);clearTimeout(JO.tw);JO.E=null;if(JO.t)JO.t.status='closed';joDraw()},true)};

/* ---------- drawing ---------- */
function joWaitHTML(){const t=JO.t,host=joIsHost(),free=t.seats.some(x=>!x),mine=JO.seat>=0;
 const seats=[0,1,2,3].map(p=>{const u=t.seats[p];return `<div class="jkseat${u?'':' free'}">${u?av(u,46):'<span class="av jkempty" style="--s:46px" aria-hidden="true">+</span>'}<b>${u?esc(u===ME.id?'შენ':pname(u)):'ცარიელი'}</b><small>${u===t.host?'მასპინძელი':u?'მზადაა':'ბოტი ითამაშებს'}</small></div>`}).join('');
 const lens=`<div class="seg" role="group" aria-label="თამაშის სიგრძე"><button data-a="jkolen" data-m="quick" aria-pressed="${t.len!=='full'}"${host?'':' disabled'}>სწრაფი · 8 ხელი</button><button data-a="jkolen" data-m="full" aria-pressed="${t.len==='full'}"${host?'':' disabled'}>სრული · 24 ხელი</button></div>`;
 const acts=host?`<div class="jkacts"><button class="btn" data-a="jkostart">${ic('play')}დაწყება</button><button class="btn ghost" data-a="jkoinvite">${ic('users')}მეგობრების მოწვევა</button><button class="btn ghost sm" data-a="jkoclose">მაგიდის დახურვა</button></div>`
  :mine?`<p class="hint">მასპინძელი მალე დაიწყებს.</p><div class="jkacts"><button class="btn ghost sm" data-a="jkoleave">მაგიდიდან ადგომა</button></div>`
  :free?`<div class="jkacts"><button class="btn" data-a="jkojoin">მაგიდასთან დაჯდომა</button></div>`:'<p class="hint">მაგიდა სავსეა.</p>';
 return `<section class="tourcard jkwait"><h3>ჯოკერი ოთხ კაცზე</h3><p class="note">${host?'მოიწვიე მეგობრები. ცარიელ ადგილებზე ბოტები ჩაჯდებიან, ასე რომ, ორნიც შეგიძლიათ ითამაშოთ.':'მეგობარმა ჯოკერის მაგიდა გაშალა. ცარიელ ადგილებზე ბოტები ითამაშებენ.'}</p><div class="jkseats">${seats}</div>${lens}${acts}</section>`}
function joStatus(){const s=JO.st,me=JO.seat;if(!s)return '';
 if(!joIsHost()&&!JO.hostHere&&JO.t.status==='play')return 'მასპინძელი გავიდა. თამაში გაგრძელდება, როცა დაბრუნდება';
 const sec=s.dl?Math.max(0,Math.round((s.dl-Date.now())/1000)):0,tm=sec&&sec<=JO_TURN?` · ${sec} წმ`:'';
 if(s.phase==='trump')return s.cur===me?'ნახე პირველი სამი კარტი და აირჩიე კოზირი'+tm:esc(joName(s.cur))+' ირჩევს კოზირს…';
 if(s.phase==='bid'){if(s.cur!==me)return esc(joName(s.cur))+' ამბობს…';const f=JK.forbidden.call({dealer:s.dealer,n:s.n,bids:s.bids},me);return 'რამდენს წაიღებ?'+(f>=0?` დამრიგებელი ხარ, ${f}-ს ვერ იტყვი`:'')+tm}
 if(s.phase==='play'){if(s.win!=null)return s.win===me?'ეს ხელი შენ წაიღე':'ხელი წაიღო: '+esc(joName(s.win));if(JO.wait)return 'იგზავნება…';return s.cur===me?'შენი სვლაა'+tm:esc(joName(s.cur))+' ფიქრობს…'}
 if(s.phase==='handover'){const{hand,prem}=jLast(s.hist),x=me>=0&&hand?hand.p[me]+(prem?prem.p[me]:0):null;return 'ხელი დასრულდა'+(x!=null?`. შენ: ${x>0?'+':''}${x}`:'')+(prem?' · სექციის პრემია':'')}
 if(s.phase==='over'){const mx=Math.max(...s.score),w=[0,1,2,3].filter(p=>s.score[p]===mx);return me>=0&&w.includes(me)?'მოიგე! 🎉':'თამაში დასრულდა. გაიმარჯვა: '+w.map(p=>esc(joName(p))).join(', ')}
 return ''}
function joCount(){const s=JO.st;if(!s||!s.dl||!joHere(JO.id))return;const el=$('#jko .status');if(el)el.innerHTML=joStatus()}
function joDraw(){const el=$('#jko');if(!el||!JO.t||!joHere(JO.id))return;const t=JO.t;
 const plain=h=>{el.className='view-pad game jko';el.innerHTML=h};
 if(t.status==='closed'){plain(empty('მაგიდა დაიხურა','მასპინძელმა თამაში დაასრულა.','<button class="btn" data-a="jkonew">ახალი მაგიდა</button>'));return}
 if(t.status==='wait'){plain(joWaitHTML());return}
 const s=JO.st;if(!s){plain('<p class="hint">მასპინძელი კარტს არიგებს…</p>');return}const g3=g3Want();if(s.deal!==JO.resDeal){JO.resDeal=s.deal;JO.resHide=0;JO.resSnd=0}
 const me=JO.seat,base=me>=0?me:0,P=k=>(base+k)%4,host=joIsHost(),live=['bid','play','trump'].includes(s.phase);
 const seat=(p,pos)=>`<div class="seat ${pos}${s.cur===p&&s.win==null&&live?' turn':''}">${joAv(p,38)}<b>${esc(joName(p))}</b><span class="bt" aria-label="ნათქვამი ${s.bids[p]??'ჯერ არა'}, წაღებული ${s.taken[p]}">${s.bids[p]??'–'} / ${s.taken[p]}</span><span>${s.score[p]}</span></div>`;
 const tr=(s.trick||[]).map(e=>{const h=jCardHTML(e.card).replace('class="card','class="card p'+((e.p-base+4)%4));return e.card.j?h.replace('</div>',`<span class="jm">${e.jm==='hi'?'მაღალი':'დაბალი'}${e.js?' '+SY[e.js]:''}</span></div>`):h}).join('');
 const trumpTxt=s.phase==='trump'?'კოზირი ირჩევა':s.trump?`კოზირი: <b style="color:${isRed(s.trump)?'#FF8A9A':'inherit'}">${SY[s.trump]}</b> ${SN[s.trump]}`:'უკოზირო';
 const myTurn=me>=0&&s.cur===me&&s.win==null&&!JO.wait;
 const L=myTurn&&s.phase==='play'?JK.legal.call({hands:{[me]:JO.hand},trick:s.trick,trump:s.trump},me):[];
 let hand='';if(me>=0){hand=s.phase==='trump'?JO.hand.map(c=>jCardHTML(c)).join('')+(s.cur===me?'<div class="card" style="opacity:.25" aria-hidden="true"></div>'.repeat(Math.max(0,s.n-JO.hand.length)):'')
  :JO.hand.map((c,i)=>`<button class="card${c.j?' jk':''}${!c.j&&isRed(c.s)?' red':''}" data-a="jkocard" data-i="${i}" aria-label="${cardName(c)}"${L.includes(c)?'':' disabled'}>${c.j?'<i>★</i>ჯოკერი':`<span>${rkTxt(c.r)}</span><span class="s2">${SY[c.s]}</span>`}</button>`).join('')}
 let panel='';
 if(myTurn&&s.phase==='trump')panel=`<div class="suits">${SUITS.map(x=>`<button class="${isRed(x)?'red':''}" data-a="jkotrump" data-s="${x}" aria-label="${SN[x]}">${SY[x]}</button>`).join('')}</div><button class="btn ghost" data-a="jkotrump" data-s="" style="align-self:center">უკოზირო</button>`;
 else if(myTurn&&s.phase==='bid'){const f=JK.forbidden.call({dealer:s.dealer,n:s.n,bids:s.bids},me);panel=`<div class="bids" role="group" aria-label="ნათქვამი">${Array.from({length:s.n+1},(_,v)=>`<button data-a="jkobid" data-v="${v}"${v===f?' disabled':''}>${v===0?'პასი':v}</button>`).join('')}</div>`}
 else if((s.phase==='handover'||s.phase==='over')&&s.hist.length){
  panel=jLastHTML(s.hist,s.score,[0,1,2,3].map(joShort))
   +(s.phase==='over'?(host?'<div class="jkacts"><button class="btn" data-a="jkoagain">ახალი პარტია იმავე მაგიდაზე</button><button class="btn ghost sm" data-a="jkoclose">მაგიდის დახურვა</button></div>':'<p class="hint">მასპინძელს შეუძლია ახალი პარტიის დაწყება.</p>')
    :host?'<button class="btn" data-a="jkonext" style="align-self:flex-start">შემდეგი ხელი</button>':'<p class="hint">შემდეგი ხელი რამდენიმე წამში დაირიგდება.</p>')}
 const turn=myTurn&&live;gTurnSnd(JO,turn);
 const mine=me>=0?`<div class="pl me${turn?' turn':''}">${av('me',34)}<span class="pln"><b>${esc(ME.name)}</b><span class="muted">${s.bids[me]??'–'} / ${s.taken[me]} · ${s.score[me]} ქულა</span></span><span class="sp"></span><button class="btn ghost sm" data-a="jkosheet">ქულები</button></div><div class="hand${g3?' g3sr':''}" aria-label="შენი კარტები">${hand}</div>`
  :`<div class="pl"><span class="muted">შენ უყურებ. კარტები მხოლოდ მოთამაშეებს უჩანთ.</span><span class="sp"></span><button class="btn ghost sm" data-a="jkosheet">ქულები</button></div>`;
 const stage=`<div class="jt${g3?' g3jt':''}">${seat(P(2),'top')}${seat(P(1),'left')}${seat(P(3),'right')}<div class="trick" aria-label="მაგიდა">${tr}</div>${g3?`<div class="g3 g3-joker${G3W.ready?'':' loading'}">${g3Rv()}${G3W.ready?'':'<span class="g3load" aria-hidden="true"></span>'}</div>`:''}</div>`;
 const info=`<div class="ginfo"><span class="trump">${trumpTxt}</span><span>ხელი ${Math.min(s.h+1,JSEQ[s.len].length)}/${JSEQ[s.len].length} · ${s.n} კარტი</span></div>`;
 let res='';if(s.phase==='over'){const mx=Math.max(...s.score),w=[0,1,2,3].filter(p=>s.score[p]===mx),win=me>=0&&w.includes(me),order=[0,1,2,3].sort((a,b)=>s.score[b]-s.score[a]);
  res=gResBox(JO,{title:win?'მოიგე!':'თამაში დასრულდა',sub:win?'ყველაზე მეტი ქულა შენ დააგროვე':'გაიმარჯვა: '+w.map(p=>esc(joName(p))).join(', '),kind:win?'win':'lose',more:`<div class="gendt">${order.map(p=>`<span><b>${esc(joShort(p))}</b>${s.score[p]}</span>`).join('')}</div>`,
   again:host?'<button class="btn gold" data-a="jkoagain">ახალი პარტია</button>':'',leave:'<button class="btn ghost" data-a="back">მაგიდიდან გასვლა</button>'})}
 const Pp=gShellParts({stage,mid:stage,top:gTop('ჯოკერი ონლაინ',null,'back')+info,bot:`${mine}<div class="status${turn?' mine':''}" role="status">${joStatus()}</div>${panel}`,res});
 el.className='view-pad game jko gx'+(Pp.w?' is3d':'');el.innerHTML=Pp.html;g3After('jko')}
A.jkosheet=()=>{const s=JO.st;if(!s||!s.hist||!s.hist.length){toast('ქულების ფურცელი პირველი ხელის შემდეგ შეივსება');return}
 sheet(head('ქულების ფურცელი')+`<div class="ph-body">${jSheetHTML(s.hist,s.score,[0,1,2,3].map(joShort))}</div>`)};
/* the result counts once per person per table, like a game against the computer */
function joResult(){const s=JO.st;if(s&&s.phase!=='over')JO.res=false;if(!s||s.phase!=='over'||JO.seat<0||JO.res)return;JO.res=true;const k='jkres-'+JO.id+'-'+s.deal;
 try{if(localStorage.getItem(k))return;localStorage.setItem(k,'1')}catch(e){}
 const mx=Math.max(...s.score);gameResult('joker',s.score[JO.seat]===mx)}
