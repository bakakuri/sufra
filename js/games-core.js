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
/* games against the computer are kept on the phone and go on where they stopped (two weeks at most) */
const GSV='gs:';
function gSaveLater(G){const c=G&&G.ctx;if(!c||c.mode!=='bot'||!c.gk)return;clearTimeout(G.svT);G.svT=setTimeout(()=>{try{const over=G.res&&G.res(),s=over?null:(G.save?G.save():G.snap());store.set(GSV+c.gk,s==null?null:{t:Date.now(),s})}catch(e){}},300)}
const gSaved=id=>{const v=store.get(GSV+id,null);return v&&v.s&&Date.now()-v.t<14*864e5?v:null};
const gUnsave=id=>store.set(GSV+id,null);
function startGame(id,ctx,sv){const G=GAME[id],fresh=!S.game;if(fresh&&(!ctx||ctx.mode!=='watch')&&GAMES.some(g=>g.id===id))store.set('glast',id);S.game=id;G.ctx=Object.assign({mode:'bot',side:1,names:{1:ME.name,'-1':'სუფრა ბოტი'},avs:{1:'me','-1':BOT},seq:0,gk:id},ctx||{});
 G.resHide=0;G.resSnd=0;G.wasMine=false;G.start();if(sv){try{G.restore?G.restore(sv.s):G.load(sv.s);if(G.ctx.gk==='chess'&&G.st){G.mv=[];G.ps=G.st;G.full=false}}catch(e){gUnsave(id)}}view.scrollTop=0;if(fresh){fsEnter();g3Intro(id)}G.render();if(G.kick)G.kick();if(fresh)navOpen('game')}
const isPlayer=c=>c.mode==='bot'||c.mode==='online'||c.mode==='tour';
/* under the name: a small disc in the player's colour (side 1 plays white in every two-player game), then rating or connection */
function plSub(c,s){const col=`<i class="pc ${s===1?'w':'b'}"></i>`,cn=s===1?'თეთრები':'შავები';if(c.mode==='watch'||c.mode==='netwatch')return col+cn;if(s===c.side)return col+'რეიტინგი '+myRating(c.gk);return col+(c.mode==='online'?(c.gone?'გავიდა':'ონლაინ'):cn+(c.gk&&(c.mode==='bot'||c.mode==='tour')?', '+BLV[bLvl(c.gk)].n.toLowerCase():''))}
/* my rating in one game (online games only change it) */
const MYR={};const myRating=g=>MYR[g]??1500;
const gTag=c=>(c.wn&&c.mode!=='netwatch'?`<span class="gtag gw" title="უყურებენ">${ic('eye')}${c.wn}</span>`:'')+gTag0(c);
const gTag0=c=>c.mode==='online'?'<span class="gtag">ონლაინ</span>':c.mode==='tour'?'<span class="gtag">ტურნირი</span>':c.mode==='watch'||c.mode==='netwatch'?'<span class="gtag">ყურება</span>':'';
const gTop=(t,c,back='lobby')=>`<div class="gtop"><button class="ibtn gb" data-a="${back}" aria-label="თამაშიდან გასვლა">${ic('back')}</button><h2>${t}</h2>${c?gTag(c):''}<span class="sp"></span>${gTools()}</div>`;
/* the game screen: the board fills the screen, the players and controls float over it */
function gShellParts(o){const w=g3Want()&&!o.center;return{w,html:`${w?`<div class="gstage">${o.stage||''}</div>`:''}<div class="ghud top">${o.top||''}</div><div class="gmid">${o.center||(w?'':o.mid||'')}</div><div class="ghud bot">${o.bot||''}</div>${o.res||''}`}}
function gShell(id,o){const P=gShellParts(o);return `<div class="view-pad game gx${P.w?' is3d':''}" data-g="${id}">${P.html}</div>`}
/* a player's plate. while it is their move a gold ring turns around the avatar; an opponent who is thinking shows three dots */
const plThink='<span class="think" aria-label="ფიქრობს"><i></i><i></i><i></i></span>';
const plCard=(c,s,turn,plx)=>{const k=c.clk,v=k?clkLeft(c,s):0;return `<div class="pl${s===c.side?' me':''}${turn?' turn':''}" data-side="${s}"><span class="plav${k?' pclk':''}"${k?` style="--ck:${clkFrac(c,v)}"`:''}>${avAny(c.avs[s],34)}</span><span class="pln"><b>${esc(c.names[s])}${turn&&!(s===c.side&&isPlayer(c))?plThink:''}</b><span class="muted">${plSub(c,s)}</span></span>${k?`<span class="gclk${turn&&k.n>=1&&!c.finished?' run':''}${v<3e4?' low':''}" data-clk="${s}" role="timer" aria-label="დარჩენილი დრო">${clkFmt(v)}</span>`:''}${plx?plx(s):''}</div>`};
/* the online clock: each player has a bank of minutes that runs only on their move and gets a few seconds back after each move.
   the first move of the game is free. each phone keeps its own clock and sends what is left with the move;
   whoever's clock runs out loses on time (the other phone waits a moment longer for a move still on its way) */
const GCLK={chess:[600,5],shashi:[600,5],nardi:[420,8]};
function clkInit(c){const tc=GCLK[c.gk];if(!tc||c.mode!=='online')return;c.clk={t:{1:tc[0]*1e3,'-1':tc[0]*1e3},base:tc[0]*1e3,inc:tc[1]*1e3,turn:null,at:0,n:0};if(!clkTick.iv)clkTick.iv=setInterval(clkTick,500)}
const clkLeft=(c,s)=>{const k=c.clk;if(!k)return 0;let v=k.t[s];if(k.turn===s&&k.n>=1&&!c.finished)v-=Date.now()-k.at;return Math.max(0,v)};
const clkFrac=(c,v)=>Math.max(0,Math.min(1,v/c.clk.base)).toFixed(3);
const clkFmt=v=>{const t=Math.ceil(v/1e3);return v<1e4?(v/1e3).toFixed(1):Math.floor(t/60)+':'+String(t%60).padStart(2,'0')};
function clkTurn(G){const c=G.ctx,k=c&&c.clk;if(!k||c.finished)return;const ts=G.turnSide?G.turnSide():null,now=Date.now();if(ts===k.turn)return;
 if(k.turn!=null){if(k.n>=1)k.t[k.turn]=Math.max(0,k.t[k.turn]-(now-k.at))+k.inc;k.n++}k.turn=ts;k.at=now}
function clkTick(){const G=S.game&&GAME[S.game],c=G&&G.ctx,k=c&&c.clk;if(!k||c.finished||S.tab!=='games'||S.page)return;
 for(const s of[1,-1]){const v=clkLeft(c,s),el=$(`[data-clk="${s}"]`,view),pv=$(`.pl[data-side="${s}"] .plav`,view);if(el){el.textContent=clkFmt(v);el.classList.toggle('low',v<3e4)}if(pv)pv.style.setProperty('--ck',clkFrac(c,v))}
 if(k.turn==null||k.n<1||c.syncing)return;const over=Date.now()-k.at-k.t[k.turn];
 if(over>=0&&k.turn===c.side&&G.resign)G.resign(c.side,'time');else if(over>2500&&k.turn===-c.side&&G.resign)G.resign(-c.side,'time')}
function gview(id,title,board,status,extra='',plx=null,topx=''){if(S.tab!=='games'||S.game!==id||S.page)return;const G=GAME[id],c=G.ctx,ts=G.turnSide?G.turnSide():null,mine=!!(G.mine&&G.mine());gTurnSnd(G,mine);
 view.innerHTML=gShell(id,{stage:board,mid:board,top:gTop(title,c)+plCard(c,-c.side,ts===-c.side,plx)+topx,bot:plCard(c,c.side,ts===c.side,plx)+`<div class="status${mine?' mine':''}" role="status">${status}</div>${extra}`,res:gResHTML(G)});gSaveLater(G)}
/* a chime when the turn comes to you */
function gTurnSnd(G,mine){if(mine&&!G.wasMine&&typeof gSnd==='function'){gSnd('turn');gBuzz(12)}G.wasMine=mine}
/* the end of a game: a card over the board with the result and what to do next */
const RESWHY={gone:'მეტოქე გავიდა',time:'დრო ამოიწურა',mate:'მატი',stale:'პატი',rep:'პოზიცია სამჯერ განმეორდა',mat:'მატისთვის საკმარისი ფიგურები აღარ დარჩა','50':'50 სვლა აყვანისა და პაიკის სვლის გარეშე',resign:'დანებება',blocked:'სვლა აღარ დარჩა',kings:'15 სვლა მხოლოდ დამებით',k31:'სამმა დამამ ერთი ვერ აიყვანა'};
function gResBox(G,{title,sub,kind,more='',again='',share='',leave='<button class="btn ghost" data-a="lobby">ლობი</button>'}){if(G.resHide)return '';if(!G.resSnd&&typeof gSnd==='function'){G.resSnd=1;setTimeout(()=>gSnd(kind==='win'?'win':kind==='draw'?'draw':'lose'),250)}
 return `<div class="gend ${kind}" role="dialog" aria-label="${esc(title)}"><div class="gendc"><span class="gendi">${ic(kind==='win'?'trophy':kind==='draw'?'flag':'chess')}</span><h2>${title}</h2>${sub?`<p>${sub}</p>`:''}${more}
  <div class="gendb">${again}${share}<button class="btn ghost" data-a="gresx">დაფის ნახვა</button>${leave}</div></div></div>`}
function gResHTML(G){const r=G.res&&G.res();if(!r)return '';const c=G.ctx,me=isPlayer(c),draw=r.w===2,win=me&&!draw&&r.w===c.side;
 const title=draw?'ფრე':!me?esc(c.names[r.w])+' მოიგო':win?'მოიგე!':'წააგე';
 let sub=r.why==='resign'?(me?(win?'მეტოქე დანებდა':'დანებდი'):esc(c.names[-r.w])+' დანებდა'):r.why==='time'&&me?(win?'მეტოქეს დრო ამოეწურა':'დრო ამოგეწურა'):RESWHY[r.why]||'';if(r.mult>1)sub=(sub?sub+' · ':'')+MULT[r.mult];if(c.gone&&!sub)sub='მეტოქე გავიდა';
 const more=(me?gEloHTML(c):'')+gRemHTML(c);
 const again=c.mode==='bot'?'<button class="btn gold" data-a="restart">ახალი პარტია</button>':c.mode==='tour'&&c.finished?'<button class="btn gold" data-a="page" data-p="tour">ტურნირზე</button>':c.mode==='online'&&!c.gone&&c.finished?`<button class="btn gold" data-a="grem"${c.remSent&&!c.remIn?' disabled':''}>${ic('turn')}${c.remIn?'რევანში, თანახმა ვარ':'რევანში'}</button>`:'';
 const share=win?gShareBtn(G.ctx.gk||S.game,c.mode==='online'?'მეტოქე: '+c.names[-c.side]:c.mode==='tour'?'ნარდის თასი':'ბოტთან, „'+BLV[bLvl(c.gk||S.game)].n+'“ დონე'):'';
 return gResBox(G,{title,sub,kind:draw?'draw':win||!me?'win':'lose',more,again,share})}
A.gresx=()=>{if(S.page&&S.page.id==='jktable'){JO.resHide=1;joDraw();return}const G=GAME[S.game];if(G){G.resHide=1;G.render()}};
function endMsg(c,w){if(w===2)return 'ფრე';if(!isPlayer(c))return esc(c.names[w])+' მოიგო';return w===c.side?'მოიგე!':esc(c.names[w])+' მოიგო. სცადე ისევ'}
const tourBack=c=>c.mode==='tour'&&c.finished?'<button class="btn" data-a="page" data-p="tour" style="align-self:flex-start">ტურნირზე დაბრუნება</button>':'';
async function gameResult(game,win){try{const before=ME.rating??1500,r=await rpc('game_result',{p_game:game,p_win:win});r.dr=(r.rating??before)-before;ME.rating=r.rating??ME.rating;setCoins(r.coins);
 if(win){const t=[r.dr?(r.dr>0?'+':'')+r.dr+' რეიტინგი':'',r.reward?'+'+r.reward+' მონეტა':''].filter(Boolean).join(', ');toast('მოიგე!'+(t?' '+t:''));confetti()}return r}catch(e){return null}}
/* online games: both phones say the game began and how it ended; the server checks that they agree and moves the ratings (when it can: until then the old result counts) */
function gMeet(c){if(c.mode!=='online'||!c.opp||!okGid(c.gid)||!['nardi','shashi','chess'].includes(c.gk))return;rpc('match_meet',{p_gid:c.gid,p_game:c.gk,p_opp:c.opp,p_side:c.side}).then(r=>{c.mid=r&&r.id;c.rated=!!(r&&r.rated);if(!c.mid)c.noElo=1;if(c.repW!=null)gReport(GAME[c.gk],c.repW)}).catch(()=>{c.noElo=1;if(c.repW!=null)gReport(GAME[c.gk],c.repW)})}
function gReport(G,w){const c=G&&G.ctx;if(!c)return;if(!c.mid&&!c.noElo){c.repW=w;return}c.repW=null;
 if(c.mid){rpc('match_report',{p_gid:c.gid,p_res:w}).then(r=>{c.elo=r||{};if(r&&!r.pending&&r.rating){MYR[c.gk]=r.rating;ME.rating=Math.max(ME.rating||0,r.rating)}if(r&&!r.pending&&r.delta>0)toast(`+${r.delta} რეიტინგი`);if(w===c.side)confetti();if(G.ctx===c)G.render()}).catch(()=>{c.elo={err:1};if(G.ctx===c)G.render()});return}
 if(w!==2)gameResult(c.gk,w===c.side).then(r=>{c.gres=r;if(G.ctx===c)G.render()})}
function gEloHTML(c){if(c.mode==='online'&&c.mid){const e=c.elo;const t=!e?'რეიტინგი ითვლება…':e.err?'რეიტინგი ვერ დაითვალა':e.pending?'რეიტინგი მეტოქის დადასტურების შემდეგ':!e.rated?'ეს პარტია რეიტინგში არ ითვლება':`${e.delta>0?'+':''}${e.delta} რეიტინგი · ${e.rating}`;return `<span class="gendd">${t}</span>`}
 const r=c.gres;if(!r)return '';const t=[r.dr?(r.dr>0?'+':'')+r.dr+' რეიტინგი':'',r.reward?'+'+r.reward+' მონეტა':''].filter(Boolean).join(' · ');return t?`<span class="gendd">${t}</span>`:''}
function finish(G,w){const c=G.ctx;if(c.finished)return;c.finished=1;if(c.mode==='bot'&&c.gk)gUnsave(c.gk);if((c.mode==='bot'||c.mode==='tour')&&Math.random()<.6){const id=S.game;setTimeout(()=>{if(S.game===id&&G.ctx===c)gRxShow(-c.side,5)},1400)}if(c.mode==='online')gReport(G,w);else if(isPlayer(c)&&w!==2){const win=w===c.side;gameResult(c.gk||G.title,win).then(r=>{c.gres=r;if(G.ctx===c)G.render()});if(c.mode==='tour')tourResult(win)}G.render()}
A.play=t=>{const g=GAMES.find(x=>x.id===t.dataset.g);if(g.soon||!GAME[g.id]){toast(g.n+' მალე დაემატება');return}const sv=gSaved(g.id);startGame(g.id,null,sv);if(sv)toast('პარტია გაგრძელდა იქიდან, სადაც შეჩერდი')};
A.lobby=()=>{closeSheet();fsExit();navKill('game');const G=GAME[S.game];if(G&&G.ctx&&G.ctx.mode==='online'&&!G.ctx.finished&&!G.ctx.gone&&G.ctx.mid&&G.ctx.seq>=3){rpc('match_report',{p_gid:G.ctx.gid,p_res:-G.ctx.side}).catch(()=>{});toast('პარტია დატოვე. მოგება მეტოქეს ჩაეთვალა')}if(G){if(G.ctx&&G.ctx.gr)netLeave();G.ctx={mode:'dead',side:1,names:{},avs:{}};G.tk=(G.tk||0)+1}S.game=null;R.games()};
A.restart=()=>{const G=GAME[S.game];if(!G)return;closeSheet();gUnsave(S.game);G.resHide=0;G.resSnd=0;if(S.game==='joker'){G.start();G.render();return}startGame(S.game,{mode:'bot',names:G.ctx.names,avs:G.ctx.avs})};
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
function onAcc(d){const p=NET.pending;if(!d||d.to!==ME.id||!p||d.gid!==p.gid)return;NET.pending=null;if(S.openConv)closeSheet();const peer=NET.peers.find(x=>x.id===d.from);joinGame(p.gid,p.gt,1,{nm:String(peer?.nm||pname(d.from)).slice(0,40),hu:peer?.hu,id:d.from},d.from,false).catch(()=>toast('დაკავშირება ვერ მოხერხდა'))}
function onDecl(d){if(!d||d.to!==ME.id||!NET.pending||d.gid!==NET.pending.gid)return;NET.pending=null;toast('გამოწვევაზე უარი მიიღე')}
A.netwatch=t=>{const p=NET.peers.find(x=>x.id===t.dataset.u);if(!p||!okGid(p.g)||!GAMES.find(x=>x.id===p.gt&&x.net))return;joinGame(p.g,p.gt,1,{a:String(p.nm).slice(0,40),b:String(p.vs||'მოთამაშე').slice(0,40)},null,true).catch(()=>toast('ყურება ვერ დაიწყო'))};
async function joinGame(gid,gt,side,opp,oppId,watch){netLeave();const G=GAME[gt];
 const names=watch?{1:opp.a,'-1':opp.b}:{[side]:ME.name,[-side]:opp.nm},avs=watch?{1:{n:opp.a,h:200},'-1':{n:opp.b,h:20}}:{[side]:'me',[-side]:oppId?Object.assign({},prof(oppId),{name:opp.nm}):{n:opp.nm,h:opp.hu}};
 const ch=sb.channel('game-'+gid,{config:{presence:{key:ME.id},broadcast:{self:false}}});
 const ctx={mode:watch?'netwatch':'online',side:watch?1:side,names,avs,gid,opp:oppId,seq:0,gk:gt,syncing:watch||side===-1,gr:{ch,emit:(ev,p)=>ch.send({type:'broadcast',event:ev,payload:p})}};clkInit(ctx);
 if(S.page)S.page=null;if(S.tab!=='games'){S.tab='games';$$('.tab').forEach(b=>b.setAttribute('aria-current',String(b.dataset.tab==='games')));view.className='';$('#app').classList.remove('media');moveInd('games')}
 {const fresh=!S.game;S.game=gt;G.ctx=ctx;G.start();NET.gr=ctx.gr;if(fresh)navOpen('game')}
 ch.on('broadcast',{event:'rx'},({payload:d})=>{if(G.ctx!==ctx||!d||!GRX[+d.i]||Date.now()-(ctx.rxAt||0)<900)return;ctx.rxAt=Date.now();const s=+d.s;if(ctx.mode==='netwatch'?(s===1||s===-1):s===-ctx.side)gRxShow(s,+d.i)})
  .on('broadcast',{event:'rem'},({payload:d})=>{if(G.ctx!==ctx||!d||!okGid(d.gid)||!ctx.finished||ctx.mode!=='online')return;if(ctx.remSent){gRematch(G,ctx.remSent<d.gid?ctx.remSent:d.gid);return}ctx.remIn=d.gid;G.resHide=0;G.render();if(typeof gSnd==='function')gSnd('turn')})
  .on('broadcast',{event:'remok'},({payload:d})=>{if(G.ctx===ctx&&d&&d.gid===ctx.remSent)gRematch(G,d.gid)})
  .on('presence',{event:'sync'},()=>{if(G.ctx!==ctx)return;let n=0,lk=null;try{const st=ch.presenceState();for(const k in st){if((st[k]||[]).some(x=>x&&x.w))n++;if(oppId&&k===oppId){const e=(st[k]||[]).find(x=>x&&x.lk);if(e)lk=lkClean(e.lk)}}}catch(e){}
   const lkc=JSON.stringify(lk)!==JSON.stringify(ctx.olk||null);if(lk)ctx.olk=lk;if(n!==(ctx.wn||0)||lkc){ctx.wn=n;G.render()}});
 ch.on('broadcast',{event:'st'},({payload:d})=>{if(G.ctx!==ctx||!d||typeof d!=='object'||!(Number(d.seq)>ctx.seq)||!d.s)return;try{G.load(d.s);ctx.seq=Number(d.seq);ctx.syncing=false;
   if(ctx.clk){const k=ctx.clk,o=-ctx.side,ck=d.ck;if(ck&&typeof ck==='object'){if(Number(ck.n)>k.n)k.n=Number(ck.n);if(Number.isFinite(+ck[o]))k.t[o]=Math.max(0,Math.min(k.base*3,+ck[o]))}clkTurn(G);if(ck&&Number.isFinite(+ck[o]))k.t[o]=Math.max(0,Math.min(k.base*3,+ck[o]))}
   G.render();if(G.checkEnd)G.checkEnd()}catch(e){}})
  .on('broadcast',{event:'need'},()=>{if(G.ctx===ctx&&ctx.mode==='online'&&side===1)netSend()})
  .on('broadcast',{event:'bye'},({payload:d})=>{if(G.ctx===ctx&&d&&d.from===oppId){ctx.gone=1;ctx.bye=1;gGone(G,ctx,4000);G.render()}})
  .on('presence',{event:'leave'},({key})=>{if(G.ctx===ctx&&oppId&&key===oppId&&!ctx.finished){ctx.gone=1;gGone(G,ctx,60000);if(ctx.mode==='online')toast('მეტოქე გავიდა. თუ წუთში არ დაბრუნდება, მოგება შენ ჩაგეთვლება');G.render()}})
  .on('presence',{event:'join'},({key})=>{if(G.ctx===ctx&&oppId&&key===oppId&&ctx.gone&&!ctx.bye&&!ctx.finished){ctx.gone=0;clearTimeout(ctx.goneT);G.render()}})
  .subscribe(st=>{if(st!=='SUBSCRIBED')return;ch.track(watch?{w:1}:{w:0,lk:myLook()});if(!watch&&!ctx.met){ctx.met=1;gMeet(ctx)}if(watch||side===-1)ctx.gr.emit('need',{});else netSend()});
 NET.state={st:watch?'watch':'play',gt,g:gid,vs:watch?null:String(opp.nm).slice(0,40)};netPresence();view.scrollTop=0;G.render()}
function netSend(){const G=GAME[S.game];if(!G||!G.ctx||G.ctx.mode!=='online'||!G.ctx.gr)return;const c=G.ctx;clkTurn(G);c.seq++;const k=c.clk;c.gr.emit('st',Object.assign({seq:c.seq,s:G.snap()},k?{ck:{[c.side]:Math.round(k.t[c.side]),n:k.n}}:{}))}
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
 if(!T)body=`<section class="tourcard"><span class="tag" style="align-self:flex-start">კვირის ტურნირი</span><h3>ნარდის თასი</h3><p class="note">8 მოთამაშე, გამოთიშვის სისტემა: მეოთხედფინალი, ნახევარფინალი, ფინალი. ყოველი მოგება მონეტებს გმატებს.</p><button class="btn" data-a="tourreg" style="align-self:flex-start">რეგისტრაცია</button><p class="note">ამ ეტაპზე მეტოქეების მაგივრად ბოტები თამაშობენ. ცოცხალ მეგობართან თამაში ლობიდანაა შესაძლებელი.</p></section>`;
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
 return `<div class="gs-shelf"><button class="gs-post big" data-a="play" data-g="${f.id}" style="--ac:${f.ac}" aria-label="${f.n}. ${f.d}">${gPic(f,1)}${gSaved(f.id)?'<small class="gs-last">გააგრძელე პარტია</small>':last===f.id?'<small class="gs-last">ბოლოს ითამაშე</small>':''}<span class="gs-body"><b class="gs-name">${f.n}</b><span class="gs-desc">${f.d}</span><span class="gs-cta"><span class="btn gold">${ic('play')}ითამაშე</span>${gMeta(f)}</span></span></button>`
 +GAMES.filter(g=>g!==f).map(g=>`<button class="gs-post" data-a="play" data-g="${g.id}" style="--ac:${g.ac}" aria-label="${g.n}. ${g.d}">${gPic(g)}${gSaved(g.id)?'<small class="gs-last">გააგრძელე</small>':''}<span class="gs-body"><b class="gs-name">${g.n}</b>${gMeta(g)}</span></button>`).join('')+`</div>`}
function gLobbyLive(){const lv=$('#glive');if(lv){const n=gLiveList().length;lv.hidden=!n;if(n)lv.lastChild.innerHTML=gLiveHTML()}const o=$('#gonl');if(o){o.hidden=!S.online.size;o.lastChild.textContent=S.online.size+' ონლაინ'}$$('.gs-post[data-g]').forEach(b=>{const g=GAMES.find(x=>x.id===b.dataset.g),m=g&&b.querySelector('.gs-meta');if(m)m.outerHTML=gMeta(g)})}
R.games=()=>{if(S.game&&GAME[S.game])return GAME[S.game].render();
 const tour=S.tour?(tourMy()?'შენი შემდეგი მატჩი გელოდება':'ნახე, როგორ დასრულდა'):'კვირის ტურნირი 8 მოთამაშეზე. რეგისტრაცია უფასოა';
 view.innerHTML=`<div class="view-pad gs-page"><header class="gs-head"><h2>სამაგიდო თამაშები</h2><div class="gs-chips"><span class="live" id="gonl"${S.online.size?'':' hidden'}><i></i>${S.online.size} ონლაინ</span><span class="gs-rt" id="gmyr">${gMyRtHTML()}</span><button class="gs-lk" data-a="glook">${ic('user')}პერსონაჟი</button></div></header>
 ${gShelf()}
 <button class="gs-tour" data-a="page" data-p="tour"><span class="gs-medal">${ic('trophy')}</span><span class="grow"><b>ნარდის თასი</b><small>${tour}</small></span><span class="gs-chev">${ic('back')}</span></button>
 <section><h3 class="sec">ონლაინ ახლა</h3><div id="onl">${onlineHTML()}</div></section>
 <section id="glive"${gLiveList().length?'':' hidden'}><h3 class="sec">ახლა თამაშობენ</h3><div class="livegames">${gLiveHTML()}</div></section>
 <section><h3 class="sec">ბოტების პარტიები</h3><div class="livegames">${LIVEG.map((g,i)=>{const G=GAMES.find(x=>x.id===g.gt),A1=BOTN[g.a],B1=BOTN[g.b];return `<button class="lgcard" data-a="watch" data-i="${i}" style="--ac:${G.ac}"><span class="gs-mini"><img src="${GART(g.gt,600)}" alt="" loading="lazy" decoding="async"><em>${G.n}</em></span><span class="vsn"><span class="gs-avs">${avAny({n:A1[0],h:A1[1]},24)}${avAny({n:B1[0],h:B1[1]},24)}</span>${A1[0]} და ${B1[0]}</span><small>უყურე, როგორ თამაშობენ</small></button>`}).join('')}</div></section>
 <section class="gs-lbs"><h3 class="sec">რეიტინგი</h3><div id="lbc">${gLbCtl()}</div><div id="lb" class="gs-lb">${skel(2)}</div></section></div>`;
 gLbLoad();gMyRtLoad();if(Date.now()-(gMyRtLoad.st||0)>6e4){gMyRtLoad.st=Date.now();rpc('match_settle_mine').then(n=>{if(n)gMyRtLoad()}).catch(()=>{})}};

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
const gTools=()=>{const on=g3Want(),fs=!!document.fullscreenElement,rx=S.page&&S.page.id==='jktable'||gRxCan();return `${rx?`<button class="ibtn grxb" data-a="grx" aria-label="რეაქცია">${ic('smile')}</button>`:''}<button class="ibtn g3tg${on?' on':''}" data-a="g3tog" aria-pressed="${on}" aria-label="3D დაფა">${ic('cube')}</button><button class="ibtn" data-a="gfull" aria-pressed="${fs}" aria-label="სრული ეკრანი">${ic(fs?'unfull':'full')}</button><button class="ibtn" data-a="gmenu" aria-label="მენიუ">${ic('more')}</button>`};
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
  ${g3Want()?`<button data-a="gqual">${ic('gear')}<span>გრაფიკა</span><small class="gmv">${GQN[gqSet()]}${gqSet()==='auto'?', '+GQN[gqLevel()].toLowerCase():''}</small></button>`:''}
  ${c&&c.mode==='bot'&&!S.page?`<button data-a="gbot">${ic('user')}<span>ბოტის დონე</span><small class="gmv">${BLV[bLvl(id)].n}</small></button>`:''}
  ${g3Want()&&['chess','shashi','nardi'].includes(id)?`<button data-a="gppl" aria-pressed="${gPplOn()}">${ic('users')}<span>მეტოქე მაგიდასთან</span>${sw(gPplOn())}</button>`:''}
  ${id==='joker'?`<button data-a="gc4" aria-pressed="${c4On()}">${ic('cards')}<span>ოთხფერიანი დასტა</span>${sw(c4On())}</button>`:''}
  ${id==='joker'&&c&&c.mode==='bot'&&!S.page?`<button data-a="ghint" aria-pressed="${jHintOn()}">${ic('help')}<span>ნათქვამის რჩევა</span>${sw(jHintOn())}</button>`:''}
  ${rules?'<button data-a="grules">'+ic('book')+'<span>წესები</span></button>':''}
  ${c&&c.mode==='bot'&&!S.page?'<button data-a="restart">'+ic('turn')+'<span>ახალი პარტია</span></button>':''}
  ${G&&G.resign&&canResign(G)&&!S.page?'<button data-a="gresign">'+ic('flag')+'<span>დანებება</span></button>':''}
  <button data-a="${S.page?'back':'lobby'}">${ic('back')}<span>${S.page?'მაგიდიდან გასვლა':'ლობიში გასვლა'}</span></button></div>`,'short')};
/* graphics quality: automatic by default (steps down by itself when frames come slowly), or chosen by hand */
const GQN={auto:'ავტომატური',high:'მაღალი',mid:'საშუალო',low:'დაბალი'};
const gqSet=()=>{const v=store.get('gq','auto');return GQN[v]?v:'auto'};
const gqLevel=()=>{const s=gqSet();if(s!=='auto')return s;const a=store.get('gqa',null);if(a&&GQN[a]&&a!=='auto')return a;const m=navigator.deviceMemory||8,c=navigator.hardwareConcurrency||8;return m<=3||c<=4?'mid':'high'};
A.gqual=()=>{const cur=gqSet();sheet(head('გრაფიკა')+`<div class="gmenu">${['auto','high','mid','low'].map(k=>`<button data-a="gqset" data-v="${k}"${k===cur?' aria-pressed="true"':''}>${ic(k===cur?'check':'cube')}<span><b>${GQN[k]}</b><br><small class="muted">${{auto:'თავისით ირჩევს შენი ტელეფონის მიხედვით',high:'ყველაზე ლამაზი: ჩრდილები, ანარეკლი, მკვეთრი სურათი',mid:'ჩრდილებით, ანარეკლის გარეშე',low:'ყველაზე მსუბუქი, სუსტი ტელეფონისთვის'}[k]}</small></span></button>`).join('')}</div>`,'short')};
A.gqset=t=>{store.set('gq',t.dataset.v);if(t.dataset.v==='auto')store.set('gqa',null);closeSheet();if(typeof g3Need==='function'){try{G3D.qSeen=null}catch(e){}g3Need()}};
A.grules=()=>{const id=gCur(),rules=id==='joker'?JK_RULES:GRULES[id]||'';sheet(head('წესები')+`<div class="ph-body"><p class="grules">${rules}</p></div>`,'short')};

/* ---------- at the table: reactions, a rematch, sharing a win ---------- */
/* a quick word to the table. it pops up over the player's plate; where the players sit at a 3D table, the character makes the gesture too */
const GRX=[['👏','ბრავო!','nod'],['😂','ჰა-ჰა','laugh'],['😮','ვაა!','wow'],['🍷','გაგიმარჯოს!','cheer'],['😤','ეჰ…','shake'],['🤝','კარგი თამაში','nod']];
const gRxCan=()=>{if(S.page&&S.page.id==='jktable')return JO.seat>=0&&!!JO.st;const G=GAME[S.game],c=G&&G.ctx;return !!c&&isPlayer(c)&&!c.finished};
A.grx=()=>{if(!gRxCan()){toast(S.page?'რეაქცია მაგიდასთან მსხდომებს შეუძლიათ':'პარტია დასრულდა');return}
 sheet(head('რეაქცია')+`<div class="grx">${GRX.map((r,i)=>`<button data-a="grxs" data-i="${i}"><span aria-hidden="true">${r[0]}</span><small>${r[1]}</small></button>`).join('')}</div>`,'short')};
A.grxs=t=>{const i=+t.dataset.i;closeSheet();if(!GRX[i]||Date.now()-(A.grxs.t||0)<1500)return;A.grxs.t=Date.now();gRxShow('me',i);
 if(S.page&&S.page.id==='jktable'){try{if(JO.ch)JO.ch.send({type:'broadcast',event:'rx',payload:{i,seat:JO.seat}})}catch(e){}return}
 const G=GAME[S.game],c=G&&G.ctx;if(!c)return;if(c.mode==='online'&&c.gr){c.gr.emit('rx',{i,s:c.side});return}
 if(c.mode==='bot'||c.mode==='tour')gRxBots(S.game,i)};
/* who: 'me', a side (1 or -1) in a game of two, or a seat counted from me ('r1' left, 'r2' across, 'r3' right) */
function gRxEl(who){const v=S.page&&S.page.id==='jktable'?$('#jko'):view;if(!v)return null;
 if(who==='me')return $('.ghud.bot .pl.me',v)||$('.pl.me',v);if(typeof who==='number')return $(`.pl[data-side="${who}"]`,v);
 return $('.seat.'+({r1:'left',r2:'top',r3:'right'}[who]||'top'),v)}
function gRxShow(who,i){const r=GRX[i];if(!r)return;const el=gRxEl(who);let L=$('#rxl');if(!L){L=document.createElement('div');L.id='rxl';L.setAttribute('aria-live','polite');document.body.appendChild(L)}
 const b=document.createElement('div'),W=innerWidth,rc=el&&el.isConnected?el.getBoundingClientRect():{left:W/2-40,right:W/2+40,top:innerHeight/2,bottom:innerHeight/2},cx=Math.max(90,Math.min(W-90,(rc.left+rc.right)/2)),up=rc.top>130;
 b.className='rxb '+(up?'up':'dn');b.innerHTML=`<span aria-hidden="true">${r[0]}</span><b>${r[1]}</b>`;b.style.left=cx+'px';b.style.top=(up?rc.top-8:rc.bottom+8)+'px';L.appendChild(b);setTimeout(()=>b.remove(),2700);
 if(typeof g3Gest==='function')try{g3Gest(who,r[2])}catch(e){}if(typeof gSnd==='function')gSnd('tap',.6)}
/* the computer's players answer: a toast is answered by the whole table, a handshake with a handshake, the rest now and then */
function gRxBots(id,i){const at=(who,j,ms)=>{const tk=GAME[id]&&GAME[id].tk;setTimeout(()=>{if(S.game===id&&!S.page&&GAME[id].tk===tk)gRxShow(who,j)},ms)},one=()=>'r'+(1+Math.floor(Math.random()*3));
 if(id==='joker'||id==='domino'){if(i===3){[1,2,3].forEach((r,n)=>at('r'+r,3,700+n*420));return}if(i===5){at(one(),5,900);return}if(Math.random()<.5)at(one(),Math.random()<.5?0:1,900);return}
 const o=-GAME[id].ctx.side;if(i===3||i===5){at(o,i,900);return}if(Math.random()<.45)at(o,Math.floor(Math.random()*3),900)}
/* a rematch with the same person: a new room, colours swapped. if both ask at once, both go to the same new room */
A.grem=()=>{const G=GAME[S.game],c=G&&G.ctx;if(!c||c.mode!=='online'||!c.gr||c.gone||!c.finished)return;
 if(c.remIn){c.gr.emit('remok',{gid:c.remIn});gRematch(G,c.remIn);return}if(c.remSent)return;
 const gid='g'+Math.random().toString(36).slice(2,12);c.remSent=gid;c.gr.emit('rem',{gid});G.render()};
function gRematch(G,gid){const c=G.ctx;if(c.remGo)return;c.remGo=1;G.resHide=0;G.resSnd=0;joinGame(gid,S.game,-c.side,{nm:c.names[-c.side],id:c.opp},c.opp,false).catch(()=>toast('დაკავშირება ვერ მოხერხდა'))}
function gRemHTML(c){if(c.mode!=='online'||c.gone)return '';if(c.remIn)return `<p class="gendr">${ic('turn')}<span><b>${esc(c.names[-c.side])}</b> რევანშს გთავაზობს</span></p>`;if(c.remSent)return `<p class="gendr">${ic('clock')}<span>რევანში შესთავაზე. ველოდებით პასუხს…</span></p>`;return ''}
/* share a win to the feed: a picture of the game with the result, and a line of text you can change */
const gIn=n=>(n.endsWith('ი')?n.slice(0,-1):n)+'ში';
async function gWinPic(id,title,sub){const S2=1080,cv=document.createElement('canvas');cv.width=cv.height=S2;const x=cv.getContext('2d'),FS='"Noto Sans Georgian","DejaVu Sans",system-ui,sans-serif';
 try{const im=await loadImg(GART(id,1000));const k=Math.max(S2/im.width,S2/im.height);x.drawImage(im,(S2-im.width*k)/2,(S2-im.height*k)/2,im.width*k,im.height*k)}catch(e){x.fillStyle='#2a1a12';x.fillRect(0,0,S2,S2)}
 const g=x.createLinearGradient(0,S2*.35,0,S2);g.addColorStop(0,'rgba(10,6,4,0)');g.addColorStop(.55,'rgba(10,6,4,.78)');g.addColorStop(1,'rgba(10,6,4,.94)');x.fillStyle=g;x.fillRect(0,0,S2,S2);
 const fit=(t,w,px,wt)=>{let s=px;x.font=`${wt} ${s}px ${FS}`;while(s>22&&x.measureText(t).width>w){s-=2;x.font=`${wt} ${s}px ${FS}`}};
 x.fillStyle='#F4BC4C';x.fillRect(72,S2-404,64,6);x.font=`800 46px ${FS}`;x.fillText(title,72,S2-342);
 x.fillStyle='#FFF7EA';x.font=`800 132px ${FS}`;x.fillText('მოვიგე!',66,S2-205);
 x.fillStyle='rgba(255,247,234,.85)';fit(sub,S2-144,42,600);x.fillText(sub,72,S2-112);
 const d=new Date(),MN=['იანვარი','თებერვალი','მარტი','აპრილი','მაისი','ივნისი','ივლისი','აგვისტო','სექტემბერი','ოქტომბერი','ნოემბერი','დეკემბერი'];
 x.fillStyle='rgba(255,247,234,.55)';x.font=`600 30px ${FS}`;x.fillText(`${d.getDate()} ${MN[d.getMonth()]}, ${d.getFullYear()}`,72,S2-56);
 x.font=`800 34px ${FS}`;const bw=x.measureText('სუფრა').width+44;x.fillStyle='rgba(10,6,4,.55)';x.beginPath();x.roundRect?x.roundRect(S2-bw-48,48,bw,62,31):x.rect(S2-bw-48,48,bw,62);x.fill();x.fillStyle='#FFF7EA';x.fillText('სუფრა',S2-bw-26,91);
 return await new Promise(r=>cv.toBlob(r,'image/jpeg',.88))}
A.gshare=async t=>{const id=t.dataset.g||gCur(),g=GAMES.find(x=>x.id===id);if(!g)return;const sub=String(t.dataset.sub||'').slice(0,80);
 t.disabled=true;let pic=null;try{pic=await gWinPic(id,g.n,sub)}catch(e){}t.disabled=false;
 compose({text:`მოვიგე ${gIn(g.n)}${sub?' · '+sub:''}! #თამაშები`,files:pic?[pic]:[]})};
const gShareBtn=(id,sub)=>`<button class="btn ghost gshr" data-a="gshare" data-g="${id}" data-sub="${esc(sub||'')}">${ic('share')}გაზიარება</button>`;
/* games being played right now by people in the lobby, one card a game, to watch */
function gLiveList(){const seen=new Set(),out=[];for(const p of NET.peers){if(p.st!=='play'||!okGid(p.g)||seen.has(p.g)||BLOCKED.has(p.id))continue;const g=GAMES.find(x=>x.id===p.gt&&x.net);if(!g)continue;seen.add(p.g);out.push({p,g})}return out.slice(0,6)}
function gLiveHTML(){return gLiveList().map(({p,g})=>`<button class="lgcard" data-a="netwatch" data-u="${p.id}" style="--ac:${g.ac}"><span class="gs-mini"><img src="${GART(g.id,600)}" alt="" loading="lazy" decoding="async"><em>${g.n}</em></span><span class="vsn"><span class="gs-avs">${av(Object.assign({},prof(p.id),{name:p.nm,hue:p.hu,avatar_url:p.av}),24)}</span>${esc(String(p.nm||'').split(' ')[0])}${p.vs?' და '+esc(String(p.vs).split(' ')[0]):''}</span><small>${FRIENDS.has(p.id)?'მეგობარი · ':''}უყურე პარტიას</small></button>`).join('')}
/* a game invitation in the messenger: two-player games start right away when both are here; joker opens a table to sit at */
function gameMsg(g,me,m){const G=GAMES.find(x=>x.id===(g&&g.gt)&&x.on);if(!G||(G.id==='joker'?!(+g.tbl>0):!okGid(g.gid)))return '';const at=new Date(m.created_at).getTime()||0;
 const btn=G.id==='joker'?`<button class="btn sm${me?' ghost':' gold'}" data-a="chgamejoin" data-g="joker" data-t="${+g.tbl}">${me?'მაგიდაზე':'მაგიდასთან დაჯდომა'}</button>`
  :me?'':`<button class="btn sm gold" data-a="chgamejoin" data-g="${G.id}" data-gid="${g.gid}" data-u="${esc(m.sender)}" data-at="${at}">${ic('play')}თამაში</button>`;
 return `<div class="gamemsg${me?' me':''}" style="--ac:${G.ac}"><img src="${GART(G.id,600)}" alt="" loading="lazy" decoding="async"><div class="gmb"><b>${G.n}</b><small>${me?'შენ გამოიწვიე':'გიწვევს თამაშში'}</small>${btn}</div></div>`}
A.chgame=()=>{closeLayer();const st=CHAT;if(!st||!st.other)return;layer(lhead('რა ვითამაშოთ?')+`<div class="reasons">${GAMES.filter(g=>g.on).map(g=>`<button data-a="chgamego" data-g="${g.id}">${ic(g.ic)} ${g.n}</button>`).join('')}</div>`)};
A.chgamego=async t=>{const st=CHAT,gt=t.dataset.g,g=GAMES.find(x=>x.id===gt&&x.on);closeLayer();if(!st||!st.other||!g)return;const to=st.other;
 if(gt==='joker'){try{const r=await q(sb.from('jk_tables').insert({host:ME.id,len:'quick',seats:[ME.id,null,null,null]}).select('id').single());await st.send({body:'🃏 ჯოკერი: მაგიდა გავშალე, შემოდი!',media:{game:{gt,tbl:r.id}}});closeSheet();openPage('jktable',r.id)}catch(e){toast(errMsg(e))}return}
 const gid='g'+Math.random().toString(36).slice(2,12);await st.send({body:`🎲 ${g.n}: მოდი ვითამაშოთ!`,media:{game:{gt,gid}}});
 if(S.online.has(to)){NET.pending={gid,gt,to};lsend('chal',{to,gt,gid,nm:ME.name});setTimeout(()=>{if(NET.pending&&NET.pending.gid===gid)NET.pending=null},45000);toast('გამოწვევა გაიგზავნა. მიღებისთანავე თამაში გაიხსნება')}
 else toast('გამოწვევა გაიგზავნა. როცა შემოვა, შეძლებს მიღებას')};
A.chgamejoin=t=>{const gt=t.dataset.g;if(gt==='joker'){const id=+t.dataset.t;if(id>0){closeSheet();openPage('jktable',id)}return}
 const u=t.dataset.u,gid=t.dataset.gid,at=+t.dataset.at||0,g=GAMES.find(x=>x.id===gt&&x.net);if(!g||!u||u===ME.id)return;
 if(NET.inv&&NET.inv.gid===gid){A.netacc();return}
 if(!S.online.has(u)){toast(String(pname(u)).split(' ')[0]+' ახლა ონლაინ არ არის. როცა შემოვა, გამოიწვიე');return}
 if(okGid(gid)&&Date.now()-at<45e3){closeSheet();lsend('acc',{to:u,gid});joinGame(gid,gt,-1,{nm:String(pname(u)).slice(0,40),id:u},u,false).catch(()=>toast('დაკავშირება ვერ მოხერხდა'));return}
 const ng='g'+Math.random().toString(36).slice(2,12);NET.pending={gid:ng,gt,to:u};lsend('chal',{to:u,gt,gid:ng,nm:ME.name});setTimeout(()=>{if(NET.pending&&NET.pending.gid===ng)NET.pending=null},45000);toast('გამოწვევა გაიგზავნა. ველოდებით პასუხს')};
/* ---------- my character: how I look sitting at a table on other people's screens ----------
   kept on the phone (and on the profile once the profile can hold it); sent to the others at an online table */
const LKO={fem:[[0,'კაცი'],[1,'ქალი']],style:[['short','მოკლე'],['long','გრძელი'],['bald','მელოტი']],mus:[[0,'არა'],[1,'კი']]};
const LKC={skin:['#F2CDB0','#EBC0A0','#E2AF8C','#D69C77','#C08261','#8D5A3B'],hair:['#1A120D','#2E2219','#4E3220','#7A4A2A','#B8875A','#8A8580'],shirt:['#2F5D8A','#8E3047','#3E6B47','#2C2C34','#C9A227','#6A4C93','#D9D4C7']};
const LKN={fem:'სახე',style:'თმა',mus:'ულვაში',skin:'კანი',hair:'თმის ფერი',shirt:'პერანგი'};
function lkClean(o){o=o&&typeof o==='object'?o:{};const hx=v=>typeof v==='string'&&/^#[0-9a-fA-F]{6}$/.test(v);
 return{fem:o.fem?1:0,style:['short','long','bald'].includes(o.style)?o.style:'short',mus:o.mus&&!o.fem?1:0,skin:hx(o.skin)?o.skin:LKC.skin[2],hair:hx(o.hair)?o.hair:LKC.hair[1],shirt:hx(o.shirt)?o.shirt:LKC.shirt[0]}}
function myLook(){const s=store.get('mylook',null)||(ME&&ME.look);if(s)return lkClean(s);const fem=ME&&ME.gender==='f';let k=0;for(const ch of String(ME&&ME.id||'x'))k=(k*31+ch.charCodeAt(0))>>>0;
 return lkClean({fem:fem?1:0,style:fem?'long':'short',skin:LKC.skin[k%4],hair:LKC.hair[(k>>3)%3],shirt:LKC.shirt[(k>>5)%LKC.shirt.length]})}
let LKD=null;
function lkOptsHTML(){const d=LKD,row=(k,body)=>`<div class="lkrow"><span class="lkn">${LKN[k]}</span><div class="lkv">${body}</div></div>`;
 const seg=k=>row(k,`<div class="seg" role="group" aria-label="${LKN[k]}">${LKO[k].map(([v,l])=>`<button data-a="glk" data-k="${k}" data-v="${v}" aria-pressed="${String(d[k])===String(v)}"${k==='mus'&&d.fem?' disabled':''}>${l}</button>`).join('')}</div>`);
 const sw=k=>row(k,`<div class="lksw" role="group" aria-label="${LKN[k]}">${LKC[k].map(c=>`<button data-a="glk" data-k="${k}" data-v="${c}" style="--c:${c}" aria-pressed="${d[k]===c}" aria-label="${LKN[k]} ${c}"></button>`).join('')}</div>`);
 return seg('fem')+seg('style')+seg('mus')+sw('skin')+sw('hair')+sw('shirt')}
A.glook=()=>{LKD=myLook();sheet(head('ჩემი პერსონაჟი')+`<div class="ph-body lked"><div class="lkprev" id="lkp">${g3Can()?'<span class="g3load" aria-hidden="true"></span>':`<span class="lkflat">${av('me',72)}</span>`}</div><div id="lkopts">${lkOptsHTML()}</div><p class="note">ასე გამოჩნდები ონლაინ: ჯოკერის მაგიდასთან და ჭადრაკის, შაშისა და ნარდის დაფის მეორე მხარეს.</p><button class="btn" data-a="glooksave" style="width:100%">შენახვა</button></div>`);lkPrev()};
function lkPrev(){if(!g3Can())return;g3Load().then(()=>{const el=$('#lkp');if(!el||!G3W.ready||typeof G3B==='undefined')return;const sc=G3S.look||(G3S.look=G3B.look());sc.host='look';sc.lk=LKD;if(!g3Mount(el,sc))return;try{G3U.look(sc)}catch(e){}$('.g3load',el)?.remove();g3Need()}).catch(()=>{})}
A.glk=t=>{if(!LKD)return;const k=t.dataset.k,v=t.dataset.v;LKD[k]=k==='fem'||k==='mus'?+v:v;if(k==='fem'){LKD.style=LKD.fem?'long':'short';if(LKD.fem)LKD.mus=0}LKD=lkClean(LKD);const o=$('#lkopts');if(o)o.innerHTML=lkOptsHTML();
 if(typeof G3S!=='undefined'&&G3S.look&&G3D.sc===G3S.look){G3S.look.lk=LKD;try{G3U.look(G3S.look)}catch(e){}}};
A.glooksave=async()=>{if(!LKD)return;const L=lkClean(LKD);store.set('mylook',L);ME.look=L;closeSheet();toast('პერსონაჟი შენახულია');netPresence();
 try{await sb.from('profiles').update({look:L}).eq('id',ME.id)}catch(e){}};
const gPplOn=()=>store.get('gppl',true)!==false;
A.gppl=t=>{const on=!gPplOn();store.set('gppl',on);gSwFlip(t,on);gRedraw()};
function gGone(G,c,ms){if(c.mode!=='online'||c.finished)return;clearTimeout(c.goneT);c.goneT=setTimeout(()=>{if(G.ctx===c&&c.gone&&!c.finished&&G.resign)G.resign(-c.side,'gone')},ms)}
/* ---------- ratings: one a game, from games with people; a season every month (Tbilisi time) ----------
   until the server keeps per-game ratings, the old single rating is shown */
const GR={ok:null,season:null};
const gSeason=()=>{try{return new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Tbilisi',year:'numeric',month:'2-digit'}).format(new Date()).slice(0,7)}catch(e){const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')}};
const GMON=['იანვრის','თებერვლის','მარტის','აპრილის','მაისის','ივნისის','ივლისის','აგვისტოს','სექტემბრის','ოქტომბრის','ნოემბრის','დეკემბრის'];
const LBG=['nardi','shashi','chess'];
const lbGame=()=>{const g=store.get('lbg',null)||store.get('glast',null);return LBG.includes(g)?g:'nardi'};
const lbScope=()=>{const s=store.get('lbs','all');return['all','friends','month'].includes(s)?s:'all'};
function gMyRtHTML(){const g=lbGame(),n=GAMES.find(x=>x.id===g).n;return GR.ok?`${ic('trophy')}<span>${n} <b>${myRating(g)}</b></span>`:`${ic('trophy')}<span>შენი რეიტინგი <b>${ME.rating??1500}</b></span>`}
function gMyRtLoad(){q(sb.from('game_ratings').select('game,rating,games,season,season_pts,season_games').eq('user_id',ME.id)).then(rows=>{GR.ok=true;GR.mine={};(rows||[]).forEach(r=>{MYR[r.game]=r.rating;GR.mine[r.game]=r});const e=$('#gmyr');if(e)e.innerHTML=gMyRtHTML()}).catch(()=>{GR.ok=false})}
function gLbCtl(){const g=lbGame(),s=lbScope(),m=+gSeason().slice(5)-1;
 return `<div class="gs-lbt" role="group" aria-label="თამაში">${LBG.map(id=>`<button data-a="glbg" data-g="${id}" aria-pressed="${id===g}">${GAMES.find(x=>x.id===id).n}</button>`).join('')}</div>
 <div class="seg flat" role="group" aria-label="ვინ">${[['all','ყველა'],['friends','მეგობრები'],['month',MONTHS[m]]].map(([k,l])=>`<button data-a="glbs" data-s="${k}" aria-pressed="${k===s}">${l}</button>`).join('')}</div>`}
A.glbg=t=>{store.set('lbg',t.dataset.g);const c=$('#lbc');if(c)c.innerHTML=gLbCtl();const e=$('#gmyr');if(e)e.innerHTML=gMyRtHTML();gLbLoad()};
A.glbs=t=>{store.set('lbs',t.dataset.s);const c=$('#lbc');if(c)c.innerHTML=gLbCtl();gLbLoad()};
async function gLbLoad(){const el=$('#lb');if(!el)return;const g=lbGame(),s=lbScope(),m2=+gSeason().slice(5)-1,tk=(gLbLoad.tk=(gLbLoad.tk||0)+1),fr=[ME.id,...FRIENDS].slice(0,300);el.innerHTML=skel(2);
 const draw=(rows,val,sub,empty)=>{if(gLbLoad.tk!==tk||!$('#lb'))return;rows.forEach(p=>{if(p.p)PC.set(p.p.id,Object.assign(PC.get(p.p.id)||{},p.p))});
  $('#lb').innerHTML=rows.length?`<table class="lb"><tbody>${rows.map((r,i)=>`<tr${r.p.id===ME.id?' class="mine"':''}><td><span class="gs-rk${i<3?' r'+(i+1):''}">${i+1}</span></td><td><button class="lbn" data-a="user" data-u="${r.p.id}">${av(r.p,28)}<span class="lbnn"><span>${esc(r.p.name)}${vb(r.p)}</span>${sub&&sub(r)?`<small>${sub(r)}</small>`:''}</span></button></td><td>${val(r)}</td></tr>`).join('')}</tbody></table>`:`<p class="note">${empty}</p>`};
 if(GR.ok!==false){try{let qq=sb.from('game_ratings').select('user_id,rating,games,wins,season,season_pts,season_games,profiles(id,name,avatar_url,hue,verified)').eq('game',g);
   if(s==='month')qq=qq.eq('season',gSeason()).gt('season_games',0).order('season_pts',{ascending:false}).limit(10);else if(s==='friends')qq=qq.in('user_id',fr).gt('games',0).order('rating',{ascending:false}).limit(50);else qq=qq.gt('games',0).order('rating',{ascending:false}).limit(10);
   const rows=(await q(qq)).filter(r=>r.profiles).map(r=>Object.assign(r,{p:r.profiles}));GR.ok=true;
   draw(rows,r=>s==='month'?(r.season_pts>0?'+':'')+r.season_pts:r.rating,r=>s==='month'?r.season_games+' პარტია':r.games+' პარტია'+(r.wins?', '+r.wins+' მოგება':''),s==='month'?`${GMON[m2]} სეზონში ჯერ არავის უთამაშია. პირველი რეიტინგული პარტია სეზონს გახსნის.`:s==='friends'?'მეგობრებს ჯერ რეიტინგული პარტია არ უთამაშიათ. გამოიწვიე რომელიმე.':'ჯერ არავის უთამაშია რეიტინგული პარტია.');return}catch(e){GR.ok=false}}
 if(s==='month'){draw([],null,null,'თვის სეზონი ჩაირთვება, როცა რეიტინგი თამაშების მიხედვით დაითვლება.');return}
 try{let qq=sb.from('profiles').select('id,name,avatar_url,hue,rating,verified').eq('onboarded',true);qq=s==='friends'?qq.in('id',fr).order('rating',{ascending:false}).limit(50):qq.order('rating',{ascending:false}).limit(10);
  const rows=(await q(qq)).map(p=>({p,rating:p.rating}));draw(rows,r=>r.rating,null,'აქ ჯერ არავინაა.')}catch(e){if(gLbLoad.tk===tk&&$('#lb'))$('#lb').innerHTML=`<p class="note">${errMsg(e)}</p>`}}
