const fs=require('fs'),vm=require('vm');const APP='/home/claude/sufra-app/js/';
const ctx={console,Math,JSON,setTimeout:()=>0,clearTimeout(){},S:{tab:'games',game:null,page:null},ME:{name:'მე',rating:1500},view:{},A:{},GAME:{},
 esc:s=>String(s),ic:()=>'',av:()=>'',avAny:()=>'',sheet(){},head:()=>'',closeSheet(){},toast(){},confirmSheet(){},gview(){},gTop:()=>'',g3Board:(i,d)=>d,g3After(){},g3On:()=>false,g3Rv:()=>'',
 finish(G,w){G.fin=w},netSend(){},gameResult(g,w){ctx.lastResult=[g,w]},tourBack:()=>'',isPlayer:c=>c.mode==='bot'||c.mode==='online'||c.mode==='tour',endMsg:()=>'',
 shuffle:a=>{for(let i=a.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a},JK_BOTS:['ნინო','ლუკა','დათო'],JK_ERG:['ნინომ','ლუკამ','დათომ'],
 flipPiece(){},castRoll(){},castBy:()=>({n:'ბოტი',id:'b'}),TCAST:[0,0,0,0],store:{get:(k,d)=>d,set(){}},$:()=>null,$$:()=>[],anim(){},pop(){},EASE:'',SPRING:'',PIPS:null};
vm.createContext(ctx);
for(const f of['games-engines.js','domino.js'])vm.runInContext(fs.readFileSync(APP+f,'utf8'),ctx,{filename:f});
const R=s=>{try{return vm.runInContext(s,ctx)}catch(e){console.log("ERR IN:",s.slice(0,240));throw e}};let fails=0,n=0;const ok=(c,m)=>{n++;if(!c){fails++;console.log('FAIL',m)}};
/* hundreds of whole Joker games, every seat a bot (levels 1 to 5), each move and each score checked against the rules written out again here */
R(`var JKS={};var gRxShow=()=>{},jkStatHand=()=>{},jkStatGame=()=>{},gEndGest=()=>{},GSND={}`);
const LEN=['quick','full','nines'];let games=0,hands=0,tricks=0;const lvWins=[0,0,0,0,0,0],lvGames=[0,0,0,0,0,0],lvPts=[0,0,0,0,0,0];
const legalRef=(hand,trick,trump)=>{if(!trick.length)return hand.slice();const L=trick[0],suit=L.card.j?L.js:L.card.s,jk=hand.filter(c=>c.j),of=hand.filter(c=>!c.j&&c.s===suit);
 if(of.length){if(L.card.j&&L.jm==='hi'){const mx=Math.max(...of.map(c=>c.r));return[...of.filter(c=>c.r===mx),...jk]}return[...of,...jk]}
 const tr=trump?hand.filter(c=>!c.j&&c.s===trump):[];return tr.length?[...tr,...jk]:hand.slice()};
const ptsRef=(b,t,n,kh)=>t===b?(b===n?100*n:b===0?50:50*b+50):(b>0&&t===0?-kh:10*t);
for(let g=0;g<360;g++){const len=LEN[g%3],lv=[1+g%5,1+(g+1)%5,1+(g+2)%5,1+(g+3)%5];
 R(`JK.start();JK.ids=['me',{n:'a'},{n:'b'},{n:'c'}];JK.ctx={mode:'watch'};JK.opt={};JK.render=()=>{};JK.step=()=>{};JK.later=f=>f();JK.len='${len}';JK.h=0;JK.score=[0,0,0,0];JK.hist=[];JK.dealer=${g%4};JK.newHand()`);
 const seq=R(`JSEQ['${len}']`);
 for(let h=0;h<seq.length;h++){const n=R('JK.n');ok(n===seq[h],'hand size '+len+' '+h);
  if(R('JK.phase')==='trump'){const p=R('JK.cur');R(`JK.setTrump(JK.botTrump(${p}))`)}
  for(let k=0;k<4;k++){const p=R('JK.cur');R(`JK.ctx.lvl=${lv[0]}`);const lvp=lv[p];R(`(()=>{const c=JK.ctx;c.lvl=${lvp};JK.bid(${p},JK.botBid(${p}))})()`)}
  const bids=R('JK.bids.slice()');ok(bids.every(b=>b>=0&&b<=n),'bids in range');ok(bids.reduce((a,b)=>a+b,0)!==n,'dealer keeps the sum off the cards '+JSON.stringify(bids)+' n'+n);
  ok(R('JK.phase')==='play','play after bids');
  for(let t=0;t<n;t++){for(let k=0;k<4;k++){const p=R('JK.cur');const before=R(`JSON.stringify({h:JK.hands[${p}],t:JK.trick,tr:JK.trump})`);const B=JSON.parse(before);
    const m=R(`(()=>{JK.ctx.lvl=${lv[p]};const m=JK.botPlay(${p});return JSON.stringify({c:m.c,jm:m.jm||null,js:m.js||null,i:JK.hands[${p}].indexOf(m.c)})})()`);const M=JSON.parse(m);
    const L=legalRef(B.h,B.t,B.tr);ok(M.i>=0&&L.some(c=>JSON.stringify(c)===JSON.stringify(M.c)),'legal move '+JSON.stringify(M.c)+' from '+JSON.stringify(B.h)+' on '+JSON.stringify(B.t));
    R(`(()=>{const p=${p},m=${m};JK.playCard(p,JK.hands[p][m.i],m.jm,m.js)})()`)}tricks++}
  const L=R('JSON.stringify(jLast(JK.hist))'),{hand}=JSON.parse(L);hands++;
  ok(hand.t.reduce((a,b)=>a+b,0)===n,'all tricks taken');const sec=R(`jSec('${len}',${h})`),kh=len==='nines'||sec%2?500:200;
  hand.p.forEach((x,p)=>ok(x===ptsRef(hand.b[p],hand.t[p],n,kh),'points '+JSON.stringify(hand)+' kh'+kh))}
  /* every premium row checked against the rule: whoever made every bid of a section gets their best hand there, the others lose theirs */
 {const H=R('JSON.stringify(JK.hist)'),hist=JSON.parse(H);hist.forEach((r,i)=>{if(!r.pr)return;const rows=hist.filter(x=>!x.pr&&x.s===r.s),all=[0,1,2,3].map(p=>rows.every(x=>x.b[p]===x.t[p])),best=[0,1,2,3].map(p=>Math.max(0,...rows.map(x=>x.p[p]))),any=all.some(Boolean);
  ok(JSON.stringify(r.p)===JSON.stringify([0,1,2,3].map(p=>all[p]?best[p]:any?-best[p]:0)),'premium '+JSON.stringify(r))})}
 ok(R('JK.phase')==='over','the game ends after its last hand ('+len+')');const sc=R('JK.score.slice()');const sum=R('JK.hist.reduce((a,r)=>a.map((x,i)=>x+r.p[i]),[0,0,0,0])');ok(JSON.stringify(sc)===JSON.stringify(sum),'score is the sum of the sheet');
 const mx=Math.max(...sc);sc.forEach((x,p)=>{lvGames[lv[p]]++;lvPts[lv[p]]+=x;if(x===mx)lvWins[lv[p]]++});games++}
console.log(`${games} games, ${hands} hands, ${tricks} tricks`);
for(let v=1;v<=5;v++)console.log(`level ${v}: won ${(100*lvWins[v]/lvGames[v]).toFixed(1)}% of seats, average ${Math.round(lvPts[v]/lvGames[v])} points`);
console.log(`${n-fails}/${n} passed`);process.exit(fails?1:0);
