/* ---------- domino (დომინო): four players in two pairs, the block game to 101 ----------
   28 tiles, seven each, nothing left to draw. the first hand starts with 6-6, later hands with the last winner.
   you must play a tile that matches an open end, otherwise you pass. the pair that goes out first takes
   the pips left in the other pair's hands; if nobody can play, the pair with fewer pips takes the others' pips */
const DMN=[null,{n:'გიორგი',h:150},{n:'ანა',h:275},{n:'ლევანი',h:95}];
const DM_TO=101;
const dmPip=t=>t[0]+t[1];
const dmTeam=p=>p%2;
const dmHalf=v=>`<span class="dh">${Array.from({length:9},(_,k)=>v&&PIPS[v].includes(k)?'<i></i>':'<span></span>').join('')}</span>`;
const dmTile=(t,cls='',attr='')=>`<${attr?'button':'span'} class="dmt${t[0]===t[1]?' dbl':''}${cls?' '+cls:''}"${attr} aria-label="${t[0]} და ${t[1]}">${dmHalf(t[0])}${dmHalf(t[1])}</${attr?'button':'span'}>`;
const DM=GAME.domino={title:'დომინო',
 start(){this.tk=(this.tk||0)+1;this.score=[0,0];this.round=0;this.lead=null;this.hist=[];this.deal()},
 nm(p){return p===0?ME.name:DMN[p].n},
 deal(){const set=[];for(let a=0;a<=6;a++)for(let b=a;b<=6;b++)set.push([a,b]);shuffle(set);
  this.hands=[0,1,2,3].map(i=>set.slice(i*7,i*7+7).sort((x,y)=>x[0]-y[0]||x[1]-y[1]));
  this.root=null;this.L=[];this.R=[];this.passes=0;this.miss=[new Set(),new Set(),new Set(),new Set()];this.sel=null;this.last=null;this.res=null;this.phase='play';this.round++;
  this.first=this.lead==null;this.cur=this.first?this.hands.findIndex(h=>h.some(t=>t[0]===6&&t[1]===6)):this.lead;this.dealAnim=1},
 ends(){if(!this.root)return null;return[this.L.length?this.L[this.L.length-1].f:this.root.t[0],this.R.length?this.R[this.R.length-1].f:this.root.t[1]]},
 /* where a tile can go: anywhere to begin (only the 6-6 in the first hand), otherwise on an end that shows one of its numbers */
 places(t){if(!t)return[];const e=this.ends();if(!e)return this.first&&!(t[0]===6&&t[1]===6)?[]:['root'];
  const fits=v=>t[0]===v||t[1]===v;if(e[0]===e[1])return fits(e[0])?[this.L.length<=this.R.length?'L':'R']:[];
  const out=[];if(fits(e[0]))out.push('L');if(fits(e[1]))out.push('R');return out},
 moves(p){const out=[];this.hands[p].forEach((t,i)=>{for(const s of this.places(t))out.push({i,s})});return out},
 put(p,i,side){const h=this.hands[p],t=h.splice(i,1)[0],e=this.ends();
  if(side==='root')this.root={t,by:p};else{const end=side==='L'?e[0]:e[1],f=t[0]===end?t[1]:t[0];(side==='L'?this.L:this.R).push({t,n:end,f,by:p})}
  this.last={p,t,side};this.passes=0;this.sel=null;if(!h.length){this.endRound('domino',p);return}this.next()},
 pass(p){const e=this.ends();if(e){this.miss[p].add(e[0]);this.miss[p].add(e[1])}this.last={p,pass:1};this.passes++;if(this.passes>=4){this.endRound('block');return}this.next()},
 next(){this.cur=(this.cur+1)%4;this.render();this.step()},
 step(){const p=this.cur,c=this.ctx,tk=this.tk;if(this.phase!=='play'||p<0)return;
  const later=(fn,ms)=>setTimeout(()=>{if(tk===this.tk&&this.ctx===c&&S.game==='domino'&&this.phase==='play'&&this.cur===p)fn()},ms);
  if(p===0){if(!this.moves(0).length)later(()=>this.pass(0),1400);return}
  later(()=>{const m=this.bot(p);if(m)this.put(p,m.i,m.s);else this.pass(p)},950)},
 kick(){this.step()},
 /* heavy tiles and doubles go first; keep numbers you still hold, leave ends the next player lacks, not ends your partner lacks */
 bot(p){const ms=this.moves(p);if(!ms.length)return null;const h=this.hands[p],e=this.ends(),mate=(p+2)%4,nx=(p+1)%4,pv=(p+3)%4;let best=null,bv=-1e9;
  for(const m of ms){const t=h[m.i];let v=dmPip(t)*1.2+(t[0]===t[1]?7:0)+Math.random();
   if(e&&m.s!=='root'){const end=m.s==='L'?e[0]:e[1],nf=t[0]===end?t[1]:t[0],other=m.s==='L'?e[1]:e[0];
    v+=h.filter((x,k)=>k!==m.i&&(x.includes(nf)||x.includes(other))).length*1.6;if(this.miss[nx].has(nf))v+=5;if(this.miss[pv].has(nf))v+=2;if(this.miss[mate].has(nf))v-=4}
   if(v>bv){bv=v;best=m}}return best},
 endRound(kind,p){const pip=q=>this.hands[q].reduce((a,t)=>a+dmPip(t),0),tp=[pip(0)+pip(2),pip(1)+pip(3)];let win,pts;
  if(kind==='domino'){win=dmTeam(p);pts=tp[1-win]}else{win=tp[0]<tp[1]?0:tp[1]<tp[0]?1:-1;pts=win<0?0:tp[1-win]}
  if(win>=0)this.score[win]+=pts;
  this.lead=kind==='domino'?p:win>=0?[win,win+2].sort((a,b)=>pip(a)-pip(b))[0]:((this.lead??0)+1)%4;
  this.res={kind,win,pts,by:p,pips:[0,1,2,3].map(pip),tp};this.hist.push({win,pts,kind});this.cur=-1;this.sel=null;
  this.phase=this.score.some(x=>x>=DM_TO)?'over':'roundover';if(this.phase==='over')gameResult('domino',this.score[0]>this.score[1]);this.render()},
 /* the line of play from the left end to the right end, each tile as it lies */
 line(){if(!this.root)return[];return[...this.L.slice().reverse().map(x=>({t:[x.f,x.n],by:x.by})),{t:this.root.t,by:this.root.by,root:1},...this.R.map(x=>({t:[x.n,x.f],by:x.by}))]},
 status(){const c=this.ctx;if(this.phase==='over')return this.score[0]>this.score[1]?'მოიგეთ! 🎉':'ამჯერად მეტოქეებმა მოიგეს';
  if(this.phase==='roundover'){const r=this.res;return (r.kind==='block'?'თამაში ჩაიკეტა. ':'')+(r.win<0?'ფრე, ქულები არავის დაეწერა':r.win===0?`ხელი თქვენია: +${r.pts}`:`მეტოქეებმა წაიღეს: +${r.pts}`)}
  const l=this.last,pre=l&&l.pass?esc(this.nm(l.p))+': პასი. ':'';
  if(this.cur===0){if(!this.moves(0).length)return pre+'შესაფერისი ქვა არ გაქვს, პასი';return pre+(this.sel!=null?'აირჩიე, რომელ ბოლოს მიუდო':this.root?'შენი სვლაა':'იწყებ შენ. დადე ექვს-ექვსი')}
  return pre+esc(this.nm(this.cur))+' ფიქრობს…'+(!this.root&&this.first?' (6-6 მასთანაა)':'')},
 render(){if(S.tab!=='games'||S.game!=='domino'||S.page)return;const c=this.ctx,g3=g3On(),mine=this.phase==='play'&&this.cur===0,ok=new Set(mine?this.moves(0).map(m=>m.i):[]);
  const seat=(p,pos)=>`<div class="seat ${pos}${this.cur===p&&this.phase==='play'?' turn':''}">${avAny(DMN[p],36)}<b>${esc(this.nm(p))}</b><span class="bt">${this.hands[p].length} ქვა${p===2?' · პარტნიორი':''}</span></div>`;
  const chain=this.line().map(x=>dmTile(x.t,x.root?'root':'')).join('');
  const hand=this.hands[0].map((t,i)=>dmTile(t,(this.sel===i?'sel':'')+(ok.has(i)?' ok':''),` data-a="dmt" data-i="${i}"${mine&&ok.has(i)?'':' disabled'}`)).join('');
  const e=this.ends();let panel='';
  if(mine&&this.sel!=null&&e)panel=`<div class="dmends" role="group" aria-label="რომელ ბოლოს"><button class="btn ghost" data-a="dmend" data-e="L">${ic('back')}მარცხნივ · ${e[0]}</button><button class="btn ghost" data-a="dmend" data-e="R">მარჯვნივ · ${e[1]}<span class="flipx">${ic('back')}</span></button></div>`;
  if(this.res&&this.phase!=='play'){const r=this.res;panel=`<div class="sheet-tbl"><table><thead><tr><th></th>${[0,1,2,3].map(p=>`<th>${esc(p===0?'შენ':this.nm(p))}</th>`).join('')}</tr></thead><tbody><tr><td>დარჩა ქულა</td>${r.pips.map(x=>`<td>${x}</td>`).join('')}</tr></tbody></table></div>
   <p class="note">ჩვენ ${r.tp[0]} · მეტოქეები ${r.tp[1]}.${r.kind==='domino'?` ${esc(r.by===0?'შენ':this.nm(r.by))} გამოვიდა პირველი.`:' არავის შეეძლო სვლა, ნაკლები ქულა იგებს.'}</p>`+(this.phase==='over'?'<button class="btn" data-a="dmagain" style="align-self:flex-start">ახალი თამაში</button>':'<button class="btn" data-a="dmnext" style="align-self:flex-start">შემდეგი ხელი</button>')}
  const info=`<div class="jinfo"><span class="trump">ჩვენ ${this.score[0]} · მეტოქეები ${this.score[1]}</span><span>ხელი ${this.round} · ${DM_TO}-მდე</span></div>`;
  view.innerHTML=`<div class="view-pad game">${gTop('დომინო',c)}<div class="jt dmtab${g3?' g3jt':''}">${seat(2,'top')}${seat(1,'left')}${seat(3,'right')}<div class="trick dmchain${g3?' g3sr':''}" aria-label="მაგიდა">${chain||'<span class="muted">მაგიდა ცარიელია</span>'}</div>${g3?`<div class="g3 g3-domino">${g3Rv()}</div>`:''}${info}</div>
   <div class="pl">${av('me',30)}<b>${esc(ME.name)}</b><span class="muted">შენ და ანა ერთ გუნდში ხართ</span></div>
   <div class="dmhand${g3?' g3sr':''}" aria-label="შენი ქვები">${hand}</div><div class="status" role="status">${this.status()}</div>${panel}
   <details><summary style="cursor:pointer;font-weight:600">წესები</summary><p class="note" style="margin-top:8px">ოთხი მოთამაშე, ორ-ორი გუნდში: შენ და ანა გიორგისა და ლევანის წინააღმდეგ. თითოეულს 7 ქვა აქვს, საბაზრო არ არის. პირველ ხელს ის იწყებს, ვისაც ექვს-ექვსი აქვს, შემდეგ ხელებს წინა ხელის გამარჯვებული. სვლისას ქვა ერთ-ერთ ღია ბოლოს უნდა მიუდო, თუ შესაფერისი არ გაქვს, პასობ. გუნდი, რომლის მოთამაშეც პირველი დაცლის ხელს, იღებს მეტოქეების ქვებზე დარჩენილ ქულებს. თუ თამაში ჩაიკეტა, იგებს გუნდი, რომელსაც ნაკლები ქულა დარჩა, და იღებს მეტოქეების ქულებს. თამაში ${DM_TO} ქულამდეა.</p></details></div>`;
  g3After('domino')}};
A.dmt=t=>{const G=DM;if(G.phase!=='play'||G.cur!==0)return;const i=+t.dataset.i,pl=G.places(G.hands[0][i]);if(!pl.length){G.sel=null;G.render();return}
 if(pl.length===1){G.put(0,i,pl[0]);return}G.sel=G.sel===i?null:i;G.render()};
A.dmend=t=>{const G=DM;if(G.phase!=='play'||G.cur!==0||G.sel==null)return;const s=t.dataset.e;if(!G.places(G.hands[0][G.sel]).includes(s))return;G.put(0,G.sel,s)};
A.dmnext=()=>{if(DM.phase==='roundover'){DM.deal();DM.render();DM.step()}};
A.dmagain=()=>{DM.start();DM.render();DM.step()};
