/* games: the people the computer plays as, what they say at the table, the career, and the other ways to play */

/* ---------- the computer's players: one person for each level, with a face and a way of talking ---------- */
const BOTC=[null,
 {n:'ნიკა',h:45,cast:'m5',lk:{style:'curly',skin:'#C08261',hair:'#1A120D',shirt:'#8E3047',hat:1,beard:1},d:'სტუდენტი, ახლა სწავლობს. ხშირად ცდება და ბევრს იცინის'},
 {n:'მარიამი',h:340,cast:'f4',lk:{fem:1,style:'long',skin:'#F1C9AC',hair:'#3A2216',shirt:'#D9D4C7'},d:'ფრთხილად თამაშობს, ყოველ სვლაზე ფიქრობს'},
 {n:'ბატონი რეზო',h:200,cast:'m2',lk:{style:'short',mus:1,hat:1,skin:'#D69C77',hair:'#2E2219',brow:'#2E2219',shirt:'#7A5A3E'},d:'ეზოს ვეტერანი, იშვიათად ცდება'},
 {n:'ოსტატი გურამი',h:20,cast:'m1',lk:{style:'short',skin:'#EBC0A0',hair:'#2E2219',shirt:'#2C2C34'},d:'ყველაზე ძლიერი. ფიქრს დრო სჭირდება'}];
const BOTP=/^(ბებო|ბატონი|ოსტატი|ქალბატონი|მასწავლებელი|მეზღვაური|ბაბუა|ჩემპიონი) /;
const botChar=(g,lv)=>BOTC[lv||bLvl(g)]||BOTC[2];
const botAv=ch=>({n:ch.n.replace(BOTP,'')[0],h:ch.h,look:ch.lk,cast:ch.cast});
const G2P=['nardi','shashi','chess'];
/* a new level picked in the menu brings its person to the table at once */
{const set=A.gbotset;A.gbotset=t=>{set(t);const id=gCur(),G=GAME[id],c=G&&G.ctx;if(c&&c.mode==='bot'&&G2P.includes(id)){const ch=botChar(id);c.names[-c.side]=ch.n;c.avs[-c.side]=botAv(ch);G.render()}}}
A.gbot=()=>{const id=gCur();if(!id)return;const lv=bLvl(id),two=G2P.includes(id);sheet(head('ბოტის დონე')+`<div class="gmenu">${[1,2,3,4].map(v=>`<button data-a="gbotset" data-v="${v}"${v===lv?' aria-pressed="true"':''}>${two?avAny(botAv(BOTC[v]),34):ic(v===lv?'check':'user')}<span><b>${two?BOTC[v].n+' · ':''}${BLV[v].n}</b><br><small class="muted">${two?BOTC[v].d:BLV[v].d}</small></span>${v===lv?ic('check'):''}</button>`).join('')}</div>`,'short')};

/* ---------- talk at the table ----------
   the computer's players say a word when something happens: a checker hit, a check, a double six, a last tile.
   only the computer's players talk, never a person playing online; it can be turned off in the menu */
const gSayOn=()=>store.get('gsay',true)!==false;
A.gsayt=t=>{const on=!gSayOn();store.set('gsay',on);gSwFlip(t,on)};
const SAY={hitMe:['ეეე, ეგ რა იყო!','ვაჰ, მომიკალი!','კარგი, კარგი… ნახავ','ამას არ ველოდი'],hitBot:['ზარზე, ზარზე!','ბოდიში, ასე მოვიდა 😄','აი, ასე!'],
 d66:['ექვს-ექვსი! 🎲','შეხედე, ექვს-ექვსი!'],dblBot:['წყვილი!','ბედმა გამიღიმა'],dblMe:['აი, ბედი!','შენც გაგიმართლა…'],
 checkBot:['ქიში!','ქიში, მეგობარო'],checkMe:['ჰმ…','კარგი სვლაა','აჰა…'],queenMe:['ვაიმე, ლაზიერი…','ეს ლაზიერი მენანება'],queenBot:['ლაზიერი ჩემია!','ლაზიერი წავიღე!'],
 mateBot:['მატი!','მატი, მეგობარო. კიდევ ვითამაშოთ?'],mateMe:['ყოჩაღ! კარგად ითამაშე','მატი… შენ მოიგე'],kingBot:['დამა!','დამა გამოვიყვანე'],kingMe:['დამა გამოიყვანე? ყოჩაღ'],
 multiBot:['ორი ერთად!','აი, ეს არის!'],multiMe:['ეჰ… ვერ დავინახე','ორი ერთად? კარგია'],last:['ბოლო ქვა!','აი, ბოლო!'],fish:['ფიში!','ჩაიკეტა!'],dbl:['დუბლი!'],pass:['არ მაქვს…','პასი'],
 jk:['ჯოკერი!','ჯოკერი, ბატონო!'],kh:['ხიშტი… 😩','ეჰ, ხიშტი'],all:['ყველა ავიღე!'],winBot:['კარგი თამაში იყო','კიდევ ერთი?'],loseBot:['ყოჩაღ, მოიგე!','დღეს შენი დღეა','კარგი თამაში იყო'],
 marsBot:['მარსი!'],marsMe:['მარსი… ეს მეტისმეტია']};
let GSAYT=0;
function gSay(who,k,o={}){if(!gSayOn()||!SAY[k])return;const now=Date.now();if(now-GSAYT<2300||Math.random()>(o.p??1))return;GSAYT=now;
 let t=SAY[k][Math.floor(Math.random()*SAY[k].length)];const nm=o.nm||'';if(/^ბებო /.test(nm))t=t.replace('მეგობარო','შვილო');if(/^ნიკა/.test(nm)&&Math.random()<.4)t+=' ჰა-ჰა';
 setTimeout(()=>{const el=gRxEl(who);let L=$('#rxl');if(!L){L=document.createElement('div');L.id='rxl';L.setAttribute('aria-live','polite');document.body.appendChild(L)}
  const b=document.createElement('div'),W=innerWidth,rc=el&&el.isConnected?el.getBoundingClientRect():{left:W/2-40,right:W/2+40,top:innerHeight/3,bottom:innerHeight/3},cx=Math.max(110,Math.min(W-110,(rc.left+rc.right)/2)),up=rc.top>130;
  b.className='rxb say '+(up?'up':'dn');b.innerHTML=`<b>${esc(t)}</b>`;b.style.left=cx+'px';b.style.top=(up?rc.top-8:rc.bottom+8)+'px';L.appendChild(b);setTimeout(()=>b.remove(),3000);
  if(o.g&&typeof g3Gest==='function')try{g3Gest(who,o.g)}catch(e){}},o.ms??350)}
/* who talks in a game of two: the computer's side, while it is the computer */
const sayBot=c=>c&&(botSide(c)||c.mode==='watch')?-c.side:null;
const sayNm=c=>{const s=sayBot(c);return s==null?'':String(c.names[s]||'')};
/* chess: checks, queens, mate */
{const pl=CH.play;CH.play=function(m){const c=this.ctx,ps=this.st,cap=ps.b[m.t]||'',mover=ps.turn;pl.call(this,m);const b=sayBot(c);if(b==null||this.ctx!==c)return;const n=this.st,o={nm:sayNm(c)};
 if(n.over&&n.why==='mate'){gSay(b,mover===b?'mateBot':'mateMe',Object.assign(o,{g:mover===b?'cheer':'nod',ms:600}));return}
 if(cap.toLowerCase()==='q'){gSay(b,mover===b?'queenBot':'queenMe',Object.assign(o,{g:mover===b?'laugh':'shake'}));return}
 if(!n.over&&chInChk(n))gSay(b,mover===b?'checkBot':'checkMe',Object.assign(o,{p:mover===b?.8:.35,g:mover===b?'nod':null}))}}
/* checkers: a double take, a new king */
{const pl=CK.play;CK.play=function(m){const c=this.ctx,mover=this.turn,p0=this.b[m.path[0][0]][m.path[0][1]];pl.call(this,m);const b=sayBot(c);if(b==null||this.ctx!==c||this.over)return;const e=m.path[m.path.length-1],o={nm:sayNm(c)};
 if(m.caps.length>=2){gSay(b,mover===b?'multiBot':'multiMe',Object.assign(o,{g:mover===b?'laugh':'shake'}));return}
 if(Math.abs(p0)===1&&Math.abs(this.b[e[0]][e[1]])===2)gSay(b,mover===b?'kingBot':'kingMe',Object.assign(o,{p:.8,g:mover===b?'cheer':'wow'}))}}
/* nardi: a checker hit, doubles */
{const mv=NR.move,ro=NR.roll;NR.move=function(s,f,to,d){const c=this.ctx,bo=this.bar[-s];mv.call(this,s,f,to,d);const b=sayBot(c);if(b==null||this.ctx!==c||this.over)return;if(this.bar[-s]>bo)gSay(b,s===b?'hitBot':'hitMe',{nm:sayNm(c),p:.75,g:s===b?'laugh':'shake'})};
 NR.roll=function(){ro.call(this);const c=this.ctx,b=sayBot(c);if(b==null||this.last[0]!==this.last[1])return;gSay(b,this.last[0]===6&&this.turn===b?'d66':this.turn===b?'dblBot':'dblMe',{nm:sayNm(c),p:this.last[0]===6?.9:.45,g:this.turn===b?'cheer':'wow',ms:900})}}
/* domino: the last tile goes down with a knock, a blocked game is a fish */
{const put=DM.put,pass=DM.pass,er=DM.endRound;DM.put=function(p,i,side){const t=this.hands[p][i],last=this.hands[p].length===1;put.call(this,p,i,side);if(!t)return;
  if(last){const w=p?'r'+p:'r2';gSay(w,'last',{g:p?'cheer':'nod',ms:200});if(typeof gSnd==='function')setTimeout(()=>{gSnd('wood',1.3);gBuzz(20)},420)}else if(p&&t[0]===t[1])gSay('r'+p,'dbl',{p:.3})};
 DM.pass=function(p){pass.call(this,p);if(p&&this.phase==='play')gSay('r'+p,'pass',{p:.25,g:'shake'})};
 DM.endRound=function(kind,p){er.call(this,kind,p);if(kind==='block')gSay('r'+(1+Math.floor(Math.random()*3)),'fish',{g:'wow',ms:300})}}
/* joker: a joker played, a ხიშტი, every trick a player said */
{const pc=JK.playCard,eh=JK.endHand;JK.playCard=function(p,c,jm,js){if(this===JK&&p&&c&&c.j)gSay('r'+p,'jk',{p:.6,g:jm==='lo'?null:'cheer'});pc.call(this,p,c,jm,js)};
 JK.endHand=function(){eh.call(this);if(this!==JK)return;const L=jLast(this.hist).hand;if(!L)return;for(let p=1;p<4;p++){if(L.b[p]>0&&L.t[p]===0){gSay('r'+p,'kh',{p:.7,g:'shake',ms:500});return}if(L.b[p]===L.n&&L.n>=3){gSay('r'+p,'all',{g:'cheer'});return}}}}
/* the end of a game of two: the computer's player says something to you */
{const fin=finish;finish=function(G,w){const c=G.ctx,was=c&&c.finished;fin(G,w);if(was||!c)return;const b=sayBot(c);if(b==null||w===2||c.mode==='puzzle')return;const r=G.res&&G.res(),mars=G===NR&&r&&r.mult>1;
 gSay(b,mars?(w===b?'marsBot':'marsMe'):w===b?'winBot':'loseBot',{nm:sayNm(c),ms:1600,g:w===b?'cheer':'nod'})}}

/* ---------- from the yard to the championship ----------
   six opponents in six places, each harder than the last. beat one and the next opens, along with the place you won in,
   which you can then pick for your own table in the menu ("ადგილი") */
const CAREER=[
 {id:'yard',g:'nardi',pl:'court',n:'ძველი თბილისის ეზო',who:{n:'დათო',h:25,cast:'m4',lk:{style:'short',mus:1,beard:1,skin:'#E2AF8C',hair:'#4E3220',shirt:'#3A4656'}},lvl:2,d:'ეზოს ნარდის მეფე. ამბობს, რომ ათი წელია არ წაუგია'},
 {id:'sololaki',g:'shashi',pl:'balcony',n:'აივანი სოლოლაკში',who:{n:'ქალბატონი თამარი',h:300,cast:'f1',lk:{fem:1,style:'pony',skin:'#F2CDB0',hair:'#B8875A',shirt:'#8E3047'}},lvl:2,d:'მეზობლებთან ყველა პარტია დამებით მოუგია'},
 {id:'library',g:'chess',pl:'desk',n:'ძველი ბიბლიოთეკა',who:{n:'მასწავლებელი ლუკა',h:210,cast:'m3',lk:{style:'short',skin:'#EBC0A0',hair:'#4E3220',shirt:'#2F5D8A'}},lvl:2,d:'ჭადრაკის წრეს ხელმძღვანელობს, ყველა დებიუტი ზეპირად იცის'},
 {id:'batumi',g:'shashi',pl:'sea',n:'ბათუმის ბულვარი',who:{n:'სალომე',h:200,cast:'f5',lk:{fem:1,style:'long',skin:'#F2CDB0',hair:'#B8875A',shirt:'#2F5D8A'}},lvl:3,d:'ზღვისპირას შაშით ერთობა, ბულვარზე ელოდება მეტოქეს'},
 {id:'sighnaghi',g:'chess',pl:'valley',n:'სიღნაღის აივანი',who:{n:'ანა',h:30,cast:'f3',lk:{fem:1,style:'long',skin:'#EBC0A0',hair:'#4E3220',shirt:'#3E6B47'}},lvl:3,d:'ალაზნის ველს გადაჰყურებს და აჩქარება არ უყვარს'},
 {id:'mtatsminda',g:'nardi',pl:'city',n:'მთაწმინდა, ღამით',who:{n:'ჩემპიონი გურამი',h:20,cast:'m1',lk:BOTC[4].lk},lvl:4,d:'ბოლო მეტოქე, ქალაქის ჩემპიონი. ბევრს არ მოუგია მისთვის'}];
const cState=()=>{const s=store.get('career',null);return s&&typeof s==='object'&&s.done?s:{done:{}}};
const cNext=()=>CAREER.find(x=>!cState().done[x.id])||null;
const cOpen=x=>{const i=CAREER.indexOf(x);return i===0||!!cState().done[CAREER[i-1].id]};
/* a career place opens for your own table once you have won there */
function gPlaceOpen(pl){if(['court','balcony','desk'].includes(pl))return true;const x=CAREER.find(z=>z.pl===pl);return !!x&&!!cState().done[x.id]}
PG.career={r(){const st=cState(),n=Object.keys(st.done).length,nx=cNext();
 view.innerHTML=pgHead('ეზოდან ჩემპიონატამდე')+`<div class="view-pad"><section class="tourcard"><p class="note">ექვსი მეტოქე ექვს ადგილას: ეზოდან მთაწმინდამდე. ყოველი მოგება შემდეგ მეტოქესა და ახალ ადგილს ხსნის. გავლილი ადგილი შენს მაგიდასაც შეგიძლია მისცე (მენიუ → ადგილი).</p>
  <div class="cbar"><i style="width:${Math.round(n/CAREER.length*100)}%"></i></div><p class="hint">${n===CAREER.length?'ყველა ეტაპი გავლილია. ჩემპიონი ხარ! 🏆':`გავლილია ${n} ეტაპი ${CAREER.length}-დან`}</p></section>
  <ol class="clist">${CAREER.map((x,i)=>{const done=!!st.done[x.id],open=cOpen(x),g=GAMES.find(z=>z.id===x.g);return `<li class="cstage${done?' done':''}${open?'':' locked'}${nx===x?' next':''}">
   <span class="cnum">${done?ic('check'):open?i+1:ic('lock')}</span><span class="cav">${avAny(botAv(x.who),46)}</span>
   <span class="grow"><b>${esc(x.n)}</b><small>${g.n} · ${esc(x.who.n)} · ${BLV[x.lvl].n}</small><small class="muted">${esc(x.d)}</small></span>
   ${open?`<button class="btn sm${done?' ghost':' gold'}" data-a="cplay" data-id="${x.id}">${done?'ხელახლა':'თამაში'}</button>`:''}</li>`}).join('')}</ol></div>`}};
A.cplay=t=>{const x=CAREER.find(z=>z.id===t.dataset.id);if(!x||!cOpen(x))return;gToTab();startGame(x.g,{mode:'career',lvl:x.lvl,stage:x.id,place:x.pl,names:{1:ME.name,'-1':x.who.n},avs:{1:'me','-1':botAv(x.who)},gk:x.g})};
/* a career win is counted at the end of the game, and the card offers the next step */
{const fin=finish;finish=function(G,w){const c=G.ctx,was=c&&c.finished;fin(G,w);if(was||!c||c.mode!=='career')return;const x=CAREER.find(z=>z.id===c.stage);if(!x)return;
 if(w===c.side){const st=cState();if(!st.done[x.id]){st.done[x.id]=Date.now();store.set('career',st);c.cnew=1;const nx=cNext();setTimeout(()=>toast(nx?`ეტაპი გავლილია! შემდეგი: ${nx.n}`:'კარიერა დასრულდა. ჩემპიონი ხარ! 🏆'),2600);if(typeof gBadge==='function')gBadge('career'+(CAREER.indexOf(x)+1))}}
 if(G.render)G.render()}}
const cResBtn=c=>{const nx=cNext();return c.cnew&&nx?`<button class="btn gold" data-a="cgo" data-id="${nx.id}">${ic('play')}შემდეგი: ${esc(nx.who.n)}</button>`:`<button class="btn gold" data-a="page" data-p="career">${c.finished&&!c.cnew?'კიდევ ვცდი':'კარიერა'}</button>`};
A.cgo=t=>{closeSheet();A.cplay(t)};
/* the place a board stands in */
A.gplace=()=>{const g=gCur();if(!GPDEF[g])return;const cur=gPlaceOf(g);sheet(head('ადგილი')+`<div class="gmenu">${Object.keys(GPLACE).map(k=>{const open=gPlaceOpen(k),x=CAREER.find(z=>z.pl===k);return `<button data-a="gplaceset" data-v="${k}"${k===cur?' aria-pressed="true"':''}${open?'':' disabled'}>${ic(k===cur?'check':open?'map':'lock')}<span><b>${GPLACE[k].n}</b>${!open&&x?`<br><small class="muted">გაიხსნება, როცა კარიერაში ${esc(x.who.n)}-ს მოუგებ</small>`:''}</span></button>`}).join('')}</div>`,'short')};
A.gplaceset=t=>{const g=gCur(),v=t.dataset.v;if(!GPDEF[g]||!gPlaceOpen(v))return;store.set('gplace:'+g,v);closeSheet();gRedraw()};

/* ---------- two people, one phone ----------
   nardi, chess and checkers passed across the table: the board turns to whoever moves, and nothing counts toward ratings or coins */
const G2L=[...G2P,'egg'];
const gLocalPick=()=>sheet(head('ორნი ერთ ტელეფონზე')+`<div class="jchoice">${G2L.map(g=>`<button data-a="glocal" data-g="${g}">${GAMES.find(z=>z.id===g).n}</button>`).join('')}</div><p class="note">ტელეფონი მაგიდაზე დადეთ ან ერთმანეთს გადააწოდეთ: დაფა იმისკენ ბრუნდება, ვისი სვლაცაა.</p>`,'short');
A.glocalpick=()=>gLocalPick();
A.glocal=t=>{const g=t.dataset.g;if(!G2L.includes(g))return;closeSheet();gToTab();startGame(g,{mode:'local',side:1,names:{1:ME.name,'-1':'მეგობარი'},avs:{1:'me','-1':{n:'მ',h:160}},gk:g,tc:gTcOf(g)})};
A.glocalagain=()=>{const G=GAME[S.game],c=G&&G.ctx;if(!c)return;closeSheet();G.resHide=0;G.resSnd=0;startGame(S.game,{mode:'local',side:1,names:{1:c.names[1],'-1':c.names[-1]},avs:{1:c.avs[1],'-1':c.avs[-1]},gk:c.gk,tc:gTcOf(S.game)})};
/* whoever is to move sits at the bottom */
for(const G of[CH,CK,NR]){const r=G.render;G.render=function(){const c=this.ctx;if(c&&c.mode==='local'){const t=this.turnSide&&this.turnSide();if(t)c.side=t}if(c&&c.clk&&!c.finished)clkTurn(this);r.call(this);if(typeof gCoach==='function')gCoach(this)}}

/* ---------- learning: a first game against the gentlest player, with a coach who explains what is happening ----------
   each tip shows once a game, when its moment first comes; "გასაგებია" closes it, and it goes by itself after a while */
const COACH={
 chess:[['check',G=>G.mine()&&G.inCheck(),'ქიში! შენს მეფეს ემუქრებიან. გადაიყვანე, დაიცავი სხვა ფიგურით ან აიღე ის, ვინც ემუქრება.'],
  ['start',G=>G.mine(),'ფიგურის გადასაყვანად შეეხე მას, მერე ოქროსფრად მონიშნულ უჯრას. ფიგურა თითით გადათრევითაც გადადის.'],
  ['take',G=>G.mine()&&G.moves.some(m=>G.st.b[m.t]),'მეტოქის ფიგურის აღება შეიძლება: აირჩიე შენი ფიგურა და ოქროსფერი რგოლი გაჩვენებს, სადაა აღებადი.'],
  ['castle',G=>G.mine()&&G.moves.some(m=>m.cs),'როქი: მეფე ორი უჯრით გადადის ეტლისკენ, ეტლი კი მის მეორე მხარეს დგება. შეეხე მეფეს და მერე მონიშნულ უჯრას.'],
  ['promo',G=>G.mine()&&G.moves.some(m=>m.pr),'პაიკი ბოლო ხაზამდე მიდის და ნებისმიერ ფიგურად იქცევა. ჩვეულებრივ ლაზიერს ირჩევენ.']],
 shashi:[['must',G=>G.mine()&&G.moves.length&&G.moves[0].caps.length,'ჭრა სავალდებულოა: მოციმციმე ქვამ მეტოქის ქვა უნდა გადახტეს. თუ ჭრა გრძელდება, ქვა ზედიზედ ჭრის.'],
  ['start',G=>G.mine(),'ქვა დიაგონალზე, ერთი უჯრით წინ დადის. შეეხე ქვას და მერე მონიშნულ უჯრას.'],
  ['king',G=>G.mine()&&G.b.flat().includes(2*G.ctx.side),'შენი ქვა დამა გახდა: ახლა მთელ დიაგონალზე დადის, წინაც და უკანაც.']],
 nardi:[['roll',G=>G.mine()&&!G.rolled,'შენი ჯერია. დააჭირე „გაგორებას“ ან თითი სწრაფად აუსვი დაფას ზემოთ.'],
  ['bar',G=>G.mine()&&G.rolled&&G.bar[G.ctx.side]>0,'შენი ქვა ზარზეა: სხვა სვლამდე ის მეტოქის სახლში უნდა შემოიყვანო.'],
  ['off',G=>G.mine()&&G.rolled&&(G.v==='long'?lHome(G,G.ctx.side):nHome(G,G.ctx.side)),'ყველა ქვა სახლშია! ახლა გატანას იწყებ: ქვა დაფიდან გადის.'],
  ['hit',G=>G.mine()&&G.rolled&&G.legal().some(m=>m.to!=='off'&&G.p[m.to]*G.ctx.side===-1),'მეტოქის მარტოხელა ქვაზე დადგომით მას მოკლავ და ზარზე გადავა.'],
  ['move',G=>G.mine()&&G.rolled&&G.legal().length,'შენი ქვები 24-დან 1-ისკენ, ქვედა მარჯვენა სახლისკენ მიდიან. შეეხე ოქროსფერ რგოლიან ქვას, მერე მონიშნულ ადგილს.']],
 domino:[['start',G=>G.phase==='play'&&G.cur===0&&G.moves(0).length,'ქვა ერთ-ერთ ღია ბოლოს უნდა მიუდო, რომელზეც იგივე რიცხვია. შესაფერისი ქვები ოდნავ აწეულია.'],
  ['pass',G=>G.phase==='play'&&G.cur===0&&!G.moves(0).length,'შესაფერისი ქვა არ გაქვს, ამიტომ პასობ. ეს ჩვეულებრივი ამბავია.'],
  ['team',G=>G.phase==='roundover'&&G.np!==2&&G.np!==3,'ანა შენი პარტნიორია. ვინც პირველი დაცლის ხელს, მისი გუნდი მეტოქეების ქვების ქულებს იღებს.']],
 joker:[['bid',G=>G.phase==='bid'&&G.cur===0,'თქვი, რამდენ ხელს წაიღებ. მონიშნული ღილაკი რჩევაა.'],
  ['joker',G=>G.phase==='play'&&G.cur===0&&G.hands[0].some(x=>x.j),'ჯოკერი ნებისმიერ დროს შეგიძლია დადო: „მაღალი“ წაიღებს ხელს, „დაბალი“ არა.'],
  ['follow',G=>G.phase==='play'&&G.cur===0&&G.trick.length>0,'ფერს უნდა აჰყვე. თუ ფერი არ გაქვს, კოზირი უნდა დადო, თუ არც კოზირი, ნებისმიერი კარტი.']]};
function gCoach(G){const c=G&&G.ctx;if(!c||c.mode!=='learn'||S.tab!=='games'||S.page||!COACH[c.gk])return;const seen=c.tips||(c.tips={});if(c.tipOn||G.res&&G.res())return;
 for(const[k,when,txt]of COACH[c.gk]){if(seen[k])continue;let ok=false;try{ok=!!when(G)}catch(e){}if(!ok)continue;seen[k]=1;c.tipOn=1;
  let el=$('#gcoach');if(!el){el=document.createElement('div');el.id='gcoach';document.body.appendChild(el)}el.className='gcoach';el.innerHTML=`<span class="gco">${ic('school')}</span><p>${txt}</p><button class="btn sm" data-a="gcoachok">გასაგებია</button>`;
  clearTimeout(gCoach.t);gCoach.t=setTimeout(()=>A.gcoachok(),14000);return}}
A.gcoachok=()=>{const el=$('#gcoach');if(el)el.remove();clearTimeout(gCoach.t);const G=GAME[S.game];if(G&&G.ctx){G.ctx.tipOn=0;setTimeout(()=>{if(GAME[S.game]===G)gCoach(G)},400)}};
{const sm=stopMedia;stopMedia=function(){sm();const el=$('#gcoach');if(el)el.remove()}}
{const lb=A.lobby;A.lobby=()=>{const el=$('#gcoach');if(el)el.remove();lb()}}
for(const G of[DM,JK]){const r=G.render;G.render=function(){r.call(this);gCoach(this)}}
const gLearnPick=()=>sheet(head('სწავლა')+`<p class="note" style="margin:0 0 10px">პირველი პარტია ყველაზე მშვიდ მოთამაშესთან. მწვრთნელი თამაშის დროს აგიხსნის, რა ხდება.</p><div class="jchoice">${GAMES.map(g=>`<button data-a="glearn" data-g="${g.id}">${g.n}</button>`).join('')}</div>`,'short');
A.glearnpick=()=>gLearnPick();
A.glearn=t=>{const g=t.dataset.g;if(!GAME[g])return;closeSheet();gToTab();const ch=BOTC[1];
 if(g==='joker'){startGame('joker',{mode:'learn',gk:'joker',lvl:1});JK.begin('quick');return}
 if(g==='domino'){startGame('domino',{mode:'learn',gk:'domino',lvl:1});return}
 startGame(g,{mode:'learn',lvl:1,names:{1:ME.name,'-1':ch.n},avs:{1:'me','-1':botAv(ch)},gk:g})};

/* ---------- the lobby: the other ways to play ---------- */
function gModesHTML(){const n=Object.keys(cState().done).length,nx=cNext(),dd=typeof jdToday==='function'?jdToday():null;
 return `<section class="gs-modes"><h3 class="sec">სხვა რეჟიმები</h3><div class="gmodes">
  <button class="gmode" data-a="page" data-p="career"><span class="gmi">${ic('trophy')}</span><b>ეზოდან ჩემპიონატამდე</b><small>${nx?`${n}/${CAREER.length} · შემდეგი: ${esc(nx.who.n)}`:'ჩემპიონი ხარ 🏆'}</small></button>
  <button class="gmode" data-a="gdaily"><span class="gmi">${ic('cards')}</span><b>დღის ხელი</b><small>${dd&&dd.done?`დღეს: ${dd.score} ქულა`:'ჯოკერი · დღეს ყველას ერთი კარტი'}</small></button>
  <button class="gmode" data-a="glocalpick"><span class="gmi">${ic('users')}</span><b>ორნი ერთ ტელეფონზე</b><small>ნარდი, ჭადრაკი, შაში, კვერცხის ჭახუნი</small></button>
  <button class="gmode" data-a="glearnpick"><span class="gmi">${ic('school')}</span><b>სწავლა</b><small>პირველი პარტია მწვრთნელთან ერთად</small></button>
  <button class="gmode" data-a="sprint"><span class="gmi">${ic('timer')}</span><b>ამოცანების სპრინტი</b><small>სამი წუთი${typeof SPR!=='undefined'&&SPR.best?` · რეკორდი ${SPR.best}`:', რამდენ მატს იპოვი'}</small></button>
  <button class="gmode" data-a="page" data-p="corrs"><span class="gmi">${ic('msg')}</span><b>მიმოწერით</b><small>სვლა, როცა გცალია</small></button>
  <button class="gmode" data-a="page" data-p="cups"><span class="gmi">${ic('crown')}</span><b>თასები და დუელები</b><small>თასი მეგობრებთან, ჯგუფი ჯგუფის წინააღმდეგ</small></button>
  <button class="gmode" data-a="gtablepick"><span class="gmi">${ic('wine')}</span><b>მეგობრების მაგიდა</b><small>ჯოკერი, დომინო ან ლოტო, ხმოვანი საუბრით</small></button></div></section>`}
A.gtablepick=()=>sheet(head('მეგობრების მაგიდა')+`<div class="jchoice"><button data-a="jkonew">${ic('cards')} ჯოკერი</button><button data-a="dmonew">${ic('domino')} დომინო</button><button data-a="lotnew">${ic('grid')} ლოტო</button></div><p class="note">მაგიდას შენ გაშლი და მეგობრებს მოიწვევ. ცარიელ ადგილებზე ბოტები ჩაჯდებიან, მაგიდასთან კი მიკროფონით შეგიძლიათ ისაუბროთ.</p>`,'short');

/* ---------- time on the clock ----------
   chess: blitz or rapid; checkers and nardi: a few minutes each with seconds back after every move.
   against the computer and on one phone it applies from the next new game; online the one who challenges picks it */
const GTC={chess:[['none','დროის გარეშე'],['3+2','ბლიცი: 3 წუთი, +2 წამი'],['5+0','ბლიცი: 5 წუთი'],['10+0','რაპიდი: 10 წუთი'],['15+10','რაპიდი: 15 წუთი, +10 წამი']],
 shashi:[['none','დროის გარეშე'],['3+3','3 წუთი, +3 წამი'],['5+5','5 წუთი, +5 წამი'],['10+5','10 წუთი, +5 წამი']],
 nardi:[['none','დროის გარეშე'],['3+5','3 წუთი, +5 წამი'],['5+8','5 წუთი, +8 წამი'],['10+8','10 წუთი, +8 წამი']]};
const gTcSet=g=>{const v=store.get('gtc:'+g,'none');return GTC[g]&&GTC[g].some(x=>x[0]===v)?v:'none'};
const tcParse=v=>{const m=/^(\d{1,2})\+(\d{1,2})$/.exec(String(v||''));return m?[+m[1]*60,+m[2]]:undefined};
function gTcOf(g){const v=gTcSet(g);return v==='none'?undefined:tcParse(v)}

/* ---------- joker house rules ---------- */
const JKO={kh:[['std','სტანდარტი: −200, ცხრიანებში −500'],['200','ყოველთვის −200'],['500','ყოველთვის −500'],['0','ხიშტის გარეშე']],tt:[[30,'30 წამი'],[60,'60 წამი'],[90,'90 წამი']]};
function jkOptGet(){const o=store.get('jkopt',null)||{};return{kh:JKO.kh.some(x=>x[0]===o.kh)?o.kh:'std',prem:o.prem!==false,tt:[30,60,90].includes(o.tt)?o.tt:60}}
const jkOpt=c=>c&&(c.daily||c.mode==='learn')?{kh:'std',prem:true,tt:60}:jkOptGet();
const jkOptTxt=o=>`ხიშტი: ${JKO.kh.find(x=>x[0]===o.kh)[1].split(':')[0].replace('სტანდარტი','სტანდარტული')} · პრემია: ${o.prem?'კი':'არა'}`;

/* ---------- a nardi match: games are played until someone reaches 3, 5 or 7 points (მარსი two, კოქსი three) ---------- */
const nMatchSet=()=>{const v=+store.get('nmatch',1);return[1,3,5,7].includes(v)?v:1};
{const st=NR.start,sn=NR.snap,ld=NR.load,stt=NR.status;
 NR.start=function(){const c=this.ctx;if(c&&c.match==null)c.match=['bot','local'].includes(c.mode)?nMatchSet():1;st.call(this)};
 NR.snap=function(){const s=sn.call(this),c=this.ctx;if(c&&c.match>1)Object.assign(s,{mt:c.match,ms:c.ms||{1:0,'-1':0}});return s};
 NR.load=function(s){ld.call(this,s);const c=this.ctx;if(c&&s&&[3,5,7].includes(s.mt)&&s.ms){c.match=s.mt;c.ms={1:Math.max(0,Math.min(9,+s.ms[1]||0)),'-1':Math.max(0,Math.min(9,+s.ms['-1']||0))}}};
 NR.status=function(){const s=stt.call(this),c=this.ctx;return c&&c.match>1?`<b>მატჩი ${(c.ms||{})[c.side]||0}:${(c.ms||{})[-c.side]||0}</b> (${c.match}-მდე) · `+s:s}}
/* a game inside a match ends with the score and the next game; only the match itself counts as a win */
{const fin=finish;finish=function(G,w){const c=G&&G.ctx;if(G===NR&&c&&c.match>1&&!c.finished&&!c.midDone&&(w===1||w===-1)){const r=NR.res()||{},why=r.why;
  if(why!=='resign'&&why!=='time'&&why!=='gone'){c.ms=c.ms||{1:0,'-1':0};c.ms[w]+=r.mult||1;if(c.ms[w]<c.match){c.mid=1;c.midDone=1;c.finAt=performance.now();G.resSnd=0;G.render();if(sayBot(c)!=null)gSay(sayBot(c),w===sayBot(c)?'winBot':'loseBot',{nm:sayNm(c),ms:900});return}}}
 if(G===NR&&c&&c.match>1&&c.ms&&w!==2&&(c.ms[w]||0)>=c.match&&w===c.side&&isPlayer(c)&&c.mode!=='local'&&c.match>=5)gBadge('match');fin(G,w)}}
/* the giveaway game says so on the board, so nobody plays it the usual way by mistake */
{const st=CK.status;CK.status=function(...a){const s=st.apply(this,a);return this.v==='give'&&!this.over?'<b>წაგებანა</b> · '+s:s}}
A.nnext=()=>{const G=NR,c=G.ctx;if(!c||!c.mid)return;c.mid=0;c.midDone=0;c.finAt=0;c.cined=0;G.resHide=0;G.resSnd=0;G.start();G.render();G.kick()};
function nMatchHTML(G){const c=G.ctx,r=G.res()||{},me=c.side,loc=c.mode==='local',win=r.w===me;
 return gResBox(G,{title:loc?esc(c.names[r.w])+' იგებს თამაშს':win?'თამაში შენია':'ეს თამაში წააგე',sub:`მატჩი ${c.match}-მდე · ანგარიში ${c.ms[me]}:${c.ms[-me]}`+(r.mult>1?' · '+MULT[r.mult]:''),kind:win||loc?'win':'lose',
  again:'<button class="btn gold" data-a="nnext">შემდეგი თამაში</button>',leave:'<button class="btn ghost" data-a="lobby">ლობი</button>'})}

/* ---------- hints: the best move in nardi and a card in joker, and a word when a nardi move was clearly worse ---------- */
const gHintOn=()=>store.get('ghint2',true)!==false;
A.ghint2=t=>{const on=!gHintOn();store.set('ghint2',on);gSwFlip(t,on);gRedraw()};
const gHintOk=c=>!!c&&['bot','learn','local'].includes(c.mode)&&gHintOn();
const nPtNo=(G,i)=>i==='bar'?'ზარი':i==='off'?'გატანა':String(G.v==='long'?24-lStep(G.ctx.side,i):G.ctx.side===1?i+1:24-i);
A.nhint=()=>{const G=NR,c=G.ctx;if(!G.mine()||!G.rolled||!gHintOk(c))return;const seq=(G.v==='long'?lBest:nBest)(G,c.side,G.dice,4);if(!seq.length)return;G.hint=seq;G.render()};
/* the position as the turn began, kept to compare with what was played */
{const ro=NR.roll,et=NR.endTurn,mv=NR.move,rn=NR.render;
 NR.roll=function(){ro.call(this);this.hint=null;const c=this.ctx;this.t0=c&&gHintOk(c)&&(this.turn===c.side||c.mode==='local')?{T:(this.v==='long'?lCopy:nCopy)(this),dice:this.dice.slice(),s:this.turn}:null};
 NR.move=function(s,f,to,d){mv.call(this,s,f,to,d);if(this.hint&&this.hint.length){const h=this.hint[0];this.hint=h.f===f&&h.to===to?this.hint.slice(1):null}};
 NR.endTurn=function(){const t0=this.t0;this.t0=null;this.hint=null;if(t0&&!this.over&&this.turn===t0.s)try{const xs=(this.v==='long'?lSeqs:nSeqs)(t0.T,t0.s,t0.dice);if(xs.length>1){const ev=this.v==='long'?lEval:nEval4;let best=null,bv=-1e9;for(const x of xs){const v=ev(x.t,t0.s);if(v>bv){bv=v;best=x}}
   const mine=ev(this,t0.s);if(bv-mine>3.5&&best)gTip(`ეს სვლა სუსტი იყო. უკეთესი იყო: ${best.seq.map(m=>nPtNo(this,m.f)+' → '+nPtNo(this,m.to)).join(', ')}`)}}catch(e){}et.call(this)};
 NR.render=function(){rn.call(this);if(S.tab!=='games'||S.game!=='nardi')return;const c=this.ctx;
  /* the hint, in words and on the board; a quick flick up the board throws the dice */
  if(this.hint&&this.hint.length&&this.mine()){const st=$('.status',view);if(st)st.innerHTML+=`<small class="bhint">რჩევა: ${this.hint.map(m=>nPtNo(this,m.f)+' → '+nPtNo(this,m.to)).join(', ')}</small>`;const h=this.hint[0];for(const k of[h.f,h.to]){const el=$(`.pt[data-k="${k}"],.barc[data-k="${k}"]`,view);if(el)el.classList.add('hint')}}
  const ctl=$('.nctl',view);if(ctl&&this.mine()&&this.rolled&&gHintOk(c)&&this.legal().length&&!$('[data-a="nhint"]',ctl)){ctl.insertAdjacentHTML('beforeend',`<button class="btn ghost sm" data-a="nhint">${ic('help')}რჩევა</button>`)}
  const nb=$('.nb',view);if(nb&&!nb.dataset.fl){nb.dataset.fl=1;let s0=null;nb.addEventListener('pointerdown',e=>{s0={y:e.clientY,x:e.clientX,t:performance.now()}});nb.addEventListener('pointerup',e=>{if(!s0)return;const dy=s0.y-e.clientY,dx=Math.abs(e.clientX-s0.x),dt=performance.now()-s0.t;s0=null;if(dt<330&&dy>60&&dx<dy&&NR.mine()&&!NR.rolled)A.nroll()})}}}
/* a short word from the coach that does not wait for a moment of its own */
function gTip(txt){let el=$('#gcoach');if(!el){el=document.createElement('div');el.id='gcoach';document.body.appendChild(el)}el.className='gcoach';el.innerHTML=`<span class="gco">${ic('help')}</span><p>${esc(txt)}</p><button class="btn sm" data-a="gcoachok">გასაგებია</button>`;clearTimeout(gCoach.t);gCoach.t=setTimeout(()=>{const e=$('#gcoach');if(e)e.remove()},9000)}
/* joker: the card the careful player would play now */
function jkPlayHint(){if(JK.phase!=='play'||JK.cur!==0||JK.win!=null||!jHintOn()||!JK.ctx||!['bot','learn'].includes(JK.ctx.mode))return null;try{const px=Object.create(JK),m=JK.botPlay.call(px,0);return m&&m.c?m:null}catch(e){return null}}
{const r=JK.render;JK.render=function(){r.call(this);if(S.tab!=='games'||S.game!=='joker'||S.page)return;const m=jkPlayHint();this.hintC=m?m.c:null;if(!m)return;const i=this.hands[0].indexOf(m.c),b=$(`.hand [data-i="${i}"]`,view);if(b)b.classList.add('hint');
 const st=$('.status',view),need=this.bids[0]-this.taken[0];if(st)st.innerHTML+=`<small class="bhint">რჩევა: ${cardName(m.c)}${m.c.j?` (${m.jm==='lo'?'დაბალი':'მაღალი'})`:''} · ${need>0?`კიდევ ${need} ხელი გჭირდება`:'ხელი აღარ გჭირდება'}</small>`}}

/* ---------- big buttons and letters, for an easier read and an easier tap ---------- */
const gBigOn=()=>!!store.get('gbig',false);
try{document.documentElement.classList.toggle('gbig',gBigOn())}catch(e){}
A.gbigt=t=>{const on=!gBigOn();store.set('gbig',on);document.documentElement.classList.toggle('gbig',on);gSwFlip(t,on);gRedraw()};

/* ---------- nardi: the dice thrown by shaking the phone ---------- */
const gShakeOn=()=>!!store.get('gshake',false);
let GSHK={t:0,on:false,last:null};
function gShakeArm(){if(GSHK.on||!gShakeOn()||typeof window.DeviceMotionEvent==='undefined')return;GSHK.on=true;
 window.addEventListener('devicemotion',e=>{const a=e.accelerationIncludingGravity||e.acceleration;if(!a||a.x==null)return;const v=[a.x,a.y,a.z],L=GSHK.last;GSHK.last=v;if(!L||!gShakeOn())return;
  const d=Math.abs(v[0]-L[0])+Math.abs(v[1]-L[1])+Math.abs(v[2]-L[2]),now=Date.now();if(d>26&&now-GSHK.t>1500&&S.tab==='games'&&S.game==='nardi'&&!S.page&&NR.mine()&&!NR.rolled){GSHK.t=now;if(typeof gBuzz==='function')gBuzz(30);A.nroll()}})}
A.gshaket=async t=>{const on=!gShakeOn();if(on&&typeof window.DeviceMotionEvent!=='undefined'&&typeof window.DeviceMotionEvent.requestPermission==='function'){try{const r=await window.DeviceMotionEvent.requestPermission();if(r!=='granted'){toast('მოძრაობის სენსორზე წვდომა არ მოგვცეს');return}}catch(e){toast('მოძრაობის სენსორი ვერ ჩაირთო');return}}
 if(on&&typeof window.DeviceMotionEvent==='undefined'){toast('ამ მოწყობილობას მოძრაობის სენსორი არ აქვს');return}store.set('gshake',on);gSwFlip(t,on);if(on){gShakeArm();toast('შეარხიე ტელეფონი და კამათელი გაგორდება')}};
gShakeArm();

/* ---------- the sheet with the kind of game: variant, match, players, rules and time ---------- */
A.gvar=()=>{const id=gCur(),G=GAME[id],c=G&&G.ctx;if(!id)return;const row=(lab,a,v,cur,txt)=>`<button data-a="${a}" data-v="${v}"${String(v)===String(cur)?' aria-pressed="true"':''}>${ic(String(v)===String(cur)?'check':'turn')}<span>${txt}</span></button>`;let h='';
 if(id==='nardi'){const v=store.get('nv','short'),m=nMatchSet();h+=`<h4 class="gvh">ნარდის სახე</h4>${row('','gvset','nv:short',v==='long'?'':'nv:short','მოკლე ნარდი (ტავლა)')}${row('','gvset','nv:long',v==='long'?'nv:long':'','გრძელი ნარდი')}
  <h4 class="gvh">მატჩი</h4>${[1,3,5,7].map(k=>row('','gvset','nmatch:'+k,'nmatch:'+m,k===1?'ერთი თამაში':k+' ქულამდე')).join('')}`}
 if(id==='shashi'){const v=store.get('cv','std');h+=`<h4 class="gvh">შაშის სახე</h4>${row('','gvset','cv:std',v==='give'?'':'cv:std','ჩვეულებრივი')}${row('','gvset','cv:give',v==='give'?'cv:give':'','წაგებანა: იგებს, ვინც ყველა ქვას დაკარგავს')}`}
 if(id==='domino'){const n=dmNp(null);h+=`<h4 class="gvh">მოთამაშეები</h4>${[4,3,2].map(k=>row('','gvset','dmn:'+k,'dmn:'+n,k===4?'ოთხი, წყვილებში':k+' მოთამაშე, ბაზრით')).join('')}<button data-a="dmonew">${ic('users')}<span>მეგობრებთან ონლაინ: ახალი მაგიდა</span></button>`}
 if(id==='joker'){const o=jkOptGet();h+=`<h4 class="gvh">ხიშტი</h4>${JKO.kh.map(([k,t])=>row('','gvset','kh:'+k,'kh:'+o.kh,t)).join('')}<h4 class="gvh">სექციის პრემია</h4>${row('','gvset','prem:1',o.prem?'prem:1':'prem:0','კი')}${row('','gvset','prem:0',o.prem?'prem:1':'prem:0','არა')}`}
 if(id==='durak'){const n=dkNp();h+=`<h4 class="gvh">მოთამაშეები</h4>${[2,3,4].map(k=>row('','gvset','dkn:'+k,'dkn:'+n,k+' მოთამაშე')).join('')}`}
 if(id==='bura'){const v=buTo();h+=`<h4 class="gvh">მატჩი</h4>${[3,5,7].map(k=>row('','gvset','buto:'+k,'buto:'+v,k+' ქულამდე')).join('')}`}
 if(GTC[id]){const v=gTcSet(id);h+=`<h4 class="gvh">დრო</h4>${GTC[id].map(([k,t])=>row('','gvset','tc:'+k,'tc:'+v,t)).join('')}`}
 sheet(head('თამაშის სახე')+`<div class="gmenu gvar">${h}<p class="note">ცვლილება ახალი პარტიიდან მოქმედებს.${c&&['bot','local','learn'].includes(c.mode)&&!S.page?' <button class="btn sm" data-a="gvnew">ახალი პარტია ახლავე</button>':''}</p></div>`,'short')};
A.gvset=t=>{const[k,v]=String(t.dataset.v).split(':'),id=gCur();
 if(k==='nv')store.set('nv',v==='long'?'long':'short');else if(k==='nmatch')store.set('nmatch',+v);else if(k==='cv')store.set('cv',v==='give'?'give':'std');else if(k==='dmn')store.set('dmn',+v);else if(k==='dkn')store.set('dkn',+v);else if(k==='buto')store.set('buto',+v);
 else if(k==='kh'){const o=jkOptGet();o.kh=v;store.set('jkopt',o)}else if(k==='prem'){const o=jkOptGet();o.prem=v==='1';store.set('jkopt',o)}else if(k==='tc'&&id)store.set('gtc:'+id,v);
 A.gvar()};
A.gvnew=()=>{const G=GAME[S.game],c=G&&G.ctx;closeSheet();if(!c)return;if(c.mode==='local'){A.glocalagain();return}if(S.game==='joker'){G.resHide=0;G.start();G.render();return}if(S.game==='domino'){G.resHide=0;G.resSnd=0;startGame('domino',{mode:c.mode});return}A.restart()};

/* ---------- badges for each game: earned once, kept on the phone and shown on the game card ----------
   each also brings a few coins once the server can give them (the database update); until then they are just yours to keep */
const GBADGES=[['mars','nardi','მარსი','მოიგე მარსით',10],['koks','nardi','კოქსი','მოიგე კოქსით',20],['mars10','nardi','მარსის ოსტატი','10 მოგება მარსით',30],['longw','nardi','გრძელი გზა','მოიგე გრძელი ნარდი',10],['match','nardi','მატჩის გამარჯვებული','მოიგე მატჩი 5 ან 7 ქულამდე',20],
 ['mate20','chess','სწრაფი მატი','მატი 20 სვლაში',20],['master','chess','ოსტატის დამარცხება','მოუგე ოსტატ გურამს',30],['pz7','chess','ამოცანების კვირა','დღის ამოცანა 7 დღე ზედიზედ',20],
 ['king','shashi','დამა','მოიგე პარტია, რომელშიც დამა გამოიყვანე',10],['take3','shashi','სამმაგი ჭრა','ერთი სვლით სამი ქვა მოჭერი',20],['give','shashi','წაგებანას ოსტატი','მოიგე წაგებანა',10],
 ['prem','joker','პრემია','სექციის ყველა ხელში ზუსტად თქვი',20],['k1000','joker','ათასი ქულა','სრულ თამაშში 1000-ზე მეტი ქულა',30],['daily','joker','დღის ხელი','ითამაშე დღის ხელი',10],
 ['fish','domino','ფიში','მოიგე ჩაკეტილი ხელი',10],['dry','domino','მშრალად','მოიგე ისე, რომ მეტოქეს ქულა არ დაუწერია',30],
 ['career3','career','შუა გზაზე','კარიერის სამი ეტაპი',20],['career6','career','ჩემპიონი','კარიერა ბოლომდე',50]];
const gBState=()=>{const s=store.get('gbadges',null);return s&&typeof s==='object'?Object.assign({got:{},n:{}},s):{got:{},n:{}}};
function gBadge(id){const b=GBADGES.find(x=>x[0]===id);if(!b)return;const s=gBState();if(s.got[id])return;s.got[id]=Date.now();store.set('gbadges',s);
 setTimeout(()=>toast(`🏅 ახალი ნიშანი: ${b[2]}`),1800);rpc('game_badge',{p_badge:id}).then(r=>{if(r&&r.coins!=null){setCoins(r.coins);toast(`+${b[4]} მონეტა ნიშნისთვის`)}}).catch(()=>{})}
const gBCount=k=>{const s=gBState();s.n[k]=(s.n[k]||0)+1;store.set('gbadges',s);return s.n[k]};
/* what each finished game earns */
{const fin=finish;finish=function(G,w){const c=G&&G.ctx,was=c&&c.finished;fin(G,w);if(was||!c||!c.finished||!isPlayer(c)||['local','learn','puzzle'].includes(c.mode)||w!==c.side)return;const r=G.res&&G.res()||{};
 if(G===NR){if(r.mult===2){gBadge('mars');if(gBCount('mars')>=10)gBadge('mars10')}if(r.mult===3)gBadge('koks');if(NR.v==='long')gBadge('longw')}
 if(G===CH){if(r.why==='mate'&&(CH.mv||[]).length<=40)gBadge('mate20');if((c.lvl||bLvl('chess'))===4)gBadge('master')}
 if(G===CK){if(c.madeKing)gBadge('king');if(CK.v==='give')gBadge('give')}}}
{const pl=CK.play;CK.play=function(m){const c=this.ctx,mover=this.turn,p0=this.b[m.path[0][0]][m.path[0][1]];pl.call(this,m);if(!c||this.ctx!==c||mover!==c.side||['local','learn','watch','netwatch'].includes(c.mode))return;
 const e=m.path[m.path.length-1];if(Math.abs(p0)===1&&Math.abs(this.b[e[0]][e[1]])===2)c.madeKing=1;if(m.caps.length>=3)gBadge('take3')}}
{const eh=JK.endHand;JK.endHand=function(){eh.call(this);if(this!==JK||!this.ctx||this.ctx.mode==='learn')return;const pr=this.hist[this.hist.length-1];if(pr&&pr.pr&&pr.p[0]>0)gBadge('prem');if(this.phase==='over'){if(this.len==='full'&&this.score[0]>1000)gBadge('k1000');if(this.ctx.daily)gBadge('daily')}}}
{const er=DM.endRound;DM.endRound=function(kind,p){er.call(this,kind,p);if(!this.ctx||this.ctx.mode==='learn')return;const r=this.res||{};if(kind==='block'&&((this.np||4)<4?r.win===0:r.win===0))gBadge('fish');
 if(this.phase==='over'&&((this.np||4)<4?this.pts[0]===Math.max(...this.pts)&&this.pts.every((x,i)=>i===0||x===0):this.score[0]>this.score[1]&&this.score[1]===0))gBadge('dry')}}
{const ps=pzSolved;pzSolved=function(G){ps(G);if(pzState().streak>=7)gBadge('pz7')}}
/* career milestones */
{const fin=finish;finish=function(G,w){fin(G,w);const n=Object.keys(cState().done).length;if(n>=3)gBadge('career3');if(n>=CAREER.length)gBadge('career6')}}
function gBadgesHTML(){const s=gBState(),got=GBADGES.filter(b=>s.got[b[0]]);
 return `<div class="gbadges"><h4>ნიშნები <small>${got.length}/${GBADGES.length}</small></h4><div class="gbl">${GBADGES.map(b=>{const has=!!s.got[b[0]];return `<span class="gbd${has?' on':''}" title="${esc(b[3])}"><i>${has?'🏅':'○'}</i><b>${esc(b[2])}</b><small>${esc(b[3])}</small></span>`}).join('')}</div></div>`}

/* ---------- leagues by rating, one in each game ----------
   the name follows the rating, so winning moves you up and losing can move you down */
const LEAGUES=[[0,'ეზოს მოთამაშე'],[1450,'უბნის ოსტატი'],[1550,'ქალაქის ჩემპიონი'],[1650,'კუთხის ჩემპიონი'],[1800,'საქართველოს ჩემპიონი']];
const gLeague=r=>{let n=LEAGUES[0][1];for(const[x,t]of LEAGUES)if((r||1500)>=x)n=t;return n};

/* ---------- the hand of the day: one quick game of joker, dealt the same for everyone today ----------
   the first game of the day counts; you can play it again, but only the first score stays */
const jdDay=()=>pzDay();
/* a small seeded random of our own (the 3D files, which have one, may not be loaded) */
const jdSeed=s=>{let k=2166136261;for(const ch of String(s)){k^=ch.charCodeAt(0);k=Math.imul(k,16777619)>>>0}return k||1};
const jdRng=seed=>{let s=seed>>>0||1;return()=>{s^=s<<13;s^=s>>>17;s^=s<<5;return(s>>>0)/4294967296}};
function jdToday(){const v=store.get('jd:'+jdDay(),null);return v?{done:true,score:v.score}:{done:false}}
A.gdaily=()=>{gToTab();startGame('joker',{mode:'bot',gk:'joker',daily:jdDay()});JK.begin('quick')};
/* a fixed shuffle for the day: the same seed gives the same deal to everyone */
{const nh=JK.newHand,bg=JK.begin;
 JK.begin=function(len){const c=this.ctx;if(this===JK&&c&&c.daily){const R=jdRng(jdSeed('jd'+c.daily)),mr=Math.random;Math.random=R;try{bg.call(this,len)}finally{Math.random=mr}return}bg.call(this,len)};
 JK.newHand=function(){const c=this.ctx;if(this===JK&&c&&c.daily){const R=jdRng(jdSeed('jd'+c.daily+':'+this.h)),mr=Math.random;Math.random=R;try{nh.call(this)}finally{Math.random=mr}return}nh.call(this)}}
{const eh=JK.endHand;JK.endHand=function(){eh.call(this);const c=this.ctx;if(this!==JK||!c||!c.daily||this.phase!=='over')return;const k='jd:'+c.daily;if(store.get(k,null))return;const sc=this.score[0];store.set(k,{score:sc,at:Date.now()});c.jdNew=1;
 q(sb.from('game_daily').upsert({user_id:ME.id,day:c.daily,game:'joker',score:sc},{onConflict:'user_id,day,game',ignoreDuplicates:true})).catch(()=>{});jdLoadFriends(c)}}
async function jdLoadFriends(c){try{const fr=[ME.id,...FRIENDS].slice(0,300),rows=await q(sb.from('game_daily').select('user_id,score').eq('day',c.daily).eq('game','joker').in('user_id',fr).order('score',{ascending:false}).limit(20));await loadProfiles(rows.map(r=>r.user_id));c.jdRows=rows}catch(e){c.jdRows=null;c.jdErr=1}if(GAME.joker.ctx===c&&S.game==='joker')JK.render()}
function jdMoreHTML(c){const v=store.get('jd:'+c.daily,null);let h=`<p class="gendr">${ic('cards')}<span>დღის ხელი${v?` · ჩაითვალა: <b>${v.score}</b> ქულა`:''}${v&&!c.jdNew?' (დღევანდელი პირველი თამაში)':''}</span></p>`;
 if(c.jdRows&&c.jdRows.length)h+=`<div class="gendt">${c.jdRows.slice(0,6).map(r=>`<span><b>${esc(r.user_id===ME.id?'შენ':String(pname(r.user_id)).split(' ')[0])}</b>${r.score}</span>`).join('')}</div>`;
 else if(c.jdErr)h+='<p class="note">მეგობრების შედეგები ბაზის განახლების შემდეგ გამოჩნდება.</p>';return h}
