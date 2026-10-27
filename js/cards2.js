/* ---------- two more card games on the same deck and the same table as joker ----------
   დურაკი: two to four, each for themselves; ბურა: one against one, with the "31" call.
   both use the full 36-card deck (6 to ace), shown with the joker cards in 2D and on the round table in 3D */
const d36=()=>{const d=[];for(const s of SUITS)for(let r=6;r<=14;r++)d.push({s,r});return d};
const cSame=(a,b)=>!!a&&!!b&&a.s===b.s&&a.r===b.r;
const cKey=c=>c.s+c.r;
/* a card as a button in my hand */
const cBtn=(c,i,a,ok,sel,extra='')=>`<button class="card${isRed(c.s)?' red':''}${sel?' sel':''}" data-a="${a}" data-i="${i}" data-s="${SY[c.s]}" aria-label="${cardName(c)}"${sel?' aria-pressed="true"':''}${ok?'':' disabled'}${extra}><span>${rkTxt(c.r)}</span><span class="s2">${SY[c.s]}</span></button>`;
const cBack=n=>`<span class="cbk" aria-label="${n} კარტი">${'<i></i>'.repeat(Math.min(n,8))}<b>${n}</b></span>`;
const cPlayers=[null,{n:'თამარი',h:190,cast:'f1'},{n:'ლევანი',h:95,cast:'m1'},{n:'ნინო',h:340,cast:'f2'}];

/* ---------- durak ----------
   six cards each, the next one turned up for trumps and slid under the deck. the attacker leads; the defender beats it
   with a higher card of the suit or with a trump, or takes. everyone but the defender may add cards of a rank already
   on the table, one at a time, up to six and never more than the defender held. beaten cards go to the discard (ბიტა),
   taken cards to the defender's hand. everyone draws back to six, the attacker first. whoever is left with cards is the durak */
const dkSeats=np=>np===2?[0,2]:np===3?[0,1,3]:[0,1,2,3];
const dkNp=()=>{const v=+store.get('dkn',2);return[2,3,4].includes(v)?v:2};
const DK=GAME.durak={title:'დურაკი',
 start(){this.tk=(this.tk||0)+1;this.np=dkNp();this.SE=dkSeats(this.np);castRoll();const f=this.fools;this.fools=f&&f.np===this.np&&String(f.cast)===String(TCAST)?f:{np:this.np,n:[0,0,0,0],games:0,cast:TCAST.slice()};this.deal()},
 nm(p){return p===0?ME.name:cPlayers[p].n},
 later(fn,ms){const tk=this.tk;setTimeout(()=>{if(tk===this.tk&&S.game==='durak'&&!S.page)fn()},ms)},
 deal(){const d=shuffle(d36());this.hands=[[],[],[],[]];for(let k=0;k<6;k++)for(const p of this.SE)this.hands[p].push(d.pop());
  this.trumpCard=d.pop();this.trump=this.trumpCard.s;d.unshift(this.trumpCard);this.deck=d;this.disc=0;this.out=[];this.durak=null;this.tbl=[];this.passed=[];this.last=null;this.gto=null;
  for(const p of this.SE)this.sort(p);
  /* the lowest trump starts */
  let att=this.SE[0],lo=99;for(const p of this.SE)for(const c of this.hands[p])if(c.s===this.trump&&c.r<lo){lo=c.r;att=p}
  this.bout(att);this.phase='att';this.dealN=(this.dealN||0)+1},
 sort(p){const t=this.trump;this.hands[p].sort((a,b)=>((a.s===t)-(b.s===t))||SUITS.indexOf(a.s)-SUITS.indexOf(b.s)||a.r-b.r)},
 active(p){return this.SE.includes(p)&&(this.hands[p].length>0||this.deck.length>0)},
 nextAct(p,skip){const S0=this.SE,i=S0.indexOf(p);for(let k=1;k<=S0.length;k++){const q=S0[(i+k)%S0.length];if(q!==skip&&this.active(q))return q}return -1},
 bout(att){this.att=att;this.def=this.nextAct(att);this.lim=Math.min(6,this.hands[this.def]?this.hands[this.def].length:0);this.tbl=[];this.passed=[];this.cur=att;this.phase='att'},
 beats(c,a){return c.s===a.s&&c.r>a.r||c.s===this.trump&&a.s!==this.trump},
 open(){return this.tbl.find(x=>!x.d)||null},
 ranks(){const R=new Set();for(const x of this.tbl){R.add(x.a.r);if(x.d)R.add(x.d.r)}return R},
 /* the attackers in turn: the one who led first, then round the table, never the defender */
 throwers(){const L=[],S0=this.SE,i=S0.indexOf(this.att);for(let k=0;k<S0.length;k++){const q=S0[(i+k)%S0.length];if(q!==this.def&&this.active(q)&&this.hands[q].length)L.push(q)}return L},
 canAdd(p){if(!this.tbl.length)return this.hands[p].slice();if(this.tbl.length>=this.lim)return[];if(this.phase==='att'&&!this.hands[this.def].length)return[];const R=this.ranks();return this.hands[p].filter(c=>R.has(c.r))},
 legal(p){if(this.cur!==p)return[];if(this.phase==='def'){const o=this.open();return o?this.hands[p].filter(c=>this.beats(c,o.a)):[]}if(this.phase==='att'||this.phase==='take')return this.canAdd(p);return[]},
 play(p,c){const h=this.hands[p],i=h.findIndex(x=>cSame(x,c));if(i<0||p!==this.cur)return false;
  if(this.phase==='def'){const o=this.open();if(!o||!this.beats(c,o.a))return false;h.splice(i,1);o.d=c;o.dp=p;this.last={p,k:'beat'};this.snd();
   if(this.tbl.length>=this.lim||!this.hands[p].length){this.endBout(false);return true}
   this.phase='att';this.cur=this.att;this.passed=[];this.go();return true}
  if(this.phase==='att'||this.phase==='take'){if(!this.canAdd(p).some(x=>cSame(x,c)))return false;h.splice(i,1);this.tbl.push({a:c,ap:p,d:null});this.last={p,k:'add'};this.snd();
   if(this.phase==='att'){this.phase='def';this.cur=this.def}
   this.go();return true}
  return false},
 snd(){if(typeof g3On==='function'&&!g3On()&&typeof gSnd==='function')gSnd('card')},
 take(p){if(p!==this.def||this.phase!=='def')return;this.phase='take';this.last={p,k:'take'};this.cur=this.att;this.passed=[];
  if(!this.throwers().some(q=>this.canAdd(q).length)){this.endBout(true);return}this.go()},
 /* the one whose turn it is to add says "enough"; when every attacker has, the bout ends */
 pass(p){if(p!==this.cur||!['att','take'].includes(this.phase)||!this.tbl.length)return;if(!this.passed.includes(p))this.passed.push(p);
  const L=this.throwers(),nx=L.find(q=>!this.passed.includes(q)&&L.indexOf(q)>L.indexOf(p))??L.find(q=>!this.passed.includes(q));
  if(nx==null){this.endBout(this.phase==='take');return}this.cur=nx;this.go()},
 endBout(taken){const cards=[];for(const x of this.tbl){cards.push(x.a);if(x.d)cards.push(x.d)}const def=this.def;
  if(taken){this.hands[def].push(...cards);this.sort(def);this.gto=def}else{this.disc+=cards.length;this.gto='disc'}
  this.lastBout={taken,def,n:cards.length};
  /* drawing back to six: the first attacker, the others in turn, the defender last */
  const S0=this.SE,ia=S0.indexOf(this.att),order=[...S0.slice(ia),...S0.slice(0,ia)].filter(q=>q!==def).concat(def);for(const q of order){while(this.hands[q].length<6&&this.deck.length)this.hands[q].push(this.deck.pop());this.sort(q)}
  for(const q of this.SE)if(!this.hands[q].length&&!this.deck.length&&!this.out.includes(q))this.out.push(q);
  const left=this.SE.filter(q=>this.hands[q].length);this.tbl=[];
  if(left.length<=1){this.durak=left.length?left[0]:-1;this.over();return}
  const att=taken?this.nextAct(def):(this.active(def)?def:this.nextAct(def));this.bout(att);this.go()},
 over(){this.phase='over';this.cur=-1;const f=this.fools;f.games++;if(this.durak>=0)f.n[this.durak]++;
  this.ctx.finAt=performance.now();const win=this.durak!==0;gameResult('durak',win);
  if(typeof gEndGest==='function')gEndGest(r=>r===this.durak?'shake':'cheer',this.SE.filter(q=>q));this.render()},
 go(){this.render();this.step()},
 /* the computer's players: low cards first, trumps and pictures kept while the deck is thick, a take when beating costs too much */
 val(c){return(c.s===this.trump?20:0)+c.r},
 lv(){return this.ctx&&this.ctx.lvl||bLvl('durak')},
 bot(p){const lv=this.lv(),byV=(a,b)=>this.val(a)-this.val(b);
  if(this.phase==='def'){const L=this.legal(p).sort(byV);if(!L.length)return{k:'take'};if(lv===1&&Math.random()<.15)return{k:'take'};
   const c=L[0];if(lv>=3&&c.s===this.trump&&c.r>=13&&this.deck.length>8&&this.tbl.length<=2&&this.open().a.s!==this.trump)return{k:'take'};return{k:'play',c}}
  const L=this.canAdd(p).sort(byV);if(!this.tbl.length){if(lv===1)return{k:'play',c:L[Math.floor(Math.random()*L.length)]};
   if(lv>=3){const cnt={};for(const c of L)if(c.s!==this.trump)cnt[c.r]=(cnt[c.r]||0)+1;const pr=L.find(c=>c.s!==this.trump&&cnt[c.r]>=2&&c.r<=11);if(pr)return{k:'play',c:pr}}
   return{k:'play',c:L[0]}}
  if(!L.length)return{k:'pass'};if(lv===1)return Math.random()<.5?{k:'play',c:L[0]}:{k:'pass'};
  const cheap=L.filter(c=>this.deck.length<=6||c.s!==this.trump&&c.r<=12);if(this.phase==='take')return cheap.length&&(lv<3||this.val(cheap[0])<13||!this.deck.length)?{k:'play',c:cheap[0]}:{k:'pass'};
  return cheap.length?{k:'play',c:cheap[0]}:{k:'pass'}},
 step(){if(!['att','def','take'].includes(this.phase))return;const p=this.cur,meOut=!this.active(0),fast=meOut?.35:1;
  if(p===0){if(this.phase!=='def'&&this.tbl.length&&!this.canAdd(0).length)this.later(()=>{if(this.cur===0)this.pass(0)},700);return}
  this.later(()=>{if(this.cur!==p)return;const m=this.bot(p);if(m.k==='take')this.take(p);else if(m.k==='pass')this.pass(p);else this.play(p,m.c)},(this.phase==='def'?850:700)*fast)},
 kick(){this.step()},
 save(){if(!['att','def','take'].includes(this.phase))return null;const o={};for(const k of['np','hands','trumpCard','trump','deck','disc','out','tbl','passed','att','def','lim','cur','phase','fools','dealN'])o[k]=this[k];return o},
 restore(s){if(!s||!Array.isArray(s.hands)||![2,3,4].includes(s.np))throw 0;Object.assign(this,s);this.SE=dkSeats(this.np);this.durak=null;this.last=null;setTimeout(()=>{if(S.game==='durak')this.step()},500)},
 status(){const p=this.cur,me=0;
  if(this.phase==='over')return this.durak===0?'დურაკი შენ ხარ 🙃':this.durak<0?'ფრე: ყველამ ერთად გაათავა':esc(this.nm(this.durak))+' დარჩა დურაკად. შენ გადარჩი! 🎉';
  if(!this.active(0))return 'შენ გამოხვედი, დურაკი არ ხარ. დანარჩენები ამთავრებენ…';
  const lb=this.lastBout&&!this.tbl.length?(this.lastBout.taken?esc(this.lastBout.def===0?'შენ აიღე':this.nm(this.lastBout.def)+'მ აიღო')+'. ':'ბიტა. '):'';
  if(p!==me){const w=esc(this.nm(p));return lb+(this.phase==='def'?w+' იგერიებს…':this.tbl.length?w+' ამატებს…':w+' იწყებს…')}
  if(this.phase==='def'){const o=this.open();return `გადაფარე ${rkTxt(o.a.r)}${SY[o.a.s]}`+(this.legal(0).length?' ან აიღე':'. ვერაფრით, უნდა აიღო')}
  if(this.phase==='take')return esc(this.nm(this.def))+' იღებს. კიდევ დაამატებ?';
  return this.tbl.length?'დაამატე იგივე ღირსების კარტი ან თქვი „ბიტა“':lb+'შენ იწყებ: დადე კარტი'},
 render(){if(S.tab!=='games'||S.game!=='durak'||S.page)return;const g3=g3Want(),c=this.ctx,mine=this.cur===0&&['att','def','take'].includes(this.phase);
  const L=mine?this.legal(0):[];gTurnSnd(this,mine&&(L.length>0||this.phase==='def'));
  const seat=(p,pos)=>this.SE.includes(p)?`<div class="seat ${pos}${this.cur===p&&this.phase!=='over'?' turn':''}${p===this.def&&this.tbl.length?' dfd':''}"${castTap(p)}>${avAny(cPlayers[p],36)}<b>${esc(this.nm(p))}</b><span class="bt">${this.hands[p].length?this.hands[p].length+' კარტი':this.active(p)?'—':'გამოვიდა'}${p===this.def&&this.phase!=='over'?' · იგერიებს':''}</span></div>`:'';
  const pairs=this.tbl.map(x=>`<span class="dpair">${jCardHTML(x.a)}${x.d?jCardHTML(x.d).replace('class="card','class="card dd'):''}</span>`).join('');
  const deck=this.deck.length?`<span class="ddeck">${jCardHTML(this.trumpCard).replace('class="card','class="card dtr')}${this.deck.length>1?cBack(this.deck.length-1):''}</span>`:`<span class="ddeck none">კოზირი <b style="color:${suitInk(this.trump)}">${SY[this.trump]}</b></span>`;
  const hand=this.hands[0].map((cd,i)=>cBtn(cd,i,'dkc',L.some(x=>cSame(x,cd)))).join('');
  let panel='';if(mine&&this.phase==='def')panel=`<div class="jkacts"><button class="btn ghost" data-a="dktake">${ic('download')}ავიღებ</button></div>`;
  else if(mine&&this.tbl.length&&this.phase==='att')panel=`<div class="jkacts"><button class="btn ghost" data-a="dkpass">${ic('check')}ბიტა</button></div>`;
  else if(mine&&this.phase==='take')panel=`<div class="jkacts"><button class="btn ghost" data-a="dkpass">მეტი არა</button></div>`;
  const f=this.fools,info=`<div class="ginfo">${trumpChip(this.trump)}<span>დასტაში ${this.deck.length} · ბიტაში ${this.disc}</span>${f.games?`<span>დურაკი: ${this.SE.map(p=>`${esc(p?this.nm(p).split(' ')[0]:'შენ')} ${f.n[p]}`).join(', ')}</span>`:''}</div>`;
  const stage=`<div class="jt dkt${g3?' g3jt':''}">${seat(2,'top')}${seat(1,'left')}${seat(3,'right')}<div class="trick dtable" aria-label="მაგიდა">${pairs||'<span class="muted">მაგიდა ცარიელია</span>'}${deck}</div>${g3?`<div class="g3 g3-joker${G3W.ready?'':' loading'}">${g3Rv()}${G3W.ready?'':'<span class="g3load" aria-hidden="true"></span>'}</div>`:''}</div>`;
  let res='';if(this.phase==='over'){const win=this.durak!==0;res=gResBox(this,{title:this.durak<0?'ფრე':win?'გადარჩი!':'დურაკი შენ ხარ',sub:this.durak<0?'ბოლო კარტები ერთად გავიდა':win?(this.np===2?esc(this.nm(this.durak))+' დარჩა კარტებით':'დურაკი: '+esc(this.nm(this.durak))):'ბოლოს შენ დაგრჩა კარტები',kind:this.durak<0?'draw':win?'win':'lose',
   more:f.games>1?`<div class="gendt">${this.SE.map(p=>`<span><b>${esc(p?this.nm(p):'შენ')}</b>${f.n[p]}</span>`).join('')}</div><p class="note" style="text-align:center">რამდენჯერ დარჩა დურაკად, ${f.games} თამაშიდან</p>`:'',again:'<button class="btn gold" data-a="dkagain">კიდევ ერთი</button>',share:win?gShareBtn('durak',this.np+' მოთამაშე'):''})}
  const st=this.status()+(mine&&g3&&L.length?' · შეეხე კარტს ორჯერ ან აიტანე მაგიდაზე':'');
  gSaveLater(this);view.innerHTML=gShell('durak',{stage,mid:stage,top:gTop('დურაკი',null)+info,bot:`<div class="pl me${mine?' turn':''}${0===this.def&&this.phase!=='over'?' dfd':''}"><span class="plav">${av('me',34)}</span><span class="pln"><b>${esc(ME.name)}</b><span class="muted">${this.hands[0].length} კარტი${0===this.def&&this.phase!=='over'?' · შენ იგერიებ':''}</span></span></div>
   <div class="hand${g3?' g3sr':''}" aria-label="შენი კარტები">${hand}</div><div class="status${mine?' mine':''}" role="status">${st}</div>${panel}`,res});
  g3After('durak')}};
A.dkc=t=>{const G=DK;if(G.cur!==0)return;const c=G.hands[0][+t.dataset.i];if(c)G.play(0,c)};
A.dktake=()=>{if(DK.cur===0)DK.take(0)};
A.dkpass=()=>{if(DK.cur===0)DK.pass(0)};
A.dkagain=()=>{const G=DK;G.resHide=0;G.resSnd=0;G.tk++;if(G.np!==dkNp()){G.np=dkNp();G.SE=dkSeats(G.np);G.fools={np:G.np,n:[0,0,0,0],games:0}}G.ctx.finAt=0;G.ctx.cined=0;G.deal();G.go()};

/* ---------- bura ----------
   three cards each, the next one turned up for trumps. the leader plays one, two or three cards of one suit; the other
   answers with as many: if each led card is beaten (a higher card of its suit, or a trump), the answer takes them all,
   otherwise the leader does. both draw back to three, the taker first. ace 11, ten 10, king 4, queen 3, jack 2, and the ten
   ranks just under the ace. whoever has taken 31 calls it and wins the deal; a wrong call loses it. three trumps in hand,
   led together, is ბურა and wins the deal at once. with the cards gone, the bigger count wins */
const BU_ORD={6:0,7:1,8:2,9:3,11:4,12:5,13:6,10:7,14:8},BU_PT={14:11,10:10,13:4,12:3,11:2};
const buPts=cs=>cs.reduce((a,c)=>a+(BU_PT[c.r]||0),0);
const buTo=()=>{const v=+store.get('buto',5);return[3,5,7].includes(v)?v:5};
const buShowPts=()=>store.get('bupts',true)!==false;
const BU=GAME.bura={title:'ბურა',
 start(){this.tk=(this.tk||0)+1;castRoll();this.to=buTo();this.match=[0,0,0,0];this.dealer=Math.random()<.5?0:2;this.dealN=0;this.newDeal()},
 nm(p){return p===0?ME.name:cPlayers[2].n},
 opp(p){return p===0?2:0},
 later(fn,ms){const tk=this.tk;setTimeout(()=>{if(tk===this.tk&&S.game==='bura'&&!S.page)fn()},ms)},
 newDeal(){const d=shuffle(d36());this.hands=[[],[],[],[]];for(let k=0;k<3;k++)for(const p of[0,2])this.hands[p].push(d.pop());this.trumpCard=d.pop();this.trump=this.trumpCard.s;d.unshift(this.trumpCard);this.deck=d;
  this.taken=[[],[],[],[]];this.tricks=[0,0,0,0];this.dealer=this.opp(this.dealer);this.lead=this.opp(this.dealer);this.cur=this.lead;this.led=null;this.resp=null;this.sel=[];this.phase='lead';this.dres=null;this.gone=new Set();this.dealN++;
  this.sort(0);this.sort(2)},
 sort(p){const t=this.trump;this.hands[p].sort((a,b)=>((a.s===t)-(b.s===t))||SUITS.indexOf(a.s)-SUITS.indexOf(b.s)||BU_ORD[a.r]-BU_ORD[b.r])},
 beats(c,l){return c.s===l.s&&BU_ORD[c.r]>BU_ORD[l.r]||c.s===this.trump&&l.s!==this.trump},
 /* can these answer cards beat those led, each its own */
 covers(ans,led){if(ans.length!==led.length)return false;const perm=a=>a.length<=1?[a]:a.flatMap((x,i)=>perm([...a.slice(0,i),...a.slice(i+1)]).map(r=>[x,...r]));return perm(ans).some(o=>o.every((c,i)=>this.beats(c,led[i])))},
 isBura(cs){return cs.length===3&&cs.every(c=>c.s===this.trump)},
 okLead(cs){return cs.length>=1&&cs.length<=3&&cs.every(c=>c.s===cs[0].s)},
 doLead(p,cs){if(p!==this.cur||this.phase!=='lead'||!this.okLead(cs))return false;const h=this.hands[p];if(!cs.every(c=>h.some(x=>cSame(x,c))))return false;
  for(const c of cs)h.splice(h.findIndex(x=>cSame(x,c)),1);this.led={p,cs};this.sel=[];this.snd();
  if(this.isBura(cs)){this.dealOver(p,'bura');return true}this.phase='resp';this.cur=this.opp(p);this.go();return true},
 doResp(p,cs){if(p!==this.cur||this.phase!=='resp'||cs.length!==this.led.cs.length)return false;const h=this.hands[p];if(!cs.every(c=>h.some(x=>cSame(x,c))))return false;
  for(const c of cs)h.splice(h.findIndex(x=>cSame(x,c)),1);const beat=this.covers(cs,this.led.cs);this.resp={p,cs,beat};this.sel=[];this.snd();
  const w=beat?p:this.led.p;this.phase='show';this.cur=-1;this.win=w;this.render();
  this.later(()=>this.collect(),1500);return true},
 snd(){if(typeof g3On==='function'&&!g3On()&&typeof gSnd==='function')gSnd('card')},
 collect(){const w=this.win,all=[...this.led.cs,...this.resp.cs];this.taken[w].push(...all);this.tricks[w]++;for(const c of all)this.gone.add(cKey(c));
  this.lastT={led:this.led,resp:this.resp,w};this.led=null;this.resp=null;this.win=null;
  for(const q of[w,this.opp(w)]){while(this.hands[q].length<3&&this.deck.length)this.hands[q].push(this.deck.pop());this.sort(q)}
  if(!this.hands[0].length&&!this.hands[2].length){const a=buPts(this.taken[0]),b=buPts(this.taken[2]);this.dealOver(a>b?0:b>a?2:-1,'count');return}
  this.lead=w;this.cur=w;this.phase='lead';this.go()},
 /* "31": counted on the spot; a wrong call gives the deal away */
 call(p){if(p!==this.cur||this.phase!=='lead')return;const ok=buPts(this.taken[p])>=31;this.dealOver(ok?p:this.opp(p),ok?'call':'miscall',p)},
 dealOver(w,why,by){const lo=w>=0?this.opp(w):-1,pts=w<0?0:why==='bura'||buPts(this.taken[lo])===0?2:1;if(w>=0)this.match[w]+=pts;
  this.dres={w,why,by:by??w,pts,a:buPts(this.taken[0]),b:buPts(this.taken[2])};this.phase='dealover';this.cur=-1;
  if(w>=0&&typeof gEndGest==='function')gEndGest(()=>w===2?'cheer':'shake',[2]);
  if(this.match[0]>=this.to||this.match[2]>=this.to){this.phase='over';this.ctx.finAt=performance.now();gameResult('bura',this.match[0]>=this.to);this.render();return}
  this.go();this.later(()=>{if(this.phase==='dealover'){this.newDeal();this.go()}},4200)},
 go(){this.render();this.step()},
 lv(){return this.ctx&&this.ctx.lvl||bLvl('bura')},
 /* the computer: leads its three trumps when it has them, calls 31 when it has it, leads what cannot be beaten or a low card,
    answers with the cheapest cards that take, and when it cannot take, gives the cards worth least */
 sure(c,p){if(c.s!==this.trump)return false;const above=Object.keys(BU_ORD).map(Number).filter(r=>BU_ORD[r]>BU_ORD[c.r]);return above.every(r=>this.gone.has(c.s+r)||this.hands[p].some(x=>x.s===c.s&&x.r===r))},
 botLead(p){const h=this.hands[p],lv=this.lv(),pts=buPts(this.taken[p]);
  if(this.isBura(h))return{k:'lead',cs:h.slice()};
  if(pts>=31&&(lv>=2||Math.random()<.6))return{k:'call'};if(lv===1&&pts>=27&&Math.random()<.15)return{k:'call'};
  if(lv===1)return{k:'lead',cs:[h[Math.floor(Math.random()*h.length)]]};
  const bySuit={};for(const c of h)(bySuit[c.s]=bySuit[c.s]||[]).push(c);
  const sure=h.filter(c=>this.sure(c,p));if(sure.length&&(buPts(sure)>=10||this.deck.length<6))return{k:'lead',cs:sure.slice(0,3)};
  if(lv>=3){const grp=Object.values(bySuit).filter(g=>g.length>=2&&g[0].s!==this.trump&&buPts(g)<=4).sort((a,b)=>b.length-a.length)[0];if(grp)return{k:'lead',cs:grp}}
  const cheap=h.slice().sort((a,b)=>((a.s===this.trump)-(b.s===this.trump))||(BU_PT[a.r]||0)-(BU_PT[b.r]||0)||BU_ORD[a.r]-BU_ORD[b.r]);return{k:'lead',cs:[cheap[0]]}},
 botResp(p){const h=this.hands[p],n=this.led.cs.length,lv=this.lv(),sets=[];const pick=(i,a)=>{if(a.length===n){sets.push(a);return}for(let k=i;k<h.length;k++)pick(k+1,[...a,h[k]])};pick(0,[]);
  if(lv===1)return{k:'resp',cs:sets[Math.floor(Math.random()*sets.length)]};
  const ledP=buPts(this.led.cs),cost=cs=>cs.reduce((a,c)=>a+(c.s===this.trump?(this.deck.length>3?4+BU_ORD[c.r]*.4:1):0),0);
  let best=null,bv=-1e9;for(const cs of sets){const beat=this.covers(cs,this.led.cs),v=beat?ledP+buPts(cs)-cost(cs)+1:-buPts(cs)-ledP-cs.filter(c=>c.s===this.trump).length*2;if(v>bv){bv=v;best=cs}}
  return{k:'resp',cs:best}},
 step(){const p=this.cur;if(p!==2)return;if(this.phase==='lead')this.later(()=>{const m=this.botLead(2);if(m.k==='call')this.call(2);else this.doLead(2,m.cs)},900);
  else if(this.phase==='resp')this.later(()=>{const m=this.botResp(2);this.doResp(2,m.cs)},950)},
 kick(){this.step()},
 save(){if(!['lead','resp'].includes(this.phase))return null;const o={};for(const k of['to','match','dealer','hands','trumpCard','trump','deck','taken','tricks','lead','cur','led','phase','dealN'])o[k]=this[k];o.gone=[...this.gone];return o},
 restore(s){if(!s||!Array.isArray(s.hands))throw 0;Object.assign(this,s);this.gone=new Set(s.gone||[]);this.sel=[];this.resp=null;this.dres=null;setTimeout(()=>{if(S.game==='bura')this.step()},500)},
 status(){const me=0;
  if(this.phase==='over')return this.match[0]>=this.to?'მატჩი შენია! 🎉':esc(this.nm(2))+'მ მოიგო მატჩი';
  if(this.phase==='dealover'){const r=this.dres,who=r.w===0?'შენ':esc(this.nm(2));
   if(r.w<0)return `ფრე: ${r.a}:${r.b}`;if(r.why==='bura')return `ბურა! ${who} იგებს დარიგებას (+2)`;
   if(r.why==='call')return `${r.by===0?'შენ':esc(this.nm(2))} თქვა „31“ და მართალი იყო: ${who} იგებს (+${r.pts})`;
   if(r.why==='miscall')return `${r.by===0?'შენ':esc(this.nm(2))} თქვა „31“, მაგრამ ჰქონდა ${r.by===0?r.a:r.b}. დარიგება ${r.w===0?'შენია':esc(this.nm(2))+'ს ერგო'}`;
   return `კარტი გათავდა: ${r.a}:${r.b}. ${r.w===0?'დარიგება შენია':'დარიგება '+esc(this.nm(2))+'ს'} (+${r.pts})`}
  if(this.phase==='show')return this.win===0?'ეს ხელი შენ წაიღე':esc(this.nm(2))+'მ წაიღო ხელი';
  if(this.cur!==me)return esc(this.nm(2))+(this.phase==='lead'?' ფიქრობს, რით დაიწყოს…':' პასუხობს…');
  if(this.phase==='lead'){const s=this.sel.map(i=>this.hands[0][i]);return this.isBura(s)?'სამი კოზირი: ეს ბურაა!':s.length?`არჩეულია ${s.length}. ჩამოდი ან დაამატე იმავე ფრის კარტი`:'შენი სვლაა: აირჩიე 1–3 ერთი ფრის კარტი'}
  const n=this.led.cs.length,s=this.sel.map(i=>this.hands[0][i]);return s.length===n?(this.covers(s,this.led.cs)?'ეს კარტები გადაფარავს და წაიღებ':'ეს ვერ გადაფარავს: წაიღებს '+esc(this.nm(2))):`აირჩიე ${n} კარტი პასუხად`},
 render(){if(S.tab!=='games'||S.game!=='bura'||S.page)return;const g3=g3Want(),mine=this.cur===0&&['lead','resp'].includes(this.phase);gTurnSnd(this,mine);
  const selC=this.sel.map(i=>this.hands[0][i]),n=this.led?this.led.cs.length:0;
  const ok=c=>{if(!mine)return false;if(this.phase==='lead')return!selC.length||selC.some(x=>cSame(x,c))||c.s===selC[0].s&&selC.length<3;return true};
  const hand=this.hands[0].map((c,i)=>cBtn(c,i,'buc',ok(c),this.sel.includes(i))).join('');
  const row=(o,cls)=>o?`<div class="burow ${cls}${this.win===o.p&&this.phase==='show'?' won':''}">${o.cs.map(c=>jCardHTML(c)).join('')}</div>`:'';
  const tbl=this.led?(this.led.p===0?row(this.resp,'opp')+row(this.led,'me'):row(this.led,'opp')+row(this.resp,'me')):'';
  const deck=this.deck.length?`<span class="ddeck">${jCardHTML(this.trumpCard).replace('class="card','class="card dtr')}${this.deck.length>1?cBack(this.deck.length-1):''}</span>`:`<span class="ddeck none">კოზირი <b style="color:${suitInk(this.trump)}">${SY[this.trump]}</b></span>`;
  let panel='';if(mine&&this.phase==='lead')panel=`<div class="jkacts"><button class="btn gold" data-a="bugo"${selC.length&&this.okLead(selC)?'':' disabled'}>${this.isBura(selC)?'ბურა!':'ჩამოსვლა'}</button><button class="btn ghost" data-a="bucall">${ic('flag')}„31 მაქვს“</button></div>`;
  else if(mine&&this.phase==='resp')panel=`<div class="jkacts"><button class="btn gold" data-a="bugo"${selC.length===n?'':' disabled'}>პასუხი</button></div>`;
  const myPts=buShowPts()?` · ჩემი ქულა: <b>${buPts(this.taken[0])}</b>`:'';
  const info=`<div class="ginfo">${trumpChip(this.trump)}<span class="gscore" aria-label="ანგარიში: შენ ${this.match[0]}, ${esc(this.nm(2))} ${this.match[2]}"><span>შენ</span><b>${this.match[0]}</b><i>:</i><b>${this.match[2]}</b><span>${esc(this.nm(2))}</span></span><span>${this.to} ქულამდე · დასტაში ${this.deck.length}</span></div>`;
  const seat=`<div class="seat top${this.cur===2?' turn':''}"${castTap(2)}>${avAny(cPlayers[2],36)}<b>${esc(this.nm(2))}</b><span class="bt">${this.hands[2].length} კარტი · წაიღო ${this.tricks[2]}</span></div>`;
  const stage=`<div class="jt bura${g3?' g3jt':''}">${seat}<div class="trick btable" aria-label="მაგიდა">${tbl||'<span class="muted">მაგიდა ცარიელია</span>'}${deck}</div>${g3?`<div class="g3 g3-joker${G3W.ready?'':' loading'}">${g3Rv()}${G3W.ready?'':'<span class="g3load" aria-hidden="true"></span>'}</div>`:''}</div>`;
  let res='';if(this.phase==='over'){const win=this.match[0]>=this.to;res=gResBox(this,{title:win?'მოიგე!':'წააგე',sub:`მატჩი ${this.to} ქულამდე · ${this.match[0]}:${this.match[2]}`,kind:win?'win':'lose',again:'<button class="btn gold" data-a="buagain">ახალი მატჩი</button>',share:win?gShareBtn('bura',`${this.match[0]}:${this.match[2]}`):''})}
  gSaveLater(this);view.innerHTML=gShell('bura',{stage,mid:stage,top:gTop('ბურა',null)+info,bot:`<div class="pl me${mine?' turn':''}"><span class="plav">${av('me',34)}</span><span class="pln"><b>${esc(ME.name)}</b><span class="muted">წაიღე ${this.tricks[0]}${myPts}</span></span></div>
   <div class="hand${g3?' g3sr':''}" aria-label="შენი კარტები">${hand}</div><div class="status${mine?' mine':''}" role="status">${this.status()}</div>${panel}`,res});
  g3After('bura')}};
A.buc=t=>{const G=BU;if(G.cur!==0||!['lead','resp'].includes(G.phase))return;const i=+t.dataset.i,c=G.hands[0][i];if(!c)return;
 if(G.sel.includes(i))G.sel=G.sel.filter(x=>x!==i);else if(G.phase==='lead'){const s=G.sel.map(k=>G.hands[0][k]);if(s.length&&(s[0].s!==c.s||s.length>=3))G.sel=[i];else G.sel.push(i)}
 else{const n=G.led.cs.length;if(G.sel.length>=n)G.sel.shift();G.sel.push(i)}
 G.render()};
A.bugo=()=>{const G=BU;if(G.cur!==0)return;const cs=G.sel.map(i=>G.hands[0][i]);if(G.phase==='lead')G.doLead(0,cs);else if(G.phase==='resp')G.doResp(0,cs)};
A.bucall=()=>{if(BU.cur===0&&BU.phase==='lead')confirmSheet('„31 მაქვს“','თუ წაღებულ კარტებში 31 ქულა ან მეტი გაქვს, დარიგება შენია. თუ არა, მეტოქეს რჩება.','ვთქვი',()=>BU.call(0))};
A.buagain=()=>{const G=BU;G.resHide=0;G.resSnd=0;G.ctx.finAt=0;G.ctx.cined=0;G.start();G.go()};
A.bupts=t=>{const on=!buShowPts();store.set('bupts',on);gSwFlip(t,on);gRedraw()};
