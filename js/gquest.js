/* ---------- games: three small tasks a day, and the seasons' events ----------
   the day's tasks are the same for everyone (picked from the date); each pays a few coins once the server can pay them.
   events come with the calendar: the New Year cup, Easter egg tapping, Tbilisoba's nardi cup, Giorgoba's chess */
const QPOOL=[
 {id:'win3',n:'მოიგე 3 პარტია',d:'ნებისმიერ თამაშში',ev:'win',goal:3,c:20},
 {id:'nardi',n:'მოიგე ნარდი',ev:'win',gk:'nardi',goal:1,c:15},
 {id:'chess',n:'მოიგე ჭადრაკი',ev:'win',gk:'chess',goal:1,c:15},
 {id:'shashi',n:'მოიგე შაში',ev:'win',gk:'shashi',goal:1,c:15},
 {id:'joker',n:'ითამაშე ჯოკერი ბოლომდე',ev:'end',gk:'joker',goal:1,c:15},
 {id:'durak',n:'ორჯერ არ გახდე დურაკი',ev:'win',gk:'durak',goal:2,c:15},
 {id:'bura',n:'მოიგე ბურას მატჩი',ev:'win',gk:'bura',goal:1,c:20},
 {id:'domino',n:'მოიგე დომინო',ev:'win',gk:'domino',goal:1,c:20},
 {id:'egg',n:'კვერცხის ჭახუნში გაიმარჯვე',ev:'win',gk:'egg',goal:1,c:10},
 {id:'loto',n:'ითამაშე ლოტო',ev:'lotoend',goal:1,c:10},
 {id:'pz',n:'ამოხსენი დღის ამოცანა',ev:'pz',goal:1,c:15},
 {id:'sprint',n:'სპრინტში იპოვე 5 მატი',ev:'sprint',goal:5,max:1,c:20},
 {id:'online',n:'ითამაშე ადამიანთან ონლაინ',ev:'online',goal:1,c:20},
 {id:'mars',n:'მოიგე ნარდი მარსით',ev:'mars',goal:1,c:25},
 {id:'three',n:'ითამაშე სამი სხვადასხვა თამაში',ev:'end',goal:3,distinct:1,c:20}];
const qDay=()=>pzDay();
function qToday(){const R=jdRng(jdSeed('quests:'+qDay())),L=QPOOL.slice();for(let i=L.length-1;i>0;i--){const j=Math.floor(R()*(i+1));[L[i],L[j]]=[L[j],L[i]]}return L.slice(0,3)}
const qState=()=>{const s=store.get('q:'+qDay(),null);return s&&s.p?s:{p:{},got:{},seen:{}}};
/* something happened in a game: move the day's tasks along, and the season's event */
function qEvent(ev,o={}){const s=qState();let ch=false;
 for(const q of qToday()){if(q.ev!==ev||q.gk&&q.gk!==o.gk||s.got[q.id])continue;
  if(q.distinct){const set=new Set(s.seen[q.id]||[]);if(!o.gk||set.has(o.gk))continue;set.add(o.gk);s.seen[q.id]=[...set];s.p[q.id]=set.size}
  else if(q.max)s.p[q.id]=Math.max(s.p[q.id]||0,o.v||0);else s.p[q.id]=(s.p[q.id]||0)+1;
  ch=true;if(s.p[q.id]>=q.goal&&!s.done)toast(`✓ დავალება შესრულდა: ${q.n}`)}
 if(ch)store.set('q:'+qDay(),s);evEvent(ev,o)}
{const gr=gameResult;gameResult=function(game,win){const g=String(game||'');qEvent('end',{gk:g});if(win)qEvent('win',{gk:g});return gr.apply(this,arguments)}}
{const fin=finish;finish=function(G,w){const c=G&&G.ctx,was=c&&c.finished;fin(G,w);if(was||!c)return;
  if(c.mode==='online'&&!c.corr){qEvent('online',{gk:c.gk});qEvent('end',{gk:c.gk});if(w===c.side)qEvent('win',{gk:c.gk})}
  if(G===NR&&w===c.side&&isPlayer(c)&&c.mode!=='local'){const r=NR.res();if(r&&r.mult>1)qEvent('mars')}}}
{const ps=pzSolved;pzSolved=function(G){if(G&&G.pz&&!G.pz.sprint&&G.pz.day)qEvent('pz');return ps(G)}}
{const se=sprEnd;sprEnd=function(){const on=SPR.on;se();if(on)qEvent('sprint',{v:SPR.score})}}
{const lo=LOTO.claim;LOTO.claim=function(p,ti){const r=lo.call(this,p,ti);if(r)qEvent('lotoend');return r}}
/* the coins: once a task is done; until the server can pay, the claim waits and is tried again later */
A.qclaim=async t=>{const id=t.dataset.id,s=qState(),q=qToday().find(x=>x.id===id);if(!q||s.got[id]===true||(s.p[id]||0)<q.goal)return;t.disabled=true;
 try{const r=await rpc('game_quest',{p_day:qDay(),p_quest:id});s.got[id]=true;store.set('q:'+qDay(),s);if(r&&r.coins!=null)setCoins(r.coins);toast(`+${q.c} მონეტა`);if(typeof confetti==='function')confetti()}
 catch(e){s.got[id]='pend';store.set('q:'+qDay(),s);toast('დავალება შენახულია. მონეტა ბაზის განახლების შემდეგ ჩაგერიცხება')}gLobbyQ()};
function qRetry(){const s=qState();for(const q of qToday())if(s.got[q.id]==='pend')rpc('game_quest',{p_day:qDay(),p_quest:q.id}).then(r=>{const s2=qState();s2.got[q.id]=true;store.set('q:'+qDay(),s2);if(r&&r.coins!=null)setCoins(r.coins);gLobbyQ()}).catch(()=>{})}
function qHTML(){const s=qState(),Q=qToday(),all=Q.every(q=>s.got[q.id]);
 return `<section class="gquests" id="gquests"><h3 class="sec">დღის დავალებები${all?' ✓':''}</h3><div class="gql">${Q.map(q=>{const p=Math.min(q.goal,s.p[q.id]||0),done=p>=q.goal,got=s.got[q.id];
  return `<div class="gq${done?' done':''}"><span class="grow"><b>${esc(q.n)}</b><small>${q.d?esc(q.d)+' · ':''}${p}/${q.goal}</small><i class="gqbar"><em style="width:${Math.round(p/q.goal*100)}%"></em></i></span>${got===true?`<span class="gqok">${ic('check')}</span>`:got==='pend'?`<span class="gqpend" title="ბაზის განახლების შემდეგ">${ic('clock')}</span>`:`<button class="btn sm${done?' gold':' ghost'}" data-a="qclaim" data-id="${q.id}"${done?'':' disabled'}>${ic('coin')}${q.c}</button>`}</div>`}).join('')}</div></section>`}
function gLobbyQ(){const el=$('#gquests');if(el)el.outerHTML=qHTML()}

/* ---------- the seasons' events ---------- */
/* Orthodox Easter is in egg.js (easterOf); Tbilisoba is the last weekend of October */
function tbilisobaOf(y){const d=new Date(Date.UTC(y,9,31));while(d.getUTCDay()!==6)d.setUTCDate(d.getUTCDate()-1);return d}
const EVS=[
 {id:'ny',n:'საახალწლო თასი',d:'მოიგე 5 პარტია ნებისმიერ თამაშში და საახალწლო ნიშანი შენია',ev:'win',goal:5,gk:null,win:y=>[Date.UTC(y,11,20),Date.UTC(y+1,0,14)],ic:'tree',play:null,col:'#2E7D59'},
 {id:'easter',n:'აღდგომის ჭახუნი',d:'გაიმარჯვე კვერცხის ჭახუნში 5-ჯერ. ქრისტე აღდგა!',ev:'win',goal:5,gk:'egg',win:y=>{const e=easterOf(y).getTime();return[e-6*864e5,e+7*864e5]},ic:'star',play:'egg',col:'#B3121C'},
 {id:'tbil',n:'თბილისობის ნარდის თასი',d:'მოიგე 5 ნარდი თბილისობის დღეებში',ev:'win',goal:5,gk:'nardi',win:y=>{const t=tbilisobaOf(y).getTime();return[t-6*864e5,t+7*864e5]},ic:'dice',play:'nardi',col:'#C9A227'},
 {id:'giorgi',n:'გიორგობის ჭადრაკი',d:'მოიგე 3 ჭადრაკი გიორგობისთვის',ev:'win',goal:3,gk:'chess',win:y=>[Date.UTC(y,10,20),Date.UTC(y,10,27)],ic:'chess',play:'chess',col:'#3E6B9E'}];
/* the event of today, if any; the New Year one starts in December and runs into January */
function evNow(){const now=Date.now(),y=new Date().getFullYear();for(const e of EVS)for(const yy of[y,y-1]){const[a,b]=e.win(yy);if(now>=a&&now<b+864e5)return Object.assign({},e,{year:yy})}return null}
const gEvActive=id=>{const e=evNow();return !!e&&e.id===id};
const evKey=e=>'ev:'+e.id+':'+e.year;
function evEvent(ev,o){const e=evNow();if(!e||e.ev!==ev||e.gk&&e.gk!==o.gk)return;const s=store.get(evKey(e),null)||{n:0};if(s.n>=e.goal)return;s.n++;store.set(evKey(e),s);
 if(s.n>=e.goal){toast(`🏅 ${e.n}: მოიგე!`);if(typeof gBadge==='function')gBadge('ev_'+e.id)}}
function evHTML(){const e=evNow();if(!e)return '';const s=store.get(evKey(e),null)||{n:0},p=Math.min(e.goal,s.n),done=p>=e.goal;
 return `<section class="gev" style="--ec:${e.col}"><span class="gevi">${ic(e.ic)}</span><span class="grow"><b>${esc(e.n)}</b><small>${esc(e.d)}</small><i class="gqbar"><em style="width:${Math.round(p/e.goal*100)}%"></em></i><small>${done?'შესრულდა! ნიშანი შენია 🏅':`${p}/${e.goal}`}</small></span>${e.play&&!done?`<button class="btn sm gold" data-a="play" data-g="${e.play}">${ic('play')}ითამაშე</button>`:''}</section>`}
/* the lobby gets the event at the top and the day's tasks after the shelf */
{const rg=R.games;R.games=function(...a){const r=rg.apply(this,a);if(S.game||S.page||S.tab!=='games')return r;const sh=$('.gs-shelf',view);if(sh){sh.insertAdjacentHTML('afterend',qHTML());const ev=evHTML();if(ev)sh.insertAdjacentHTML('beforebegin',ev)}qRetry();return r}}
/* the badges of the events, with the rest */
GBADGES.push(['ev_ny','career','საახალწლო თასი','5 მოგება ახალი წლის დღეებში',30],['ev_easter','egg','აღდგომის ჭახუნი','5 მოგება აღდგომის დღეებში',30],['ev_tbil','nardi','თბილისობის თასი','5 ნარდი თბილისობაზე',30],['ev_giorgi','chess','გიორგობის ჭადრაკი','3 ჭადრაკი გიორგობაზე',30],['egg10','egg','კვერცხების ჩემპიონი','10 მოგებული კვერცხი',20]);
