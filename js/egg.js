/* ---------- egg tapping (კვერცხის ჭახუნი): the Easter game with red eggs ----------
   pick an egg from the basket (a knock on it tells something: a high, clear sound is a strong shell), then tap tip against
   tip and end against end. the striker times the blow, the other holds steady. the egg cracked at both ends is beaten and
   goes to the winner. if each loses one end, the two whole ends meet once more */
const EGG_COL=['#B3121C','#A5161E','#C21A22','#8E1218','#B8231A','#9D1B2B','#C0392B','#7E1016'];
/* the computer's players hear the shells too: the stronger the player, the better the egg it picks */
function eggBasket(n=6){const b=[];for(let i=0;i<n;i++){const s=.32+Math.random()*.66;b.push({id:i,str:s,col:EGG_COL[Math.floor(Math.random()*EGG_COL.length)],pat:Math.random()<.45?1:Math.random()<.5?2:0,ends:{t:s*(.9+Math.random()*.2),b:s*(.92+Math.random()*.16)},cr:{t:false,b:false}})}return b}
const eggEnds=e=>(e.cr.t?1:0)+(e.cr.b?1:0);
/* sounds: a knock whose pitch follows the shell, and a crack */
function eggKnock(e){const x=typeof gsCtx==='function'&&gsCtx();if(!x)return;const t=x.currentTime+.01,f=520+e.str*820+(Math.random()-.5)*90;try{gsTone(x,t,{f,f2:f*.82,type:'triangle',peak:.16,dec:.07});gsNoise(x,t,{f:f*3.2,q:4,peak:.12,dec:.03})}catch(er){}}
function eggCrack(){const x=typeof gsCtx==='function'&&gsCtx();if(!x)return;const t=x.currentTime+.01;try{gsNoise(x,t,{f:3400,q:.8,peak:.42,dec:.05,rate:1.4});gsNoise(x,t+.03,{f:1800,q:1.2,peak:.25,dec:.07});gsTone(x,t,{f:300,f2:120,peak:.12,dec:.06})}catch(er){}}
function eggTick(){const x=typeof gsCtx==='function'&&gsCtx();if(!x)return;const t=x.currentTime+.01;try{gsTone(x,t,{f:880,f2:700,type:'triangle',peak:.12,dec:.05});gsNoise(x,t,{f:2600,q:3,peak:.14,dec:.03})}catch(er){}}
/* the egg drawn flat: the pointed end up, the shell's dye, leaf prints or dots, and cracks where it broke */
function eggSVG(e,cls='',lab=''){const g='eg'+Math.random().toString(36).slice(2,8);
 const leaves=e.pat===1?`<g fill="#F7E6D8" opacity=".5"><path d="M38 52c6-14 20-16 24-10-6 2-14 6-24 10z"/><path d="M58 78c-8-10-4-24 4-26-1 8 0 16-4 26z"/><path d="M30 86c10-4 18 2 18 8-8-2-12-4-18-8z"/></g>`:e.pat===2?`<g fill="#F7E6D8" opacity=".55">${[[34,40],[60,46],[46,64],[70,70],[32,80],[56,92],[44,104]].map(([x,y])=>`<circle cx="${x}" cy="${y}" r="2.6"/>`).join('')}</g>`:'';
 const ck=(y0,dir)=>`<path d="M30 ${y0}l7 ${4*dir}l5 ${-5*dir}l6 ${7*dir}l5 ${-6*dir}l6 ${5*dir}l6 ${-4*dir}l5 ${5*dir}" fill="none" stroke="#2A0E0C" stroke-width="2.2" stroke-linejoin="round"/><path d="M42 ${y0-dir}l3 ${9*dir}l-4 ${6*dir}M58 ${y0}l2 ${8*dir}" fill="none" stroke="#2A0E0C" stroke-width="1.4"/>`;
 return `<svg class="egg ${cls}" viewBox="0 0 100 120" role="img" aria-label="${lab||'კვერცხი'}"><defs><radialGradient id="${g}" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="#FF8A80" stop-opacity=".55"/><stop offset=".35" stop-color="${e.col}"/><stop offset="1" stop-color="#3A0608"/></radialGradient></defs>
  <path d="M50 4C76 4 92 52 92 74C92 100 73 117 50 117C27 117 8 100 8 74C8 52 24 4 50 4Z" fill="url(#${g})"/>${leaves}<ellipse cx="36" cy="38" rx="9" ry="16" fill="#fff" opacity=".18" transform="rotate(-18 36 38)"/>${e.cr.t?ck(20,1):''}${e.cr.b?ck(104,-1):''}</svg>`}

const EG=GAME.egg={title:'კვერცხის ჭახუნი',
 start(){this.tk=(this.tk||0)+1;const c=this.ctx;this.local=c.mode==='local';this.basket=eggBasket();this.sel=null;this.pick={1:null,'-1':null};this.picker=1;this.phase='pick';this.round=0;this.log=[];this.win=null;this.anim=null;this.hold=null;
  if(!this.local){const ch=botChar('egg');c.names={1:ME.name,'-1':ch.n};c.avs={1:'me','-1':botAv(ch)};c.olk=ch.lk}this.wins=store.get('eggs',0)||0},
 later(fn,ms){const tk=this.tk;setTimeout(()=>{if(tk===this.tk&&S.game==='egg'&&!S.page)fn()},ms)},
 nm(s){return this.ctx.names[s]},
 egg(s){return this.basket[this.pick[s]]},
 /* knock an egg in the basket, then take it */
 knock(i){if(this.phase!=='pick')return;const e=this.basket[i];if(!e||e.taken)return;this.sel=i;eggKnock(e);this.render()},
 take(){if(this.phase!=='pick'||this.sel==null)return;const e=this.basket[this.sel];if(!e||e.taken)return;e.taken=1;this.pick[this.picker]=this.sel;this.sel=null;
  if(this.local&&this.picker===1){this.picker=-1;toast(`გადაეცი ტელეფონი: ${this.nm(-1)} ირჩევს`);this.render();return}
  if(!this.local){const lv=bLvl('egg'),left=this.basket.filter(x=>!x.taken),tried=left.sort(()=>Math.random()-.5).slice(0,Math.min(left.length,lv));
   const b=tried.reduce((a,x)=>x.str*(.85+Math.random()*.3)>a.str*(.85+Math.random()*.3)?x:a,tried[0]);b.taken=1;this.pick[-1]=b.id}
  this.phase='duel';this.round=0;this.next();this.render()},
 /* who strikes and with which end: tips first (the first player strikes), then the other ends (the second strikes), then the whole ends if each has one left */
 clash(){const A=this.egg(1),B=this.egg(-1);if(this.round===0)return{s:1,ea:'t',eb:'t'};if(this.round===1)return{s:-1,ea:'b',eb:'b'};return{s:1,ea:A.cr.t?'b':'t',eb:B.cr.t?'b':'t'}},
 next(){const k=this.clash();this.turn=k.s;this.stage='aim';this.t0=performance.now();this.hold=null;
  /* the computer strikes on its own after a moment; then you hold steady */
  if(!this.local&&k.s===-1){this.stage='brace';this.later(()=>{this.hold={t0:performance.now(),dur:1300};this.render();this.later(()=>{if(this.stage==='brace')this.hit(.35+.13*bLvl('egg')+(Math.random()-.5)*.2,this.hold&&this.hold.d!=null?this.hold.d:.25)},1350)},700)}},
 /* the needle runs back and forth; a blow at the middle is the best one */
 needle(){const t=((performance.now()-this.t0)/1100)%2;return t<1?t:2-t},
 strike(){if(this.phase!=='duel'||this.stage!=='aim')return;const x=this.needle(),q=1-Math.min(1,Math.abs(x-.5)*2);
  const d=this.local?.55:Math.max(.1,Math.min(.95,.4+.12*bLvl('egg')+(Math.random()-.5)*.25));this.hit(q,d)},
 brace(){if(this.stage!=='brace'||!this.hold)return;const k=(performance.now()-this.hold.t0)/this.hold.dur;this.hold.d=Math.max(0,1-Math.abs(k-.95)*3);eggTick()},
 hit(q,d){const k=this.clash(),S1=k.s,S2=-k.s,A=this.egg(S1),B=this.egg(S2),ea=S1===1?k.ea:k.eb,eb=S1===1?k.eb:k.ea;
  const a=A.ends[ea]*(.82+.36*q)*(.94+Math.random()*.12),b=B.ends[eb]*(.88+.24*d)*(.94+Math.random()*.12),lose=a<b?S1:S2,le=lose===S1?ea:eb;
  this.egg(lose).cr[le]=true;this.log.push({s:S1,q,lose,end:le});this.stage='hit';this.anim={s:S1,at:performance.now(),lose};this.render();
  this.later(()=>{eggCrack();if(typeof g3Sparks==='function'&&typeof G3D!=='undefined'&&G3D.sc&&G3D.sc.host==='egg')try{g3Sparks(G3D.sc,[0,2.25,2.15],[1,.95,.9],10,0)}catch(e){}this.stage='after';this.render();
   this.later(()=>this.after(),1600)},230)},
 after(){const A=this.egg(1),B=this.egg(-1),na=eggEnds(A),nb=eggEnds(B);
  if(na>=2||nb>=2||this.round>=2){this.win=na>=2?-1:nb>=2?1:(na<nb?1:-1);this.phase='over';this.ctx.finAt=performance.now();
   const me=this.win===1;if(!this.local){if(me){this.wins++;store.set('eggs',this.wins);gameResult('egg',true);if(typeof gBadge==='function'&&this.wins>=10)gBadge('egg10')}if(typeof gEndGest==='function')gEndGest(()=>me?'shake':'cheer',[-1])}
   if(typeof gSnd==='function')gSnd(this.local||me?'win':'lose');this.render();return}
  this.round++;this.next();this.render()},
 save(){return null},
 status(){const n=s=>esc(this.nm(s));
  if(this.phase==='pick'){if(this.local)return `${n(this.picker)} ირჩევს: დააკაკუნე კვერცხებს და აირჩიე ერთი`;return this.sel==null?'დააკაკუნე კვერცხს: მაღალი, წკრიალა ხმა მაგარ ნაჭუჭზე მეტყველებს':'მოგწონს? აიღე ან სხვასაც დააკაკუნე'}
  if(this.phase==='over')return this.local?`${n(this.win)} იგებს! კვერცხი მისია`:this.win===1?'შენი კვერცხი გაუძლო! მეტოქისაც შენია 🥚':`${n(-1)}მ მოიგო, კვერცხი მას დარჩა`;
  const k=this.clash(),end=k.ea==='t'?'წვერით':'ძირით';
  if(this.stage==='aim')return this.local||k.s===1?`${n(k.s)} არტყამს ${end}: დააჭირე, როცა ისარი შუაშია`:'';
  if(this.stage==='brace')return `${n(-1)} არტყამს ${end}. დაიჭირე მაგრად: დააჭირე, როცა რგოლი კვერცხს შეეხება`;
  if(this.stage==='hit')return 'ჭახ!';
  const l=this.log[this.log.length-1];return l?`${l.lose===1?(this.local?n(1)+'ის':'შენი'):n(-1)+'ის'} კვერცხს ${l.end==='t'?'წვერი':'ძირი'} გაუტყდა`:''},
 render(){if(S.tab!=='games'||S.game!=='egg'||S.page)return;const g3=g3Want(),c=this.ctx,top=gTop('კვერცხის ჭახუნი',null);
  let stage2d='',panel='';
  if(this.phase==='pick'){stage2d=`<div class="ebasket">${this.basket.map((e,i)=>e.taken?`<span class="eslot"></span>`:`<button class="eslot${this.sel===i?' sel':''}" data-a="eggk" data-i="${i}" aria-label="კვერცხი ${i+1}: დააკაკუნე">${eggSVG(e)}</button>`).join('')}</div>`;
   panel=`<div class="jkacts"><button class="btn gold" data-a="eggtake"${this.sel==null?' disabled':''}>${ic('check')}ამას ავიღებ</button></div>`}
  else{const A=this.egg(1),B=this.egg(-1),hit=this.stage==='hit'?' hit s'+(this.anim.s===1?'a':'b'):'',k=this.phase==='duel'?this.clash():{ea:'t',eb:'t'};
   /* the ends that meet face each other: the pointed ends first, then the round ones */
   stage2d=`<div class="educl${hit}"><div class="eside b">${eggSVG(B,k.eb==='t'?'flip':'',this.nm(-1))}<small>${esc(this.nm(-1))}</small></div><div class="eside a">${eggSVG(A,k.ea==='b'?'flip':'',this.nm(1))}<small>${esc(this.local?this.nm(1):'შენ')}</small></div></div>`;
   if(this.phase==='duel'&&this.stage==='aim'&&(this.local||this.turn===1))panel=`<div class="emeter" aria-hidden="true"><i style="animation-duration:2.2s;animation-delay:${-((performance.now()-this.t0)%2200)}ms"></i><b></b></div><div class="jkacts"><button class="btn gold eggbtn" data-a="eggs">ჭახ!</button></div>`;
   else if(this.phase==='duel'&&this.stage==='brace'&&this.hold)panel=`<div class="ering" aria-hidden="true"><i style="animation-duration:${this.hold.dur}ms"></i></div><div class="jkacts"><button class="btn gold eggbtn" data-a="eggh">ვიჭერ!</button></div>`}
  const info=`<div class="ginfo"><span>${this.phase==='pick'?'კვერცხის არჩევა':this.phase==='duel'?['წვერი წვერს','ძირი ძირს','ბოლო დარტყმა'][this.round]:'დასრულდა'}</span>${this.local?'':`<span class="gscore"><span>მოგებული კვერცხები</span><b>${this.wins}</b></span>`}</div>`;
  let res='';if(this.phase==='over'){const me=this.win===1;res=gResBox(this,{title:this.local?esc(this.nm(this.win))+' იგებს':me?'შენმა კვერცხმა გაუძლო!':'კვერცხი გატყდა',sub:this.local?'გამარჯვებული კვერცხს იღებს':me?`სულ ${this.wins} მოგებული კვერცხი`:'შემდეგ ჯერზე სხვა აირჩიე',kind:this.local||me?'win':'lose',
   again:`<button class="btn gold" data-a="eggagain">კიდევ ერთხელ</button>`,share:me&&!this.local?gShareBtn('egg',this.wins+' მოგებული კვერცხი'):''})}
  const opp=!this.local?`<div class="pl"><span class="plav">${avAny(c.avs[-1],34)}</span><span class="pln"><b>${esc(this.nm(-1))}</b><span class="muted">${BLV[bLvl('egg')].n}</span></span></div>`:'';
  const stage=g3?`<div class="g3 g3-egg${G3W.ready?'':' loading'}">${g3Rv()}${G3W.ready?'':'<span class="g3load" aria-hidden="true"></span>'}</div><div class="g3sr">${stage2d}</div>`:'';
  view.innerHTML=gShell('egg',{stage,mid:stage2d,top:top+info+opp,bot:`<div class="status${(this.phase==='duel'&&(this.stage==='aim'&&(this.local||this.turn===1)||this.stage==='brace'))||this.phase==='pick'?' mine':''}" role="status">${this.status()}</div>${panel}`,res});
  g3After('egg')}};
A.eggk=t=>EG.knock(+t.dataset.i);
A.eggtake=()=>EG.take();
A.eggs=()=>EG.strike();
A.eggh=()=>EG.brace();
A.eggagain=()=>{EG.resHide=0;EG.resSnd=0;EG.ctx.finAt=0;EG.ctx.cined=0;EG.start();EG.render()};
/* Easter in the Orthodox calendar: the Julian date by Meeus, moved to the Gregorian calendar */
function easterOf(y){const a=y%4,b=y%7,c=y%19,d=(19*c+15)%30,e=(2*a+4*b-d+34)%7,m=Math.floor((d+e+114)/31),day=(d+e+114)%31+1;const j=new Date(Date.UTC(y,m-1,day));j.setUTCDate(j.getUTCDate()+13);return j}
