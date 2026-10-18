/* ---------- checkers (შაში): Russian rules, mandatory capture, flying kings ---------- */
const DIRS=[[-1,-1],[-1,1],[1,-1],[1,1]];
const inB=(r,c)=>r>=0&&r<8&&c>=0&&c<8;
function ckJumps(b,r,c,king,side,path,cap,out){let ext=false;const taken=(a,d)=>cap.some(x=>x[0]===a&&x[1]===d);
 for(const[dr,dc]of DIRS){
  if(king){let rr=r+dr,cc=c+dc;while(inB(rr,cc)&&!b[rr][cc]){rr+=dr;cc+=dc}
   if(!inB(rr,cc)||Math.sign(b[rr][cc])!==-side||taken(rr,cc))continue;
   let lr=rr+dr,lc=cc+dc;while(inB(lr,lc)&&!b[lr][lc]){ext=true;ckJumps(b,lr,lc,true,side,[...path,[lr,lc]],[...cap,[rr,cc]],out);lr+=dr;lc+=dc}}
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
function ckEval(b){let s=0;for(let r=0;r<8;r++)for(let c=0;c<8;c++){const p=b[r][c];if(p)s+=Math.sign(p)*(Math.abs(p)===2?3.2:1+(p>0?7-r:r)*.04+(c>1&&c<6?.03:0))}return s}
function ckSearch(b,side,depth,al,be){const ms=ckAll(b,side);if(!ms.length)return -side*100;if(!depth)return ckEval(b);
 let best=side===1?-1e9:1e9;for(const m of ms){const v=ckSearch(ckApply(b,m),-side,depth-1,al,be);
  if(side===1){if(v>best)best=v;if(v>al)al=v}else{if(v<best)best=v;if(v<be)be=v}if(be<=al)break}return best}
function ckBot(b,side){let best=null,bv=-1e9;for(const m of ckAll(b,side)){const v=side*ckSearch(ckApply(b,m),-side,3,-1e9,1e9)+Math.random()*.08;if(v>bv){bv=v;best=m}}return best}
const CK=GAME.shashi={title:'შაში',
 start(){this.b=Array.from({length:8},(_,r)=>Array.from({length:8},(_,c)=>(r+c)%2?(r<3?-1:r>4?1:0):0));this.turn=1;this.sel=null;this.last=[];this.over=0;this.moves=ckAll(this.b,1)},
 snap(){return{b:this.b,turn:this.turn,last:this.last,over:this.over}},
 load(s){if(!Array.isArray(s.b)||s.b.length!==8)throw 0;this.b=s.b.map(r=>r.map(v=>[-2,-1,0,1,2].includes(v)?v:0));this.turn=s.turn===-1?-1:1;this.last=Array.isArray(s.last)?s.last:[];this.over=[1,-1].includes(s.over)?s.over:0;this.sel=null;this.moves=ckAll(this.b,this.turn)},
 mine(){return isPlayer(this.ctx)&&this.turn===this.ctx.side&&!this.over&&!this.ctx.gone},
 status(must){const c=this.ctx;if(this.over)return endMsg(c,this.over);if(c.gone)return 'მოწინააღმდეგე გავიდა თამაშიდან';if(this.mine())return must?'მოჭრა სავალდებულოა. აირჩიე მოციმციმე ქვა':this.sel?'აირჩიე უჯრა, სადაც გადავა':'შენი სვლაა';return esc(c.names[this.turn])+' ფიქრობს…'},
 render(){const c=this.ctx,flip=c.side===-1,b=this.b,sel=this.sel,mine=this.mine();
  const tg=sel?this.moves.filter(m=>m.path[0][0]===sel[0]&&m.path[0][1]===sel[1]).map(m=>m.path[m.path.length-1].join()):[];
  const must=mine&&this.moves.length&&this.moves[0].caps.length,movable=new Set(mine?this.moves.map(m=>m.path[0].join()):[]);
  let cells='';for(let dr=0;dr<8;dr++)for(let dc=0;dc<8;dc++){const r=flip?7-dr:dr,cc=flip?7-dc:dc,d=(r+cc)%2,p=b[r][cc],k=r+','+cc;
   cells+=`<button class="sq ${d?'d':'l'}${sel&&sel.join()===k?' sel':''}${tg.includes(k)?' tgt':''}${this.last.some(x=>x.join()===k)?' last':''}"${d?` data-a="ck" data-r="${r}" data-c="${cc}"`:' disabled tabindex="-1"'} aria-label="${'abcdefgh'[cc]}${8-r}${p?(p>0?' თეთრი':' შავი')+(Math.abs(p)===2?' დამა':''):''}">${p?`<span class="man ${p>0?'w':'b'}${Math.abs(p)===2?' k':''}${must&&movable.has(k)?' can':''}"></span>`:''}</button>`}
  const cnt=s=>b.flat().filter(v=>Math.sign(v)===s).length;
  gview('shashi','შაში',`<div class="ck" aria-label="შაშის დაფა">${cells}</div>`,this.status(must),`<p class="note">${isPlayer(c)?'შენ '+(c.side===1?'თეთრებით':'შავებით')+' თამაშობ. ':''}ქვა უკანაც ჭრის, დამა მთელ დიაგონალზე დადის. ქვები: თეთრი ${cnt(1)}, შავი ${cnt(-1)}.</p>${tourBack(c)}`)},
 play(m){this.b=ckApply(this.b,m);this.last=m.path;this.sel=null;this.turn*=-1;this.moves=ckAll(this.b,this.turn);if(!this.moves.length)this.over=-this.turn;
  if(this.ctx.mode==='online')netSend();if(this.over){finish(this,this.over);return}this.render();this.kick()},
 kick(){const c=this.ctx;if(this.over)return;if(!(c.mode==='watch'||((c.mode==='bot'||c.mode==='tour')&&this.turn!==c.side)))return;const b0=this.b;
  setTimeout(()=>{if(this.ctx!==c||this.b!==b0||this.over)return;const m=ckBot(this.b,this.turn);if(m)this.play(m)},c.mode==='watch'?1000:650)},
 checkEnd(){if(this.over)finish(this,this.over)}};
A.ck=t=>{const G=CK;if(!G.mine())return;const r=+t.dataset.r,c=+t.dataset.c,me=G.ctx.side;
 if(G.sel){const m=G.moves.find(m=>m.path[0][0]===G.sel[0]&&m.path[0][1]===G.sel[1]&&m.path[m.path.length-1][0]===r&&m.path[m.path.length-1][1]===c);if(m){G.play(m);return}}
 G.sel=Math.sign(G.b[r][c])===me&&G.moves.some(m=>m.path[0][0]===r&&m.path[0][1]===c)?[r,c]:null;G.render()};

/* ---------- nardi (backgammon): side 1 = white, moves from point 24 to 1 ---------- */
const PIPS={1:[4],2:[0,8],3:[0,4,8],4:[0,2,6,8],5:[0,2,4,6,8],6:[0,2,3,5,6,8]};
const dieHTML=(v,used)=>`<span class="die${used?' used':''}" role="img" aria-label="${v}">${Array.from({length:9},(_,k)=>PIPS[v].includes(k)?'<i></i>':'<span></span>').join('')}</span>`;
const NR=GAME.nardi={title:'ნარდი',
 start(){const p=Array(24).fill(0);p[23]=2;p[12]=5;p[7]=3;p[5]=5;p[0]=-2;p[11]=-5;p[16]=-3;p[18]=-5;
  this.p=p;this.bar={1:0,'-1':0};this.off={1:0,'-1':0};this.dice=[];this.last=[];this.turn=1;this.rolled=false;this.sel=null;this.over=0},
 snap(){return{p:this.p,bar:this.bar,off:this.off,dice:this.dice,last:this.last,turn:this.turn,rolled:this.rolled,over:this.over}},
 load(s){const n=v=>Math.max(0,Math.min(15,Number(v)||0)),d=a=>Array.isArray(a)?a.map(Number).filter(x=>x>=1&&x<=6).slice(0,4):[];
  if(!Array.isArray(s.p)||s.p.length!==24)throw 0;this.p=s.p.map(v=>Math.max(-15,Math.min(15,Number(v)||0)));this.bar={1:n(s.bar&&s.bar[1]),'-1':n(s.bar&&s.bar['-1'])};this.off={1:n(s.off&&s.off[1]),'-1':n(s.off&&s.off['-1'])};
  this.dice=d(s.dice);this.last=d(s.last).slice(0,2);this.turn=s.turn===-1?-1:1;this.rolled=!!s.rolled;this.over=[1,-1].includes(s.over)?s.over:0;this.sel=null},
 home(s){if(this.bar[s])return false;for(let i=0;i<24;i++)if(this.p[i]*s>0&&!(s===1?i<=5:i>=18))return false;return true},
 dist(s,i){return s===1?i+1:24-i},
 target(s,from,d){
  if(from==='bar'){if(!this.bar[s])return null;const to=s===1?24-d:d-1;return this.p[to]*s<=-2?null:to}
  if(this.bar[s]||this.p[from]*s<=0)return null;const to=from-s*d;
  if(to<0||to>23){if(!this.home(s))return null;const ds=this.dist(s,from);if(d===ds)return 'off';for(let i=0;i<24;i++)if(this.p[i]*s>0&&this.dist(s,i)>ds)return null;return 'off'}
  return this.p[to]*s<=-2?null:to},
 opts(s,from){return[...new Set(this.dice)].map(d=>({d,to:this.target(s,from,d)})).filter(o=>o.to!==null)},
 any(s){return(this.bar[s]?['bar']:[...Array(24).keys()]).some(f=>this.opts(s,f).length)},
 move(s,from,to,d){if(from==='bar')this.bar[s]--;else this.p[from]-=s;
  if(to==='off')this.off[s]++;else{if(this.p[to]*s===-1){this.p[to]=0;this.bar[-s]++}this.p[to]+=s}
  this.dice.splice(this.dice.indexOf(d),1);if(this.off[s]===15)this.over=s},
 roll(){const a=1+Math.floor(Math.random()*6),b=1+Math.floor(Math.random()*6);this.last=[a,b];this.dice=a===b?[a,a,a,a]:[a,b];this.rolled=true},
 mine(){return isPlayer(this.ctx)&&this.turn===this.ctx.side&&!this.over&&!this.ctx.gone},
 botPick(s){let best=null,bs=-1e9;const inHome=i=>s===1?i<=5:i>=18;
  for(const f of(this.bar[s]?['bar']:[...Array(24).keys()]))for(const o of this.opts(s,f)){const to=o.to;let sc=Math.random()*2+o.d*.3;
   if(f==='bar')sc+=50;if(to==='off')sc+=30;
   else{const v=this.p[to]*s;if(v===-1)sc+=24+(inHome(to)?6:0);if(v===1)sc+=16;if(v===0)sc-=5+(inHome(to)?0:3);if(inHome(to))sc+=4}
   if(f!=='bar'&&this.p[f]*s===2)sc-=7;
   if(sc>bs){bs=sc;best={f,to,d:o.d}}}
  return best},
 endTurn(){this.turn*=-1;this.rolled=false;this.dice=[];this.sel=null;if(this.ctx.mode==='online')netSend();this.render();this.kick()},
 kick(){const c=this.ctx;if(this.over)return;if(!(c.mode==='watch'||((c.mode==='bot'||c.mode==='tour')&&this.turn!==c.side)))return;const s=this.turn,fast=c.mode==='watch';
  setTimeout(()=>{if(this.ctx!==c||this.over||this.turn!==s||this.rolled)return;this.roll();this.render();
   const step=()=>{if(this.ctx!==c||this.over)return;const mv=this.botPick(s);if(!mv){this.endTurn();return}this.move(s,mv.f,mv.to,mv.d);if(this.over){finish(this,this.over);return}this.render();setTimeout(step,fast?600:550)};
   setTimeout(step,800)},fast?900:700)},
 checkEnd(){if(this.over)finish(this,this.over)},
 status(){const c=this.ctx,d=this.last.join(' და ');if(this.over)return endMsg(c,this.over);if(c.gone)return 'მოწინააღმდეგე გავიდა თამაშიდან';
  if(this.mine()){if(!this.rolled)return 'შენი ჯერია. გააგორე კამათელი';if(!this.any(c.side))return `გააგორე ${d}. სვლა არ გაქვს`;return this.sel!==null?'აირჩიე ოქროსფრად მონიშნული პუნქტი':`გააგორე ${d}. აირჩიე ქვა`}
  return esc(c.names[this.turn])+(this.rolled?' თამაშობს, გააგორა '+d:' აგორებს…')},
 render(){const c=this.ctx,me=c.side,flip=me===-1,s=this.sel,mine=this.mine(),tg=mine&&this.rolled&&s!==null?this.opts(me,s).map(o=>o.to):[];
  const ptHTML=(di,row,col)=>{const i=flip?23-di:di,v=this.p[i],n=Math.abs(v);let ch='';for(let k=0;k<Math.min(n,5);k++)ch+=`<span class="ch ${v>0?'w':'b'}">${k===4&&n>5?n:''}</span>`;
   return `<button class="pt ${row}${di%2?' alt':''}${s===i?' sel':''}${tg.includes(i)?' tgt':''}" style="grid-area:${row==='top'?1:3}/${col}" data-a="npt" data-k="${i}" aria-label="პუნქტი ${me===1?i+1:24-i}${n?', '+n+(v>0?' თეთრი':' შავი'):''}"><span class="tri"></span>${ch}</button>`};
  let pts='';for(let j=0;j<6;j++)pts+=ptHTML(12+j,'top',j+1)+ptHTML(18+j,'top',j+8)+ptHTML(11-j,'bot',j+1)+ptHTML(5-j,'bot',j+8);
  const bch=(sd,n)=>n?`<span class="ch ${sd===1?'w':'b'}">${n>1?n:''}</span>`:'';
  const bar=`<button class="barc${s==='bar'?' sel':''}" data-a="npt" data-k="bar" aria-label="ზარი: ${this.bar[me]} შენი, ${this.bar[-me]} მეტოქის">${bch(-me,this.bar[-me])}<span class="sp"></span>${bch(me,this.bar[me])}</button>`;
  const shown=this.dice.length?this.dice.map(v=>dieHTML(v)).join(''):this.last.map(v=>dieHTML(v,1)).join('');
  const ctl=`<div class="nctl"><div class="dice" aria-label="კამათელი">${shown}</div><span class="sp"></span>${mine&&!this.rolled?'<button class="btn" data-a="nroll">გაგორება</button>':''}</div>
  <div class="offs"><button class="offbtn${tg.includes('off')?' tgt':''}" data-a="npt" data-k="off">გატანილი: ${isPlayer(c)?'შენ':esc(c.names[me])} ${this.off[me]}/15</button><span class="offbtn" style="border-style:solid">${esc(c.names[-me])} ${this.off[-me]}/15</span></div>
  ${isPlayer(c)?`<p class="note">შენ ${me===1?'თეთრი':'შავი'} ქვებით თამაშობ და ქვედა მარჯვენა სახლისკენ მოძრაობ. შეეხე ქვას, შემდეგ ოქროსფრად მონიშნულ პუნქტს. მარტოხელა ქვა იჭრება და ზარზე გადადის. როცა ყველა ქვა სახლშია, გაიტანე ისინი.</p>`:''}${tourBack(c)}`;
  gview('nardi','ნარდი',`<div class="nb" aria-label="ნარდის დაფა">${pts}${bar}</div>`,this.status(),ctl)}};
A.nroll=()=>{const G=NR;if(!G.mine()||G.rolled)return;G.roll();if(G.ctx.mode==='online')netSend();G.render();
 if(!G.any(G.ctx.side)){const c=G.ctx;setTimeout(()=>{if(G.ctx===c&&G.turn===c.side)G.endTurn()},1400)}};
A.npt=t=>{const G=NR,me=G.ctx.side;if(!G.mine()||!G.rolled)return;const k=t.dataset.k,id=k==='bar'||k==='off'?k:+k;
 if(G.sel!==null){const o=G.opts(me,G.sel).find(o=>o.to===id);if(o){G.move(me,G.sel,o.to,o.d);G.sel=null;if(G.ctx.mode==='online')netSend();
  if(G.over){finish(G,G.over);return}if(!G.dice.length||!G.any(me)){G.render();const c=G.ctx;setTimeout(()=>{if(G.ctx===c&&G.turn===me)G.endTurn()},700)}else G.render();return}}
 G.sel=id!=='off'&&G.opts(me,id).length?id:null;G.render()};
/* ---------- chess ---------- */
const CPV={p:100,n:320,b:330,r:500,q:900,k:0};
const KN=[[-2,-1],[-2,1],[-1,-2],[-1,2],[1,-2],[1,2],[2,-1],[2,1]],KG=[[-1,-1],[-1,0],[-1,1],[0,-1],[0,1],[1,-1],[1,0],[1,1]],BD=[[-1,-1],[-1,1],[1,-1],[1,1]],RD=[[-1,0],[1,0],[0,-1],[0,1]];
const isW=p=>!!p&&p===p.toUpperCase();
const colOf=p=>!p?0:isW(p)?1:-1;
const GLY={k:'♚',q:'♛',r:'♜',b:'♝',n:'♞',p:'♟︎'},PNAME={k:'მეფე',q:'ლაზიერი',r:'ეტლი',b:'კუ',n:'მხედარი',p:'პაიკი'};
function chInit(){const r='rnbqkbnr',b=Array(64).fill('');for(let c=0;c<8;c++){b[c]=r[c];b[8+c]='p';b[48+c]='P';b[56+c]=r[c].toUpperCase()}return{b,turn:1,cs:'KQkq',ep:-1,last:[],over:0,hm:0}}
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
function chApply(st,m){const b=st.b.slice(),p=b[m.f],side=colOf(p);let cap=b[m.t];b[m.t]=m.pr?(side===1?'Q':'q'):p;b[m.f]='';
 if(m.ep){const cq=m.t+(side===1?8:-8);cap=b[cq];b[cq]=''}
 if(m.cs==='k'){b[m.f+1]=b[m.f+3];b[m.f+3]=''}if(m.cs==='q'){b[m.f-1]=b[m.f-4];b[m.f-4]=''}
 let cs=st.cs;if(p==='K')cs=cs.replace(/[KQ]/g,'');if(p==='k')cs=cs.replace(/[kq]/g,'');
 for(const[sq,ch]of[[63,'K'],[56,'Q'],[7,'k'],[0,'q']])if(m.f===sq||m.t===sq)cs=cs.replace(ch,'');
 return{b,turn:-st.turn,cs,ep:m.dbl?(m.f+m.t)/2:-1,last:[m.f,m.t],over:0,hm:(p.toLowerCase()==='p'||cap)?0:(st.hm||0)+1}}
const chKing=(b,side)=>b.indexOf(side===1?'K':'k');
const chLegal=(st,side)=>chPseudo(st,side).filter(m=>{const n=chApply(st,m);return !chAttacked(n.b,chKing(n.b,side),-side)});
const PST=[0,1,2,3,3,2,1,0];
function chEval(b){let s=0;for(let i=0;i<64;i++){const p=b[i];if(!p)continue;const t=p.toLowerCase(),w=isW(p)?1:-1,r=i>>3,c=i&7;let v=CPV[t];
 if(t==='n'||t==='b')v+=(PST[r]+PST[c])*4;else if(t==='p')v+=(w===1?6-r:r-1)*8+(c>1&&c<6?4:0);else if(t==='k')v+=(w===1?r===7:r===0)?12:0;s+=w*v}return s}
function chSearch(st,depth,al,be){if(chKing(st.b,1)<0)return -1e5;if(chKing(st.b,-1)<0)return 1e5;if(!depth)return chEval(st.b);
 const side=st.turn,ms=chPseudo(st,side);if(!ms.length)return chEval(st.b);const val=m=>st.b[m.t]?CPV[st.b[m.t].toLowerCase()]||1e4:0;ms.sort((a,b)=>val(b)-val(a));
 let best=side===1?-1e9:1e9;for(const m of ms){const v=chSearch(chApply(st,m),depth-1,al,be);if(side===1){if(v>best)best=v;if(v>al)al=v}else{if(v<best)best=v;if(v<be)be=v}if(be<=al)break}return best}
function chBot(st){const side=st.turn;let best=null,bv=-1e9;for(const m of chLegal(st,side)){const v=side*chSearch(chApply(st,m),2,-1e9,1e9)+Math.random()*8;if(v>bv){bv=v;best=m}}return best}
const CH=GAME.chess={title:'ჭადრაკი',
 start(){this.st=chInit();this.sel=null;this.moves=chLegal(this.st,1)},
 snap(){return this.st},
 load(s){if(!Array.isArray(s.b)||s.b.length!==64)throw 0;const ok=/^[pnbrqkPNBRQK]?$/;this.st={b:s.b.map(x=>ok.test(x)?x:''),turn:s.turn===-1?-1:1,cs:String(s.cs||'').replace(/[^KQkq]/g,''),ep:Number.isInteger(s.ep)?s.ep:-1,last:Array.isArray(s.last)?s.last.slice(0,2):[],over:[1,-1,2].includes(s.over)?s.over:0,hm:Number(s.hm)||0};this.sel=null;this.moves=this.st.over?[]:chLegal(this.st,this.st.turn)},
 mine(){return isPlayer(this.ctx)&&this.st.turn===this.ctx.side&&!this.st.over&&!this.ctx.gone},
 inCheck(){const st=this.st;return chAttacked(st.b,chKing(st.b,st.turn),-st.turn)},
 status(){const c=this.ctx,st=this.st;if(st.over)return (st.over!==2&&this.inCheck()?'მატი. ':'')+endMsg(c,st.over);if(c.gone)return 'მოწინააღმდეგე გავიდა თამაშიდან';const chk=this.inCheck()?'ქიში! ':'';
  return this.mine()?chk+(this.sel!==null?'აირჩიე უჯრა':'შენი სვლაა'):chk+esc(c.names[st.turn])+' ფიქრობს…'},
 render(){const c=this.ctx,flip=c.side===-1,st=this.st,sel=this.sel,tg=sel!==null?this.moves.filter(m=>m.f===sel):[],chkK=this.inCheck()?chKing(st.b,st.turn):-1;
  let cells='';for(let di=0;di<64;di++){const i=flip?63-di:di,r=i>>3,cc=i&7,p=st.b[i],t=tg.find(m=>m.t===i);
   cells+=`<button class="cs ${(r+cc)%2?'d':'l'}${sel===i?' sel':''}${t?' tgt'+(p||t.ep?' cap':''):''}${st.last.includes(i)?' last':''}${i===chkK?' chk':''}" data-a="chm" data-i="${i}" aria-label="${'abcdefgh'[cc]}${8-r}${p?' '+(isW(p)?'თეთრი ':'შავი ')+PNAME[p.toLowerCase()]:''}">${p?`<span class="${isW(p)?'pw':'pb'}">${GLY[p.toLowerCase()]}</span>`:''}</button>`}
  gview('chess','ჭადრაკი',`<div class="cb" aria-label="ჭადრაკის დაფა">${cells}</div>`,this.status(),`<p class="note">${isPlayer(c)?'შენ '+(c.side===1?'თეთრებით':'შავებით')+' თამაშობ. ':''}ბოლო ხაზამდე მისული პაიკი ლაზიერად იქცევა.</p>${tourBack(c)}`)},
 play(m){const n=chApply(this.st,m);this.st=n;this.sel=null;this.moves=chLegal(n,n.turn);
  if(!this.moves.length)n.over=this.inCheck()?-n.turn:2;else if(n.hm>=100)n.over=2;
  if(this.ctx.mode==='online')netSend();if(n.over){finish(this,n.over);return}this.render();this.kick()},
 kick(){const c=this.ctx;if(this.st.over)return;if(!(c.mode==='watch'||((c.mode==='bot'||c.mode==='tour')&&this.st.turn!==c.side)))return;const s0=this.st;
  setTimeout(()=>{if(this.ctx!==c||this.st!==s0||s0.over)return;const m=chBot(s0);if(m)this.play(m)},c.mode==='watch'?1100:400)},
 checkEnd(){if(this.st.over)finish(this,this.st.over)}};
A.chm=t=>{const G=CH;if(!G.mine())return;const i=+t.dataset.i;
 if(G.sel!==null){const m=G.moves.find(m=>m.f===G.sel&&m.t===i);if(m){G.play(m);return}}
 G.sel=colOf(G.st.b[i])===G.ctx.side&&G.moves.some(m=>m.f===i)?i:null;G.render()};

/* ---------- joker (ჯოკერი), 4 players, simplified Georgian rules ---------- */
const SUITS=['s','c','h','d'],SY={s:'♠',c:'♣',h:'♥',d:'♦'},SN={s:'ყვავი',c:'ჯვარი',h:'გული',d:'აგური'},RK={11:'J',12:'Q',13:'K',14:'A'};
const rkTxt=r=>RK[r]||String(r);
const isRed=s=>s==='h'||s==='d';
function jDeck(){const d=[];for(const s of SUITS)for(let r=6;r<=14;r++)if(!(r===6&&(s==='s'||s==='c')))d.push({s,r});d.push({j:1},{j:2});return d}
const sortHand=h=>h.sort((a,b)=>(a.j?99:SUITS.indexOf(a.s)*20+a.r)-(b.j?99:SUITS.indexOf(b.s)*20+b.r));
const jCardHTML=(c,extra='')=>c.j?`<div class="card jk"${extra}><i>★</i>ჯოკერი</div>`:`<div class="card${isRed(c.s)?' red':''}"${extra}><span>${rkTxt(c.r)}</span><span class="s2">${SY[c.s]}</span></div>`;
const cardName=c=>c.j?'ჯოკერი':rkTxt(c.r)+' '+SN[c.s];
const JSEQ={quick:[1,2,3,4,5,6,7,8],full:[1,2,3,4,5,6,7,8,9,9,9,9,8,7,6,5,4,3,2,1,9,9,9,9]};
const JK=GAME.joker={title:'ჯოკერი',
 start(){this.tk=(this.tk||0)+1;this.phase='setup';this.ids=['me',{n:JK_BOTS[0],h:20},{n:JK_BOTS[1],h:200},{n:JK_BOTS[2],h:120}]},
 nm(p){return p===0?ME.name:JK_BOTS[p-1]},
 begin(len){this.len=len;this.h=0;this.score=[0,0,0,0];this.hist=[];this.dealer=Math.floor(Math.random()*4);this.newHand()},
 newHand(){const n=JSEQ[this.len][this.h];this.n=n;this.dealer=(this.dealer+1)%4;const d=shuffle(jDeck());
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
 winner(t){t=t||this.trick;const lead=t[0],suit=lead.card.j?lead.js:lead.card.s;let best=0,bv=-Infinity;
  t.forEach((e,i)=>{let v;if(e.card.j)v=e.jm==='hi'?1000+i:-1;else if(this.trump&&e.card.s===this.trump)v=100+e.card.r;else if(e.card.s===suit)v=e.card.r;else v=0;if(v>bv){bv=v;best=i}});
  return bv<=0?t[0].p:t[best].p},
 playCard(p,c,jm,js){const h=this.hands[p];h.splice(h.indexOf(c),1);const lead=!this.trick.length;
  this.trick.push({p,card:c,jm:c.j?(jm||'hi'):null,js:c.j&&lead?(js||SUITS[Math.floor(Math.random()*4)]):null});
  if(this.trick.length<4){this.cur=(p+1)%4;this.render();this.step();return}
  const w=this.winner();this.taken[w]++;this.cur=-1;this.win=w;this.render();
  this.later(()=>{this.trick=[];this.win=null;if(!this.hands[0].length){this.endHand();return}this.cur=w;this.render();this.step()},1400)},
 pts(b,t,n){if(t===b)return b===n?100*n:b===0?50:50*b+50;if(b>0&&t===0)return -200;return 10*t},
 endHand(){const pts=[0,1,2,3].map(p=>this.pts(this.bids[p],this.taken[p],this.n));pts.forEach((x,p)=>this.score[p]+=x);this.hist.push({n:this.n,b:this.bids.slice(),t:this.taken.slice(),p:pts});this.h++;
  if(this.h>=JSEQ[this.len].length){this.phase='over';const win=this.score[0]===Math.max(...this.score);gameResult('joker',win)}else this.phase='handover';this.render()},
 val(c){return c.j?60:(this.trump&&c.s===this.trump?20+c.r:c.r)},
 botTrump(p){const sc={};for(const c of this.first3[p])if(!c.j)sc[c.s]=(sc[c.s]||0)+c.r;const best=Object.entries(sc).sort((a,b)=>b[1]-a[1])[0];return best&&best[1]>=11?best[0]:null},
 botBid(p){const hand=this.hands[p],n=hand.length;let e=0;for(const c of hand){if(c.j)e+=1;else if(this.trump&&c.s===this.trump)e+=c.r>=13?.9:c.r>=11?.55:.3;else e+=c.r===14?.7:c.r===13?.3:0}
  let b=Math.max(0,Math.min(n,Math.round(e)));if(b===this.forbidden(p))b=b>0?b-1:b+1;return Math.min(n,b)},
 botPlay(p){const L=this.legal(p),need=this.bids[p]-this.taken[p],t=this.trick,nj=L.filter(c=>!c.j),jk=L.find(c=>c.j);
  const wins=c=>this.winner([...t,{p,card:c,jm:null,js:null}])===p,byV=(a,b)=>this.val(a)-this.val(b);
  if(!t.length){if(need>0){const top=nj.slice().sort(byV).pop();if(top&&(top.r===14||(this.trump&&top.s===this.trump&&top.r>=13)))return{c:top};if(jk)return{c:jk,jm:'hi',js:SUITS.filter(s=>s!==this.trump)[Math.floor(Math.random()*3)]};return{c:top||L[0]}}
   const low=nj.slice().sort(byV)[0];return low?{c:low}:{c:L[0],jm:'lo',js:this.trump||'h'}}
  if(need>0){const w=nj.filter(wins).sort(byV);if(w.length)return{c:w[0]};if(jk)return{c:jk,jm:'hi'};return{c:nj.sort(byV)[0]||L[0],jm:'lo'}}
  const lose=nj.filter(c=>!wins(c)).sort(byV);if(lose.length)return{c:lose.pop()};if(jk)return{c:jk,jm:'lo'};return{c:nj.sort(byV)[0]}},
 render(){if(S.tab!=='games'||S.game!=='joker'||S.page)return;const top=gTop('ჯოკერი',{mode:'bot'});
  if(this.phase==='setup'){view.innerHTML=`<div class="view-pad game">${top}<section class="tourcard"><h3>ჯოკერი ოთხ კაცზე</h3><p class="note">36 კარტი, ორი ჯოკერი. ყოველ ხელში წინასწარ თქვი, რამდენ ხელს წაიღებ. თუ ზუსტად იმდენს წაიღებ, რამდენიც თქვი, ქულებს მიიღებ. მეტოქეებს ბოტი თამაშობს.</p>
   <div style="display:flex;gap:8px;flex-wrap:wrap"><button class="btn" data-a="jstart" data-m="quick">სწრაფი · 8 ხელი</button><button class="btn ghost" data-a="jstart" data-m="full">სრული · 24 ხელი</button></div>
   <details><summary style="cursor:pointer;font-weight:600">წესები</summary><p class="note" style="margin-top:8px">ფერი უნდა აჰყვე. თუ ფერი არ გაქვს, კოზირი უნდა დადო. ჯოკერი ნებისმიერ დროს შეგიძლია დადო: „მაღალი“ წაიღებს ხელს, „დაბალი“ არ წაიღებს. ჯოკერით დაწყებისას ითხოვ ფერს: „მაღალი“ ნიშნავს, რომ ყველამ ამ ფრის უმაღლესი კარტი უნდა დადოს და ხელი შენია, „დაბალი“ კი, რომ ამ ფრის უმაღლესი კარტი წაიღებს. ქულები: ზუსტად ნათქვამი 50 თითო ხელზე და 50 ბონუსი, ყველა ხელის წაღება 100 თითოზე, პასი და ნული 50. მეტის წაღებისას 10 თითოზე. თუ თქვი და ვერცერთი ვერ წაიღე, ხიშტი: −200.</p></details></section></div>`;return}
  const seat=(p,pos)=>`<div class="seat ${pos}${this.cur===p&&(this.phase==='bid'||this.phase==='play'||this.phase==='trump')?' turn':''}">${avAny(this.ids[p],38)}<b>${esc(this.nm(p))}</b><span class="bt" aria-label="ნათქვამი ${this.bids[p]??'ჯერ არა'}, წაღებული ${this.taken[p]}">${this.bids[p]??'–'} / ${this.taken[p]}</span><span>${this.score[p]}</span></div>`;
  const tr=this.trick.map(e=>{const h=jCardHTML(e.card).replace('class="card','class="card p'+e.p);return e.card.j?h.replace('</div>',`<span class="jm">${e.jm==='hi'?'მაღალი':'დაბალი'}${e.js?' '+SY[e.js]:''}</span></div>`):h}).join('');
  const trumpTxt=this.phase==='trump'?'კოზირი ირჩევა':this.trump?`კოზირი: <b style="color:${isRed(this.trump)?'#FF8A9A':'inherit'}">${SY[this.trump]}</b> ${SN[this.trump]}`:'უკოზირო';
  const L=this.phase==='play'&&this.cur===0?this.legal(0):[];
  const hand=this.phase==='trump'&&this.cur===0?this.first3[0].map(c=>jCardHTML(c)).join('')+'<div class="card" style="opacity:.25" aria-hidden="true"></div>'.repeat(this.n-3)
   :this.hands[0].map((c,i)=>`<button class="card${c.j?' jk':''}${!c.j&&isRed(c.s)?' red':''}" data-a="jcard" data-i="${i}" aria-label="${cardName(c)}"${L.includes(c)?'':' disabled'}>${c.j?'<i>★</i>ჯოკერი':`<span>${rkTxt(c.r)}</span><span class="s2">${SY[c.s]}</span>`}</button>`).join('');
  let panel='',st='';
  if(this.phase==='trump'){if(this.cur===0){st='ნახე პირველი სამი კარტი და აირჩიე კოზირი';panel=`<div class="suits">${SUITS.map(s=>`<button class="${isRed(s)?'red':''}" data-a="jtrump" data-s="${s}" aria-label="${SN[s]}">${SY[s]}</button>`).join('')}</div><button class="btn ghost" data-a="jtrump" data-s="" style="align-self:center">უკოზირო</button>`}else st=esc(this.nm(this.cur))+' ირჩევს კოზირს…'}
  else if(this.phase==='bid'){if(this.cur===0){const f=this.forbidden(0);st='რამდენს წაიღებ?'+(f>=0?` დამრიგებელი ხარ, ${f}-ს ვერ იტყვი`:'');panel=`<div class="bids" role="group" aria-label="ნათქვამი">${Array.from({length:this.n+1},(_,v)=>`<button data-a="jbid" data-v="${v}"${v===f?' disabled':''}>${v===0?'პასი':v}</button>`).join('')}</div>`}else st=esc(this.nm(this.cur))+' ამბობს…'}
  else if(this.phase==='play'){st=this.win!=null?(this.win===0?'ეს ხელი შენ წაიღე':esc(JK_ERG[this.win-1])+' წაიღო ხელი'):this.cur===0?'შენი სვლაა':esc(this.nm(this.cur))+' ფიქრობს…'}
  else if(this.phase==='handover'||this.phase==='over'){const last=this.hist[this.hist.length-1];
   st=this.phase==='over'?(this.score[0]===Math.max(...this.score)?'მოიგე! +12 რეიტინგი, +10 მონეტა':'თამაში დასრულდა'):`ხელი დასრულდა. შენ: ${last.p[0]>0?'+':''}${last.p[0]}`;
   panel=`<div class="sheet-tbl"><table><thead><tr><th></th>${[0,1,2,3].map(p=>`<th>${esc(this.nm(p))}</th>`).join('')}</tr></thead><tbody><tr><td>თქვა / წაიღო</td>${[0,1,2,3].map(p=>`<td>${last.b[p]} / ${last.t[p]}</td>`).join('')}</tr><tr><td>ქულა</td>${last.p.map(x=>`<td class="${x<0?'neg':''}">${x>0?'+':''}${x}</td>`).join('')}</tr><tr class="tot"><td>სულ</td>${this.score.map(x=>`<td>${x}</td>`).join('')}</tr></tbody></table></div>`
    +(this.phase==='over'?'<button class="btn" data-a="jagain" style="align-self:flex-start">ახალი თამაში</button>':'<button class="btn" data-a="jnext" style="align-self:flex-start">შემდეგი ხელი</button>')}
  view.innerHTML=`<div class="view-pad game">${top}<div class="jt">${seat(2,'top')}${seat(1,'left')}${seat(3,'right')}<div class="trick" aria-label="მაგიდა">${tr}</div>
   <div class="jinfo"><span class="trump">${trumpTxt}</span><span>ხელი ${Math.min(this.h+1,JSEQ[this.len].length)}/${JSEQ[this.len].length} · ${this.n} კარტი</span></div></div>
   <div class="pl">${av('me',30)}<b>${esc(ME.name)}</b><span class="muted">${this.bids[0]??'–'} / ${this.taken[0]} · ${this.score[0]} ქულა</span><span class="sp"></span><button class="btn ghost sm" data-a="jsheet">ქულების ფურცელი</button></div>
   <div class="hand" aria-label="შენი კარტები">${hand}</div><div class="status" role="status">${st}</div>${panel}</div>`}};
A.jstart=t=>JK.begin(t.dataset.m);
A.jagain=()=>{JK.start();JK.render()};
A.jnext=()=>{if(JK.phase==='handover')JK.newHand()};
A.jbid=t=>{if(JK.phase==='bid'&&JK.cur===0)JK.bid(0,+t.dataset.v)};
A.jtrump=t=>{if(JK.phase==='trump'&&JK.cur===0)JK.setTrump(t.dataset.s)};
A.jcard=t=>{if(JK.phase!=='play'||JK.cur!==0)return;const c=JK.hands[0][+t.dataset.i];if(!JK.legal(0).includes(c))return;
 if(!c.j){JK.playCard(0,c);return}JK.pj=c;const lead=!JK.trick.length;
 sheet(head('ჯოკერი')+(lead?`<div class="form"><b>მაღალი: ვითხოვ ამ ფრის უმაღლესს და ხელს ვიღებ</b><div class="suits">${SUITS.map(s=>`<button class="${isRed(s)?'red':''}" data-a="jj" data-m="hi" data-s="${s}" aria-label="მაღალი, ${SN[s]}">${SY[s]}</button>`).join('')}</div><b>დაბალი: ამ ფრის უმაღლესმა წაიღოს</b><div class="suits">${SUITS.map(s=>`<button class="${isRed(s)?'red':''}" data-a="jj" data-m="lo" data-s="${s}" aria-label="დაბალი, ${SN[s]}">${SY[s]}</button>`).join('')}</div></div>`
  :`<div class="jchoice"><button data-a="jj" data-m="hi">მაღალი<br><small class="muted">წაიღებს ხელს</small></button><button data-a="jj" data-m="lo">დაბალი<br><small class="muted">არ წაიღებს</small></button></div>`),'short')};
A.jj=t=>{closeSheet();if(JK.pj&&JK.phase==='play'&&JK.cur===0){const c=JK.pj;JK.pj=null;JK.playCard(0,c,t.dataset.m,t.dataset.s||null)}};
A.jsheet=()=>{if(!JK.hist||!JK.hist.length){toast('ქულების ფურცელი პირველი ხელის შემდეგ შეივსება');return}
 sheet(head('ქულების ფურცელი')+`<div class="ph-body"><div class="sheet-tbl"><table><thead><tr><th>ხელი</th>${[0,1,2,3].map(p=>`<th>${esc(JK.nm(p))}</th>`).join('')}</tr></thead><tbody>${JK.hist.map((h,i)=>`<tr><td>${i+1} · ${h.n}</td>${[0,1,2,3].map(p=>`<td class="${h.p[p]<0?'neg':''}">${h.b[p]}/${h.t[p]} · ${h.p[p]}</td>`).join('')}</tr>`).join('')}<tr class="tot"><td>სულ</td>${JK.score.map(x=>`<td>${x}</td>`).join('')}</tr></tbody></table></div></div>`)};

/* board games: moving pieces, rolling dice, dealt cards */
{const p=CH.play,r=CH.render,l=CH.load;
 CH.play=function(m){this.anim=[m.f,m.t];p.call(this,m)};
 CH.load=function(s){const prev=this.st&&this.st.last;l.call(this,s);const n=this.st.last;if(n.length===2&&(!prev||prev.join()!==n.join()))this.anim=n};
 CH.render=function(){r.call(this);if(this.anim&&S.tab==='games'&&S.game==='chess'){const[a,b]=this.anim;this.anim=null;flipPiece($(`.cs[data-i="${a}"]`,view),$(`.cs[data-i="${b}"]`,view))}}}
{const p=CK.play,r=CK.render,l=CK.load;
 CK.play=function(m){this.anim=[m.path[0],m.path[m.path.length-1]];p.call(this,m)};
 CK.load=function(s){const prev=JSON.stringify(this.last||[]);l.call(this,s);if(this.last.length>1&&JSON.stringify(this.last)!==prev)this.anim=[this.last[0],this.last[this.last.length-1]]};
 CK.render=function(){r.call(this);if(this.anim&&S.tab==='games'&&S.game==='shashi'){const[a,b]=this.anim;this.anim=null;const q=x=>$(`.sq[data-r="${x[0]}"][data-c="${x[1]}"]`,view);flipPiece(q(a),q(b))}}}
{const m=NR.move,ro=NR.roll,r=NR.render;
 NR.move=function(s,f,to,d){m.call(this,s,f,to,d);this.lastTo=to};
 NR.roll=function(){ro.call(this);this.rollAnim=1};
 NR.render=function(){r.call(this);if(S.tab!=='games'||S.game!=='nardi')return;
  if(this.rollAnim){this.rollAnim=0;$$('.dice .die',view).forEach(d=>d.classList.add('roll'))}
  if(this.lastTo!=null){const k=this.lastTo;this.lastTo=null;const el=k==='off'?$('.offbtn',view):$(`.pt[data-k="${k}"]`,view);if(el){const c=k==='off'?el:[...el.querySelectorAll('.ch')].pop();if(c){c.classList.add('drop');if(k==='off')pop(c)}}}}}
{const nh=JK.newHand,pc=JK.playCard,r=JK.render,V={0:'0 130px',1:'-130px 0',2:'0 -130px',3:'130px 0'};
 JK.newHand=function(){this.dealAnim=1;nh.call(this)};
 JK.playCard=function(p,c,jm,js){this.newCard=p;pc.call(this,p,c,jm,js);if(this.win!=null){const w=this.win,tk=this.tk;setTimeout(()=>{if(tk!==this.tk)return;$$('.trick .card',view).forEach(el=>anim(el,[{translate:'0 0',opacity:1},{translate:V[w],opacity:0}],{duration:380,easing:EASE,fill:'forwards'}))},950)}};
 JK.render=function(){r.call(this);if(S.tab!=='games'||S.game!=='joker')return;
  if(this.dealAnim){this.dealAnim=0;$$('.hand .card',view).forEach((el,i)=>anim(el,[{translate:'0 -70px',opacity:0},{translate:'0 0',opacity:1}],{duration:420,delay:i*55,easing:SPRING,fill:'backwards'}))}
  if(this.newCard!=null){const p=this.newCard;this.newCard=null;const el=$(`.trick .card.p${p}`,view);anim(el,[{translate:V[p],opacity:0},{translate:'0 0',opacity:1}],{duration:380,easing:EASE})}}}

