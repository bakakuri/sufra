/* a short, stable fingerprint of a position, for the repetition rules */
const hash53=s=>{let a=0xdeadbeef,b=0x41c6ce57;for(let i=0;i<s.length;i++){const c=s.charCodeAt(i);a=Math.imul(a^c,2654435761);b=Math.imul(b^c,1597334677)}
 a=Math.imul(a^(a>>>16),2246822507)^Math.imul(b^(b>>>13),3266489909);b=Math.imul(b^(b>>>16),2246822507)^Math.imul(a^(a>>>13),3266489909);return(4294967296*(2097151&b)+(a>>>0)).toString(36)};
const repOk=a=>Array.isArray(a)?a.filter(x=>typeof x==='string'&&x.length<16).slice(-120):[];
/* why a game ended, in words */
const WHY={rep:'ფრე: პოზიცია სამჯერ განმეორდა',mat:'ფრე: მატისთვის საკმარისი ფიგურები აღარ დარჩა','50':'ფრე: 50 სვლა აყვანისა და პაიკის სვლის გარეშე',stale:'პატი. ფრე',kings:'ფრე: 15 სვლა მხოლოდ დამებით, აყვანის გარეშე',k31:'ფრე: სამმა დამამ ერთი 15 სვლაში ვერ აიყვანა'};
function overMsg(c,w,why){if(w===2)return WHY[why]||'ფრე';const pre=why==='mate'?'მატი. ':why==='blocked'?'სვლა აღარ დარჩა. ':'';
 if(why==='gone')return isPlayer(c)?(w===c.side?'მეტოქე გავიდა. მოგება შენ ჩაგეთვალა':'შენ გახვედი'):esc(c.names[-w])+' გავიდა';
 if(why==='time')return isPlayer(c)?(w===c.side?'მეტოქეს დრო ამოეწურა. მოიგე!':'დრო ამოგეწურა. '+esc(c.names[w])+' მოიგო'):esc(c.names[-w])+'-ს დრო ამოეწურა';
 if(why==='resign')return isPlayer(c)?(w===c.side?'მეტოქე დანებდა. მოიგე!':'დანებდი. '+esc(c.names[w])+' მოიგო'):esc(c.names[-w])+' დანებდა';return pre+endMsg(c,w)}
const canResign=G=>{const c=G.ctx;return isPlayer(c)&&!c.gone&&!c.finished};
const resignBtn=G=>canResign(G)?'<button class="btn ghost sm gres" data-a="gresign">'+ic('flag')+'დანებება</button>':'';
A.gresign=()=>{const G=GAME[S.game];if(!G||!G.resign||!canResign(G))return;closeSheet();confirmSheet('დანებება','პარტია წაგებულად ჩაითვლება.','დანებება',()=>{if(GAME[S.game]===G&&canResign(G))G.resign()},true)};

/* ---------- checkers (შაში): Russian rules, mandatory capture, flying kings ---------- */
const DIRS=[[-1,-1],[-1,1],[1,-1],[1,1]];
const inB=(r,c)=>r>=0&&r<8&&c>=0&&c<8;
/* captured men stay on the board until the move ends and cannot be jumped twice (Turkish strike).
   a king may land on any free square behind the man it takes, but if some of those squares let it take again, it must land on one of them */
function ckJumps(b,r,c,king,side,path,cap,out){let ext=false;const taken=(a,d)=>cap.some(x=>x[0]===a&&x[1]===d);
 for(const[dr,dc]of DIRS){
  if(king){let rr=r+dr,cc=c+dc;while(inB(rr,cc)&&!b[rr][cc]){rr+=dr;cc+=dc}
   if(!inB(rr,cc)||Math.sign(b[rr][cc])!==-side||taken(rr,cc))continue;
   const subs=[];let lr=rr+dr,lc=cc+dc;while(inB(lr,lc)&&!b[lr][lc]){const o=[];ckJumps(b,lr,lc,true,side,[...path,[lr,lc]],[...cap,[rr,cc]],o);subs.push(o);lr+=dr;lc+=dc}
   if(!subs.length)continue;ext=true;const n=cap.length+1,more=subs.filter(o=>o.some(m=>m.caps.length>n));for(const o of more.length?more:subs)out.push(...o)}
  else{const rr=r+dr,cc=c+dc,lr=r+2*dr,lc=c+2*dc;
   if(!inB(lr,lc)||Math.sign(b[rr][cc])!==-side||b[lr][lc]||taken(rr,cc))continue;
   ext=true;ckJumps(b,lr,lc,(side===1&&lr===0)||(side===-1&&lr===7),side,[...path,[lr,lc]],[...cap,[rr,cc]],out)}}
 if(!ext&&cap.length)out.push({path,caps:cap})}
function ckAll(b,side){const caps=[],steps=[];
 for(let r=0;r<8;r++)for(let c=0;c<8;c++){const p=b[r][c];if(Math.sign(p)!==side)continue;const king=Math.abs(p)===2;
  b[r][c]=0;ckJumps(b,r,c,king,side,[[r,c]],[],caps);b[r][c]=p;if(caps.length)continue;
  for(const[dr,dc]of DIRS){if(!king&&dr!==-side)continue;let rr=r+dr,cc=c+dc;while(inB(rr,cc)&&!b[rr][cc]){steps.push({path:[[r,c],[rr,cc]],caps:[]});if(!king)break;rr+=dr;cc+=dc}}}
 return caps.length?caps:steps}
function ckApply(b,m){const nb=b.map(r=>r.slice()),s=m.path[0],e=m.path[m.path.length-1];let p=nb[s[0]][s[1]];nb[s[0]][s[1]]=0;
 for(const[r,c]of m.caps)nb[r][c]=0;if(Math.abs(p)===1&&m.path.some(([r])=>(p===1&&r===0)||(p===-1&&r===7)))p*=2;nb[e[0]][e[1]]=p;return nb}
const ckKey=(b,t)=>hash53(b.flat().map(v=>v+2).join('')+t);
function ckEval(b){let s=0;for(let r=0;r<8;r++)for(let c=0;c<8;c++){const p=b[r][c];if(p)s+=Math.sign(p)*(Math.abs(p)===2?3.2:1+(p>0?7-r:r)*.04+(c>1&&c<6?.03:0))}return s}
function ckSearch(b,side,depth,al,be){const ms=ckAll(b,side);if(!ms.length)return -side*100;if(!depth)return ckEval(b);
 let best=side===1?-1e9:1e9;for(const m of ms){const v=ckSearch(ckApply(b,m),-side,depth-1,al,be);
  if(side===1){if(v>best)best=v;if(v>al)al=v}else{if(v<best)best=v;if(v<be)be=v}if(be<=al)break}return best}
function ckBot(b,side){let best=null,bv=-1e9;for(const m of ckAll(b,side)){const v=side*ckSearch(ckApply(b,m),-side,3,-1e9,1e9)+Math.random()*.08;if(v>bv){bv=v;best=m}}return best}
const CK=GAME.shashi={title:'შაში',
 start(){this.b=Array.from({length:8},(_,r)=>Array.from({length:8},(_,c)=>(r+c)%2?(r<3?-1:r>4?1:0):0));this.turn=1;this.sel=null;this.last=[];this.lcap=[];this.over=0;this.why='';this.kq=0;this.k31=0;this.k31s='';this.rep=[ckKey(this.b,1)];this.moves=ckAll(this.b,1)},
 snap(){return{b:this.b,turn:this.turn,last:this.last,lcap:this.lcap,over:this.over,why:this.why,kq:this.kq,k31:this.k31,k31s:this.k31s,rep:this.rep}},
 load(s){if(!Array.isArray(s.b)||s.b.length!==8)throw 0;const sq=a=>Array.isArray(a)?a.filter(x=>Array.isArray(x)&&inB(+x[0],+x[1])).map(x=>[+x[0],+x[1]]).slice(0,20):[];
  this.b=s.b.map(r=>(Array.isArray(r)?r:[]).slice(0,8).map(v=>[-2,-1,0,1,2].includes(v)?v:0));this.turn=s.turn===-1?-1:1;this.last=sq(s.last);this.lcap=sq(s.lcap);this.over=[1,-1,2].includes(s.over)?s.over:0;
  this.why=['rep','kings','k31','resign','blocked','time','gone'].includes(s.why)?s.why:'';this.kq=Math.max(0,Math.min(99,+s.kq||0));this.k31=Math.max(0,Math.min(99,+s.k31||0));this.k31s=String(s.k31s||'').slice(0,8);this.rep=repOk(s.rep);this.sel=null;this.moves=this.over?[]:ckAll(this.b,this.turn)},
 mine(){return isPlayer(this.ctx)&&this.turn===this.ctx.side&&!this.over&&!this.ctx.gone&&!this.ctx.syncing},
 res(){return this.over?{w:this.over,why:this.why}:null},turnSide(){return this.over?null:this.turn},
 status(must){const c=this.ctx;if(this.over)return overMsg(c,this.over,this.why);if(c.gone)return 'მოწინააღმდეგე გავიდა თამაშიდან';if(this.mine())return must?'მოჭრა სავალდებულოა. აირჩიე მოციმციმე ქვა':this.sel?'აირჩიე უჯრა, სადაც გადავა':'შენი სვლაა';return esc(c.names[this.turn])+' ფიქრობს…'},
 cnt(s){return this.b.flat().filter(v=>Math.sign(v)===s).length},
 targets(){const sel=this.sel;return sel?this.moves.filter(m=>m.path[0][0]===sel[0]&&m.path[0][1]===sel[1]).map(m=>m.path[m.path.length-1].join()):[]},
 render(){const c=this.ctx,flip=c.side===-1,b=this.b,sel=this.sel,mine=this.mine(),tg=this.targets();
  const must=mine&&this.moves.length&&this.moves[0].caps.length,movable=new Set(mine?this.moves.map(m=>m.path[0].join()):[]);
  let cells='';for(let dr=0;dr<8;dr++)for(let dc=0;dc<8;dc++){const r=flip?7-dr:dr,cc=flip?7-dc:dc,d=(r+cc)%2,p=b[r][cc],k=r+','+cc;
   cells+=`<button class="sq ${d?'d':'l'}${sel&&sel.join()===k?' sel':''}${tg.includes(k)?' tgt':''}${this.last.some(x=>x.join()===k)?' last':''}"${d?` data-a="ck" data-r="${r}" data-c="${cc}"`:' disabled tabindex="-1"'} aria-label="${'abcdefgh'[cc]}${8-r}${p?(p>0?' თეთრი':' შავი')+(Math.abs(p)===2?' დამა':''):''}">${p?`<span class="man ${p>0?'w':'b'}${Math.abs(p)===2?' k':''}${must&&movable.has(k)?' can':''}"></span>`:''}</button>`}
  const dom=`<div class="ck" aria-label="შაშის დაფა">${cells}</div>`;
  gview('shashi','შაში',g3Board('shashi',dom),this.status(must),`<div class="gacts">${resignBtn(this)}</div><p class="note">${isPlayer(c)?'შენ '+(c.side===1?'თეთრებით':'შავებით')+' თამაშობ. ':''}ქვა უკანაც ჭრის, დამა მთელ დიაგონალზე დადის. ქვები: თეთრი ${this.cnt(1)}, შავი ${this.cnt(-1)}.</p>${tourBack(c)}`,s=>{const n=Math.max(0,12-this.cnt(-s));return n?`<span class="gcap ckd ${s===1?'b':'w'}" aria-label="აღებული ქვები: ${n}"><i></i>${n}</span>`:''});
  g3After('shashi')},
 play(m){const p0=this.b[m.path[0][0]][m.path[0][1]];this.b=ckApply(this.b,m);this.last=m.path;this.lcap=m.caps;this.sel=null;this.turn*=-1;this.moves=ckAll(this.b,this.turn);
  const fl=this.b.flat(),kings=s=>fl.includes(2*s),pcs=s=>fl.filter(v=>Math.sign(v)===s);
  if(Math.abs(p0)===1||m.caps.length){this.rep=[];this.kq=0}else this.kq=kings(1)&&kings(-1)?this.kq+1:0;
  const w=pcs(1),bl=pcs(-1),lone=(a,o)=>a.length===1&&Math.abs(a[0])===2&&o.length>=3&&o.every(v=>Math.abs(v)===2),sig=w.length+':'+bl.length;
  if(lone(w,bl)||lone(bl,w)){this.k31=this.k31s===sig?this.k31+1:1;this.k31s=sig}else{this.k31=0;this.k31s=''}
  const k=ckKey(this.b,this.turn);this.rep=[...this.rep,k].slice(-120);
  if(!this.moves.length){this.over=-this.turn;this.why=this.cnt(this.turn)?'blocked':''}
  else if(this.rep.filter(x=>x===k).length>=3){this.over=2;this.why='rep'}else if(this.kq>=30){this.over=2;this.why='kings'}else if(this.k31>=30){this.over=2;this.why='k31'}
  if(this.ctx.mode==='online')netSend();if(this.over){finish(this,this.over);return}this.render();this.kick()},
 resign(s=this.ctx.side,why='resign'){if(this.over)return;this.over=-s;this.why=why;this.sel=null;if(this.ctx.mode==='online')netSend();finish(this,this.over)},
 kick(){const c=this.ctx;if(this.over)return;if(!(c.mode==='watch'||((c.mode==='bot'||c.mode==='tour')&&this.turn!==c.side)))return;const b0=this.b;
  const lv=c.mode==='watch'?2:bLvl('shashi'),t0=Date.now(),side=this.turn,ok=()=>this.ctx===c&&this.b===b0&&!this.over;
  botThink({g:'shashi',b:b0,side,lvl:lv,budget:BUDGET[lv]}).then(m=>{if(!ok())return;const L=ckAll(b0,side),mm=(m&&L.find(x=>JSON.stringify(x.path)===JSON.stringify(m.path)))||ckBot(b0,side);setTimeout(()=>{if(ok()&&mm)this.play(mm)},Math.max(0,(c.mode==='watch'?1000:650)-(Date.now()-t0)))})},
 checkEnd(){if(this.over)finish(this,this.over)}};
A.ck=t=>{const G=CK;if(!G.mine())return;const r=+t.dataset.r,c=+t.dataset.c,me=G.ctx.side;
 if(G.sel){const ms=G.moves.filter(m=>m.path[0][0]===G.sel[0]&&m.path[0][1]===G.sel[1]&&m.path[m.path.length-1][0]===r&&m.path[m.path.length-1][1]===c).sort((a,b)=>b.caps.length-a.caps.length);if(ms.length){G.play(ms[0]);return}}
 G.sel=Math.sign(G.b[r][c])===me&&G.moves.some(m=>m.path[0][0]===r&&m.path[0][1]===c)?[r,c]:null;G.render()};

/* ---------- nardi (backgammon): side 1 = white, moves from point 24 to 1 ---------- */
const PIPS={1:[4],2:[0,8],3:[0,4,8],4:[0,2,6,8],5:[0,2,4,6,8],6:[0,2,3,5,6,8]};
const dieHTML=(v,used)=>`<span class="die${used?' used':''}" role="img" aria-label="${v}">${Array.from({length:9},(_,k)=>PIPS[v].includes(k)?'<i></i>':'<span></span>').join('')}</span>`;
/* the rules work on a plain position {p,bar,off}, so the bot can try whole turns on copies */
const nHome=(T,s)=>{if(T.bar[s])return false;for(let i=0;i<24;i++)if(T.p[i]*s>0&&!(s===1?i<=5:i>=18))return false;return true};
const nDist=(s,i)=>s===1?i+1:24-i;
function nTarget(T,s,from,d){
 if(from==='bar'){if(!T.bar[s])return null;const to=s===1?24-d:d-1;return T.p[to]*s<=-2?null:to}
 if(T.bar[s]||T.p[from]*s<=0)return null;const to=from-s*d;
 if(to<0||to>23){if(!nHome(T,s))return null;const ds=nDist(s,from);if(d===ds)return 'off';for(let i=0;i<24;i++)if(T.p[i]*s>0&&nDist(s,i)>ds)return null;return 'off'}
 return T.p[to]*s<=-2?null:to}
function nDo(T,s,from,to){if(from==='bar')T.bar[s]--;else T.p[from]-=s;if(to==='off'){T.off[s]++;return false}const hit=T.p[to]*s===-1;if(hit){T.p[to]=0;T.bar[-s]++}T.p[to]+=s;return hit}
const nCopy=T=>({p:T.p.slice(),bar:{1:T.bar[1],'-1':T.bar[-1]},off:{1:T.off[1],'-1':T.off[-1]}});
const nRm=(dice,d)=>{const a=dice.slice();a.splice(a.indexOf(d),1);return a};
function nSingles(T,s,dice){const out=[],ds=[...new Set(dice)];for(const f of T.bar[s]?['bar']:[...Array(24).keys()])for(const d of ds){const to=nTarget(T,s,f,d);if(to!==null)out.push({f,to,d})}return out}
function nMax(T,s,dice){if(!dice.length)return 0;let best=0;for(const m of nSingles(T,s,dice)){const t=nCopy(T);nDo(t,s,m.f,m.to);const v=1+nMax(t,s,nRm(dice,m.d));if(v>best){best=v;if(best===dice.length)break}}return best}
/* a move is legal only if the rest of the turn can still use as many dice as possible; when just one die can be used, it must be the larger one */
function nLegal(T,s,dice){if(!dice.length)return[];const all=nSingles(T,s,dice);if(!all.length)return[];const mx=nMax(T,s,dice);
 let ok=mx===1?all:all.filter(m=>{const t=nCopy(T);nDo(t,s,m.f,m.to);return 1+nMax(t,s,nRm(dice,m.d))===mx});
 if(mx===1&&dice.length===2&&dice[0]!==dice[1]){const hi=Math.max(...dice);if(ok.some(m=>m.d===hi))ok=ok.filter(m=>m.d===hi)}return ok}
/* every way to play the whole roll, one per resulting position */
function nSeqs(T,s,dice){const res=new Map();let mx=0;
 const rec=(t,ds,seq)=>{const ms=ds.length?nSingles(t,s,ds):[];if(!ms.length){if(seq.length>mx){mx=seq.length;res.clear()}if(seq.length===mx){const k=(seq.length===1?seq[0].d+'#':'')+t.p.join()+'|'+t.bar[1]+t.bar[-1]+'|'+t.off[1]+','+t.off[-1];if(!res.has(k))res.set(k,{t,seq})}return}
  for(const m of ms){const t2=nCopy(t);nDo(t2,s,m.f,m.to);rec(t2,nRm(ds,m.d),[...seq,m])}};
 rec(nCopy(T),dice.slice(),[]);let out=[...res.values()];
 if(mx===1&&dice.length===2&&dice[0]!==dice[1]){const hi=Math.max(...dice);if(out.some(x=>x.seq[0].d===hi))out=out.filter(x=>x.seq[0].d===hi)}return out}
function nEval(T,s){const o=-s,pip=x=>{let n=T.bar[x]*25;for(let i=0;i<24;i++)if(T.p[i]*x>0)n+=Math.abs(T.p[i])*nDist(x,i);return n};
 let sc=(pip(o)-pip(s))*.9+(T.off[s]-T.off[o])*2.6+(T.bar[o]-T.bar[s])*9,run=0;
 for(let k=0;k<24;k++){const i=s===1?k:23-k,v=T.p[i]*s;
  if(v>=2){sc+=k<6?3.2:k<12?2:1.2;run++;if(run>=2)sc+=run*1.1}else run=0;
  if(v===1){let shots=0;for(let j=0;j<24;j++){if(T.p[j]*o<=0)continue;const dd=o===1?j-i:i-j;if(dd>0&&dd<=12)shots+=dd<=6?2:1}
   if(T.bar[o]){const dd=o===1?24-i:i+1;if(dd>0&&dd<=12)shots+=dd<=6?2:1}const risk=Math.min(1,shots/8);sc-=risk*(2+(25-nDist(s,i))*.35)}}
 return sc}
function nBest(T,s,dice,lvl=2){const xs=nSeqs(T,s,dice);if(!xs.length)return[];if(lvl===1&&Math.random()<.5)return xs[Math.floor(Math.random()*xs.length)].seq;
 const nz=[0,6,.6,.15,0][lvl];let best=null,bv=-1e9;for(const x of xs){const v=(lvl>=4?nEval4(x.t,s):nEval(x.t,s))+Math.random()*nz;if(v>bv){bv=v;best=x.seq}}return best||[]}
/* a win counts double (მარსი) if the loser bore off nothing, triple (კოქსი) if a loser's checker is still on the bar or in the winner's home */
function nMult(T,w){const l=-w;if(T.off[l])return 1;if(T.bar[l])return 3;for(let i=0;i<24;i++)if(T.p[i]*l>0&&(w===1?i<=5:i>=18))return 3;return 2}
const MULT={2:'მარსი, ორმაგი მოგება',3:'კოქსი, სამმაგი მოგება'};
const NR=GAME.nardi={title:'ნარდი',
 start(){const p=Array(24).fill(0);p[23]=2;p[12]=5;p[7]=3;p[5]=5;p[0]=-2;p[11]=-5;p[16]=-3;p[18]=-5;
  Object.assign(this,{p,bar:{1:0,'-1':0},off:{1:0,'-1':0},sel:null,over:0,why:'',mult:1,lg:null});
  /* the opening roll: each side throws one die, the higher one starts and plays both numbers */
  let a,b;do{a=1+Math.floor(Math.random()*6);b=1+Math.floor(Math.random()*6)}while(a===b);
  this.open=[a,b];this.turn=a>b?1:-1;this.last=[a,b];this.dice=[a,b];this.rolled=true;this.rollAnim=1},
 snap(){return{p:this.p,bar:this.bar,off:this.off,dice:this.dice,last:this.last,turn:this.turn,rolled:this.rolled,over:this.over,why:this.why,mult:this.mult,open:this.open}},
 load(s){const n=v=>Math.max(0,Math.min(15,Number(v)||0)),d=a=>Array.isArray(a)?a.map(Number).filter(x=>x>=1&&x<=6).slice(0,4):[];
  if(!Array.isArray(s.p)||s.p.length!==24)throw 0;this.p=s.p.map(v=>Math.max(-15,Math.min(15,Math.trunc(Number(v))||0)));this.bar={1:n(s.bar&&s.bar[1]),'-1':n(s.bar&&s.bar['-1'])};this.off={1:n(s.off&&s.off[1]),'-1':n(s.off&&s.off['-1'])};
  this.dice=d(s.dice);this.last=d(s.last).slice(0,2);this.turn=s.turn===-1?-1:1;this.rolled=!!s.rolled;this.over=[1,-1].includes(s.over)?s.over:0;this.why=['resign','time','gone'].includes(s.why)?s.why:'';this.mult=[1,2,3].includes(s.mult)?s.mult:1;
  const o=d(s.open);this.open=o.length===2?o:null;this.sel=null;this.lg=null},
 legal(){if(!this.lg)this.lg=this.rolled&&!this.over?nLegal(this,this.turn,this.dice):[];return this.lg},
 opts(s,from){return s===this.turn?this.legal().filter(m=>m.f===from).map(m=>({d:m.d,to:m.to})):[]},
 any(s){return s===this.turn&&this.legal().length>0},
 move(s,from,to,d){nDo(this,s,from,to);this.dice.splice(this.dice.indexOf(d),1);this.lg=null;if(this.off[s]===15){this.over=s;this.mult=nMult(this,s)}},
 roll(){const a=1+Math.floor(Math.random()*6),b=1+Math.floor(Math.random()*6);this.last=[a,b];this.dice=a===b?[a,a,a,a]:[a,b];this.rolled=true;this.open=null;this.lg=null},
 mine(){return isPlayer(this.ctx)&&this.turn===this.ctx.side&&!this.over&&!this.ctx.gone&&!this.ctx.syncing},
 res(){return this.over?{w:this.over,why:this.why,mult:this.mult}:null},turnSide(){return this.over?null:this.turn},
 endTurn(){this.turn*=-1;this.rolled=false;this.dice=[];this.sel=null;this.open=null;this.lg=null;if(this.ctx.mode==='online')netSend();this.render();this.kick()},
 resign(s=this.ctx.side,why='resign'){if(this.over)return;this.over=-s;this.why=why;this.mult=1;this.sel=null;if(this.ctx.mode==='online')netSend();finish(this,this.over)},
 kick(){const c=this.ctx;if(this.over)return;if(!(c.mode==='watch'||((c.mode==='bot'||c.mode==='tour')&&this.turn!==c.side)))return;const s=this.turn,fast=c.mode==='watch',tk=this.tk=(this.tk||0)+1;
  const live=()=>this.ctx===c&&!this.over&&this.turn===s&&this.tk===tk;
  const play=()=>{if(!live())return;const seq=nBest(this,s,this.dice,fast?2:bLvl('nardi'));if(!seq.length){this.render();setTimeout(()=>{if(live())this.endTurn()},1200);return}
   let i=0;const step=()=>{if(!live())return;if(i>=seq.length){this.endTurn();return}const m=seq[i++];this.move(s,m.f,m.to,m.d);if(this.over){finish(this,this.over);return}this.render();setTimeout(step,fast?650:600)};setTimeout(step,750)};
  if(this.rolled)setTimeout(play,fast?1000:900);else setTimeout(()=>{if(!live()||this.rolled)return;this.roll();this.render();play()},fast?900:700)},
 checkEnd(){if(this.over)finish(this,this.over)},
 status(){const c=this.ctx,d=this.last.join(' და ');if(this.over)return overMsg(c,this.over,this.why)+(this.mult>1?' · '+MULT[this.mult]:'');if(c.gone)return 'მოწინააღმდეგე გავიდა თამაშიდან';
  const op=this.open?`${esc(c.names[1])}: ${this.open[0]}, ${esc(c.names[-1])}: ${this.open[1]}. `:'';
  if(this.mine()){if(!this.rolled)return 'შენი ჯერია. გააგორე კამათელი';if(!this.any(c.side))return op+`გააგორე ${d}. სვლა არ გაქვს`;return op+(this.sel!==null?'აირჩიე ოქროსფრად მონიშნული პუნქტი':this.open?'იწყებ შენ. აირჩიე ქვა':`გააგორე ${d}. აირჩიე ქვა`)}
  return op+esc(c.names[this.turn])+(this.open?' იწყებს':this.rolled?' თამაშობს, გააგორა '+d:' აგორებს…')},
 render(){const c=this.ctx,me=c.side,flip=me===-1,s=this.sel,mine=this.mine(),tg=mine&&this.rolled&&s!==null?this.opts(me,s).map(o=>o.to):[];
  const ptHTML=(di,row,col)=>{const i=flip?23-di:di,v=this.p[i],n=Math.abs(v);let ch='';for(let k=0;k<Math.min(n,5);k++)ch+=`<span class="ch ${v>0?'w':'b'}">${k===4&&n>5?n:''}</span>`;
   return `<button class="pt ${row}${di%2?' alt':''}${s===i?' sel':''}${tg.includes(i)?' tgt':''}" style="grid-area:${row==='top'?1:3}/${col}" data-a="npt" data-k="${i}" aria-label="პუნქტი ${me===1?i+1:24-i}${n?', '+n+(v>0?' თეთრი':' შავი'):''}"><span class="tri"></span>${ch}</button>`};
  let pts='';for(let j=0;j<6;j++)pts+=ptHTML(12+j,'top',j+1)+ptHTML(18+j,'top',j+8)+ptHTML(11-j,'bot',j+1)+ptHTML(5-j,'bot',j+8);
  const bch=(sd,n)=>n?`<span class="ch ${sd===1?'w':'b'}">${n>1?n:''}</span>`:'';
  const bar=`<button class="barc${s==='bar'?' sel':''}" data-a="npt" data-k="bar" aria-label="ზარი: ${this.bar[me]} შენი, ${this.bar[-me]} მეტოქის">${bch(-me,this.bar[-me])}<span class="sp"></span>${bch(me,this.bar[me])}</button>`;
  const shown=this.dice.length?this.dice.map(v=>dieHTML(v)).join(''):this.last.map(v=>dieHTML(v,1)).join('');
  const ctl=`<div class="nctl"><div class="dice g3hide" aria-label="კამათელი">${shown}</div><span class="sp"></span>${mine&&!this.rolled?`<button class="btn" data-a="nroll">${ic('dice')}გაგორება</button>`:''}${resignBtn(this)}</div>
  ${tg.includes('off')?`<div class="offs"><button class="btn" data-a="npt" data-k="off">${ic('check')}ქვის გატანა</button></div>`:''}
  ${isPlayer(c)?`<p class="note">შენ ${me===1?'თეთრი':'შავი'} ქვებით თამაშობ და ქვედა მარჯვენა სახლისკენ მოძრაობ. შეეხე ქვას, შემდეგ ოქროსფრად მონიშნულ პუნქტს. თუ ორივე კამათლის გამოყენება შეიძლება, ორივე უნდა გამოიყენო, თუ მხოლოდ ერთის, უფრო დიდის. მარტოხელა ქვა იჭრება და ზარზე გადადის. როცა ყველა ქვა სახლშია, გაიტანე ისინი.</p>`:''}${tourBack(c)}`;
  gview('nardi','ნარდი',g3Board('nardi',`<div class="nb" aria-label="ნარდის დაფა">${pts}${bar}</div>`),this.status(),ctl,s=>`<span class="goff" aria-label="გატანილი ${this.off[s]} ქვა 15-დან"><i style="--p:${this.off[s]/15}"></i>${this.off[s]}/15</span>`);g3After('nardi')}};
A.nroll=()=>{const G=NR;if(!G.mine()||G.rolled)return;G.roll();if(G.ctx.mode==='online')netSend();G.render();
 if(!G.any(G.ctx.side)){const c=G.ctx;setTimeout(()=>{if(G.ctx===c&&G.turn===c.side&&G.rolled)G.endTurn()},1500)}};
A.npt=t=>{const G=NR,me=G.ctx.side;if(!G.mine()||!G.rolled)return;const k=t.dataset.k,id=k==='bar'||k==='off'?k:+k;
 if(G.sel!==null){const o=G.opts(me,G.sel).filter(o=>o.to===id).sort((a,b)=>a.d-b.d)[0];if(o){G.move(me,G.sel,o.to,o.d);G.sel=null;if(G.ctx.mode==='online')netSend();
  if(G.over){finish(G,G.over);return}if(!G.dice.length||!G.any(me)){G.render();const c=G.ctx;setTimeout(()=>{if(G.ctx===c&&G.turn===me)G.endTurn()},700)}else G.render();return}}
 G.sel=id!=='off'&&G.opts(me,id).length?id:null;G.render()};

/* ---------- chess ---------- */
const CPV={p:100,n:320,b:330,r:500,q:900,k:0};
const KN=[[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]],KG=[[-1,-1],[-1,0],[-1,1],[0,-1],[0,1],[1,-1],[1,0],[1,1]],BD=[[-1,-1],[-1,1],[1,-1],[1,1]],RD=[[-1,0],[1,0],[0,-1],[0,1]];
const isW=p=>!!p&&p===p.toUpperCase();
const colOf=p=>!p?0:isW(p)?1:-1;
const GLY={k:'♚',q:'♛',r:'♜',b:'♝',n:'♞',p:'♟︎'},PNAME={k:'მეფე',q:'ლაზიერი',r:'ეტლი',b:'კუ',n:'მხედარი',p:'პაიკი'};
function chInit(){const r='rnbqkbnr',b=Array(64).fill('');for(let c=0;c<8;c++){b[c]=r[c];b[8+c]='p';b[48+c]='P';b[56+c]=r[c].toUpperCase()}const st={b,turn:1,cs:'KQkq',ep:-1,last:[],over:0,hm:0,rep:[],why:''};st.rep=[chKey(st)];return st}
function chAttacked(b,sq,by){if(sq<0)return false;const r=sq>>3,c=sq&7,on=(rr,cc)=>rr>=0&&rr<8&&cc>=0&&cc<8;
 const pr=r+(by===1?1:-1);for(const dc of[-1,1])if(on(pr,c+dc)&&b[pr*8+c+dc]===(by===1?'P':'p'))return true;
 for(const[dr,dc]of KN)if(on(r+dr,c+dc)&&b[(r+dr)*8+c+dc]===(by===1?'N':'n'))return true;
 for(const[dr,dc]of KG)if(on(r+dr,c+dc)&&b[(r+dr)*8+c+dc]===(by===1?'K':'k'))return true;
 const slide=(dirs,set)=>{for(const[dr,dc]of dirs){let rr=r+dr,cc=c+dc;while(on(rr,cc)){const p=b[rr*8+cc];if(p){if(colOf(p)===by&&set.includes(p.toLowerCase()))return true;break}rr+=dr;cc+=dc}}return false};
 return slide(BD,'bq')||slide(RD,'rq')}
function chPseudo(st,side){const b=st.b,mv=[];
 for(let sq=0;sq<64;sq++){const p=b[sq];if(colOf(p)!==side)continue;const r=sq>>3,c=sq&7,t=p.toLowerCase(),add=(to,x)=>mv.push(Object.assign({f:sq,t:to},x||{}));
  if(t==='p'){const dir=side===1?-8:8,r0=side===1?6:1,last=side===1?0:7,one=sq+dir;
   if(one>=0&&one<64&&!b[one]){(one>>3)===last?add(one,{pr:1}):add(one);if(r===r0&&!b[one+dir])add(one+dir,{dbl:1})}
   for(const dc of[-1,1]){const cc=c+dc;if(cc<0||cc>7)continue;const to=one+dc;if(to<0||to>63)continue;if(b[to]&&colOf(b[to])===-side)(to>>3)===last?add(to,{pr:1}):add(to);else if(to===st.ep)add(to,{ep:1})}}
  else if(t==='n'||t==='k'){for(const[dr,dc]of t==='n'?KN:KG){const rr=r+dr,cc=c+dc;if(rr<0||rr>7||cc<0||cc>7)continue;const to=rr*8+cc;if(colOf(b[to])!==side)add(to)}
   if(t==='k'&&sq===(side===1?60:4)&&!chAttacked(b,sq,-side)){const R_=side===1?'R':'r';
    if(st.cs.includes(side===1?'K':'k')&&!b[sq+1]&&!b[sq+2]&&b[sq+3]===R_&&!chAttacked(b,sq+1,-side)&&!chAttacked(b,sq+2,-side))add(sq+2,{cs:'k'});
    if(st.cs.includes(side===1?'Q':'q')&&!b[sq-1]&&!b[sq-2]&&!b[sq-3]&&b[sq-4]===R_&&!chAttacked(b,sq-1,-side)&&!chAttacked(b,sq-2,-side))add(sq-2,{cs:'q'})}}
  else for(const[dr,dc]of t==='b'?BD:t==='r'?RD:BD.concat(RD)){let rr=r+dr,cc=c+dc;while(rr>=0&&rr<8&&cc>=0&&cc<8){const to=rr*8+cc;if(!b[to])add(to);else{if(colOf(b[to])===-side)add(to);break}rr+=dr;cc+=dc}}}
 return mv}
/* m.pr is 1 for "promote" (a queen) or the letter the player picked: q, r, b or n */
function chApply(st,m){const b=st.b.slice(),p=b[m.f],side=colOf(p);let cap=b[m.t];const pp=typeof m.pr==='string'&&/^[qrbn]$/.test(m.pr)?m.pr:'q';b[m.t]=m.pr?(side===1?pp.toUpperCase():pp):p;b[m.f]='';
 if(m.ep){const cq=m.t+(side===1?8:-8);cap=b[cq];b[cq]=''}
 if(m.cs==='k'){b[m.f+1]=b[m.f+3];b[m.f+3]=''}if(m.cs==='q'){b[m.f-1]=b[m.f-4];b[m.f-4]=''}
 let cs=st.cs;if(p==='K')cs=cs.replace(/[KQ]/g,'');if(p==='k')cs=cs.replace(/[kq]/g,'');
 for(const[sq,ch]of[[63,'K'],[56,'Q'],[7,'k'],[0,'q']])if(m.f===sq||m.t===sq)cs=cs.replace(ch,'');
 return{b,turn:-st.turn,cs,ep:m.dbl?(m.f+m.t)/2:-1,last:[m.f,m.t],over:0,hm:(p.toLowerCase()==='p'||cap)?0:(st.hm||0)+1,rep:st.rep,why:''}}
const chKing=(b,side)=>b.indexOf(side===1?'K':'k');
const chLegal=(st,side)=>chPseudo(st,side).filter(m=>{const n=chApply(st,m);return !chAttacked(n.b,chKing(n.b,side),-side)});
/* the same position: same pieces, same side to move, same castling rights and a real en passant chance */
function chKey(st){const ep=st.ep>=0&&chLegal(st,st.turn).some(m=>m.ep)?st.ep:-1;return hash53(st.b.map(x=>x||'.').join('')+st.turn+st.cs+ep)}
/* nobody can mate: kings alone, a lone bishop or knight, or bishops that all stand on one colour */
function chInsuf(b){const pc=[];for(let i=0;i<64;i++){const p=b[i];if(p&&p.toLowerCase()!=='k')pc.push([p.toLowerCase(),i])}
 if(!pc.length)return true;if(pc.length===1&&(pc[0][0]==='b'||pc[0][0]==='n'))return true;
 if(pc.every(([t])=>t==='b')){const sq=pc.map(([,i])=>((i>>3)+(i&7))%2);return sq.every(v=>v===sq[0])}return false}
/* pieces each side has taken, for the trays next to the board */
const CH_ALL={p:8,n:2,b:2,r:2,q:1};
/* short algebraic notation with figurines: ♘f3, e×d5, O-O, e8=♕, check +, mate # */
const FIG={k:'♔',q:'♕',r:'♖',b:'♗',n:'♘'},FILES='abcdefgh';
function chSan(ps,st){const[f,t]=st.last,p=ps.b[f];if(!p)return '';const k=p.toLowerCase(),side=colOf(p),sq=i=>FILES[i&7]+(8-(i>>3));let s;
 if(k==='k'&&Math.abs((f&7)-(t&7))===2)s=(t&7)>(f&7)?'O-O':'O-O-O';
 else{const cap=!!ps.b[t]||(k==='p'&&(f&7)!==(t&7));
  if(k==='p')s=(cap?FILES[f&7]+'×':'')+sq(t);
  else{const o=chLegal(ps,side).filter(m=>m.t===t&&m.f!==f&&ps.b[m.f]===p);let d='';
   if(o.length)d=!o.some(m=>(m.f&7)===(f&7))?FILES[f&7]:!o.some(m=>(m.f>>3)===(f>>3))?String(8-(f>>3)):sq(f);
   s=FIG[k]+d+(cap?'×':'')+sq(t)}
  if(k==='p'&&(t>>3)%7===0&&st.b[t])s+='='+FIG[st.b[t].toLowerCase()]}
 return s+(chAttacked(st.b,chKing(st.b,st.turn),-st.turn)?(chLegal(st,st.turn).length?'+':'#'):'')}
function chTaken(b,col){const n={p:0,n:0,b:0,r:0,q:0};for(const p of b)if(p&&colOf(p)===col&&n[p.toLowerCase()]!=null)n[p.toLowerCase()]++;const out=[];for(const t of'qrbnp')for(let k=n[t];k<CH_ALL[t];k++)out.push(t);return out}
const PST=[0,1,2,3,3,2,1,0];
/* where each piece likes to stand (white's view, rank 8 first): centre pawns forward, knights and bishops out and central, the king tucked away */
const PSTS={p:[0,0,0,0,0,0,0,0,50,50,50,50,50,50,50,50,10,10,20,30,30,20,10,10,5,5,10,25,25,10,5,5,0,0,0,20,20,0,0,0,5,-5,-10,0,0,-10,-5,5,5,10,10,-20,-20,10,10,5,0,0,0,0,0,0,0,0],
 n:[-50,-40,-30,-30,-30,-30,-40,-50,-40,-20,0,0,0,0,-20,-40,-30,0,10,15,15,10,0,-30,-30,5,15,20,20,15,5,-30,-30,0,15,20,20,15,0,-30,-30,5,10,15,15,10,5,-30,-40,-20,0,5,5,0,-20,-40,-50,-40,-30,-30,-30,-30,-40,-50],
 b:[-20,-10,-10,-10,-10,-10,-10,-20,-10,0,0,0,0,0,0,-10,-10,0,5,10,10,5,0,-10,-10,5,5,10,10,5,5,-10,-10,0,10,10,10,10,0,-10,-10,10,10,10,10,10,10,-10,-10,5,0,0,0,0,5,-10,-20,-10,-10,-10,-10,-10,-10,-20],
 r:[0,0,0,0,0,0,0,0,5,10,10,10,10,10,10,5,-5,0,0,0,0,0,0,-5,-5,0,0,0,0,0,0,-5,-5,0,0,0,0,0,0,-5,-5,0,0,0,0,0,0,-5,-5,0,0,0,0,0,0,-5,0,0,0,5,5,0,0,0],
 q:[-20,-10,-10,-5,-5,-10,-10,-20,-10,0,0,0,0,0,0,-10,-10,0,5,5,5,5,0,-10,-5,0,5,5,5,5,0,-5,0,0,5,5,5,5,0,-5,-10,5,5,5,5,5,0,-10,-10,0,5,0,0,0,0,-10,-20,-10,-10,-5,-5,-10,-10,-20],
 k:[-30,-40,-40,-50,-50,-40,-40,-30,-30,-40,-40,-50,-50,-40,-40,-30,-30,-40,-40,-50,-50,-40,-40,-30,-30,-40,-40,-50,-50,-40,-40,-30,-20,-30,-30,-40,-40,-30,-30,-20,-10,-20,-20,-20,-20,-20,-20,-10,20,20,0,0,0,0,20,20,20,30,10,0,0,10,30,20]};
function chEval(b){let s=0;for(let i=0;i<64;i++){const p=b[i];if(!p)continue;const t=p.toLowerCase(),w=isW(p)?1:-1;s+=w*(CPV[t]+PSTS[t][w===1?i:(7-(i>>3))*8+(i&7)])}return s}
function chSearch(st,depth,al,be){if(chKing(st.b,1)<0)return -1e5;if(chKing(st.b,-1)<0)return 1e5;if(!depth)return chEval(st.b);
 const side=st.turn,ms=chPseudo(st,side);if(!ms.length)return chEval(st.b);const val=m=>st.b[m.t]?CPV[st.b[m.t].toLowerCase()]||1e4:0;ms.sort((a,b)=>val(b)-val(a));
 let best=side===1?-1e9:1e9;for(const m of ms){const v=chSearch(chApply(st,m),depth-1,al,be);if(side===1){if(v>best)best=v;if(v>al)al=v}else{if(v<best)best=v;if(v<be)be=v}if(be<=al)break}return best}
function chBot(st){const side=st.turn;let best=null,bv=-1e9;for(const m of chLegal(st,side)){const v=side*chSearch(chApply(st,m),2,-1e9,1e9)+Math.random()*8;if(v>bv){bv=v;best=m}}return best}
const CH=GAME.chess={title:'ჭადრაკი',
 start(){this.st=chInit();this.sel=null;this.pend=null;this.moves=chLegal(this.st,1);this.mv=[];this.ps=this.st;this.full=true},
 snap(){return this.st},
 load(s){if(!Array.isArray(s.b)||s.b.length!==64)throw 0;const ok=/^[pnbrqkPNBRQK]?$/;
  this.st={b:s.b.map(x=>typeof x==='string'&&ok.test(x)?x:''),turn:s.turn===-1?-1:1,cs:String(s.cs||'').replace(/[^KQkq]/g,''),ep:Number.isInteger(s.ep)&&s.ep>=0&&s.ep<64?s.ep:-1,last:Array.isArray(s.last)?s.last.slice(0,2).map(Number).filter(x=>x>=0&&x<64):[],over:[1,-1,2].includes(s.over)?s.over:0,hm:Math.max(0,Math.min(200,Number(s.hm)||0)),rep:repOk(s.rep),why:['mate','stale','rep','mat','50','resign','time','gone'].includes(s.why)?s.why:''};
  this.sel=null;this.pend=null;this.moves=this.st.over?[]:chLegal(this.st,this.st.turn)},
 mine(){return isPlayer(this.ctx)&&this.st.turn===this.ctx.side&&!this.st.over&&!this.ctx.gone&&!this.ctx.syncing},
 res(){return this.st.over?{w:this.st.over,why:this.st.why}:null},turnSide(){return this.st.over?null:this.st.turn},
 inCheck(){const st=this.st;return chAttacked(st.b,chKing(st.b,st.turn),-st.turn)},
 /* the move list is read off each new position as it arrives, so it is the same for bots, online games and watching.
    if a position does not follow from the last one (joined late, reconnected), the list starts again without move numbers */
 note(){const st=this.st;if(st===this.ps)return;const ps=this.ps;this.ps=st;if(!this.mv)this.mv=[];
  if(!st.last.length&&st.rep.length<=1){this.mv=[];this.full=true;return}
  const ok=ps&&st.last.length===2&&ps.turn!==st.turn&&chLegal(ps,ps.turn).some(m=>m.f===st.last[0]&&m.t===st.last[1]);
  if(!ok){if(ps&&ps.b.join()===st.b.join())return;this.mv=[];this.full=false;return}this.mv.push(chSan(ps,st))},
 movesHTML(){const mv=this.mv||[],from=Math.max(0,mv.length-12);let h='';
  for(let j=from;j<mv.length;j++){if(this.full&&j%2===0)h+=`<span class="n">${j/2+1}.</span>`;h+=`<span${j===mv.length-1?' class="now"':''}>${mv[j].replace(/[♔♕♖♗♘]/g,'<i class="fg">$&</i>')}</span>`}
  return `<div class="mvs" aria-label="სვლები">${h}</div>`},
 status(){const c=this.ctx,st=this.st;if(st.over)return overMsg(c,st.over,st.why);if(c.gone)return 'მოწინააღმდეგე გავიდა თამაშიდან';const chk=this.inCheck()?'ქიში! ':'';
  return this.mine()?chk+(this.sel!==null?'აირჩიე უჯრა':'შენი სვლაა'):chk+esc(c.names[st.turn])+' ფიქრობს…'},
 render(){this.note();const c=this.ctx,flip=c.side===-1,st=this.st,sel=this.sel,tg=sel!==null?this.moves.filter(m=>m.f===sel):[],chkK=this.inCheck()?chKing(st.b,st.turn):-1;
  let cells='';for(let di=0;di<64;di++){const i=flip?63-di:di,r=i>>3,cc=i&7,p=st.b[i],t=tg.find(m=>m.t===i);
   cells+=`<button class="cs ${(r+cc)%2?'d':'l'}${sel===i?' sel':''}${t?' tgt'+(p||t.ep?' cap':''):''}${st.last.includes(i)?' last':''}${i===chkK?' chk':''}" data-a="chm" data-i="${i}" aria-label="${'abcdefgh'[cc]}${8-r}${p?' '+(isW(p)?'თეთრი ':'შავი ')+PNAME[p.toLowerCase()]:''}">${p?`<span class="${isW(p)?'pw':'pb'}">${GLY[p.toLowerCase()]}</span>`:''}</button>`}
  const tk=s=>{const t=chTaken(st.b,-s),adv=t.reduce((a,x)=>a+CPV[x],0)-chTaken(st.b,s).reduce((a,x)=>a+CPV[x],0);return t.length?`<span class="gcap ${s===1?'b':'w'}">${t.map(x=>GLY[x]).join('')}${adv>0?` <small>+${Math.round(adv/100)}</small>`:''}</span>`:''};
  gview('chess','ჭადრაკი',g3Board('chess',`<div class="cb" aria-label="ჭადრაკის დაფა">${cells}</div>`),this.status(),`<div class="gacts">${resignBtn(this)}</div><p class="note">${isPlayer(c)?'შენ '+(c.side===1?'თეთრებით':'შავებით')+' თამაშობ. ':''}ბოლო ხაზამდე მისული პაიკი შენს არჩეულ ფიგურად იქცევა. ფრეა პატი, სამჯერ განმეორებული პოზიცია, 50 სვლა აყვანის გარეშე და მატისთვის არასაკმარისი ფიგურები.</p>${tourBack(c)}`,tk,this.movesHTML());
  g3After('chess')},
 play(m){const prev=this.st,n=chApply(prev,m);this.sel=null;this.pend=null;this.moves=chLegal(n,n.turn);const k=chKey(n);n.rep=n.hm===0?[k]:[...(prev.rep||[]),k].slice(-120);this.st=n;
  if(!this.moves.length){n.over=this.inCheck()?-n.turn:2;n.why=n.over===2?'stale':'mate'}
  else if(n.rep.filter(x=>x===k).length>=3){n.over=2;n.why='rep'}else if(chInsuf(n.b)){n.over=2;n.why='mat'}else if(n.hm>=100){n.over=2;n.why='50'}
  if(this.ctx.mode==='online')netSend();if(n.over){finish(this,n.over);return}this.render();this.kick()},
 resign(s=this.ctx.side,why='resign'){const st=this.st;if(st.over)return;st.over=-s;st.why=why;this.sel=null;this.moves=[];if(this.ctx.mode==='online')netSend();finish(this,st.over)},
 kick(){const c=this.ctx;if(this.st.over)return;if(!(c.mode==='watch'||((c.mode==='bot'||c.mode==='tour')&&this.st.turn!==c.side)))return;const s0=this.st;
  const lv=c.mode==='watch'?2:bLvl('chess'),t0=Date.now(),ok=()=>this.ctx===c&&this.st===s0&&!s0.over;
  botThink({g:'chess',st:s0,lvl:lv,budget:BUDGET[lv]}).then(m=>{if(!ok())return;const mm=(m&&chLegal(s0,s0.turn).find(x=>x.f===m.f&&x.t===m.t&&!!x.pr===!!m.pr))||chBot(s0);setTimeout(()=>{if(ok()&&mm)this.play(mm)},Math.max(0,(c.mode==='watch'?1100:400)-(Date.now()-t0)))})},
 checkEnd(){if(this.st.over)finish(this,this.st.over)}};
A.chm=t=>{const G=CH;if(!G.mine())return;const i=+t.dataset.i;
 if(G.sel!==null){const m=G.moves.find(m=>m.f===G.sel&&m.t===i);if(m){if(m.pr){G.pend=m;const cl=G.ctx.side===1?'pw':'pb';
   sheet(head('პაიკი რად იქცეს?')+`<div class="prom" role="group" aria-label="ფიგურის არჩევა">${'qrbn'.split('').map(p=>`<button data-a="chpr" data-p="${p}"><span class="${cl}">${GLY[p]}</span>${PNAME[p]}</button>`).join('')}</div>`,'short');return}
  G.play(m);return}}
 G.sel=colOf(G.st.b[i])===G.ctx.side&&G.moves.some(m=>m.f===i)?i:null;G.render()};
A.chpr=t=>{const G=CH,m=G.pend;closeSheet();G.pend=null;if(!m||!G.mine()||!G.moves.includes(m)||!/^[qrbn]$/.test(t.dataset.p))return;G.play(Object.assign({},m,{pr:t.dataset.p}))};

/* ---------- joker (ჯოკერი), 4 players, Georgian rules ---------- */
const SUITS=['s','c','h','d'],SY={s:'♠',c:'♣',h:'♥',d:'♦'},SN={s:'ყვავი',c:'ჯვარი',h:'გული',d:'აგური'},RK={11:'J',12:'Q',13:'K',14:'A'};
const rkTxt=r=>RK[r]||String(r);
const isRed=s=>s==='h'||s==='d';
/* the four-colour deck (spades black, clubs green, hearts red, diamonds blue) is easier to tell apart across a table */
const SC4={s:'#17110E',c:'#1C7A3A',h:'#CE1430',d:'#1A55C4'},SC4D={s:'inherit',c:'#62D18E',h:'#FF8A9A',d:'#8DB0FF'};
const c4On=()=>!!store.get('c4',false);
const suitInk=s=>c4On()?SC4D[s]:isRed(s)?'#FF8A9A':'inherit';
try{document.documentElement.classList.toggle('c4',c4On())}catch(e){}
/* how many tricks a hand should take, counted the way a careful player does; the bid hint and the stronger bots use it */
function jEst(hand,tr){let e=0;const len=s=>hand.filter(c=>!c.j&&c.s===s).length,nt=tr?len(tr):0;
 for(const c of hand){if(c.j)e+=1;else if(tr&&c.s===tr)e+=c.r===14?.95:c.r===13?.8:c.r===12?.55:c.r===11?.4:.25;else{const L=len(c.s);e+=c.r===14?(L<=3?.8:.6):c.r===13?(L>=2&&L<=4?.4:.2):0}}
 if(tr&&nt>=4)e+=(nt-3)*.3;if(tr&&nt)for(const s of SUITS)if(s!==tr&&!len(s))e+=Math.min(nt,2)*.3;return e}
function jHint(hand,tr,n,f){const e=jEst(hand,tr);let b=Math.max(0,Math.min(n,Math.round(e)));if(b===f)b=e>=b&&b<n?b+1:b>0?b-1:b+1;return b}
const jHintOn=()=>store.get('jkhint',true)!==false;
/* the last trick, laid out as it lay on the table: who played what, in which order, and who took it */
function jLastOpen(L,nm,base){if(!L||!L.t||L.t.length<4)return;const pos=['b','l','t','r'];
 sheet(head('ბოლო ხელი')+`<div class="ph-body"><div class="jlast">${L.t.map((e,k)=>{const r=(e.p-base+4)%4,w=e.p===L.w;return `<div class="jl ${pos[r]}${w?' won':''}"><span class="jlc">${jCardHTML(e.card)}<em>${k+1}</em></span><b>${esc(nm(e.p))}</b>${e.card.j?`<small>${e.jm==='hi'?'მაღალი':'დაბალი'}${e.js?' '+SY[e.js]:''}</small>`:''}${w?'<small class="jlw">წაიღო</small>':''}</div>`}).join('')}<span class="jlmid" aria-hidden="true">${ic('cards')}</span></div></div>`,'short')}
const jLastBtn=a=>`<button class="jlt" data-a="${a}" aria-label="ბოლო ხელის ნახვა">${ic('cards')}<span>ბოლო ხელი</span></button>`;
function jDeck(){const d=[];for(const s of SUITS)for(let r=6;r<=14;r++)if(!(r===6&&(s==='s'||s==='c')))d.push({s,r});d.push({j:1},{j:2});return d}
const sortHand=h=>h.sort((a,b)=>(a.j?99:SUITS.indexOf(a.s)*20+a.r)-(b.j?99:SUITS.indexOf(b.s)*20+b.r));
const jCardHTML=(c,extra='')=>c.j?`<div class="card jk"${extra}><i>★</i>ჯოკერი</div>`:`<div class="card${isRed(c.s)?' red':''}" data-s="${SY[c.s]}"${extra}><span>${rkTxt(c.r)}</span><span class="s2">${SY[c.s]}</span></div>`;
const cardName=c=>c.j?'ჯოკერი':rkTxt(c.r)+' '+SN[c.s];
const JSEQ={quick:[1,2,3,4,5,6,7,8],full:[1,2,3,4,5,6,7,8,9,9,9,9,8,7,6,5,4,3,2,1,9,9,9,9]};
/* the full game has four sections: 1 to 8, four nines, 8 to 1, four nines; the quick game is one section */
const jSec=(len,h)=>len==='full'?(h<8?0:h<12?1:h<20?2:3):0;
const jSecEnd=(len,h)=>len==='full'?[7,11,19,23].includes(h):h===7;
/* a section premium: whoever made every bid of a section doubles their best hand there, and the others lose their best hand */
function jPremium(hist,sec){const rows=hist.filter(r=>!r.pr&&r.s===sec);if(!rows.length)return[0,0,0,0];
 const all=[0,1,2,3].map(p=>rows.every(r=>r.b[p]===r.t[p])),best=[0,1,2,3].map(p=>Math.max(0,...rows.map(r=>r.p[p]))),any=all.some(Boolean);
 return[0,1,2,3].map(p=>all[p]?best[p]:any?-best[p]:0)}
/* score one hand (and the premium when a section ends); shared by the game against the computer and the online table */
function jScore(E){const sec=jSec(E.len,E.h),kh=sec%2?500:200,pts=[0,1,2,3].map(p=>JK.pts(E.bids[p],E.taken[p],E.n,kh));pts.forEach((x,p)=>E.score[p]+=x);
 E.hist.push({n:E.n,b:E.bids.slice(),t:E.taken.slice(),p:pts,s:sec});
 if(jSecEnd(E.len,E.h)){const pr=jPremium(E.hist,sec);if(pr.some(Boolean)){pr.forEach((x,p)=>E.score[p]+=x);E.hist.push({pr:1,n:0,s:sec,b:[],t:[],p:pr})}}E.h++}
const jLast=hist=>{const n=hist.length,l=hist[n-1];return l&&l.pr?{hand:hist[n-2],prem:l}:{hand:l,prem:null}};
/* the score sheet as it is kept at a real table: squared notebook paper, blue ballpoint, minus in red.
   one column a player; a row a hand (cards dealt in the margin), with what they said small in the corner and the points;
   a bid that took nothing (ხიშტი) is struck through; a double line closes each section with the running totals */
const jInk=s=>[...String(s)].map((ch,i)=>{if(ch===' ')return ' ';const h=(ch.charCodeAt(0)*7+i*13)%17;return `<i style="--r:${((h%7)-3)*1.3}deg;--y:${((h%5)-2)*.7}px">${esc(ch)}</i>`}).join('');
function jNoteHTML(hist,score,names,o={}){const rows=[],run=[0,0,0,0];hist=hist||[];
 hist.forEach((h,ix)=>{h.p.forEach((x,p)=>run[p]+=x);const nw=o.hl&&ix>=hist.length-(hist[hist.length-1]&&hist[hist.length-1].pr?2:1)?' new':'';
  if(h.pr)rows.push(`<div class="jn-r jn-pr${nw}"><span class="jn-m">★</span>${h.p.map(x=>`<span class="jn-c${x<0?' neg':''}">${x?jInk((x>0?'+':'')+x):''}</span>`).join('')}</div>`);
  else rows.push(`<div class="jn-r${nw}"><span class="jn-m">${jInk(h.n)}</span>${[0,1,2,3].map(p=>{const b=h.b[p],t=h.t[p],x=h.p[p];return `<span class="jn-c${x<0?' neg':''}${b>0&&t===0?' kh':''}"><sup>${b===0?'—':jInk(b)}</sup>${jInk(x)}</span>`}).join('')}</div>`);
  const nx=hist[ix+1];if(nx&&nx.s!==h.s)rows.push(`<div class="jn-r jn-sub"><span class="jn-m"></span>${run.map(x=>`<span class="jn-c${x<0?' neg':''}">${jInk(x)}</span>`).join('')}</div>`)});
 const body=o.last?rows.slice(-o.last):rows;
 return `<div class="jnote" aria-label="ქულების ფურცელი"><div class="jn-r jn-h"><span class="jn-m"></span>${names.map(n=>`<span class="jn-c">${jInk(String(n).split(' ')[0])}</span>`).join('')}</div>${body.join('')}${hist.length?`<div class="jn-r jn-tot"><span class="jn-m">${jInk('სულ')}</span>${score.map(x=>`<span class="jn-c${x<0?' neg':''}">${jInk(x)}</span>`).join('')}</div>`:''}</div>`}
/* the sheet lies small in the corner; after a hand it slides out for a moment with the new row; a tap opens it in full */
const jMiniHTML=(hist,score,names,pop,a)=>`<button class="jsm${pop?' pop':''}" data-a="${a}" aria-label="ქულების ფურცელი">${jNoteHTML(hist,score,names,{last:pop?4:8,hl:pop})}</button>`;
function jSheetOpen(hist,score,names){sheet(head('ქულების ფურცელი')+`<div class="ph-body jnbody">${jNoteHTML(hist,score,names)}</div>`,'jnp')}
/* what a player said and took: one pip per trick said, filled when taken; extra tricks in red; a pass shows the word */
function jPips(b,t){const lab=`aria-label="ნათქვამი ${b??'ჯერ არა'}, წაღებული ${t}"`;if(b==null)return `<span class="bt pips" ${lab}>–</span>`;
 if(b===0)return `<span class="bt pips z${t?' over':''}" ${lab}>${t?'პასი, +'+t:'პასი'}</span>`;
 return `<span class="bt pips${t>b?' over':''}" ${lab}>${Array.from({length:b},(_,k)=>`<i${k<t?' class="on"':''}></i>`).join('')}${t>b?`<em>+${t-b}</em>`:''}</span>`}
const jBidCols=n=>n+1<=8?n+1:Math.ceil((n+1)/2);
const JK=GAME.joker={title:'ჯოკერი',
 start(){this.tk=(this.tk||0)+1;this.phase='setup';this.ids=['me',{n:JK_BOTS[0],h:20},{n:JK_BOTS[1],h:200},{n:JK_BOTS[2],h:120}]},
 nm(p){return p===0?ME.name:JK_BOTS[p-1]},
 save(){if(!['trump','bid','play','handover'].includes(this.phase)||!this.hands)return null;return{lastT:this.lastT||null,len:this.len,h:this.h,score:this.score,hist:this.hist,dealer:this.dealer,n:this.n,hands:this.hands,first3:this.first3,bids:this.bids,taken:this.taken,trick:this.trick,trump:this.trump,trumpCard:this.trumpCard,phase:this.phase,cur:this.cur,win:this.win,gone:[...(this.gone||[])]}},
 restore(s){if(!s||!JSEQ[s.len]||!Array.isArray(s.hands))throw 0;Object.assign(this,{len:s.len,h:s.h,score:s.score,hist:s.hist||[],dealer:s.dealer,n:s.n,hands:s.hands,first3:s.first3,bids:s.bids,taken:s.taken,trick:s.trick||[],trump:s.trump,trumpCard:s.trumpCard,phase:s.phase,cur:s.cur,win:s.win,gone:new Set(s.gone||[]),lastT:s.lastT&&Array.isArray(s.lastT.t)?s.lastT:null});
  if(this.phase==='handover')this.later(()=>{if(this.phase==='handover')this.newHand()},1800);
  else if(this.phase==='play'&&(this.win!=null||this.cur<0)){const w=this.win??0;this.trick=[];this.win=null;if(!this.hands[0].length){this.endHand();return}this.cur=w}
  setTimeout(()=>{if(S.game==='joker')this.step()},500)},
 begin(len){this.len=len;this.h=0;this.score=[0,0,0,0];this.hist=[];this.dealer=Math.floor(Math.random()*4);this.newHand()},
 newHand(){const n=JSEQ[this.len][this.h];this.n=n;this.gone=new Set();this.lastT=null;this.dealer=(this.dealer+1)%4;const d=shuffle(jDeck());
  this.first3=[0,1,2,3].map(i=>d.slice(i*n,i*n+3));this.hands=[0,1,2,3].map(i=>sortHand(d.slice(i*n,(i+1)*n)));
  this.bids=[null,null,null,null];this.taken=[0,0,0,0];this.trick=[];this.win=null;this.cur=(this.dealer+1)%4;
  if(n<9){const tc=d[4*n];this.trumpCard=tc;this.trump=tc.j?null:tc.s;this.phase='bid'}else{this.trumpCard=null;this.trump=null;this.phase='trump'}
  this.render();this.step()},
 later(fn,ms){const tk=this.tk;setTimeout(()=>{if(tk===this.tk&&S.game==='joker')fn()},ms)},
 step(){if(this.cur===0||this.cur<0)return;if(this.phase==='trump')this.later(()=>this.setTrump(this.botTrump(this.cur)),900);
  else if(this.phase==='bid')this.later(()=>this.bid(this.cur,this.botBid(this.cur)),750);
  else if(this.phase==='play')this.later(()=>{const m=this.botPlay(this.cur);this.playCard(this.cur,m.c,m.jm,m.js)},800)},
 setTrump(s){this.trump=s||null;this.phase='bid';this.cur=(this.dealer+1)%4;this.render();this.step()},
 forbidden(p){if(p!==this.dealer)return -1;const f=this.n-this.bids.reduce((a,x)=>a+(x||0),0);return f>=0?f:-1},
 bid(p,b){this.bids[p]=b;if(this.bids.every(x=>x!==null)){this.phase='play';this.cur=(this.dealer+1)%4}else this.cur=(p+1)%4;this.render();this.step()},
 legal(p){const hand=this.hands[p],t=this.trick;if(!t.length)return hand.slice();const lead=t[0],suit=lead.card.j?lead.js:lead.card.s,jokers=hand.filter(c=>c.j);
  const of=hand.filter(c=>!c.j&&c.s===suit);if(of.length){if(lead.card.j&&lead.jm==='hi'){const mx=Math.max(...of.map(c=>c.r));return[...of.filter(c=>c.r===mx),...jokers]}return[...of,...jokers]}
  const tr=this.trump?hand.filter(c=>!c.j&&c.s===this.trump):[];return tr.length?[...tr,...jokers]:hand.slice()},
 /* a later high joker beats an earlier one. a high joker that led a plain suit loses to a trump.
    a low joker that led wins only if nobody followed the suit, trumped or played a high joker */
 winner(t){t=t||this.trick;const lead=t[0],suit=lead.card.j?lead.js:lead.card.s,trumped=!!this.trump&&t.some(e=>!e.card.j&&e.card.s===this.trump);let best=0,bv=-Infinity;
  t.forEach((e,i)=>{let v;if(e.card.j)v=e.jm==='hi'?(i===0&&trumped&&lead.js!==this.trump?99:1000+i):-1;else if(this.trump&&e.card.s===this.trump)v=100+e.card.r;else if(e.card.s===suit)v=e.card.r;else v=0;if(v>bv){bv=v;best=i}});
  return bv<=0?t[0].p:t[best].p},
 playCard(p,c,jm,js){const h=this.hands[p];h.splice(h.indexOf(c),1);const lead=!this.trick.length;if(this.gone&&!c.j)this.gone.add(c.s+c.r);
  this.trick.push({p,card:c,jm:c.j?(jm||'hi'):null,js:c.j&&lead?(js||SUITS[Math.floor(Math.random()*4)]):null});
  if(this.trick.length<4){this.cur=(p+1)%4;this.render();this.step();return}
  const w=this.winner();this.taken[w]++;this.cur=-1;this.win=w;this.render();
  this.later(()=>{this.lastT={t:this.trick.slice(),w};this.trick=[];this.win=null;if(!this.hands[0].length){this.endHand();return}this.cur=w;this.render();this.step()},1400)},
 /* bid and made: 50 a trick plus 50; all tricks bid and taken: 100 a trick; pass and none: 50; otherwise 10 a trick; bid but took none (ხიშტი): −200, or −500 in the nine-card sections */
 pts(b,t,n,kh=200){if(t===b)return b===n?100*n:b===0?50:50*b+50;if(b>0&&t===0)return -kh;return 10*t},
 endHand(){jScore(this);if(this===JK)this.botRx();
  if(this.h>=JSEQ[this.len].length){this.phase='over';const mx=Math.max(...this.score),win=this.score[0]===mx;gameResult('joker',win);if(typeof gEndGest==='function')gEndGest(r=>this.score[r]===mx?'cheer':'clap',[1,2,3])}else{this.phase='handover';this.later(()=>{if(this.phase==='handover')this.newHand()},3800)}this.render()},
 botRx(){const L=jLast(this.hist).hand;if(!L)return;const ev=[];
  for(let p=1;p<4;p++){if(L.b[p]>0&&L.t[p]===0&&Math.random()<.6)ev.push(['r'+p,4]);else if(L.b[p]===L.t[p]&&L.b[p]>=2&&Math.random()<.35)ev.push(['r'+p,Math.random()<.5?0:1])}
  if(L.b[0]>0&&L.t[0]===0&&Math.random()<.5)ev.push(['r'+(1+Math.floor(Math.random()*3)),1]);ev.slice(0,2).forEach(([w,i],n)=>this.later(()=>gRxShow(w,i),700+n*800))},
 val(c){return c.j?60:(this.trump&&c.s===this.trump?20+c.r:c.r)},
 botTrump(p){const sc={};for(const c of this.first3[p])if(!c.j)sc[c.s]=(sc[c.s]||0)+c.r;const best=Object.entries(sc).sort((a,b)=>b[1]-a[1])[0];return best&&best[1]>=11?best[0]:null},
 botBid(p){const hand=this.hands[p],n=hand.length,lv=this===JK?bLvl('joker'):3;let e=0;
  if(lv>=3)e=jEst(hand,this.trump);
  else for(const c of hand){if(c.j)e+=1;else if(this.trump&&c.s===this.trump)e+=c.r>=13?.9:c.r>=11?.55:.3;else e+=c.r===14?.7:c.r===13?.3:0}
  if(lv===1)e+=Math.random()*2.4-1.2;
  let b=Math.max(0,Math.min(n,Math.round(e)));if(b===this.forbidden(p))b=b>0?b-1:b+1;return Math.min(n,b)},
 botPlay(p){const L=this.legal(p),need=this.bids[p]-this.taken[p],t=this.trick,nj=L.filter(c=>!c.j),jk=L.find(c=>c.j),lv=this===JK?bLvl('joker'):3;
  if(lv===1&&Math.random()<.45){const c=L[Math.floor(Math.random()*L.length)];return c.j?{c,jm:Math.random()<.5?'hi':'lo',js:this.trump||SUITS[Math.floor(Math.random()*4)]}:{c}}
  /* the top level leads a card nobody can beat any more: every higher card of its suit is already played or in its own hand */
  if(lv>=4&&!t.length&&this.gone){const hand=this.hands[p],sure=c=>!c.j&&(!this.trump||c.s===this.trump||this.gone.size>=20)&&[...Array(14-c.r)].every((_,k)=>{const r=c.r+1+k;return this.gone.has(c.s+r)||hand.some(h=>!h.j&&h.s===c.s&&h.r===r)});
   const ss=nj.filter(sure);if(need>0&&ss.length)return{c:ss.sort((a,b)=>this.val(b)-this.val(a))[0]};if(need<=0){const safe=nj.filter(c=>!sure(c));if(safe.length)return{c:safe.sort((a,b)=>this.val(a)-this.val(b))[0]}}}
  const wins=c=>this.winner([...t,{p,card:c,jm:null,js:null}])===p,byV=(a,b)=>this.val(a)-this.val(b);
  if(!t.length){if(need>0){const top=nj.slice().sort(byV).pop();if(top&&(top.r===14||(this.trump&&top.s===this.trump&&top.r>=13)))return{c:top};if(jk)return{c:jk,jm:'hi',js:this.trump||SUITS[Math.floor(Math.random()*4)]};return{c:top||L[0]}}
   const low=nj.slice().sort(byV)[0];return low?{c:low}:{c:L[0],jm:'lo',js:this.trump||'h'}}
  if(need>0){const w=nj.filter(wins).sort(byV);if(w.length)return{c:w[0]};if(jk&&this.winner([...t,{p,card:jk,jm:'hi',js:null}])===p)return{c:jk,jm:'hi'};return{c:nj.sort(byV)[0]||L[0],jm:'lo'}}
  const lose=nj.filter(c=>!wins(c)).sort(byV);if(lose.length)return{c:lose.pop()};if(jk)return{c:jk,jm:'lo'};return{c:nj.sort(byV)[0]}},
 render(){if(S.tab!=='games'||S.game!=='joker'||S.page)return;const top=gTop('ჯოკერი',null);
  if(this.phase==='setup'){view.innerHTML=gShell('joker',{top,center:`<section class="setupc"><h3>ჯოკერი ოთხ კაცზე</h3><p class="note">36 კარტი, ორი ჯოკერი. ყოველ ხელში წინასწარ თქვი, რამდენ ხელს წაიღებ. თუ ზუსტად იმდენს წაიღებ, რამდენიც თქვი, ქულებს მიიღებ. მეტოქეებს ბოტი თამაშობს.</p>
   <div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn" data-a="jstart" data-m="quick">სწრაფი · 8 ხელი</button><button class="btn ghost" data-a="jstart" data-m="full">სრული · 24 ხელი</button></div>
   <div class="jkonline"><div><b>მეგობრებთან ონლაინ</b><p class="note">გაშალე მაგიდა და მოიწვიე მეგობრები. ცარიელ ადგილებზე ბოტები ჩაჯდებიან.</p></div><button class="btn ghost" data-a="jkonew">${ic('users')}მაგიდის გაშლა</button></div></section>`,bot:''});return}
  const g3=g3Want(),mine=this.cur===0&&['bid','play','trump'].includes(this.phase)&&this.win==null;gTurnSnd(this,mine);
  const pips=p=>jPips(this.bids[p],this.taken[p]);
  const seat=(p,pos)=>`<div class="seat ${pos}${this.cur===p&&(this.phase==='bid'||this.phase==='play'||this.phase==='trump')?' turn':''}">${avAny(this.ids[p],38)}<b>${esc(this.nm(p))}</b>${pips(p)}<span>${this.score[p]}</span></div>`;
  const tr=this.trick.map(e=>{const h=jCardHTML(e.card).replace('class="card','class="card p'+e.p);return e.card.j?h.replace('</div>',`<span class="jm">${e.jm==='hi'?'მაღალი':'დაბალი'}${e.js?' '+SY[e.js]:''}</span></div>`):h}).join('');
  const trumpTxt=this.phase==='trump'?'კოზირი ირჩევა':this.trump?`კოზირი: <b style="color:${suitInk(this.trump)}">${SY[this.trump]}</b> ${SN[this.trump]}`:'უკოზირო';
  const L=this.phase==='play'&&this.cur===0?this.legal(0):[];
  const hand=this.phase==='trump'&&this.cur===0?this.first3[0].map(c=>jCardHTML(c)).join('')+'<div class="card" style="opacity:.25" aria-hidden="true"></div>'.repeat(this.n-3)
   :this.hands[0].map((c,i)=>`<button class="card${c.j?' jk':''}${!c.j&&isRed(c.s)?' red':''}" data-a="jcard" data-i="${i}"${c.j?'':` data-s="${SY[c.s]}"`} aria-label="${cardName(c)}"${L.includes(c)?'':' disabled'}>${c.j?'<i>★</i>ჯოკერი':`<span>${rkTxt(c.r)}</span><span class="s2">${SY[c.s]}</span>`}</button>`).join('');
  let panel='',st='';
  if(this.phase==='trump'){if(this.cur===0){st='ნახე პირველი სამი კარტი და აირჩიე კოზირი';panel=`<div class="suits">${SUITS.map(s=>`<button class="${isRed(s)?'red':''}" data-a="jtrump" data-s="${s}" aria-label="${SN[s]}">${SY[s]}</button>`).join('')}</div><button class="btn ghost" data-a="jtrump" data-s="" style="align-self:center">უკოზირო</button>`}else st=esc(this.nm(this.cur))+' ირჩევს კოზირს…'}
  else if(this.phase==='bid'){if(this.cur===0){const f=this.forbidden(0),hn=jHintOn()?jHint(this.hands[0],this.trump,this.n,f):-1;st='რამდენს წაიღებ?'+(f>=0?` დამრიგებელი ხარ, ${f}-ს ვერ იტყვი`:'')+(hn>=0?`<small class="bhint">რჩევა: ${hn===0?'პასი':hn}</small>`:'');panel=`<div class="bids" role="group" aria-label="ნათქვამი" style="--c:${jBidCols(this.n)}">${Array.from({length:this.n+1},(_,v)=>`<button data-a="jbid" data-v="${v}"${v===f?' disabled':''}${v===hn?' class="hint" aria-description="რჩევა"':''}>${v===0?'პასი':v}</button>`).join('')}</div>`}else st=esc(this.nm(this.cur))+' ამბობს…'}
  else if(this.phase==='play'){st=this.win!=null?(this.win===0?'ეს ხელი შენ წაიღე':esc(JK_ERG[this.win-1])+' წაიღო ხელი'):this.cur===0?(g3?'შენი სვლაა. შეეხე კარტს ორჯერ ან აიტანე მაგიდაზე':'შენი სვლაა'):esc(this.nm(this.cur))+' ფიქრობს…'}
  else if(this.phase==='handover'||this.phase==='over'){const{hand:last,prem}=jLast(this.hist);const mn=last.p[0]+(prem?prem.p[0]:0);
   st=this.phase==='over'?(this.score[0]===Math.max(...this.score)?'მოიგე! +12 რეიტინგი, +10 მონეტა':'თამაში დასრულდა'):`ხელი დასრულდა. შენ: ${mn>0?'+':''}${mn}`+(prem?' · სექციის პრემია':'');
   panel=''}
  const info=`<div class="ginfo"><span class="trump">${trumpTxt}</span><span>ხელი ${Math.min(this.h+1,JSEQ[this.len].length)}/${JSEQ[this.len].length}, ${this.n} კარტი</span>${this.lastT&&this.phase==='play'?jLastBtn('jlast'):''}</div>`;
  const stage=`<div class="jt${g3?' g3jt':''}">${seat(2,'top')}${seat(1,'left')}${seat(3,'right')}<div class="trick" aria-label="მაგიდა">${tr}</div>${g3?`<div class="g3 g3-joker${G3W.ready?'':' loading'}">${g3Rv()}${G3W.ready?'':'<span class="g3load" aria-hidden="true"></span>'}</div>`:''}</div>`;
  let res='';if(this.phase==='over'){const mx=Math.max(...this.score),win=this.score[0]===mx,pl=[0,1,2,3].sort((a,b)=>this.score[b]-this.score[a]);
   res=gResBox(this,{title:win?'მოიგე!':'თამაში დასრულდა',sub:win?'ყველაზე მეტი ქულა შენ დააგროვე':'გაიმარჯვა: '+esc(this.nm(pl[0])),kind:win?'win':'lose',more:`<div class="gendt">${pl.map(p=>`<span><b>${esc(this.nm(p))}</b>${this.score[p]}</span>`).join('')}</div>`,again:'<button class="btn gold" data-a="jagain">ახალი თამაში</button>',share:win?gShareBtn('joker',this.score[0]+' ქულით'):''})}
  gSaveLater(this);view.innerHTML=gShell('joker',{stage,mid:stage,top:top+info+jMiniHTML(this.hist,this.score,[0,1,2,3].map(p=>this.nm(p)),this.phase==='handover','jsheet'),bot:`<div class="pl me${mine?' turn':''}"><span class="plav">${av('me',34)}</span><span class="pln"><b>${esc(ME.name)}</b><span class="muted jme">${pips(0)}<span>${this.score[0]} ქულა</span></span></span></div>
   <div class="hand${g3?' g3sr':''}" aria-label="შენი კარტები">${hand}</div><div class="status${mine?' mine':''}" role="status">${st}</div>${panel}`,res});
  g3After('joker')}};
const JK_RULES='ფერი უნდა აჰყვე. თუ ფერი არ გაქვს, კოზირი უნდა დადო. ჯოკერი ნებისმიერ დროს შეგიძლია დადო: „მაღალი“ წაიღებს ხელს, „დაბალი“ არ წაიღებს. მოგვიანებით დადებული მაღალი ჯოკერი უფრო ძლიერია. ჯოკერით დაწყებისას ითხოვ ფერს: „მაღალი“ ნიშნავს, რომ ყველამ ამ ფრის უმაღლესი კარტი უნდა დადოს და ხელი შენია, თუმცა თუ ფერი კოზირი არ არის და ვინმემ კოზირი დადო, უმაღლესი კოზირი წაიღებს. „დაბალი“ ნიშნავს, რომ ამ ფრის უმაღლესი კარტი წაიღებს. ქულები: ზუსტად ნათქვამი 50 თითო ხელზე და 50 ბონუსი, ყველა ხელის წაღება 100 თითოზე, პასი და ნული 50. მეტის ან ნაკლების წაღებისას 10 თითოზე. თუ თქვი და ვერცერთი ვერ წაიღე, ხიშტი: −200, ცხრიან სექციებში −500. ვინც სექციის ყველა ხელში ზუსტად ნათქვამს წაიღებს, პრემიას იღებს: მისი საუკეთესო ხელი ორმაგდება, დანარჩენებს კი საუკეთესო ხელი ეშლებათ.';
A.jstart=t=>JK.begin(t.dataset.m);
A.jagain=()=>{JK.resHide=0;JK.resSnd=0;JK.start();JK.render()};
A.jnext=()=>{if(JK.phase==='handover')JK.newHand()};
A.jbid=t=>{if(JK.phase==='bid'&&JK.cur===0)JK.bid(0,+t.dataset.v)};
A.jtrump=t=>{if(JK.phase==='trump'&&JK.cur===0)JK.setTrump(t.dataset.s)};
const jkJokerSheet=(lead,a)=>sheet(head('ჯოკერი')+(lead?`<div class="form"><b>მაღალი: ვითხოვ ამ ფრის უმაღლესს და ხელს ვიღებ</b><div class="suits">${SUITS.map(s=>`<button class="${isRed(s)?'red':''}" data-a="${a}" data-m="hi" data-s="${s}" aria-label="მაღალი, ${SN[s]}">${SY[s]}</button>`).join('')}</div><b>დაბალი: ამ ფრის უმაღლესმა წაიღოს</b><div class="suits">${SUITS.map(s=>`<button class="${isRed(s)?'red':''}" data-a="${a}" data-m="lo" data-s="${s}" aria-label="დაბალი, ${SN[s]}">${SY[s]}</button>`).join('')}</div></div>`
  :`<div class="jchoice"><button data-a="${a}" data-m="hi">მაღალი<br><small class="muted">წაიღებს ხელს</small></button><button data-a="${a}" data-m="lo">დაბალი<br><small class="muted">არ წაიღებს</small></button></div>`),'short');
A.jcard=t=>{if(JK.phase!=='play'||JK.cur!==0)return;const c=JK.hands[0][+t.dataset.i];if(!c||!JK.legal(0).includes(c))return;
 if(!c.j){JK.playCard(0,c);return}JK.pj=c;jkJokerSheet(!JK.trick.length,'jj')};
A.jj=t=>{closeSheet();if(JK.pj&&JK.phase==='play'&&JK.cur===0){const c=JK.pj;JK.pj=null;JK.playCard(0,c,t.dataset.m,t.dataset.s||null)}};
A.jsheet=()=>jSheetOpen(JK.hist,JK.score||[0,0,0,0],[0,1,2,3].map(p=>JK.nm(p)));
A.jlast=()=>jLastOpen(JK.lastT,p=>p===0?'შენ':JK.nm(p),0);
/* menu switches for cards: the four-colour deck, and the bid hint against the computer */
function gSwFlip(t,on){const b=t&&t.closest&&t.closest('button'),s=b&&b.querySelector('.sw');if(b)b.setAttribute('aria-pressed',String(on));if(s)s.classList.toggle('on',on)}
function gRedraw(){if(S.page&&S.page.id==='jktable'){if(typeof joDraw==='function')joDraw();return}const G=S.tab==='games'&&GAME[S.game];if(G&&G.render)G.render()}
A.gc4=t=>{const on=!c4On();store.set('c4',on);document.documentElement.classList.toggle('c4',on);gSwFlip(t,on);gRedraw()};
A.ghint=t=>{const on=!jHintOn();store.set('jkhint',on);gSwFlip(t,on);gRedraw()};

/* flat boards: moving pieces, rolling dice, dealt cards (the 3D boards animate by themselves) */
{const p=CH.play,r=CH.render,l=CH.load;
 CH.play=function(m){this.anim=[m.f,m.t];p.call(this,m)};
 CH.load=function(s){const prev=this.st&&this.st.last;l.call(this,s);const n=this.st.last;if(n.length===2&&(!prev||prev.join()!==n.join()))this.anim=n};
 CH.render=function(){r.call(this);if(S.tab!=='games'||S.game!=='chess')return;const st=this.st,k=st.rep&&st.rep[st.rep.length-1];if(this.inCheck()&&!st.over&&k!==this.chk){this.chk=k;gSnd('check')}
  if(this.anim&&!g3On()){const[a,b]=this.anim;flipPiece($(`.cs[data-i="${a}"]`,view),$(`.cs[data-i="${b}"]`,view));gSnd('wood')}this.anim=null}}
{const p=CK.play,r=CK.render,l=CK.load;
 CK.play=function(m){this.anim=[m.path[0],m.path[m.path.length-1]];p.call(this,m)};
 CK.load=function(s){const prev=JSON.stringify(this.last||[]);l.call(this,s);if(this.last.length>1&&JSON.stringify(this.last)!==prev)this.anim=[this.last[0],this.last[this.last.length-1]]};
 CK.render=function(){r.call(this);if(this.anim&&S.tab==='games'&&S.game==='shashi'&&!g3On()){const[a,b]=this.anim;const q=x=>$(`.sq[data-r="${x[0]}"][data-c="${x[1]}"]`,view);flipPiece(q(a),q(b));gSnd(this.lcap&&this.lcap.length?'cap':'wood')}this.anim=null}}
{const m=NR.move,ro=NR.roll,r=NR.render;
 NR.move=function(s,f,to,d){m.call(this,s,f,to,d);this.lastTo=to};
 NR.roll=function(){ro.call(this);this.rollAnim=1};
 NR.render=function(){r.call(this);if(S.tab!=='games'||S.game!=='nardi')return;const sig=this.rolled?this.turn+':'+this.last.join():'';if(sig&&sig!==this.rsig)gSnd('dice');this.rsig=sig;
  if(g3On()){this.lastTo=null;return}if(this.lastTo!=null)gSnd('wood');
  if(this.rollAnim){this.rollAnim=0;$$('.dice .die',view).forEach(d=>d.classList.add('roll'))}
  if(this.lastTo!=null){const k=this.lastTo;this.lastTo=null;const el=k==='off'?$('.offbtn',view):$(`.pt[data-k="${k}"]`,view);if(el){const c=k==='off'?el:[...el.querySelectorAll('.ch')].pop();if(c){c.classList.add('drop');if(k==='off')pop(c)}}}}}
{const nh=JK.newHand,pc=JK.playCard,r=JK.render,V={0:'0 130px',1:'-130px 0',2:'0 -130px',3:'130px 0'};
 JK.newHand=function(){this.dealAnim=1;nh.call(this)};
 JK.playCard=function(p,c,jm,js){this.newCard=p;pc.call(this,p,c,jm,js);if(this.win!=null&&!g3On()){const w=this.win,tk=this.tk;setTimeout(()=>{if(tk!==this.tk)return;$$('.trick .card',view).forEach(el=>anim(el,[{translate:'0 0',opacity:1},{translate:V[w],opacity:0}],{duration:380,easing:EASE,fill:'forwards'}))},950)}};
 JK.render=function(){r.call(this);if(S.tab!=='games'||S.game!=='joker'||g3On()){this.dealAnim=0;this.newCard=null;return}if(this.dealAnim)gSnd('deal');if(this.newCard!=null)gSnd('card');
  if(this.dealAnim){this.dealAnim=0;$$('.hand .card',view).forEach((el,i)=>anim(el,[{translate:'0 -70px',opacity:0},{translate:'0 0',opacity:1}],{duration:420,delay:i*55,easing:SPRING,fill:'backwards'}))}
  if(this.newCard!=null){const p=this.newCard;this.newCard=null;const el=$(`.trick .card.p${p}`,view);anim(el,[{translate:V[p],opacity:0},{translate:'0 0',opacity:1}],{duration:380,easing:EASE})}}}

/* ---------- how well the computer plays: four levels per game, chosen in the game menu ----------
   chess and checkers think in a background worker, so the board keeps moving while the bot searches */
const BLV=[null,{n:'ახალბედა',d:'ხშირად ცდება, კარგია სწავლისთვის'},{n:'მოყვარული',d:'საშუალო სირთულე, მშვიდი პარტიისთვის'},{n:'გამოცდილი',d:'უფრო შორს ითვლის და იშვიათად ცდება'},{n:'ოსტატი',d:'ყველაზე ძლიერი, დრო სჭირდება საფიქრად'}];
const bLvl=g=>{const v=(store.get('blv',{})||{})[g];return v>=1&&v<=4?v:2};
/* chess: negamax with alpha-beta, captures searched to quiet positions, moves ordered by what they take, deeper each round until time runs out */
function chOrder(ms,st,first){const val=m=>(st.b[m.t]?10*(CPV[st.b[m.t].toLowerCase()]||1e4)-(CPV[st.b[m.f].toLowerCase()]||0):0)+(m.pr?800:0)+(first&&m.f===first.f&&m.t===first.t?1e7:0);ms.sort((a,b)=>val(b)-val(a));return ms}
function chQS(st,al,be,d,T){const side=st.turn;if(chKing(st.b,side)<0)return -1e5;const sp=side*chEval(st.b);if(d<=0||sp>=be)return sp;if(sp>al)al=sp;
 for(const m of chOrder(chPseudo(st,side).filter(m=>st.b[m.t]||m.ep||m.pr),st)){const v=-chQS(chApply(st,m),-be,-al,d-1,T);if(v>=be)return v;if(v>al)al=v}return al}
function chNega(st,depth,al,be,ply,T){if((T.n++&1023)===0&&Date.now()>T.end)T.stop=true;const side=st.turn;if(chKing(st.b,side)<0)return -1e5+ply;if(depth<=0)return T.qs?chQS(st,al,be,4,T):side*chEval(st.b);
 const ms=chOrder(chPseudo(st,side),st);if(!ms.length)return 0;let best=-1e9;
 for(const m of ms){const v=-chNega(chApply(st,m),depth-1,-be,-al,ply+1,T);if(T.stop)return best>-1e9?best:v;if(v>best)best=v;if(v>al)al=v;if(al>=be)break}return best}
function chThinkSync(st,lvl,budget){const L=chLegal(st,st.turn);if(!L.length)return null;if(lvl===1&&Math.random()<.25)return L[Math.floor(Math.random()*L.length)];
 const T={n:0,end:Date.now()+budget,stop:false,qs:lvl>=3},maxD=[0,1,3,4,6][lvl],noise=[0,150,14,8,5][lvl];let bestM=L[0];
 for(let d=1;d<=maxD;d++){let bv=-1e9,bm=null,al=-1e9;for(const m of chOrder(L.slice(),st,bestM)){const raw=-chNega(chApply(st,m),d-1,-1e9,-(al-noise),1,T),v=raw+Math.random()*noise;if(T.stop)break;if(v>bv){bv=v;bm=m}if(raw>al)al=raw}
  if(T.stop&&d>1)break;if(bm)bestM=bm}return bestM}
/* checkers: the same search; a forced capture is played at once */
function ckNega(b,side,depth,al,be,T){if((T.n++&1023)===0&&Date.now()>T.end)T.stop=true;const ms=ckAll(b,side);if(!ms.length)return -100;if(depth<=0)return side*ckEval(b);
 let best=-1e9;for(const m of ms){const v=-ckNega(ckApply(b,m),-side,depth-1,-be,-al,T);if(T.stop)return best>-1e9?best:v;if(v>best)best=v;if(v>al)al=v;if(al>=be)break}return best}
function ckThinkSync(b,side,lvl,budget){const L=ckAll(b,side);if(!L.length)return null;if(L.length===1)return L[0];if(lvl===1&&Math.random()<.25)return L[Math.floor(Math.random()*L.length)];
 const T={n:0,end:Date.now()+budget,stop:false},maxD=[0,1,4,6,9][lvl],noise=[0,.6,.08,.03,0][lvl];let bestM=L[0];
 for(let d=1;d<=maxD;d++){let bv=-1e9,bm=null,al=-1e9;for(const m of L){const raw=-ckNega(ckApply(b,m),-side,d-1,-1e9,-(al-noise),T),v=raw+Math.random()*noise;if(T.stop)break;if(v>bv){bv=v;bm=m}if(raw>al)al=raw}
  if(T.stop&&d>1)break;if(bm)bestM=bm}return bestM}
const BOTW={w:undefined,id:0,cb:new Map()};
function botWorker(){if(BOTW.w!==undefined)return BOTW.w;BOTW.w=null;
 try{if(typeof Worker!=='function')return null;const J=v=>JSON.stringify(v);
  const src=[`const CPV=${J(CPV)},KN=${J(KN)},KG=${J(KG)},BD=${J(BD)},RD=${J(RD)},PST=${J(PST)},PSTS=${J(PSTS)},DIRS=${J(DIRS)};`,`const isW=${isW};const colOf=${colOf};const chKing=${chKing};const chLegal=${chLegal};const inB=${inB};`,
   chAttacked,chPseudo,chApply,chEval,chOrder,chQS,chNega,chThinkSync,ckJumps,ckAll,ckApply,ckEval,ckNega,ckThinkSync].map(String).join('\n')
   +`\nonmessage=e=>{const d=e.data;let m=null;try{m=d.g==='chess'?chThinkSync(d.st,d.lvl,d.budget):ckThinkSync(d.b,d.side,d.lvl,d.budget)}catch(x){}postMessage({id:d.id,m})}`;
  const w=new Worker(URL.createObjectURL(new Blob([src],{type:'text/javascript'})));w.onmessage=e=>{const f=BOTW.cb.get(e.data.id);if(f){BOTW.cb.delete(e.data.id);f(e.data.m)}};w.onerror=()=>{BOTW.w=null};BOTW.w=w}catch(e){BOTW.w=null}return BOTW.w}
function botThink(job){return new Promise(res=>{const w=botWorker(),sync=()=>{try{res(job.g==='chess'?chThinkSync(job.st,job.lvl,job.budget):ckThinkSync(job.b,job.side,job.lvl,job.budget))}catch(e){res(null)}};
 if(!w){sync();return}const id=++BOTW.id;BOTW.cb.set(id,res);try{w.postMessage(Object.assign({id},job))}catch(e){BOTW.cb.delete(id);sync();return}setTimeout(()=>{if(BOTW.cb.has(id)){BOTW.cb.delete(id);sync()}},job.budget+5000)})}
const BUDGET=[0,200,400,700,1600];
/* nardi: the strongest level knows when the armies have passed each other and it is only a race home */
function nEval4(T,s){const o=-s,pip=x=>{let n=T.bar[x]*25;for(let i=0;i<24;i++)if(T.p[i]*x>0)n+=Math.abs(T.p[i])*nDist(x,i);return n};
 let mx=-1,mn=24;for(let i=0;i<24;i++){if(T.p[i]>0){mx=Math.max(mx,i);mn=Math.min(mn,i)}}let mxo=-1,mno=24;for(let i=0;i<24;i++)if(T.p[i]<0){mxo=Math.max(mxo,i);mno=Math.min(mno,i)}
 const contact=T.bar[1]||T.bar[-1]||(mx>mno);if(!contact)return(pip(o)-pip(s))*1.6+(T.off[s]-T.off[o])*5;
 let sc=nEval(T,s),home=0;for(let k=0;k<6;k++){const i=s===1?k:23-k;if(T.p[i]*s>=2)home++}return sc+home*home*.35}
/* the menu row and its sheet */
A.gbot=()=>{const id=gCur();if(!id)return;const lv=bLvl(id);sheet(head('ბოტის დონე')+`<div class="gmenu">${[1,2,3,4].map(v=>`<button data-a="gbotset" data-v="${v}"${v===lv?' aria-pressed="true"':''}>${ic(v===lv?'check':'user')}<span><b>${BLV[v].n}</b><br><small class="muted">${BLV[v].d}</small></span></button>`).join('')}</div>`,'short')};
A.gbotset=t=>{const id=gCur();if(!id)return;const m=Object.assign({},store.get('blv',{})||{});m[id]=+t.dataset.v;store.set('blv',m);closeSheet();toast('ბოტის დონე: '+BLV[+t.dataset.v].n);const G=GAME[id];if(G&&G.render)G.render()};
