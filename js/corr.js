/* ---------- games by correspondence (მიმოწერით) ----------
   chess, checkers or nardi with a friend, a move whenever you like. the game waits on the shared tables between moves:
   the one who started it keeps the record on the table, the other's moves wait as entries until the starter opens it again.
   each move is the whole position, as in a live game; a short chat message tells the other it is their turn,
   unless they are looking at the board right now. nothing here changes ratings */
const CORRG=['chess','shashi','nardi'];
const CRR={id:null,ch:null,t:null,here:new Set(),gk:null,sent:0};
const corrSide=t=>t.seats[0]===ME.id?1:t.seats[1]===ME.id?-1:0;
const corrOpp=t=>t.seats[0]===ME.id?t.seats[1]:t.seats[0];
/* the newest position: the table's record or a later entry of the other player */
function corrLatest(t,moves){let best={s:t.state&&t.state.s||null,seq:t.state&&t.state.seq||0};for(const m of moves||[]){const v=m.move||{};if(m.table_id===t.id&&Number(v.seq)>best.seq&&v.s)best={s:v.s,seq:Number(v.seq)}}return best}
const corrTurn=s=>!s?null:s.over?0:s.turn;
PG.corrs={r(){view.innerHTML=pgHead('მიმოწერით')+`<div class="view-pad"><section class="tourcard"><p class="note">ჭადრაკი, შაში ან ნარდი მეგობართან, როცა დრო გაქვს: ერთი სვლა დღეში, ან ათი ერთ საღამოს. როცა სვლას გააკეთებ, მეგობარს ჩატში მიუვა შეტყობინება.</p><div class="jkacts"><button class="btn gold" data-a="corrpick">${ic('plus')}ახალი პარტია</button></div></section><div id="corrl">${skel(3)}</div></div>`;corrList()}};
async function corrList(){const el=()=>$('#corrl');let rows=[],mv=[];
 try{rows=await q(sb.from('jk_tables').select('id,host,seats,status,state,updated_at').contains('seats',[ME.id]).eq('state->>g','corr').neq('status','closed').order('updated_at',{ascending:false}).limit(30))}catch(e){if(el())el().innerHTML=`<p class="note">სია ვერ ჩაიტვირთა. ${esc(errMsg(e))}</p>`;return}
 rows=(rows||[]).filter(t=>t.state&&t.state.g==='corr'&&CORRG.includes(t.state.gk));
 if(rows.length)try{mv=await q(sb.from('jk_moves').select('table_id,move,id').in('table_id',rows.map(t=>t.id)).order('id',{ascending:false}).limit(120))}catch(e){mv=[]}
 await loadProfiles(rows.map(corrOpp).filter(Boolean));if(!el())return;
 if(!rows.length){el().innerHTML=empty('პარტიები ჯერ არ არის','დაიწყე პირველი: აირჩიე თამაში და მეგობარი.','');return}
 const item=t=>{const L=corrLatest(t,mv),turn=corrTurn(L.s),side=corrSide(t),g=GAMES.find(x=>x.id===t.state.gk),o=corrOpp(t),mine=turn===side,over=turn===0||t.status==='over';
  return `<button class="row crow${mine&&!over?' mine':''}" data-a="corropen" data-id="${t.id}">${av(o,44)}<span class="grow"><b>${esc(pname(o))}</b><span class="sub">${g?g.n:''} · ${over?'დასრულდა':mine?'შენი სვლაა':!L.s?'იწყება':'მეგობრის სვლაა'} · ${ago(t.updated_at)}</span></span>${mine&&!over?'<span class="badge">სვლა</span>':''}</button>`};
 el().innerHTML=`<div class="ph-body">${rows.map(item).join('')}</div>`}
A.corrpick=t=>{const pre=t&&t.dataset&&t.dataset.u;sheet(head('რას ვითამაშებთ?')+`<div class="jchoice">${CORRG.map(g=>`<button data-a="corrgame" data-g="${g}"${pre?` data-u="${pre}"`:''}>${GAMES.find(x=>x.id===g).n}</button>`).join('')}</div>`,'short')};
A.corrgame=t=>{const gk=t.dataset.g,pre=t.dataset.u;if(!CORRG.includes(gk))return;if(pre){closeSheet();corrNew(gk,pre);return}
 friendPicker('ვისთან?','დაწყება',sel=>{const u=[...sel][0];closeSheet();if(u)corrNew(gk,u)})};
async function corrNew(gk,u){try{const r=await q(sb.from('jk_tables').insert({host:ME.id,len:'quick',status:'play',seats:[ME.id,u,null,null],state:{g:'corr',gk,s:null,seq:0}}).select('id').single());
  const g=GAMES.find(x=>x.id===gk);corrNote(u,r.id,gk,`♟ ${g.n} მიმოწერით: ახალი პარტია დავიწყე`);corrOpen(r.id)}catch(e){toast(errMsg(e))}}
A.corropen=t=>corrOpen(+t.dataset.id);
A.corrnew=()=>{const G=GAME[S.game],c=G&&G.ctx;if(!c||!c.corr)return;const u=c.opp,gk=c.gk;A.lobby();corrNew(gk,u)};
/* a short message in the chat with the other player; the button in it opens the game */
async function corrNote(u,id,gk,body){try{const c=await rpc('start_dm',{other:u});await q(sb.from('messages').insert({conv_id:c,sender:ME.id,body,media:{game:{gt:'corr',tbl:id,gk}}}))}catch(e){}}
async function corrOpen(id){let t=null,mv=[];try{t=await q(sb.from('jk_tables').select('*').eq('id',id).maybeSingle())}catch(e){}
 if(!t||!t.state||t.state.g!=='corr'||!CORRG.includes(t.state.gk)){toast('პარტია ვერ მოიძებნა');return}const side=corrSide(t);if(!side){toast('ეს პარტია სხვებისაა');return}
 try{mv=await q(sb.from('jk_moves').select('table_id,move,id').eq('table_id',id).order('id',{ascending:false}).limit(20))}catch(e){}
 const gk=t.state.gk,o=corrOpp(t);await loadProfiles([o]);const L=corrLatest(t,mv);corrClose();
 CRR.id=id;CRR.t=t;CRR.gk=gk;CRR.sent=0;closeSheet();gToTab();
 startGame(gk,{mode:'online',corr:id,side,opp:o,gid:'c'+id,names:{[side]:ME.name,[-side]:pname(o)},avs:{[side]:'me',[-side]:Object.assign({},prof(o))},seq:L.seq,noElo:1,gr:{ch:null,emit:corrEmit}});
 const G=GAME[gk];if(L.s){try{G.load(L.s);G.ctx.seq=L.seq}catch(e){}G.render();if(G.checkEnd)G.checkEnd()}
 else if(side===1){G.ctx.seq=0;corrSave(G,0)}else{G.ctx.syncing=true;G.render();toast('მეგობარს პარტია ჯერ არ გაუხსნია')}
 const ch=sb.channel('corr-'+id,{config:{presence:{key:ME.id}}});
 ch.on('postgres_changes',{event:'UPDATE',schema:'public',table:'jk_tables',filter:'id=eq.'+id},pl=>{const r=pl.new;if(r&&r.state&&r.state.by!==ME.id)corrIn(r.state.s,Number(r.state.seq))})
  .on('postgres_changes',{event:'INSERT',schema:'public',table:'jk_moves',filter:'table_id=eq.'+id},pl=>{const r=pl.new;if(r&&r.user_id!==ME.id&&r.move)corrIn(r.move.s,Number(r.move.seq))})
  .on('presence',{event:'sync'},()=>{try{CRR.here=new Set(Object.keys(ch.presenceState()))}catch(e){}})
  .subscribe(s=>{if(s==='SUBSCRIBED')ch.track({at:Date.now()}).catch(()=>{})});
 CRR.ch=ch}
/* a newer position from the other player, while both look at the board */
function corrIn(s,seq){const G=GAME[CRR.gk],c=G&&G.ctx;if(!c||c.corr!==CRR.id||!s||!(seq>c.seq||c.syncing&&seq>=c.seq))return;try{G.load(s);c.seq=seq;c.syncing=false;G.render();if(G.checkEnd)G.checkEnd();if(typeof gSnd==='function')gSnd('turn')}catch(e){}}
function corrSave(G,seq){const c=G.ctx,t=CRR.t,s=G.snap(),res=G.res&&G.res(),turn=G.turnSide?G.turnSide():null;if(!t)return;
 if(c.side===1){const st=Object.assign({},t.state,{s,seq,by:ME.id,turn});t.state=st;q(sb.from('jk_tables').update({state:st,status:res?'over':'play',updated_at:new Date().toISOString()}).eq('id',t.id)).catch(e=>toast('სვლა ვერ შეინახა: '+errMsg(e)))}
 else q(sb.from('jk_moves').insert({table_id:t.id,seat:1,user_id:ME.id,move:{s,seq}})).catch(e=>toast('სვლა ვერ შეინახა: '+errMsg(e)));
 /* the other player hears about it once a turn, when the move is theirs or the game is over */
 const o=c.opp,passed=res||turn===-c.side;if(passed&&o&&!CRR.here.has(o)&&CRR.sent!==seq){CRR.sent=seq;const g=GAMES.find(x=>x.id===c.gk);corrNote(o,t.id,c.gk,res?`♟ ${g.n} მიმოწერით: პარტია დასრულდა`:`♟ ${g.n} მიმოწერით: შენი სვლაა`)}}
/* the game's own "send" carries each position here instead of to a live channel */
function corrEmit(ev,p){if(ev!=='st'||!p)return;const G=GAME[CRR.gk];if(!G||!G.ctx||G.ctx.corr!==CRR.id)return;corrSave(G,Number(p.seq))}
function corrClose(){if(CRR.ch){try{CRR.ch.untrack()}catch(e){}try{sb.removeChannel(CRR.ch)}catch(e){}}Object.assign(CRR,{id:null,ch:null,t:null,here:new Set(),gk:null})}
{const lb=A.lobby;A.lobby=function(...a){if(CRR.id)corrClose();return lb.apply(this,a)}}
/* the other player is not sitting at the board: their turn waits, it is not "thinking" */
for(const G of[CH,CK,NR]){const st=G.status;G.status=function(...a){const s=st.apply(this,a),c=this.ctx;if(!c||!c.corr||typeof s!=='string'||!s.endsWith(' ფიქრობს…'))return s;return s.slice(0,-' ფიქრობს…'.length)+': მისი სვლაა. როცა გააკეთებს, ჩატში შეტყობინება მოგივა'}}
