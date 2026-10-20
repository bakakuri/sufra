/* games: lobby, online play over realtime, tournaments, leaderboard */
/* pl: players at the table. on: can be played online with people. ac: accent colour taken from the board's own material (key art in icons/g, rendered with the game's 3D engine) */
const GAMES=[{id:'nardi',n:'ნარდი',d:'ტავლა, ქვის მოჭრით და ზარით',ic:'dice',net:1,on:1,pl:2,ac:'#E3A04A'},{id:'shashi',n:'შაში',d:'რუსული წესები, მფრინავი დამით',ic:'checker',net:1,on:1,pl:2,ac:'#E0574C'},{id:'chess',n:'ჭადრაკი',d:'კლასიკური წესები, როქით და გავლით აღებით',ic:'chess',net:1,on:1,pl:2,ac:'#EAD9B8'},{id:'joker',n:'ჯოკერი',d:'ქართული ბანქო ოთხ მოთამაშეზე',ic:'cards',on:1,pl:4,ac:'#4FC383'},{id:'domino',n:'დომინო',d:'წყვილებში, 101 ქულამდე',ic:'domino',pl:4,ac:'#4BB4DA'}];
const GART=(id,w)=>`/icons/g/${id}-${w}.webp?v=1`;
const GAME={};
const JK_BOTS=['ნინო','ლუკა','დათო'],JK_ERG=['ნინომ','ლუკამ','დათომ'];
const BOTN=[['ლუკა',205],['დათო',12],['გიორგი',150],['ნინო',340],['ანა',275],['ლევანი',95],['თამარი',190]];
const shuffle=a=>{for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
const BOT={n:'ბ',h:42};
/* a game opens over the whole screen, like a game app; one back step closes it */
function startGame(id,ctx){const G=GAME[id],fresh=!S.game;if(fresh&&(!ctx||ctx.mode!=='watch')&&GAMES.some(g=>g.id===id))store.set('glast',id);S.game=id;G.ctx=Object.assign({mode:'bot',side:1,names:{1:ME.name,'-1':'სუფრა ბოტი'},avs:{1:'me','-1':BOT},seq:0},ctx||{});
 G.resHide=0;G.resSnd=0;G.wasMine=false;G.start();view.scrollTop=0;if(fresh){fsEnter();g3Intro(id)}G.render();if(G.kick)G.kick();if(fresh)navOpen('game')}
const isPlayer=c=>c.mode==='bot'||c.mode==='online'||c.mode==='tour';
/* under the name: a small disc in the player's colour (side 1 plays white in every two-player game), then rating or connection */
function plSub(c,s){const col=`<i class="pc ${s===1?'w':'b'}"></i>`,cn=s===1?'თეთრები':'შავები';if(c.mode==='watch'||c.mode==='netwatch')return col+cn;if(s===c.side)return col+'რეიტინგი '+(ME.rating??1500);return col+(c.mode==='online'?(c.gone?'გავიდა':'ონლაინ'):cn)}
const gTag=c=>c.mode==='online'?'<span class="gtag">ონლაინ</span>':c.mode==='tour'?'<span class="gtag">ტურნირი</span>':c.mode==='watch'||c.mode==='netwatch'?'<span class="gtag">ყურება</span>':'';
const gTop=(t,c,back='lobby')=>`<div class="gtop"><button class="ibtn gb" data-a="${back}" aria-label="თამაშიდან გასვლა">${ic('back')}</button><h2>${t}</h2>${c?gTag(c):''}<span class="sp"></span>${gTools()}</div>`;
/* the game screen: the board fills the screen, the players and controls float over it */
function gShellParts(o){const w=g3Want()&&!o.center;return{w,html:`${w?`<div class="gstage">${o.stage||''}</div>`:''}<div class="ghud top">${o.top||''}</div><div class="gmid">${o.center||(w?'':o.mid||'')}</div><div class="ghud bot">${o.bot||''}</div>${o.res||''}`}}
function gShell(id,o){const P=gShellParts(o);return `<div class="view-pad game gx${P.w?' is3d':''}" data-g="${id}">${P.html}</div>`}
/* a player's plate. while it is their move a gold ring turns around the avatar; an opponent who is thinking shows three dots */
const plThink='<span class="think" aria-label="ფიქრობს"><i></i><i></i><i></i></span>';
const plCard=(c,s,turn,plx)=>`<div class="pl${s===c.side?' me':''}${turn?' turn':''}"><span class="plav">${avAny(c.avs[s],34)}</span><span class="pln"><b>${esc(c.names[s])}${turn&&!(s===c.side&&isPlayer(c))?plThink:''}</b><span class="muted">${plSub(c,s)}</span></span>${plx?plx(s):''}</div>`;
function gview(id,title,board,status,extra='',plx=null,topx=''){if(S.tab!=='games'||S.game!==id||S.page)return;const G=GAME[id],c=G.ctx,ts=G.turnSide?G.turnSide():null,mine=!!(G.mine&&G.mine());gTurnSnd(G,mine);
 view.innerHTML=gShell(id,{stage:board,mid:board,top:gTop(title,c)+plCard(c,-c.side,ts===-c.side,plx)+topx,bot:plCard(c,c.side,ts===c.side,plx)+`<div class="status${mine?' mine':''}" role="status">${status}</div>${extra}`,res:gResHTML(G)})}
/* a chime when the turn comes to you */
function gTurnSnd(G,mine){if(mine&&!G.wasMine&&typeof gSnd==='function'){gSnd('turn');gBuzz(12)}G.wasMine=mine}
/* the end of a game: a card over the board with the result and what to do next */
const RESWHY={mate:'მატი',stale:'პატი',rep:'პოზიცია სამჯერ განმეორდა',mat:'მატისთვის საკმარისი ფიგურები აღარ დარჩა','50':'50 სვლა აყვანისა და პაიკის სვლის გარეშე',resign:'დანებება',blocked:'სვლა აღარ დარჩა',kings:'15 სვლა მხოლოდ დამებით',k31:'სამმა დამამ ერთი ვერ აიყვანა'};
function gResBox(G,{title,sub,kind,more='',again='',leave='<button class="btn ghost" data-a="lobby">ლობი</button>'}){if(G.resHide)return '';if(!G.resSnd&&typeof gSnd==='function'){G.resSnd=1;setTimeout(()=>gSnd(kind==='win'?'win':kind==='draw'?'draw':'lose'),250)}
 return `<div class="gend ${kind}" role="dialog" aria-label="${esc(title)}"><div class="gendc"><span class="gendi">${ic(kind==='win'?'trophy':kind==='draw'?'flag':'chess')}</span><h2>${title}</h2>${sub?`<p>${sub}</p>`:''}${more}
  <div class="gendb">${again}<button class="btn ghost" data-a="gresx">დაფის ნახვა</button>${leave}</div></div></div>`}
function gResHTML(G){const r=G.res&&G.res();if(!r)return '';const c=G.ctx,me=isPlayer(c),draw=r.w===2,win=me&&!draw&&r.w===c.side;
 const title=draw?'ფრე':!me?esc(c.names[r.w])+' მოიგო':win?'მოიგე!':'წააგე';
 let sub=r.why==='resign'?(me?(win?'მეტოქე დანებდა':'დანებდი'):esc(c.names[-r.w])+' დანებდა'):RESWHY[r.why]||'';if(r.mult>1)sub=(sub?sub+' · ':'')+MULT[r.mult];if(c.gone&&!sub)sub='მეტოქე გავიდა';
 const more=me&&!draw?`<span class="gendd">${win?'+12':'−9'} რეიტინგი</span>`:'';
 const again=c.mode==='bot'?'<button class="btn gold" data-a="restart">ახალი პარტია</button>':c.mode==='tour'&&c.finished?'<button class="btn gold" data-a="page" data-p="tour">ტურნირზე</button>':'';
 return gResBox(G,{title,sub,kind:draw?'draw':win||!me?'win':'lose',more,again})}
A.gresx=()=>{if(S.page&&S.page.id==='jktable'){JO.resHide=1;joDraw();return}const G=GAME[S.game];if(G){G.resHide=1;G.render()}};
function endMsg(c,w){if(w===2)return 'ფრე';if(!isPlayer(c))return esc(c.names[w])+' მოიგო';return w===c.side?'მოიგე!':esc(c.names[w])+' მოიგო. სცადე ისევ'}
const tourBack=c=>c.mode==='tour'&&c.finished?'<button class="btn" data-a="page" data-p="tour" style="align-self:flex-start">ტურნირზე დაბრუნება</button>':'';
async function gameResult(game,win){try{const r=await rpc('game_result',{p_game:game,p_win:win});ME.rating=r.rating;setCoins(r.coins);if(win)toast(r.reward?`მოიგე! +12 რეიტინგი, +${r.reward} მონეტა`:'მოიგე! +12 რეიტინგი');if(win)confetti()}catch(e){}}
function finish(G,w){const c=G.ctx;if(c.finished)return;c.finished=1;if(isPlayer(c)&&w!==2){const win=w===c.side;gameResult(G.title,win);if(c.mode==='tour')tourResult(win)}G.render()}
A.play=t=>{const g=GAMES.find(x=>x.id===t.dataset.g);if(g.soon||!GAME[g.id]){toast(g.n+' მალე დაემატება');return}startGame(g.id)};
A.lobby=()=>{closeSheet();fsExit();navKill('game');const G=GAME[S.game];if(G){if(G.ctx&&G.ctx.gr)netLeave();G.ctx={mode:'dead',side:1,names:{},avs:{}};G.tk=(G.tk||0)+1}S.game=null;R.games()};
A.restart=()=>{const G=GAME[S.game];if(!G)return;closeSheet();G.resHide=0;G.resSnd=0;if(S.game==='joker'){G.start();G.render();return}startGame(S.game,{mode:'bot',names:G.ctx.names,avs:G.ctx.avs})};
const LIVEG=[{gt:'nardi',a:0,b:1},{gt:'chess',a:2,b:4},{gt:'shashi',a:3,b:5}];
A.watch=t=>{const g=LIVEG[+t.dataset.i],a=BOTN[g.a],b=BOTN[g.b];startGame(g.gt,{mode:'watch',names:{1:a[0]+' (ბოტი)','-1':b[0]+' (ბოტი)'},avs:{1:{n:a[0],h:a[1]},'-1':{n:b[0],h:b[1]}}})};

/* online: lobby presence + challenges, game rooms over broadcast */
const NET={lobby:null,peers:[],pending:null,inv:null,gr:null,state:null};
function netInit(){const ch=sb.channel('lobby',{config:{presence:{key:ME.id},broadcast:{self:false}}});
 ch.on('presence',{event:'sync'},()=>{const st=ch.presenceState();S.online=new Set(Object.keys(st));NET.peers=Object.entries(st).filter(([k])=>k!==ME.id).map(([k,arr])=>Object.assign({id:k},arr[arr.length-1]));if(S.tab==='games'&&!S.game&&!S.page){const ol=$('#onl');if(ol)ol.innerHTML=onlineHTML();gLobbyLive()}})
  .on('broadcast',{event:'chal'},({payload})=>onChal(payload)).on('broadcast',{event:'acc'},({payload})=>onAcc(payload)).on('broadcast',{event:'decl'},({payload})=>onDecl(payload))
  .subscribe(st=>{if(st==='SUBSCRIBED')netPresence()});NET.lobby=ch}
function netPresence(){if(!NET.lobby)return;if(ME.privacy&&ME.privacy.online===false){NET.lobby.untrack();return}NET.lobby.track(Object.assign({nm:ME.name,hu:ME.hue,av:ME.avatar_url||null,st:'idle',gt:null,g:null,vs:null},NET.state||{}))}
const lsend=(ev,payload)=>NET.lobby&&NET.lobby.send({type:'broadcast',event:ev,payload:Object.assign({from:ME.id},payload)});
function onlineHTML(){const others=NET.peers.filter(p=>!BLOCKED.has(p.id)),off=ME.privacy?.online===false?'<p class="note" style="margin-bottom:8px">შენი ონლაინ სტატუსი დამალულია, ამიტომ სხვები ლობიში ვერ გხედავენ.</p>':'';
 if(!others.length)return off+`<div class="ohint"><p>ახლა სხვა ონლაინ არავინაა. მოიწვიე მეგობარი და როცა შემოვა, აქ გამოჩნდება.</p><button class="btn sm ghost" data-a="invite">${ic('share')}მოწვევა</button></div>`;
 return off+`<div class="olist">${others.slice(0,30).map(p=>{const g=GAMES.find(x=>x.id===p.gt);return `<div class="orow"><button data-a="user" data-u="${p.id}" aria-label="${esc(p.nm)}">${av(Object.assign({},prof(p.id),{name:p.nm,hue:p.hu,avatar_url:p.av}),40)}</button><div class="grow"><b>${esc(String(p.nm||'').slice(0,40))}${FRIENDS.has(p.id)?' · მეგობარი':''}</b><span class="sub">${p.st==='play'&&g?'თამაშობს: '+g.n+(p.vs?' · '+esc(String(p.vs).slice(0,40)):''):p.st==='watch'?'უყურებს პარტიას':'თავისუფალია'}</span></div>${p.st==='play'&&p.g?`<button class="btn sm ghost" data-a="netwatch" data-u="${p.id}">ყურება</button>`:`<button class="btn sm" data-a="netchal" data-u="${p.id}">გამოწვევა</button>`}</div>`}).join('')}</div>`}
const okGid=g=>/^g[a-z0-9]{4,14}$/.test(String(g));
A.netchal=t=>{const to=t.dataset.u;if(!S.online.has(to)){toast('ახლა ონლაინ არ არის. ითამაშე ბოტთან ან სცადე მოგვიანებით');return}sheet(head('რა ვითამაშოთ?')+`<div class="jchoice">${GAMES.filter(g=>g.net).map(g=>`<button data-a="netsend" data-u="${to}" data-g="${g.id}">${g.n}</button>`).join('')}</div>`,'short')};
A.challenge=A.netchal;
A.netsend=t=>{const gid='g'+Math.random().toString(36).slice(2,12),to=t.dataset.u,gt=t.dataset.g;NET.pending={gid,gt,to};closeSheet();lsend('chal',{to,gt,gid,nm:ME.name});toast('გამოწვევა გაიგზავნა. ველოდებით პასუხს');setTimeout(()=>{if(NET.pending&&NET.pending.gid===gid){NET.pending=null;toast('პასუხი არ მოვიდა')}},45000)};
function onChal(d){if(!d||d.to!==ME.id)return;const g=GAMES.find(x=>x.id===d.gt&&x.net);if(!g||!okGid(d.gid))return;const pr=ME.privacy?.chal||'all';
 if(BLOCKED.has(d.from)||pr==='none'||(pr==='friends'&&!FRIENDS.has(d.from))){lsend('decl',{to:d.from,gid:d.gid});return}
 const nm=String(d.nm||'მოთამაშე').slice(0,40);NET.inv={from:d.from,gid:d.gid,gt:d.gt,nm};
 sheet(`<div class="match"><p class="eyebrow">გამოწვევა</p><h2 style="font-size:34px">${g.n}</h2><p><b>${esc(nm)}</b> გიწვევს თამაშში.</p><button class="btn" data-a="netacc">მიღება</button><button class="btn ghost" data-a="netdecl">უარი</button></div>`,'short')}
A.netacc=async()=>{const v=NET.inv;if(!v)return;closeSheet();NET.inv=null;lsend('acc',{to:v.from,gid:v.gid});try{await joinGame(v.gid,v.gt,-1,{nm:v.nm,id:v.from},v.from,false)}catch(e){toast('დაკავშირება ვერ მოხერხდა')}};
A.netdecl=()=>{const v=NET.inv;closeSheet();NET.inv=null;if(v)lsend('decl',{to:v.from,gid:v.gid})};
function onAcc(d){const p=NET.pending;if(!d||d.to!==ME.id||!p||d.gid!==p.gid)return;NET.pending=null;const peer=NET.peers.find(x=>x.id===d.from);joinGame(p.gid,p.gt,1,{nm:String(peer?.nm||pname(d.from)).slice(0,40),hu:peer?.hu,id:d.from},d.from,false).catch(()=>toast('დაკავშირება ვერ მოხერხდა'))}
function onDecl(d){if(!d||d.to!==ME.id||!NET.pending||d.gid!==NET.pending.gid)return;NET.pending=null;toast('გამოწვევაზე უარი მიიღე')}
A.netwatch=t=>{const p=NET.peers.find(x=>x.id===t.dataset.u);if(!p||!okGid(p.g)||!GAMES.find(x=>x.id===p.gt&&x.net))return;joinGame(p.g,p.gt,1,{a:String(p.nm).slice(0,40),b:String(p.vs||'მოთამაშე').slice(0,40)},null,true).catch(()=>toast('ყურება ვერ დაიწყო'))};
async function joinGame(gid,gt,side,opp,oppId,watch){netLeave();const G=GAME[gt];
 const names=watch?{1:opp.a,'-1':opp.b}:{[side]:ME.name,[-side]:opp.nm},avs=watch?{1:{n:opp.a,h:200},'-1':{n:opp.b,h:20}}:{[side]:'me',[-side]:oppId?Object.assign({},prof(oppId),{name:opp.nm}):{n:opp.nm,h:opp.hu}};
 const ch=sb.channel('game-'+gid,{config:{presence:{key:ME.id},broadcast:{self:false}}});
 const ctx={mode:watch?'netwatch':'online',side:watch?1:side,names,avs,gid,opp:oppId,seq:0,syncing:watch||side===-1,gr:{ch,emit:(ev,p)=>ch.send({type:'broadcast',event:ev,payload:p})}};
 if(S.page)S.page=null;if(S.tab!=='games'){S.tab='games';$$('.tab').forEach(b=>b.setAttribute('aria-current',String(b.dataset.tab==='games')));view.className='';$('#app').classList.remove('media');moveInd('games')}
 {const fresh=!S.game;S.game=gt;G.ctx=ctx;G.start();NET.gr=ctx.gr;if(fresh)navOpen('game')}
 ch.on('broadcast',{event:'st'},({payload:d})=>{if(G.ctx!==ctx||!d||typeof d!=='object'||!(Number(d.seq)>ctx.seq)||!d.s)return;try{G.load(d.s);ctx.seq=Number(d.seq);ctx.syncing=false;G.render();if(G.checkEnd)G.checkEnd()}catch(e){}})
  .on('broadcast',{event:'need'},()=>{if(G.ctx===ctx&&ctx.mode==='online'&&side===1)netSend()})
  .on('broadcast',{event:'bye'},({payload:d})=>{if(G.ctx===ctx&&d&&d.from===oppId){ctx.gone=1;G.render()}})
  .on('presence',{event:'leave'},({key})=>{if(G.ctx===ctx&&oppId&&key===oppId){ctx.gone=1;G.render()}})
  .subscribe(st=>{if(st!=='SUBSCRIBED')return;ch.track({w:watch?1:0});if(watch||side===-1)ctx.gr.emit('need',{});else netSend()});
 NET.state={st:watch?'watch':'play',gt,g:gid,vs:watch?null:String(opp.nm).slice(0,40)};netPresence();view.scrollTop=0;G.render()}
function netSend(){const G=GAME[S.game];if(!G||!G.ctx||G.ctx.mode!=='online'||!G.ctx.gr)return;G.ctx.seq++;G.ctx.gr.emit('st',{seq:G.ctx.seq,s:G.snap()})}
function netLeave(){if(NET.gr){const g=NET.gr;NET.gr=null;try{g.emit('bye',{from:ME.id})}catch(e){}setTimeout(()=>sb.removeChannel(g.ch),400)}NET.state=null;netPresence()}

/* weekly tournament (nardi, 8 players, bots play the other seats) */
S.tour=store.get('tour',null);
const tName=x=>x==='me'?ME.name:BOTN[x][0];
const tourParts=k=>k===0?S.tour.pl:S.tour.r[k-1];
function tourRound(){for(let k=0;k<3;k++)if(S.tour.r[k].filter(v=>v!==null).length<tourParts(k).length/2)return k;return 3}
function tourMy(){if(!S.tour)return null;const k=tourRound();if(k>2)return null;const parts=tourParts(k),i=parts.indexOf('me');return i<0?null:{k,i,opp:parts[i^1]}}
function tourSim(k){const T=S.tour,parts=tourParts(k);for(let m=0;m<parts.length/2;m++)if(T.r[k][m]===null)T.r[k][m]=Math.random()<.5?parts[2*m]:parts[2*m+1]}
function tourResult(win){const my=tourMy();if(!my)return;const T=S.tour;T.r[my.k][my.i>>1]=win?'me':my.opp;tourSim(my.k);if(!win)for(let k=my.k+1;k<3;k++)tourSim(k);if(win&&my.k===2){toast('ჩემპიონი ხარ!');confetti()}store.set('tour',T)}
PG.tour={r(){const T=S.tour;let body;
 if(!T)body=`<section class="tourcard"><span class="tag" style="align-self:flex-start">კვირის ტურნირი</span><h3>ნარდის თასი</h3><p class="note">8 მოთამაშე, გამოთიშვის სისტემა: მეოთხედფინალი, ნახევარფინალი, ფინალი. ყოველი მოგება რეიტინგს და მონეტებს გმატებს.</p><button class="btn" data-a="tourreg" style="align-self:flex-start">რეგისტრაცია</button><p class="note">ამ ეტაპზე მეტოქეების მაგივრად ბოტები თამაშობენ. ცოცხალ მეგობართან თამაში ლობიდანაა შესაძლებელი.</p></section>`;
 else{const my=tourMy(),champ=T.r[2][0];const col=(k,title)=>{const parts=k===0?T.pl:T.r[k-1];let h=`<div class="bcol"><h4>${title}</h4>`;for(let m=0;m<4/2**k;m++){const a=parts[2*m],b=parts[2*m+1],w=T.r[k][m];h+=`<div class="bm">${[a,b].map(x=>`<div class="${x!=null&&w!=null?(x===w?'w':'l'):''}${x==='me'?' me':''}"><span>${x!=null?esc(tName(x)):'…'}</span>${x!=null&&w===x?'✓':''}</div>`).join('')}</div>`}return h+'</div>'};
  body=`<section class="tourcard"><h3>ნარდის თასი</h3>${champ!=null?`<p><b>${champ==='me'?'შენ მოიგე ტურნირი!':esc(tName(champ))+' გახდა ჩემპიონი.'}</b></p><button class="btn ghost" data-a="tourreset" style="align-self:flex-start">ახალი ტურნირი</button>`
  :my?`<p>შემდეგი მატჩი: <b>${esc(tName(my.opp))} (ბოტი)</b> · ${['მეოთხედფინალი','ნახევარფინალი','ფინალი'][my.k]}</p><button class="btn gold" data-a="tourplay" style="align-self:flex-start">მატჩის დაწყება</button>`
  :`<p>ამჯერად გამოეთიშე ტურნირს.</p><button class="btn ghost" data-a="tourreset" style="align-self:flex-start">ახალი ტურნირი</button>`}<div class="bwrap"><div class="bracket">${col(0,'მეოთხედფინალი')}${col(1,'ნახევარფინალი')}${col(2,'ფინალი')}</div></div></section>`}
 view.innerHTML=pgHead('ტურნირი')+`<div class="view-pad">${body}</div>`}};
A.tourreg=()=>{S.tour={pl:shuffle(['me',0,1,2,3,4,5,6]),r:[[null,null,null,null],[null,null],[null]]};store.set('tour',S.tour);rp();toast('დარეგისტრირდი')};
A.tourreset=()=>{S.tour=null;store.set('tour',null);rp()};
A.tourplay=()=>{const my=tourMy();if(!my)return;go('games');const b=BOTN[my.opp];startGame('nardi',{mode:'tour',names:{1:ME.name,'-1':b[0]+' (ბოტი)'},avs:{1:'me','-1':{n:b[0],h:b[1]}}})};

/* the lobby: a shelf of games (the last one played is the big poster), the cup, who is online, bot matches, top 10 */
const gPlaying=id=>NET.peers.filter(p=>p.st==='play'&&p.gt===id).length;
function gMeta(g){const n=gPlaying(g.id);return `<span class="gs-meta"><span>${g.pl} მოთამაშე, ${g.on?'ონლაინ':'ბოტებთან'}</span>${n?`<span class="on"><i></i>${n} თამაშობს</span>`:''}</span>`}
function gPic(g,big){return `<img class="gs-pic" src="${GART(g.id,big?1000:600)}" srcset="${GART(g.id,600)} 600w, ${GART(g.id,1000)} 1000w" sizes="${big?'(min-width:600px) 528px, 100vw':'(min-width:600px) 258px, 50vw'}" alt="" decoding="async"${big?'':' loading="lazy"'}>`}
function gShelf(){const last=store.get('glast',null),f=GAMES.find(g=>g.id===last)||GAMES[0];
 return `<div class="gs-shelf"><button class="gs-post big" data-a="play" data-g="${f.id}" style="--ac:${f.ac}" aria-label="${f.n}. ${f.d}">${gPic(f,1)}${last===f.id?'<small class="gs-last">ბოლოს ითამაშე</small>':''}<span class="gs-body"><b class="gs-name">${f.n}</b><span class="gs-desc">${f.d}</span><span class="gs-cta"><span class="btn gold">${ic('play')}ითამაშე</span>${gMeta(f)}</span></span></button>`
 +GAMES.filter(g=>g!==f).map(g=>`<button class="gs-post" data-a="play" data-g="${g.id}" style="--ac:${g.ac}" aria-label="${g.n}. ${g.d}">${gPic(g)}<span class="gs-body"><b class="gs-name">${g.n}</b>${gMeta(g)}</span></button>`).join('')+`</div>`}
function gLobbyLive(){const o=$('#gonl');if(o){o.hidden=!S.online.size;o.lastChild.textContent=S.online.size+' ონლაინ'}$$('.gs-post[data-g]').forEach(b=>{const g=GAMES.find(x=>x.id===b.dataset.g),m=g&&b.querySelector('.gs-meta');if(m)m.outerHTML=gMeta(g)})}
R.games=()=>{if(S.game&&GAME[S.game])return GAME[S.game].render();
 const tour=S.tour?(tourMy()?'შენი შემდეგი მატჩი გელოდება':'ნახე, როგორ დასრულდა'):'კვირის ტურნირი 8 მოთამაშეზე. რეგისტრაცია უფასოა';
 view.innerHTML=`<div class="view-pad gs-page"><header class="gs-head"><h2>სამაგიდო თამაშები</h2><div class="gs-chips"><span class="live" id="gonl"${S.online.size?'':' hidden'}><i></i>${S.online.size} ონლაინ</span><span class="gs-rt">${ic('trophy')}<span>შენი რეიტინგი <b>${ME.rating??1500}</b></span></span></div></header>
 ${gShelf()}
 <button class="gs-tour" data-a="page" data-p="tour"><span class="gs-medal">${ic('trophy')}</span><span class="grow"><b>ნარდის თასი</b><small>${tour}</small></span><span class="gs-chev">${ic('back')}</span></button>
 <section><h3 class="sec">ონლაინ ახლა</h3><div id="onl">${onlineHTML()}</div></section>
 <section><h3 class="sec">ბოტების პარტიები</h3><div class="livegames">${LIVEG.map((g,i)=>{const G=GAMES.find(x=>x.id===g.gt),A1=BOTN[g.a],B1=BOTN[g.b];return `<button class="lgcard" data-a="watch" data-i="${i}" style="--ac:${G.ac}"><span class="gs-mini"><img src="${GART(g.gt,600)}" alt="" loading="lazy" decoding="async"><em>${G.n}</em></span><span class="vsn"><span class="gs-avs">${avAny({n:A1[0],h:A1[1]},24)}${avAny({n:B1[0],h:B1[1]},24)}</span>${A1[0]} და ${B1[0]}</span><small>უყურე, როგორ თამაშობენ</small></button>`}).join('')}</div></section>
 <section><h3 class="sec">რეიტინგი, ტოპ 10</h3><div id="lb" class="gs-lb">${skel(2)}</div></section></div>`;
 q(sb.from('profiles').select('id,name,avatar_url,hue,rating,verified').eq('onboarded',true).order('rating',{ascending:false}).limit(10)).then(rows=>{rows.forEach(p=>PC.set(p.id,Object.assign(PC.get(p.id)||{},p)));const el=$('#lb');if(el)el.innerHTML=`<table class="lb"><tbody>${rows.map((r,i)=>`<tr${r.id===ME.id?' class="mine"':''}><td><span class="gs-rk${i<3?' r'+(i+1):''}">${i+1}</span></td><td><button class="lbn" data-a="user" data-u="${r.id}">${av(r,28)}${esc(r.name)}${vb(r)}</button></td><td>${r.rating}</td></tr>`).join('')}</tbody></table>`}).catch(()=>{})};

/* ---------- 3D boards, fullscreen, the game menu ----------
   the 3D code loads only when a game opens. without WebGL, or when the person picks the flat board, everything stays flat.
   the game screen always covers the app; the browser's own fullscreen is asked for too, where the browser allows it */
const G3W={p:null,ready:false,fail:false};
const g3Pref=()=>{const v=store.get('g3d',null);return v===null?!ECO():!!v};
const g3Can=()=>!G3W.fail&&!!window.WebGLRenderingContext;
const g3Want=()=>g3Pref()&&g3Can();
function g3On(){if(!g3Want())return false;if(G3W.ready)return true;g3Load();return false}
function g3Load(){if(G3W.p)return G3W.p;const v=(($('script[src*="/js/core.js"]')||{}).src||'').split('v=')[1]||'';
 const one=f=>new Promise((res,rej)=>{const s=document.createElement('script');s.src=`/js/${f}.js${v?'?v='+v:''}`;s.onload=res;s.onerror=rej;document.head.appendChild(s)});
 G3W.p=one('g3d').then(()=>one('g3d-art')).then(()=>one('g3d-games')).then(()=>{G3W.ready=typeof g3Init==='function'&&g3Init();if(!G3W.ready)G3W.fail=true;g3Redraw()},()=>{G3W.fail=true;G3W.p=null;g3Redraw()});return G3W.p}
function g3Redraw(){const on=g3Want();$$('[data-a="g3tog"]').forEach(b=>{b.classList.toggle('on',on);b.setAttribute('aria-pressed',String(on))});
 if(S.page){if(S.page.id==='jktable'&&typeof joDraw==='function')joDraw();return}const G=S.tab==='games'&&GAME[S.game];if(G)G.render()}
const g3Rv=()=>`<button class="g3rv" data-a="g3reset" aria-label="ხედის აღდგენა">${ic('turn')}</button>`;
const g3Board=(id,dom)=>g3Want()?`<div class="g3 g3-${id}${G3W.ready?'':' loading'}"><div class="g3sr">${dom}</div>${g3Rv()}${G3W.ready?'':'<span class="g3load" aria-hidden="true"></span>'}</div>`:dom;
function g3After(id){if(g3On()&&typeof g3Show==='function')g3Show(id)}
function g3Intro(id){if(typeof G3D!=='undefined')G3D.intro=id;else G3W.intro=id}
/* the browser's own fullscreen; where it is missing (iPhone) the game still covers the whole app */
const GFS={native:false};
function fsEnter(){const d=document.documentElement;if(!store.get('gfs',true)||document.fullscreenElement||!d.requestFullscreen)return;
 try{d.requestFullscreen({navigationUI:'hide'}).then(()=>{GFS.native=true;fsSync()},()=>{})}catch(e){}}
function fsExit(){const was=GFS.native;GFS.native=false;try{if(was&&document.fullscreenElement)document.exitFullscreen().catch(()=>{})}catch(e){}}
function fsSync(){const on=!!document.fullscreenElement;$$('[data-a="gfull"]').forEach(b=>{b.setAttribute('aria-pressed',String(on));const s=b.querySelector('.sw');if(s)s.classList.toggle('on',on);else b.innerHTML=ic(on?'unfull':'full')})}
document.addEventListener('fullscreenchange',()=>{if(!document.fullscreenElement)GFS.native=false;fsSync();setTimeout(()=>{if(typeof G3D!=='undefined'&&G3D.sc)g3Need()},60)});
{const sm=stopMedia;stopMedia=function(){sm();if(GFS.native&&S.game)fsExit()}}
A.gfull=()=>{if(document.fullscreenElement){store.set('gfs',false);fsExit();GFS.native=false;try{document.exitFullscreen().catch(()=>{})}catch(e){}}else{store.set('gfs',true);fsEnter()}};
A.g3tog=t=>{const on=!g3Want();store.set('g3d',on);if(on&&!g3Can()){toast('ამ მოწყობილობაზე 3D დაფა ვერ ჩაირთო');return}const b=t&&t.closest&&t.closest('button'),s=b&&b.querySelector('.sw');if(s)s.classList.toggle('on',on);else toast(on?'3D დაფა':'ბრტყელი დაფა');g3Redraw()};
const gTools=()=>{const on=g3Want(),fs=!!document.fullscreenElement;return `<button class="ibtn g3tg${on?' on':''}" data-a="g3tog" aria-pressed="${on}" aria-label="3D დაფა">${ic('cube')}</button><button class="ibtn" data-a="gfull" aria-pressed="${fs}" aria-label="სრული ეკრანი">${ic(fs?'unfull':'full')}</button><button class="ibtn" data-a="gmenu" aria-label="მენიუ">${ic('more')}</button>`};
/* the game menu: board, screen, sound, rules, a new game, resign, leave */
const GRULES={
 chess:'კლასიკური ჭადრაკი. მეფეს ქიშიდან უნდა გაიყვანო; როქი შესაძლებელია, თუ მეფე და ეტლი ჯერ არ დაძრულან და გზა ცარიელი და დაუცველია. გავლით აღება მხოლოდ მომდევნო სვლაზეა. ბოლო ხაზამდე მისული პაიკი შენს არჩეულ ფიგურად იქცევა. მატი იგებს. ფრეა პატი, სამჯერ განმეორებული პოზიცია, 50 სვლა აყვანისა და პაიკის სვლის გარეშე და მატისთვის არასაკმარისი ფიგურები. ფიგურის გადასატანად შეეხე მას და შემდეგ უჯრას, ან უბრალოდ გადაათრიე.',
 shashi:'რუსული შაში. ქვა წინ, დიაგონალზე დადის, ჭრა კი წინაც შეუძლია და უკანაც. ჭრა სავალდებულოა და ზედიზედ გრძელდება; მოჭრილი ქვები სვლის ბოლოს იხსნება და ერთ ქვას ორჯერ ვერ მოჭრი. ბოლო ხაზამდე მისული ქვა დამა ხდება და, თუ ჭრა გრძელდება, უკვე დამასავით აგრძელებს. დამა მთელ დიაგონალზე დადის და მოჭრის შემდეგ იქ უნდა დაჯდეს, საიდანაც ჭრას გააგრძელებს. იგებს ის, ვინც მეტოქეს ქვებს მოუჭრის ან სვლას წაართმევს. ფრეა სამჯერადი გამეორება, 15 სვლა მხოლოდ დამებით და სამი დამა ერთის წინააღმდეგ 15 სვლაში.',
 nardi:'ტავლა. პირველ სვლას კამათლის გაგორებით ირჩევენ: ვისაც მეტი მოუვა, ის იწყებს და ორივე რიცხვს თამაშობს. ქვები 24-დან 1-ისკენ მოძრაობს. ორივე კამათლის გამოყენება სავალდებულოა; თუ მხოლოდ ერთი გამოდის, უფრო დიდი უნდა ითამაშო. წყვილი ოთხ სვლას იძლევა. ორი ან მეტი ქვა პუნქტს კეტავს, მარტოხელა ქვა იჭრება და ზარზე გადადის, ზარიდან კი ჯერ უნდა შემოიყვანო. როცა ყველა ქვა სახლშია, იწყებ გატანას. ვინც პირველი გაიტანს 15 ქვას, იგებს; თუ მეტოქეს ერთიც არ გაუტანია, მარსია (ორმაგი), თუ ქვა ზარზე ან შენს სახლშიც უდგას, კოქსი (სამმაგი).',
 domino:'ოთხი მოთამაშე, ორ-ორი გუნდში: შენ და ანა გიორგისა და ლევანის წინააღმდეგ. თითოეულს 7 ქვა აქვს, საბაზრო არ არის. პირველ ხელს ის იწყებს, ვისაც ექვს-ექვსი აქვს, შემდეგ ხელებს წინა ხელის გამარჯვებული. ქვა ერთ-ერთ ღია ბოლოს უნდა მიუდო; თუ შესაფერისი არ გაქვს, პასობ. გუნდი, რომლის მოთამაშეც პირველი დაცლის ხელს, იღებს მეტოქეების ქვებზე დარჩენილ ქულებს. თუ თამაში ჩაიკეტა, იგებს გუნდი, რომელსაც ნაკლები ქულა დარჩა. თამაში 101 ქულამდეა. ქვა შეგიძლია მაგიდაზე გადაათრიო.'};
const gCur=()=>S.page&&S.page.id==='jktable'?'joker':S.game;
A.gmenu=()=>{const id=gCur(),G=GAME[id],c=G&&G.ctx,sw=on=>`<i class="sw${on?' on':''}" aria-hidden="true"></i>`,rules=id==='joker'?JK_RULES:GRULES[id]||'';
 navMark('gmenu',()=>A.gmenu());
 sheet(head('თამაში')+`<div class="gmenu">
  <button data-a="g3tog" aria-pressed="${g3Want()}">${ic('cube')}<span>3D დაფა</span>${sw(g3Want())}</button>
  <button data-a="gfull" aria-pressed="${!!document.fullscreenElement}">${ic('full')}<span>სრული ეკრანი</span>${sw(!!document.fullscreenElement)}</button>
  <button data-a="gsnd" aria-pressed="${GS.on}">${ic('mic')}<span>ხმა და ვიბრაცია</span>${sw(GS.on)}</button>
  ${rules?'<button data-a="grules">'+ic('book')+'<span>წესები</span></button>':''}
  ${c&&c.mode==='bot'&&!S.page?'<button data-a="restart">'+ic('turn')+'<span>ახალი პარტია</span></button>':''}
  ${G&&G.resign&&canResign(G)&&!S.page?'<button data-a="gresign">'+ic('flag')+'<span>დანებება</span></button>':''}
  <button data-a="${S.page?'back':'lobby'}">${ic('back')}<span>${S.page?'მაგიდიდან გასვლა':'ლობიში გასვლა'}</span></button></div>`,'short')};
A.grules=()=>{const id=gCur(),rules=id==='joker'?JK_RULES:GRULES[id]||'';sheet(head('წესები')+`<div class="ph-body"><p class="grules">${rules}</p></div>`,'short')};
