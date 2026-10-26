/* ---------- a game on air: friends watch a game against the computer, and everyone watching can comment ----------
   switched on in the game menu: the board goes out on a live channel, as a game between two people does, and the game
   shows up in the lobby under "ახლა თამაშობენ" for whoever is online. watchers and players can send short comments;
   they float over the board for everyone at the table and are not kept anywhere */
const GLV={on:false,gid:null,gk:null,ch:null,seq:0,last:'',wn:0};
const gLiveCan=()=>{const G=GAME[S.game],c=G&&G.ctx;return !S.page&&!!c&&['bot','career','learn','local'].includes(c.mode)&&['chess','shashi','nardi'].includes(S.game)};
A.glivet=t=>{if(GLV.on)gLiveStop(true);else gLiveStart();gSwFlip(t,GLV.on)};
function gLiveStart(){if(!gLiveCan())return;const G=GAME[S.game],c=G.ctx,gid='g'+Math.random().toString(36).slice(2,12);
 Object.assign(GLV,{on:true,gid,gk:S.game,seq:0,last:'',wn:0,ctx:c});
 const ch=sb.channel('game-'+gid,{config:{presence:{key:ME.id},broadcast:{self:false}}});
 ch.on('broadcast',{event:'need'},()=>gLiveSend(true)).on('broadcast',{event:'cmt'},({payload:d})=>gCmtShow(d))
  .on('presence',{event:'sync'},()=>{let n=0;try{const st=ch.presenceState();for(const k in st)if((st[k]||[]).some(x=>x&&x.w))n++}catch(e){}GLV.wn=n;const G2=GAME[GLV.gk];if(G2&&G2.ctx===GLV.ctx){G2.ctx.wn=n;G2.render()}})
  .subscribe(s=>{if(s==='SUBSCRIBED'){ch.track({w:0}).catch(()=>{});gLiveSend(true)}});
 GLV.ch=ch;const opp=String(c.names[-c.side]||'ბოტი').slice(0,40);NET.state={st:'play',gt:S.game,g:gid,vs:opp,live:1};netPresence();
 toast('ლაივი ჩაირთო: ონლაინ მეგობრები ლობიში დაინახავენ და შეძლებენ ყურებას');G.render()}
function gLiveSend(force){const G=GAME[GLV.gk];if(!GLV.on||!GLV.ch||!G||G.ctx!==GLV.ctx)return;let s;try{s=G.snap()}catch(e){return}const j=JSON.stringify(s);if(!force&&j===GLV.last)return;GLV.last=j;GLV.seq++;
 try{GLV.ch.send({type:'broadcast',event:'st',payload:{seq:GLV.seq,s}})}catch(e){}}
function gLiveStop(say){if(!GLV.on)return;GLV.on=false;const ch=GLV.ch;GLV.ch=null;if(ch){try{ch.send({type:'broadcast',event:'bye',payload:{from:ME.id}})}catch(e){}setTimeout(()=>{try{sb.removeChannel(ch)}catch(e){}},400)}
 if(NET.state&&NET.state.live){NET.state=null;netPresence()}const G=GAME[GLV.gk];if(G&&G.ctx===GLV.ctx){G.ctx.wn=0;if(S.game===GLV.gk)G.render()}if(say)toast('ლაივი გამოირთო')}
for(const G of[CH,CK,NR]){const r=G.render;G.render=function(...a){const x=r.apply(this,a);if(GLV.on&&S.game===GLV.gk&&this.ctx===GLV.ctx)gLiveSend(false);return x}}
{const lb=A.lobby;A.lobby=function(...a){gLiveStop(false);return lb.apply(this,a)}}

/* ---------- comments over the board ---------- */
const GCMT=['ბრავო!','ვაჰ!','ფრთხილად!','კარგი სვლაა','ეგ რა იყო?','გაუმარჯოს!'];
function gCmtShow(d,mine){if(!d||typeof d.t!=='string')return;const t=d.t.trim().slice(0,120),n=String(d.n||'').slice(0,40);if(!t)return;if(!mine&&d.from===ME.id)return;
 let L=$('#gcmt');if(!L){L=document.createElement('div');L.id='gcmt';L.setAttribute('aria-live','polite');document.body.appendChild(L)}
 const el=document.createElement('div');el.className='gcm'+(mine?' me':'');el.innerHTML=`<b>${esc(n.split(' ')[0])}</b> ${esc(t)}`;L.appendChild(el);while(L.children.length>4)L.firstChild.remove();
 setTimeout(()=>{el.classList.add('out');setTimeout(()=>el.remove(),600)},7000);if(!mine&&typeof gSnd==='function')gSnd('tap',.5)}
/* who can comment: watchers, both players of a live game between people, and the player of a game on air */
const gCmtCh=()=>{const G=GAME[S.game],c=G&&G.ctx;if(!c||S.page)return null;if(GLV.on&&c===GLV.ctx)return d=>GLV.ch&&GLV.ch.send({type:'broadcast',event:'cmt',payload:d});
 if((c.mode==='netwatch'||c.mode==='online'&&!c.corr)&&c.gr)return d=>c.gr.emit('cmt',d);return null};
A.gcmt=()=>{if(!gCmtCh()){toast('კომენტარი ლაივ პარტიაზე იწერება');return}sheet(head('კომენტარი')+`<div class="ph-body"><div class="gcq">${GCMT.map(x=>`<button class="chip" data-a="gcmtq" data-t="${esc(x)}">${esc(x)}</button>`).join('')}</div>
  <form class="gcf" data-f="gcmtsend"><input name="t" maxlength="120" placeholder="დაწერე რამე…" autocomplete="off" aria-label="კომენტარი"><button class="btn gold" type="submit">${ic('send')}</button></form></div>`,'short');setTimeout(()=>{const i=$('.gcf input');if(i)i.focus()},120)};
function gCmtSend(t){const f=gCmtCh();t=String(t||'').trim().slice(0,120);if(!f||!t)return;const d={from:ME.id,n:ME.name,t};try{f(d)}catch(e){}gCmtShow(d,true)}
A.gcmtq=t=>{closeSheet();gCmtSend(t.dataset.t)};
document.addEventListener('submit',e=>{const f=e.target;if(!f||!f.matches||!f.matches('form.gcf'))return;e.preventDefault();const v=f.t&&f.t.value;closeSheet();gCmtSend(v)},true);
