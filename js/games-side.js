/* ---------- a side column on tablets and computers ----------
   on a wide screen the game's bars stand in a column on the right. the room in the middle of that column shows
   the game so far: every chess move, the joker score sheet, the domino hands, the nardi match */
const GWIDE=typeof matchMedia==='function'?matchMedia('(min-aspect-ratio:5/4)'):null;
const gWide=()=>!!GWIDE&&GWIDE.matches&&innerWidth>=700&&innerHeight>=520;
function gSideChess(G){const mv=G.mv||[];if(!mv.length)return '';const fig=s=>esc(s).replace(/[♔♕♖♗♘]/g,'<i class="fg">$&</i>');let rows='';
 if(G.full){for(let j=0;j<mv.length;j+=2)rows+=`<tr${j>=mv.length-2?' class="now"':''}><td class="n">${j/2+1}.</td><td>${fig(mv[j])}</td><td>${mv[j+1]?fig(mv[j+1]):''}</td></tr>`}
 else rows=mv.map((m,j)=>`<tr${j===mv.length-1?' class="now"':''}><td class="n">…</td><td colspan="2">${fig(m)}</td></tr>`).join('');
 return `<h4>სვლები</h4>${G.opn?`<p class="gsp">${ic('book')} ${esc(G.opn.n)}</p>`:''}<div class="gsl"><table class="gsmv">${rows}</table></div>`}
/* names: who took a hand (a pair in the game of four, a seat otherwise); tot: the running score after each hand, if any */
function gSideDomino(hist,names,tot){if(!hist||!hist.length)return '';let a=0,b=0;
 const rows=hist.map((h,i)=>{if(h.win===0)a+=h.pts;else if(h.win===1)b+=h.pts;return `<tr><td class="n">${i+1}.</td><td>${h.kind==='block'?'ჩაიკეტა':'დომინო'}</td><td>${h.win<0||h.win==null?'ფრე':esc(names[h.win])+' +'+h.pts}</td><td class="t">${tot?tot(a,b):''}</td></tr>`}).join('');
 return `<h4>ხელები</h4><div class="gsl"><table class="gsmv dm">${rows}</table></div>`}
function gSideHTML(){
 if(S.page&&S.page.id==='jktable'){const s=JO.st;return s&&s.hist&&s.hist.length?`<h4>ქულების ფურცელი</h4><div class="gsl">${jNoteHTML(s.hist,s.score||[0,0,0,0],[0,1,2,3].map(joShort))}</div>`:''}
 if(S.page&&S.page.id==='dmtable'){const s=DMO.st;if(!s||!s.hist)return '';const me=DMO.seat>=0,us=me?DMO.seat%2:0,nm=!me?['I წყვილი','II წყვილი']:us===0?['ჩვენ','მეტოქეები']:['მეტოქეები','ჩვენ'];
  return gSideDomino(s.hist,nm,(a,b)=>us===0?a+':'+b:b+':'+a)}
 if(S.page||S.tab!=='games'||!S.game)return '';const G=GAME[S.game];if(!G||!G.ctx)return '';
 if(S.game==='chess')return gSideChess(G);
 if(S.game==='joker')return G.hist&&G.hist.length?`<h4>ქულების ფურცელი</h4><div class="gsl">${jNoteHTML(G.hist,G.score,[0,1,2,3].map(p=>G.nm(p)))}</div>`:'';
 if(S.game==='domino'){if((G.np||4)<4){const SE=dmSeats(G.np),h=gSideDomino(G.hist,[0,1,2,3].map(p=>p?G.nm(p):'შენ'),null);return h&&`<p class="gsp">${SE.map(p=>`${esc(p?G.nm(p):'შენ')}: <b>${G.pts[p]}</b>`).join(' · ')}</p>`+h}
  return gSideDomino(G.hist,['ჩვენ','მეტოქეები'],(a,b)=>a+':'+b)}
 if(S.game==='nardi'){const c=G.ctx;if(!(c.match>1))return '';const me=c.side,ms=c.ms||{1:0,'-1':0};
  return `<h4>მატჩი ${c.match} ქულამდე</h4><div class="gsmatch"><span><b>${ms[me]||0}</b>${esc(String(c.names[me]||'').split(' ')[0])}</span><i>:</i><span><b>${ms[-me]||0}</b>${esc(String(c.names[-me]||'').split(' ')[0])}</span></div><p class="gsp">მარსი ორ ქულად ითვლება, კოქსი სამად.</p>`}
 return ''}
function gSide(){const gx=$('.gx',view);if(!gx)return;const bot=$('.ghud.bot',gx);if(!bot)return;let el=$('.gside',bot);
 const h=gWide()?gSideHTML():'';if(!h){if(el)el.remove();return}
 if(!el){el=document.createElement('section');el.className='gside';el.setAttribute('aria-label','თამაშის მსვლელობა');bot.prepend(el)}
 el.innerHTML=h;const sc=$('.gsl',el);if(sc)sc.scrollTop=sc.scrollHeight}
{const gv=gview;gview=function(...a){const r=gv.apply(this,a);try{gSide()}catch(e){}return r}}
{const jd=joDraw;joDraw=function(...a){const r=jd.apply(this,a);try{gSide()}catch(e){}return r}}
{const dd=dmoDraw;dmoDraw=function(...a){const r=dd.apply(this,a);try{gSide()}catch(e){}return r}}
for(const G of[JK,DM]){const r=G.render;G.render=function(...a){const x=r.apply(this,a);try{gSide()}catch(e){}return x}}
if(GWIDE)try{GWIDE.addEventListener('change',()=>{if(S.tab==='games')gRedraw()})}catch(e){}
