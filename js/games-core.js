/* games: lobby, online play over realtime, tournaments, leaderboard */
const GAMES=[{id:'nardi',n:'ნარდი',d:'ტავლა · ქვის მოჭრით და ზარით',ic:'dice',net:1},{id:'shashi',n:'შაში',d:'რუსული წესები · მფრინავი დამა',ic:'checker',net:1},{id:'chess',n:'ჭადრაკი',d:'კლასიკური წესები, როქით და გავლით აღებით',ic:'chess',net:1},{id:'joker',n:'ჯოკერი',d:'ქართული ბანქო, ოთხი მოთამაშე',ic:'cards'},{id:'domino',n:'დომინო',d:'კლასიკური, წყვილებში',ic:'domino',soon:1}];
const GAME={};
const JK_BOTS=['ნინო','ლუკა','დათო'],JK_ERG=['ნინომ','ლუკამ','დათომ'];
const BOTN=[['ლუკა',205],['დათო',12],['გიორგი',150],['ნინო',340],['ანა',275],['ლევანი',95],['თამარი',190]];
const shuffle=a=>{for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a};
const BOT={n:'ბ',h:42};
function startGame(id,ctx){const G=GAME[id],fresh=!S.game;S.game=id;G.ctx=Object.assign({mode:'bot',side:1,names:{1:ME.name,'-1':'სუფრა ბოტი'},avs:{1:'me','-1':BOT},seq:0},ctx||{});G.start();view.scrollTop=0;G.render();if(G.kick)G.kick();if(fresh)navOpen('game')}
const isPlayer=c=>c.mode==='bot'||c.mode==='online'||c.mode==='tour';
function plSub(c,s){if(c.mode==='watch'||c.mode==='netwatch')return '';if(s===c.side)return 'რეიტინგი '+(ME.rating??1500);return c.mode==='online'?(c.gone?'გავიდა':'ონლაინ'):'ბოტი'}
const gTag=c=>c.mode==='bot'?'<button class="btn ghost sm" data-a="restart">ახალი პარტია</button>':c.mode==='online'?'<span class="tag">ონლაინ</span>':c.mode==='tour'?'<span class="tag">ტურნირი</span>':'<span class="tag soon">ყურება</span>';
const gTop=(t,c)=>`<div class="gtop"><button class="ibtn" data-a="lobby" aria-label="ლობიში დაბრუნება">${ic('back')}</button><h2>${t}</h2><span class="sp"></span>${gTag(c)}</div>`;
function gview(id,title,board,status,extra=''){if(S.tab!=='games'||S.game!==id||S.page)return;const c=GAME[id].ctx;
 const pl=s=>`<div class="pl">${avAny(c.avs[s],30)}<b>${esc(c.names[s])}</b><span class="muted">${plSub(c,s)}</span></div>`;
 view.innerHTML=`<div class="view-pad game">${gTop(title,c)}${pl(-c.side)}${board}${pl(c.side)}<div class="status" role="status">${status}</div>${extra}</div>`}
function endMsg(c,w){if(w===2)return 'ფრე';if(!isPlayer(c))return esc(c.names[w])+' მოიგო';return w===c.side?'მოიგე!':esc(c.names[w])+' მოიგო. სცადე ისევ'}
const tourBack=c=>c.mode==='tour'&&c.finished?'<button class="btn" data-a="page" data-p="tour" style="align-self:flex-start">ტურნირზე დაბრუნება</button>':'';
async function gameResult(game,win){try{const r=await rpc('game_result',{p_game:game,p_win:win});ME.rating=r.rating;setCoins(r.coins);if(win)toast(r.reward?`მოიგე! +12 რეიტინგი, +${r.reward} მონეტა`:'მოიგე! +12 რეიტინგი');if(win)confetti()}catch(e){}}
function finish(G,w){const c=G.ctx;if(c.finished)return;c.finished=1;if(isPlayer(c)&&w!==2){const win=w===c.side;gameResult(G.title,win);if(c.mode==='tour')tourResult(win)}G.render()}
A.play=t=>{const g=GAMES.find(x=>x.id===t.dataset.g);if(g.soon||!GAME[g.id]){toast(g.n+' მალე დაემატება');return}startGame(g.id)};
A.lobby=()=>{navKill('game');const G=GAME[S.game];if(G){if(G.ctx&&G.ctx.gr)netLeave();G.ctx={mode:'dead',side:1,names:{},avs:{}};G.tk=(G.tk||0)+1}S.game=null;R.games()};
A.restart=()=>{const G=GAME[S.game];if(!G)return;if(S.game==='joker'){G.start();G.render();return}startGame(S.game,{mode:'bot',names:G.ctx.names,avs:G.ctx.avs})};
const LIVEG=[{gt:'nardi',a:0,b:1},{gt:'chess',a:2,b:4},{gt:'shashi',a:3,b:5}];
A.watch=t=>{const g=LIVEG[+t.dataset.i],a=BOTN[g.a],b=BOTN[g.b];startGame(g.gt,{mode:'watch',names:{1:a[0]+' (ბოტი)','-1':b[0]+' (ბოტი)'},avs:{1:{n:a[0],h:a[1]},'-1':{n:b[0],h:b[1]}}})};

/* online: lobby presence + challenges, game rooms over broadcast */
const NET={lobby:null,peers:[],pending:null,inv:null,gr:null,state:null};
function netInit(){const ch=sb.channel('lobby',{config:{presence:{key:ME.id},broadcast:{self:false}}});
 ch.on('presence',{event:'sync'},()=>{const st=ch.presenceState();S.online=new Set(Object.keys(st));NET.peers=Object.entries(st).filter(([k])=>k!==ME.id).map(([k,arr])=>Object.assign({id:k},arr[arr.length-1]));if(S.tab==='games'&&!S.game&&!S.page){const ol=$('#onl');if(ol)ol.innerHTML=onlineHTML()}})
  .on('broadcast',{event:'chal'},({payload})=>onChal(payload)).on('broadcast',{event:'acc'},({payload})=>onAcc(payload)).on('broadcast',{event:'decl'},({payload})=>onDecl(payload))
  .subscribe(st=>{if(st==='SUBSCRIBED')netPresence()});NET.lobby=ch}
function netPresence(){if(!NET.lobby)return;if(ME.privacy&&ME.privacy.online===false){NET.lobby.untrack();return}NET.lobby.track(Object.assign({nm:ME.name,hu:ME.hue,av:ME.avatar_url||null,st:'idle',gt:null,g:null,vs:null},NET.state||{}))}
const lsend=(ev,payload)=>NET.lobby&&NET.lobby.send({type:'broadcast',event:ev,payload:Object.assign({from:ME.id},payload)});
function onlineHTML(){const others=NET.peers.filter(p=>!BLOCKED.has(p.id)),off=ME.privacy?.online===false?'<p class="note" style="margin-bottom:8px">შენი ონლაინ სტატუსი დამალულია, ამიტომ სხვები ლობიში ვერ გხედავენ.</p>':'';
 if(!others.length)return off+`<p class="ohint">ახლა სხვა ონლაინ არავინაა. მოიწვიე მეგობარი და როცა შემოვა, აქ გამოჩნდება.</p>`;
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
 const ctx={mode:watch?'netwatch':'online',side:watch?1:side,names,avs,gid,opp:oppId,seq:0,gr:{ch,emit:(ev,p)=>ch.send({type:'broadcast',event:ev,payload:p})}};
 if(S.page)S.page=null;if(S.tab!=='games'){S.tab='games';$$('.tab').forEach(b=>b.setAttribute('aria-current',String(b.dataset.tab==='games')));view.className='';$('#app').classList.remove('media');moveInd(3)}
 {const fresh=!S.game;S.game=gt;G.ctx=ctx;G.start();NET.gr=ctx.gr;if(fresh)navOpen('game')}
 ch.on('broadcast',{event:'st'},({payload:d})=>{if(G.ctx!==ctx||!d||typeof d!=='object'||!(Number(d.seq)>ctx.seq)||!d.s)return;try{G.load(d.s);ctx.seq=Number(d.seq);G.render();if(G.checkEnd)G.checkEnd()}catch(e){}})
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

R.games=()=>{if(S.game&&GAME[S.game])return GAME[S.game].render();
 view.innerHTML=`<div class="view-pad"><section class="ghero"><span class="live"><i></i>${S.online.size} ონლაინ</span><h2>სამაგიდო თამაშები</h2><p>ითამაშე ბოტთან, გამოიწვიე მეგობარი ან უყურე პარტიებს.</p><div class="hrow"><button class="btn gold" data-a="play" data-g="nardi">ნარდის დაწყება</button><span class="rt">შენი რეიტინგი<b>${ME.rating??1500}</b></span></div></section>
 <section><h3 class="sec">ონლაინ ახლა</h3><div id="onl">${onlineHTML()}</div></section>
 <div class="glist">${GAMES.map(g=>`<button class="gcard" data-a="play" data-g="${g.id}"${g.soon?' aria-disabled="true"':''}><span class="gicon">${ic(g.ic)}</span><span><h3>${g.n}</h3><p>${g.d}</p></span><span class="tag${g.soon?' soon':''}">${g.soon?'მალე':'თამაში'}</span></button>`).join('')}</div>
 <button class="tourcard" data-a="page" data-p="tour" style="text-align:left;width:100%"><span class="tag" style="align-self:flex-start">კვირის ტურნირი</span><h3>ნარდის თასი</h3><p class="note">${S.tour?(tourMy()?'შენი შემდეგი მატჩი გელოდება':'ნახე შედეგები'):'8 მოთამაშე, გამოთიშვის სისტემა. რეგისტრაცია უფასოა'}</p></button>
 <section><h3 class="sec">ბოტების პარტიები</h3><div class="livegames">${LIVEG.map((g,i)=>`<button class="lgcard" data-a="watch" data-i="${i}"><span class="vsn">${avAny({n:BOTN[g.a][0],h:BOTN[g.a][1]},24)}${BOTN[g.a][0]} · ${BOTN[g.b][0]}${avAny({n:BOTN[g.b][0],h:BOTN[g.b][1]},24)}</span><small>${GAMES.find(x=>x.id===g.gt).n} · უყურე როგორ თამაშობენ</small></button>`).join('')}</div></section>
 <section><h3 class="sec">რეიტინგი · ტოპ 10</h3><div id="lb">${skel(2)}</div></section></div>`;
 q(sb.from('profiles').select('id,name,avatar_url,hue,rating,verified').eq('onboarded',true).order('rating',{ascending:false}).limit(10)).then(rows=>{rows.forEach(p=>PC.set(p.id,Object.assign(PC.get(p.id)||{},p)));const el=$('#lb');if(el)el.innerHTML=`<table class="lb"><tbody>${rows.map((r,i)=>`<tr${r.id===ME.id?' class="mine"':''}><td>${i+1}</td><td><button class="lbn" data-a="user" data-u="${r.id}">${av(r,28)}${esc(r.name)}${vb(r)}</button></td><td>${r.rating}</td></tr>`).join('')}</tbody></table>`}).catch(()=>{})};
