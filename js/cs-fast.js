/* fast games: the aviator, mines and plinko. The aviator flies over Tbilisi at night: the city, Narikala and the TV tower fall
   away as it climbs. Alone (av_start) the flight is yours; once the server has the shared rounds (avl_state), everyone flies the
   same plane and sees who is in and who has cashed out. Mines and plinko stay hidden until the server has them */

/* ---------- the aviator: the sky ---------- */
const AV={view:{phase:'idle'},solo:null,live:null,off:0,raf:0,poll:0,ticking:false,goneAt:0,hist:[],L:null,queue:null,seen:''};
const AV_AUTO=[1.2,1.5,2,3,5,10,20,50,100];
const AVK=.11;
const avAuto=()=>{const v=+store.get('avauto',2);return AV_AUTO.includes(v)?v:2};
const avAutoOn=()=>!!store.get('avautoon',false);
const avCls=m=>m>=10?'hi':m>=2?'mid':'lo';
const avSrv=()=>Date.now()/1000+AV.off;
const avM=V=>V.phase==='fly'?Math.exp((V.k||AVK)*Math.max(0,avSrv()-V.t0)):V.phase==='gone'?V.crash||1:1;
/* the city at night, drawn once per size: the far layer (the ridge, Mtatsminda and the TV tower, Narikala, Sameba) and the near one
   (the old town, the Bridge of Peace, the river) */
function avLayers(W,H,dpr){const mk=()=>{const c=csCv(Math.round(W*dpr),Math.round(H*dpr)),x=c.getContext('2d');x.scale(dpr,dpr);return[c,x]};const rnd=(()=>{let s=7;return()=>(s=(s*16807)%2147483647)/2147483647})();
 const[sky,s]=mk();let g=s.createLinearGradient(0,0,0,H);g.addColorStop(0,'#05071A');g.addColorStop(.55,'#130E36');g.addColorStop(.85,'#2C1548');g.addColorStop(1,'#3A1A4E');s.fillStyle=g;s.fillRect(0,0,W,H);
 for(let i=0;i<150;i++){const y=rnd()*H*.8,a=.25+rnd()*.6*(1-y/H);s.fillStyle=`rgba(255,255,255,${a.toFixed(2)})`;s.fillRect(rnd()*W,y,rnd()<.1?1.6:1,rnd()<.1?1.6:1)}
 const[far,f]=mk();g=f.createLinearGradient(0,H*.36,0,H);g.addColorStop(0,'#1C1240');g.addColorStop(1,'#0B0720');f.fillStyle=g;
 f.beginPath();f.moveTo(0,H*.66);f.bezierCurveTo(W*.1,H*.6,W*.2,H*.5,W*.27,H*.52);f.bezierCurveTo(W*.36,H*.55,W*.46,H*.66,W*.56,H*.62);f.bezierCurveTo(W*.68,H*.56,W*.78,H*.38,W*.86,H*.38);f.bezierCurveTo(W*.94,H*.39,W,H*.44,W,H*.46);f.lineTo(W,H);f.lineTo(0,H);f.closePath();f.fill();
 /* the TV tower on Mtatsminda: a tapering lattice */
 const tx=W*.86,ty=H*.385,th=H*.27;f.strokeStyle='rgba(150,140,190,.55)';f.lineWidth=1.1;f.beginPath();f.moveTo(tx-W*.018,ty);f.lineTo(tx-2,ty-th);f.moveTo(tx+W*.018,ty);f.lineTo(tx+2,ty-th);
 for(let k=1;k<9;k++){const yy=ty-th*k/9,w=W*.018*(1-k/9)+2;f.moveTo(tx-w,yy);f.lineTo(tx+w,yy-th/9);f.moveTo(tx+w,yy);f.lineTo(tx-w,yy-th/9)}f.stroke();f.beginPath();f.moveTo(tx,ty-th);f.lineTo(tx,ty-th-H*.06);f.stroke();
 /* Narikala: the walls along the ridge, lit warm from below */
 f.fillStyle='#160D30';f.strokeStyle='rgba(255,184,92,.75)';f.lineWidth=1;const wy=x0=>H*.66-(H*.14)*Math.sin(Math.min(1,x0/(W*.27))*Math.PI/2);
 for(let x0=W*.06;x0<W*.33;x0+=W*.012){const y0=wy(x0)-H*.012,hgt=H*(.018+(Math.floor(x0/(W*.05))%3===0?.02:0));f.fillRect(x0,y0-hgt,W*.011,hgt+4);f.beginPath();f.moveTo(x0,y0-hgt);f.lineTo(x0+W*.011,y0-hgt);f.stroke()}
 f.fillStyle='rgba(255,170,80,.16)';f.beginPath();f.ellipse(W*.19,H*.52,W*.16,H*.05,0,0,Math.PI*2);f.fill();
 /* the Mother of Georgia on the hill */
 f.fillStyle='#E9DFC8';f.fillRect(W*.345,H*.505,2.2,H*.05);f.fillRect(W*.345-4,H*.52,10,1.6);f.beginPath();f.arc(W*.345+1.1,H*.5,2,0,Math.PI*2);f.fill();
 /* Sameba: the body, the drum and the gold dome with its cross */
 const sx=W*.64,sy=H*.6;f.fillStyle='#1A1134';f.fillRect(sx-W*.03,sy-H*.05,W*.06,H*.05);f.fillRect(sx-W*.012,sy-H*.085,W*.024,H*.04);
 g=f.createRadialGradient(sx,sy-H*.09,1,sx,sy-H*.09,H*.06);g.addColorStop(0,'rgba(255,214,107,.55)');g.addColorStop(1,'rgba(255,214,107,0)');f.fillStyle=g;f.fillRect(sx-H*.06,sy-H*.15,H*.12,H*.12);
 f.fillStyle='#FFD36B';f.beginPath();f.arc(sx,sy-H*.085,W*.013,Math.PI,0);f.fill();f.fillRect(sx-.6,sy-H*.115,1.2,H*.02);f.fillRect(sx-2.5,sy-H*.108,5,1.2);
 const[near,n]=mk();
 /* the old town: houses with balconies and lit windows */
 for(let x0=-4;x0<W;){const w=W*(.04+rnd()*.05),h=H*(.07+rnd()*.12),y0=H*.88-h;n.fillStyle=rnd()<.5?'#120A26':'#170E2E';n.fillRect(x0,y0,w,h+H*.12);
  n.beginPath();n.moveTo(x0-2,y0);n.lineTo(x0+w/2,y0-H*.025);n.lineTo(x0+w+2,y0);n.fillStyle='#0E0820';n.fill();
  for(let wy=y0+5;wy<H*.86;wy+=8)for(let wx=x0+3;wx<x0+w-4;wx+=7)if(rnd()<.32){n.fillStyle=rnd()<.8?'rgba(255,196,110,.85)':'rgba(170,220,255,.7)';n.fillRect(wx,wy,2.4,3.2)}x0+=w+1}
 /* the river and the lights in it */
 g=n.createLinearGradient(0,H*.88,0,H);g.addColorStop(0,'#0A0A2A');g.addColorStop(1,'#05051A');n.fillStyle=g;n.fillRect(0,H*.88,W,H*.12);
 for(let i=0;i<40;i++){const x0=rnd()*W;n.fillStyle=`rgba(255,${180+rnd()*60|0},${90+rnd()*120|0},${.15+rnd()*.3})`;n.fillRect(x0,H*.89+rnd()*H*.1,1+rnd()*8,1.2)}
 return{sky,far,near,W,H,dpr}}
/* the Bridge of Peace: a wave of glass with its lights running, drawn live */
function avBridge(x,W,H,dy,t){const y0=H*.875+dy,x0=W*.26,x1=W*.56;x.save();x.lineWidth=2;x.strokeStyle='rgba(120,230,255,.75)';x.shadowColor='#4DE3FF';x.shadowBlur=8;x.beginPath();
 for(let k=0;k<=40;k++){const u=k/40,px=x0+(x1-x0)*u,py=y0-Math.abs(Math.sin(u*Math.PI*3))*H*.035;k?x.lineTo(px,py):x.moveTo(px,py)}x.stroke();x.shadowBlur=0;
 for(let k=0;k<=24;k++){const u=k/24,px=x0+(x1-x0)*u,py=y0-Math.abs(Math.sin(u*Math.PI*3))*H*.035,on=(Math.sin(t*3-k*.6)+1)/2;x.fillStyle=`rgba(255,255,255,${(.3+on*.7).toFixed(2)})`;x.fillRect(px-1,py-1,2,2)}
 x.fillStyle='rgba(120,230,255,.25)';x.fillRect(x0,y0,x1-x0,1.4);x.restore()}
function avCloud(x,cx,cy,s,a){x.save();x.globalAlpha=a;for(const[dx,dy,r]of[[0,0,1],[.9,.15,.75],[-.85,.2,.7],[.35,-.35,.7],[-.4,-.3,.6]]){const g=x.createRadialGradient(cx+dx*s,cy+dy*s,0,cx+dx*s,cy+dy*s,r*s);g.addColorStop(0,'rgba(200,190,240,.5)');g.addColorStop(1,'rgba(200,190,240,0)');x.fillStyle=g;x.beginPath();x.arc(cx+dx*s,cy+dy*s,r*s,0,Math.PI*2);x.fill()}x.restore()}
/* the plane, side on, nose to the right; the propeller a blur */
function avPlane(x,px,py,ang,s,al,t){x.save();x.translate(px,py);x.rotate(ang);x.scale(s,s);x.globalAlpha=al;
 const g=x.createLinearGradient(0,-9,0,7);g.addColorStop(0,'#FF7A88');g.addColorStop(.45,'#E0203A');g.addColorStop(1,'#7A0616');
 x.fillStyle='#9A0C20';x.beginPath();x.moveTo(-28,-5);x.lineTo(-35,-19);x.lineTo(-25,-19);x.lineTo(-17,-6);x.closePath();x.fill();
 x.fillStyle=g;x.beginPath();x.moveTo(-31,-1);x.quadraticCurveTo(-27,-8,-14,-8.5);x.lineTo(15,-8.5);x.quadraticCurveTo(27,-8,31,-1.5);x.quadraticCurveTo(32.5,3,28,5.5);x.lineTo(-24,6);x.quadraticCurveTo(-31,5,-31,-1);x.fill();
 x.fillStyle='rgba(255,255,255,.8)';x.fillRect(-24,-1.4,50,2.2);
 x.fillStyle='#B30F26';x.beginPath();x.moveTo(-7,2);x.lineTo(9,2);x.lineTo(3,15);x.lineTo(-13,15);x.closePath();x.fill();
 x.fillStyle='#8E0A1E';x.beginPath();x.moveTo(-30,2);x.lineTo(-40,4.5);x.lineTo(-29,6.5);x.closePath();x.fill();
 x.fillStyle='#A8DEFF';x.beginPath();x.moveTo(1,-8.5);x.quadraticCurveTo(8,-15.5,15,-8.5);x.closePath();x.fill();x.fillStyle='rgba(255,255,255,.7)';x.fillRect(6,-12.5,3,2);
 x.fillStyle='#DADDE2';x.beginPath();x.arc(31.5,1,3.2,0,Math.PI*2);x.fill();
 const p=Math.abs(Math.sin(t*40));x.fillStyle='rgba(255,255,255,.35)';x.beginPath();x.ellipse(34,1,1.8,4+p*10,0,0,Math.PI*2);x.fill();
 x.fillStyle='#1B1B22';x.beginPath();x.arc(6,10,2.6,0,Math.PI*2);x.fill();x.restore()}
/* a frame of the sky */
function avPaint(now){const cv=$('#av_cv');if(!cv)return false;const dpr=Math.min(2,window.devicePixelRatio||1),W=cv.clientWidth,H=cv.clientHeight;if(!W||!H)return false;
 if(cv.width!==Math.round(W*dpr)||cv.height!==Math.round(H*dpr)){cv.width=Math.round(W*dpr);cv.height=Math.round(H*dpr);AV.L=null}if(!AV.L)AV.L=avLayers(W,H,dpr);
 const x=cv.getContext('2d'),V=AV.view,t=now/1000,m=avM(V),fly=V.phase==='fly',gone=V.phase==='gone',ft=Math.log(m)/(V.k||AVK),alt=Math.min(1,Math.log(m)/Math.log(40));
 x.setTransform(1,0,0,1,0,0);x.drawImage(AV.L.sky,0,-alt*H*.12,cv.width,cv.height*1.12);x.setTransform(dpr,0,0,dpr,0,0);
 x.drawImage(AV.L.far,0,alt*H*.55,W,H);
 /* the TV tower's lights and Narikala's glow breathe */
 const blink=(Math.sin(t*3)+1)/2;x.fillStyle=`rgba(255,60,80,${(.35+blink*.65).toFixed(2)})`;for(const k of[0,.5])x.fillRect(W*.86-1.5,H*.385-H*.27*(1-k)-H*.06*(1-k)+alt*H*.55,3,3);
 x.drawImage(AV.L.near,0,alt*H*1.1,W,H);avBridge(x,W,H,alt*H*1.1,t);
 /* clouds pass as the plane climbs */
 for(let i=0;i<6;i++){const cy=H*(.15+i*.14)+(alt*H*1.6)-H*.7*((i%3)/3)-H*.35,cx=((i*W*.37-t*(14+i*5))%(W*1.4)+W*1.4)%(W*1.4)-W*.2;if(cy>-40&&cy<H+40)avCloud(x,cx,cy,22+i*5,.55)}
 const pad=24,tmax=Math.max(8,ft*1.15),mmax=Math.max(1.9,1+(m-1)*1.2),X=s=>pad+s/tmax*(W-pad*2.6),Y=v=>H-pad-(v-1)/(mmax-1)*(H-pad*2.6);
 if(V.phase==='idle'||V.phase==='wait'){const bob=Math.sin(t*2.2)*2;avPlane(x,X(0)+26,Y(1)-8+bob,-.12,1.05,1,t);return V.phase==='wait'}
 const pts=[];for(let i=0;i<=60;i++){const s=ft*i/60;pts.push([X(s),Y(Math.exp((V.k||AVK)*s))])}
 const gr=x.createLinearGradient(0,Y(m),0,H);gr.addColorStop(0,gone?'rgba(150,150,180,.28)':'rgba(255,59,92,.42)');gr.addColorStop(1,'rgba(255,59,92,0)');
 x.beginPath();x.moveTo(pts[0][0],Y(1));pts.forEach(p=>x.lineTo(p[0],p[1]));x.lineTo(pts[60][0],Y(1));x.closePath();x.fillStyle=gr;x.fill();
 x.save();x.shadowColor=gone?'#8E8EA8':'#FF3B5C';x.shadowBlur=14;x.beginPath();pts.forEach((p,i)=>i?x.lineTo(p[0],p[1]):x.moveTo(p[0],p[1]));x.strokeStyle=gone?'#9A9AB4':'#FF3B5C';x.lineWidth=4;x.lineCap='round';x.lineJoin='round';x.stroke();x.restore();
 const[a,b]=pts[60],[c,d]=pts[57],ang=Math.atan2(b-d,a-c);
 if(gone){const f=Math.min(1,(now-AV.goneAt)/700);avPlane(x,a+f*W*.6,b-f*H*.7,ang-f*.3,1.05,1-f,t);return f<1}
 for(let k=1;k<6;k++){const p=pts[Math.max(0,60-k*3)];x.fillStyle=`rgba(255,255,255,${(.18-k*.03).toFixed(2)})`;x.beginPath();x.arc(p[0]-6,p[1]+2,3+k*1.4,0,Math.PI*2);x.fill()}
 avPlane(x,a,b,ang,1.05,1,t);return true}
function avLoop(){if(AV.raf)return;const step=now=>{AV.raf=0;if(!$('#av_cv'))return;const more=avPaint(now);avHud();if(more||AV.view.phase==='wait'||AV.view.phase==='fly')AV.raf=requestAnimationFrame(step)};AV.raf=requestAnimationFrame(step)}
function avStop(){cancelAnimationFrame(AV.raf);AV.raf=0;clearInterval(AV.poll);AV.poll=0}
/* the number in the middle, the countdown, the button while flying */
function avHud(){const V=AV.view,el=$('#av_m');if(!el)return;const m=avM(V),cd=$('#av_cd');
 if(V.phase==='fly'){el.className='av-m '+avCls(m);el.innerHTML=`<b>${m.toFixed(2)}×</b>`;const me=avMine();const b=$('#av_go');if(b&&me&&!me.m&&b.classList.contains('out'))b.innerHTML=`<b>აიღე</b><small>+${nf(Math.floor(me.bet*m))}</small>`;
  if(me&&me.auto&&!me.m&&m>=me.auto)avPollNow()}
 else if(V.phase==='gone'){el.className='av-m gone';el.innerHTML=`<b>${(+V.crash||1).toFixed(2)}×</b><small>გაფრინდა</small>`}
 else if(V.phase==='wait'){const left=Math.max(0,V.t0-avSrv());el.className='av-m wait';el.innerHTML=`<small>შემდეგი ფრენა</small><b>${left.toFixed(1)}</b>`;if(cd)cd.style.setProperty('--p',Math.min(1,left/(V.win||7)).toFixed(3))}
 else{el.className='av-m';el.innerHTML='<b>1.00×</b><small>დადე ფსონი და გაუშვი</small>'}
 $('#av_st')?.classList.toggle('waiting',V.phase==='wait')}
const avMine=()=>AV.live?AV.live.me:AV.solo&&AV.solo.state==='open'?AV.solo:null;
function avHist(){const h=$('#av_hist');if(h)h.innerHTML=AV.hist.slice(0,20).map((m,k)=>`<span class="av-p ${avCls(m)}${k?'':' new'}">${(+m).toFixed(2)}×</span>`).join('')}
PG.aviator={r(){avStop();AV.solo=null;AV.live=null;AV.view={phase:'idle'};AV.L=null;csPage('aviator','ავიატორი',avDraw,{cls:'av-pg'})}};
function avDraw(el,i){const live=csHas('avl')&&(i.games||{}).avl!==false;AV.mode=live?'live':'solo';
 el.innerHTML=`<div class="av-stage" id="av_st"><canvas id="av_cv" aria-hidden="true"></canvas><div class="av-m" id="av_m" aria-live="polite"></div><i class="av-cd" id="av_cd" aria-hidden="true"></i><div class="av-flash" id="av_fl" aria-live="polite"></div></div>
 <div class="av-hist" id="av_hist"></div>
 <div class="av-panel"><div class="av-row">${csBetHTML('aviator')}<div class="av-auto"><button type="button" class="switch" role="switch" data-a="avautosw" aria-checked="${avAutoOn()}" aria-label="ავტომატურად აღება"></button><span><small>ავტომატურად</small><span class="av-av"><button type="button" class="cs-step sm" data-a="avautostep" data-d="-1" aria-label="ნაკლები">−</button><b id="av_auto">${avAuto().toFixed(2)}×</b><button type="button" class="cs-step sm" data-a="avautostep" data-d="1" aria-label="მეტი">+</button></span></span></div></div>
 <button class="av-go" id="av_go" data-a="avgo"></button></div>${csDayHTML(i)}
 ${live?`<section class="cs-card av-bets"><h3>ამ ფრენაში <small id="av_bn"></small></h3><div class="av-bl" id="av_bl"></div></section>`:''}
 <section class="cs-card"><h3>როგორ ითამაშო</h3><p class="note">${live?'ყველა ერთ თვითმფრინავზე ფრენს. დადე ფსონი აფრენამდე, მერე დააჭირე „აიღე“, სანამ გაფრინდება: მიიღებ ფსონს გამრავლებულს იმ კოეფიციენტზე. თუ ადრე გაფრინდა, ფსონი იკარგება.':'თვითმფრინავი აფრინდება და კოეფიციენტი იზრდება. დააჭირე „აიღე“, სანამ გაფრინდება: მიიღებ ფსონს გამრავლებულს იმ კოეფიციენტზე. თუ ადრე გაფრინდა, ფსონი იკარგება.'} „ავტომატურად“ თავად აიღებს მითითებულ კოეფიციენტზე.</p></section>`;
 CS_ONBET.aviator=()=>avBtn();avHud();avBtn();avLoop();
 if(live){avlPoll();AV.poll=setInterval(avlPoll,900);return}
 rpc('casino_mine',{p_game:'aviator'}).then(rows=>{AV.hist=(rows||[]).map(x=>x.d&&x.d.crash).filter(Boolean).map(Number);avHist()}).catch(()=>{});
 q(sb.from('casino_rounds').select('id').eq('game','aviator').eq('state','open').order('id',{ascending:false}).limit(1)).then(o=>{if(o&&o[0]&&$('#av_cv'))return rpc('av_tick',{p_round:o[0].id}).then(avSolo)}).catch(()=>{})}
/* the button: bet, cash out, wait, or a bet kept for the next flight */
function avBtn(){const b=$('#av_go');if(!b)return;const V=AV.view,me=avMine(),bet=csBet('aviator');b.disabled=false;
 if(me&&V.phase==='fly'&&!me.m){b.className='av-go out';b.innerHTML=`<b>აიღე</b><small>+${nf(Math.floor(me.bet*avM(V)))}</small>`;return}
 if(AV.mode==='live'){if(me&&V.phase==='wait'){b.className='av-go set';b.disabled=true;b.innerHTML=`<b>ფსონი დადებულია</b><small>${nf(me.bet)}${me.auto?` · ავტო ${(+me.auto).toFixed(2)}×`:''}</small>`;return}
  if(V.phase!=='wait'){b.className='av-go'+(AV.queue?' set':'');b.innerHTML=AV.queue?`<b>შემდეგ ფრენაზე</b><small>${nf(AV.queue.bet)} · შეეხე გასაუქმებლად</small>`:`<b>ფსონი შემდეგ ფრენაზე</b><small>${nf(bet)} მონეტა</small>`;return}}
 b.className='av-go';b.innerHTML=`<b>ფსონი</b><small>${nf(bet)} მონეტა</small>`}
A.avautosw=t=>{const on=t.getAttribute('aria-checked')!=='true';t.setAttribute('aria-checked',String(on));store.set('avautoon',on)};
A.avautostep=t=>{const i=AV_AUTO.indexOf(avAuto()),n=AV_AUTO[Math.max(0,Math.min(AV_AUTO.length-1,i+(+t.dataset.d)))];store.set('avauto',n);$('#av_auto').textContent=n.toFixed(2)+'×'};
A.avgo=async t=>{if(t.disabled)return;const V=AV.view,me=avMine(),bet=csBet('aviator'),auto=avAutoOn()?avAuto():null;
 if(me&&V.phase==='fly'&&!me.m){t.disabled=true;try{AV.mode==='live'?avlTake(await rpc('avl_cashout',{p_round:AV.live.id})):avSolo(await rpc('av_cashout',{p_round:AV.solo.id}))}catch(e){t.disabled=false;toast(errMsg(e))}return}
 if((ME.coins||0)<bet){toast('მონეტები არ გყოფნის');return}
 if(AV.mode==='live'){if(V.phase!=='wait'){AV.queue=AV.queue?null:{bet,auto};csSnd('chip',.5);avBtn();return}t.disabled=true;try{avlTake(await rpc('avl_bet',{p_round:AV.live.id,p_bet:bet,p_auto:auto}));csSnd('chip');csAfter(ME.coins-bet,bet);csBalShow(ME.coins)}catch(e){t.disabled=false;toast(errMsg(e))}return}
 t.disabled=true;try{const r=await rpc('av_start',{p_bet:bet,p_auto:auto});if(r.state==='open'&&r.bet===bet)csAfter(r.coins,bet);csBalShow(r.coins);csSnd('fly');avSolo(r)}catch(e){t.disabled=false;toast(errMsg(e))}};
/* the solo flight from the server: in the air, or over */
function avSolo(r){if(!r)return;AV.solo=r;AV.off=(r.now||Date.now()/1000)-Date.now()/1000;
 if(r.state==='open'){AV.view={phase:'fly',t0:+r.t0,k:+r.k||AVK};clearInterval(AV.poll);AV.poll=setInterval(avPollNow,350);avBtn();avLoop();return}
 clearInterval(AV.poll);AV.poll=0;avOver(+r.crash||1,r.m!=null?+r.m:null,r.win,r.bet,r.coins);setTimeout(()=>{if($('#av_go')&&!(AV.solo&&AV.solo.state==='open')){AV.solo=null;AV.view={phase:'idle'};avHud();avBtn();avLoop()}},2200)}
async function avPollNow(){if(AV.ticking)return;if(AV.mode==='live'){avlPoll();return}const r=AV.solo;if(!r||r.state!=='open')return;if(S.page?.id!=='aviator'){avStop();return}AV.ticking=true;
 try{const n=await rpc('av_tick',{p_round:r.id});if(n.state!=='open')avSolo(n)}catch(e){}AV.ticking=false}
/* a flight ends: the plane goes, the history grows; a cash-out shows its sum and the coins fly */
function avOver(crash,m,win,bet,coins){AV.view={phase:'gone',crash};AV.goneAt=performance.now();AV.hist.unshift(crash);avHist();avLoop();avHud();
 const fl=$('#av_fl');if(m){fl.className='av-flash win';fl.innerHTML=`<b>+${nf(win)}</b><small>აიღე ${m.toFixed(2)}×-ზე</small>`;csWin(coins,bet,win,fl)}else{csSnd('crash',.8);if(bet){fl.className='av-flash lose';fl.innerHTML='<b>გაფრინდა</b><small>ფსონი დაიკარგა</small>';csTrack(bet,0);if(coins!=null){setCoins(coins);csBalTo(coins)}}}
 setTimeout(()=>{const f=$('#av_fl');if(f)f.className='av-flash'},2000);const b=$('#av_go');if(b){b.disabled=true;b.className='av-go';b.innerHTML=m?`<b>აიღე ${m.toFixed(2)}×</b><small>+${nf(win)}</small>`:'<b>გაფრინდა</b><small>შემდეგი ფრენა მალე</small>'}}

/* ---------- the shared flight: everyone in the same plane ---------- */
async function avlPoll(){if(AV.ticking)return;if(S.page?.id!=='aviator'){avStop();return}AV.ticking=true;try{avlTake(await rpc('avl_state'))}catch(e){}AV.ticking=false}
function avlTake(s){if(!s||!$('#av_cv'))return;const was=AV.live,prev=AV.view.phase;AV.live=s;AV.off=(s.now||Date.now()/1000)-Date.now()/1000;if(s.hist)AV.hist=s.hist.map(Number);
 const ph=s.phase==='bet'?'wait':s.phase==='fly'?'fly':'gone';
 if(ph==='gone'&&(prev!=='gone'||!was||was.id!==s.id)){const me=s.me;avOver(+s.crash||1,me&&me.m?+me.m:null,me?me.win:0,me?me.bet:0,s.coins);AV.view.k=s.k}
 else if(ph!=='gone'){if(ph==='fly'&&prev!=='fly')csSnd('fly',.6);AV.view={phase:ph,t0:+s.t0,k:+s.k||AVK,win:s.win_s||7}}
 /* a cash-out that just happened (by hand or the automatic one) */
 if(s.me&&s.me.m&&was&&was.id===s.id&&was.me&&!was.me.m&&ph==='fly'){const fl=$('#av_fl');fl.className='av-flash win';fl.innerHTML=`<b>+${nf(s.me.win)}</b><small>აიღე ${(+s.me.m).toFixed(2)}×-ზე</small>`;csWin(s.coins,s.me.bet,s.me.win,fl);setTimeout(()=>{const f=$('#av_fl');if(f)f.className='av-flash'},2000)}
 if(ph==='wait'&&AV.queue&&!s.me){const Q=AV.queue;AV.queue=null;rpc('avl_bet',{p_round:s.id,p_bet:Q.bet,p_auto:Q.auto}).then(n=>{csSnd('chip');csAfter(n.coins,Q.bet);csBalShow(n.coins);avlTake(n)}).catch(e=>toast(errMsg(e)))}
 if(ph!=='gone')avBtn();avHist();avlBets(s);avLoop()}
async function avlBets(s){const el=$('#av_bl');if(!el)return;const B=(s.bets||[]).slice().sort((a,b)=>(b.m?1:0)-(a.m?1:0)||b.bet-a.bet),ids=B.map(x=>x.u),key=ids.join();
 if(key!==AV.seen){AV.seen=key;await loadProfiles(ids)}if(!el.isConnected)return;const n=$('#av_bn');if(n)n.textContent=B.length?`${B.length} მოთამაშე · ${nf(B.reduce((a,x)=>a+x.bet,0))} მონეტა`:'';
 el.innerHTML=B.length?B.slice(0,30).map(x=>`<div class="av-b${x.m?' won':s.phase==='gone'?' lost':''}${x.u===ME.id?' me':''}">${av(x.u,28)}<span class="grow">${esc(pname(x.u))}</span><b>${nf(x.bet)}</b>${x.m?`<em class="av-p ${avCls(+x.m)}">${(+x.m).toFixed(2)}×</em><b class="plus">+${nf(x.win)}</b>`:'<i>—</i>'}</div>`).join(''):'<p class="note">ჯერ არავის დაუდია. იყავი პირველი.</p>'}

/* ---------- mines: 25 tiles, gems and mines ---------- */
const MN={r:null,busy:false,n:+store.get('mnmines',3)||3};
const MN_N=[1,3,5,10,15,20,24];
/* the multiplier after k gems with n mines: the fair price less 3% (the server holds the same) */
function mnMult(n,k){let p=1;for(let j=0;j<k;j++)p*=(25-j)/(25-n-j);return Math.floor(.97*p*100)/100}
const MN_GEM=`<svg viewBox="0 0 64 64" aria-hidden="true"><path d="M14 22l8-10h20l8 10-18 30z" fill="#2BD47A"/><path d="M14 22h36L32 52z" fill="#14A35A"/><path d="M22 12l4 10h12l4-10z" fill="#7CFFB0"/><path d="M14 22l12 0 6 30z" fill="#1FBF6A"/><path d="M26 22l6-10 6 10z" fill="#B8FFD6" opacity=".8"/><path d="M20 18l3-3" stroke="#fff" stroke-width="2.4" stroke-linecap="round"/></svg>`;
const MN_BOMB=`<svg viewBox="0 0 64 64" aria-hidden="true"><circle cx="30" cy="38" r="17" fill="#1B1C22"/><circle cx="24" cy="32" r="5" fill="#fff" opacity=".25"/><rect x="34" y="16" width="10" height="9" rx="2" transform="rotate(35 39 20)" fill="#3A3D48"/><path d="M42 16c4-6 10-4 12-8" stroke="#C9A36A" stroke-width="2.4" fill="none"/><circle cx="54" cy="8" r="4" fill="#FFD35C"/><circle cx="54" cy="8" r="2" fill="#fff"/></svg>`;
PG.mines={r(){MN.r=null;csPage('mines','ნაღმები',mnDraw,{cls:'mn-pg',need:'mines'})}};
function mnDraw(el,i){MN.busy=false;
 el.innerHTML=`<div class="mn-top"><span class="mn-cur" id="mn_cur"></span><div class="mn-steps" id="mn_steps"></div></div>
 <div class="mn-grid" id="mn_grid">${Array.from({length:25},(_,k)=>`<button class="mn-t" data-a="mnpick" data-i="${k}" aria-label="უჯრა ${k+1}"><i class="mn-f mn-b"></i><i class="mn-f mn-r"></i></button>`).join('')}</div>
 <div class="mn-ctl" id="mn_ctl"></div>${csDayHTML(i)}
 <section class="cs-card"><h3>როგორ ითამაშო</h3><p class="note">აირჩიე ნაღმების რაოდენობა და ფსონი. ხსენი უჯრებს: ყოველი ბრილიანტი კოეფიციენტს ზრდის. აიღე ნებისმიერ დროს. ნაღმი თუ გახსენი, ფსონი იკარგება.</p></section>`;
 mnShow(true);q(sb.from('casino_rounds').select('id').eq('game','mines').eq('state','open').order('id',{ascending:false}).limit(1)).then(o=>{if(o&&o[0]&&$('#mn_grid'))return rpc('mines_start',{p_bet:csBet('mines'),p_mines:MN.n}).then(r=>{MN.r=r;mnShow(true)})}).catch(()=>{})}
function mnShow(resume,boom){const r=MN.r,open=r&&r.state==='open',n=r?r.mines:MN.n,picks=r?r.picks||[]:[],c=$('#mn_ctl');if(!c)return;
 $$('.mn-t').forEach((t,k)=>{const pk=picks.includes(k),mine=r&&r.pos&&r.pos.includes(k),done=r&&r.state==='done';t.className='mn-t'+(pk?' gem':'')+(done&&mine?' mine':'')+(done&&!pk&&!mine?' rest':'')+(boom===k?' boom':'')+(!resume&&pk&&k===r.last?' nw':'');
  t.querySelector('.mn-r').innerHTML=pk||done&&!mine?MN_GEM:mine?MN_BOMB:'';t.disabled=!open||pk||MN.busy});
 const k=picks.length,cur=r?(+r.m||1):1,nx=mnMult(n,k+1);$('#mn_cur').innerHTML=open?`<small>ახლა</small><b>${cur.toFixed(2)}×</b><small>შემდეგი ${nx.toFixed(2)}×</small>`:`<small>${n} ნაღმი</small><b>${mnMult(n,1).toFixed(2)}×</b><small>პირველი ბრილიანტი</small>`;
 $('#mn_steps').innerHTML=Array.from({length:Math.min(25-n,8)},(_,j)=>{const s=Math.max(0,Math.min(k-3,25-n-8))+j;return `<span class="${s<k?'on':''}${s===k&&open?' nx':''}">${mnMult(n,s+1).toFixed(2)}×</span>`}).join('');
 if(open)c.innerHTML=`<button class="mn-rand" data-a="mnrand"${MN.busy?' disabled':''}>${ic('dice')}<small>შემთხვევითი</small></button><button class="mn-out" data-a="mnout"${k&&!MN.busy?'':' disabled'}><b>აიღე</b><small>${k?'+'+nf(Math.floor(r.bet*cur)):'ჯერ გახსენი უჯრა'}</small></button>`;
 else c.innerHTML=`<div class="mn-set">${csBetHTML('mines')}<div class="mn-n"><small>ნაღმები</small><div>${MN_N.map(v=>`<button class="${v===MN.n?'on':''}" data-a="mnn" data-v="${v}">${v}</button>`).join('')}</div></div></div><button class="mn-go" data-a="mngo">თამაში</button>`}
A.mnn=t=>{MN.n=+t.dataset.v;store.set('mnmines',MN.n);csSnd('tap');if(MN.r&&MN.r.state==='done')MN.r=null;mnShow(true)};
A.mngo=async t=>{if(MN.busy)return;const bet=csBet('mines');if((ME.coins||0)<bet){toast('მონეტები არ გყოფნის');return}MN.busy=true;t.disabled=true;
 try{MN.r=await rpc('mines_start',{p_bet:bet,p_mines:MN.n});MN.busy=false;csSnd('chip');csAfter(MN.r.coins,bet);csBalShow(MN.r.coins);$('#mn_grid').classList.add('mn-on');mnShow(true)}catch(e){MN.busy=false;t.disabled=false;toast(errMsg(e))}};
A.mnpick=async t=>{const r=MN.r;if(MN.busy||!r||r.state!=='open')return;const k=+t.dataset.i;if((r.picks||[]).includes(k))return;MN.busy=true;t.classList.add('wait');
 try{const n=await rpc('mines_pick',{p_round:r.id,p_cell:k});MN.r=n;MN.busy=false;n.last=k;
  if(n.boom!=null){csSnd('boom');gBuzz([60,40,90]);$('#mn_grid').classList.add('shake');setTimeout(()=>$('#mn_grid')?.classList.remove('shake','mn-on'),600);mnShow(false,k);csTrack(n.bet,0);csBalTo(n.coins);setCoins(n.coins)}
  else{csSnd('gem',.8);gBuzz(10);mnShow(false);if(n.state==='done'){$('#mn_grid').classList.remove('mn-on');csWin(n.coins,n.bet,n.win,t)}}}catch(e){MN.busy=false;t.classList.remove('wait');toast(errMsg(e))}};
A.mnrand=()=>{const r=MN.r;if(!r||MN.busy)return;const free=Array.from({length:25},(_,k)=>k).filter(k=>!(r.picks||[]).includes(k));const k=free[Math.floor(Math.random()*free.length)];const t=$(`.mn-t[data-i="${k}"]`);if(t)A.mnpick(t)};
A.mnout=async t=>{const r=MN.r;if(MN.busy||!r||r.state!=='open'||!(r.picks||[]).length)return;MN.busy=true;t.disabled=true;
 try{const n=await rpc('mines_cashout',{p_round:r.id});MN.r=n;MN.busy=false;$('#mn_grid').classList.remove('mn-on');mnShow(false);csWin(n.coins,n.bet,n.win,t)}catch(e){MN.busy=false;t.disabled=false;toast(errMsg(e))}};

/* ---------- plinko: the ball falls through the pegs ---------- */
const PK_TAB={8:{low:[5.5,2,1.1,1,0.45,1,1.1,2,5.5],mid:[13,3,1.3,0.7,0.35,0.7,1.3,3,13],high:[29,4,1.5,0.25,0.2,0.25,1.5,4,29]},
 12:{low:[10,3,1.6,1.4,1.1,1,0.4,1,1.1,1.4,1.6,3,10],mid:[33,11,4,2,1.1,0.6,0.2,0.6,1.1,2,4,11,33],high:[170,24,8,1.8,0.7,0.2,0.2,0.2,0.7,1.8,8,24,170]},
 16:{low:[16,9,2,1.4,1.4,1.2,1.1,1,0.4,1,1.1,1.2,1.4,1.4,2,9,16],mid:[110,41,10,5,3,1.5,1,0.5,0.2,0.5,1,1.5,3,5,10,41,110],high:[1000,130,25,8,4,2,0.2,0.2,0.2,0.2,0.2,2,4,8,25,130,1000]}};
const PK={rows:+store.get('pkrows',12)||12,risk:store.get('pkrisk','mid'),balls:[],raf:0,hit:{},land:{},hist:[],busy:0};
const PK_RISK=[['low','დაბალი'],['mid','საშუალო'],['high','მაღალი']];
const pkCol=(m)=>m>=10?'#FF3B5C':m>=3?'#FF7A3D':m>=1.5?'#FFB020':m>=1?'#E9D04A':'#8FD14F';
PG.plinko={r(){PK.balls=[];csPage('plinko','პლინკო',pkDraw,{cls:'pk-pg',need:'plinko'})}};
function pkDraw(el,i){el.innerHTML=`<div class="pk-stage" id="pk_st"><canvas id="pk_cv" aria-hidden="true"></canvas><div class="pk-hist" id="pk_hist"></div></div>
 <div class="pk-opts"><div class="pk-seg" role="group" aria-label="რისკი">${PK_RISK.map(([k,n])=>`<button class="${k===PK.risk?'on':''}" data-a="pkrisk" data-v="${k}">${n}</button>`).join('')}</div><div class="pk-seg" role="group" aria-label="რიგები">${[8,12,16].map(v=>`<button class="${v===PK.rows?'on':''}" data-a="pkrows" data-v="${v}">${v}</button>`).join('')}</div></div>
 <div class="pk-ctl">${csBetHTML('plinko')}<button class="pk-go" id="pk_go" data-a="pkdrop">ჩაგდება</button></div>${csDayHTML(i)}
 <section class="cs-card"><h3>როგორ ითამაშო</h3><p class="note">${CS_RULES.plinko[1]} ერთდროულად რამდენიმე ბურთის ჩაგდებაც შეიძლება.</p></section>`;
 pkPaint(performance.now());pkHist()}
const pkLock=()=>PK.balls.some(b=>!b.done);
A.pkrisk=t=>{if(pkLock()){toast('მოიცადე, ბურთები ჯერ ეცემა');return}PK.risk=t.dataset.v;store.set('pkrisk',PK.risk);$$('[data-a="pkrisk"]').forEach(b=>b.classList.toggle('on',b===t));csSnd('tap');pkPaint(performance.now())};
A.pkrows=t=>{if(pkLock()){toast('მოიცადე, ბურთები ჯერ ეცემა');return}PK.rows=+t.dataset.v;store.set('pkrows',PK.rows);$$('[data-a="pkrows"]').forEach(b=>b.classList.toggle('on',b===t));csSnd('tap');PK.hit={};PK.land={};pkPaint(performance.now())};
A.pkdrop=async()=>{const bet=csBet('plinko');if((ME.coins||0)<bet+PK.busy*bet){toast('მონეტები არ გყოფნის');return}if(PK.busy>=5)return;PK.busy++;
 const rows=PK.rows,risk=PK.risk;csSnd('chip',.6);
 try{const r=await rpc('plinko_drop',{p_bet:bet,p_rows:rows,p_risk:risk});PK.busy--;csAfter(r.coins-r.win,bet);csBalShow(CSN.bal-bet);
  PK.balls.push({r,rows,risk,bet,t0:performance.now(),seg:-1,done:false,jit:(Math.random()-.5)*.3});pkLoop()}catch(e){PK.busy--;toast(errMsg(e))}};
function pkGeo(W,H,rows){const top=H*.08,bot=H*.86,dy=(bot-top)/(rows+.6),dx=Math.min(W*.92/(rows+2),dy*1.25),cx=W/2,pr=Math.max(2,Math.min(4.2,dx*.13)),br=Math.max(4,Math.min(8,dx*.28));
 return{top,dy,dx,cx,pr,br,slotY:top+rows*dy+dy*.35,peg:(r,j)=>[cx+(j-(r+2)/2)*dx,top+r*dy],slot:k=>cx+(k-rows/2)*dx}}
/* where a ball is: from one peg row to the next it hops a little and falls; the last fall takes it into its slot */
function pkBall(b,G,now){const per=150,path=b.r.path,n=b.rows,u=(now-b.t0)/per;if(u<0)return null;const s=Math.min(n,Math.floor(u)),f=u-s;let c=0;for(let i=0;i<s;i++)c+=path[i]?1:-1;
 const at=(r,cc)=>[G.cx+cc*G.dx/2,G.top+r*G.dy-G.pr-G.br];if(s>=n){const[x0,y0]=at(n,c);const k=Math.min(1,f*1.6);return{x:x0,y:y0+(G.slotY-y0)*k*k,seg:n,end:k>=1}}
 const[x0,y0]=at(s,c),[x1,y1]=at(s+1,c+(path[s]?1:-1)),e=f;return{x:x0+(x1-x0)*e+b.jit*G.dx*Math.sin(e*Math.PI)*.2,y:y0+(y1-y0)*e*e-G.dy*.32*Math.sin(e*Math.PI),seg:s}}
function pkLoop(){if(PK.raf)return;const step=now=>{PK.raf=0;if(!$('#pk_cv'))return;const more=pkPaint(now);if(more)PK.raf=requestAnimationFrame(step)};PK.raf=requestAnimationFrame(step)}
function pkPaint(now){const cv=$('#pk_cv');if(!cv)return false;const dpr=Math.min(2,window.devicePixelRatio||1),W=cv.clientWidth,H=cv.clientHeight;if(!W||!H)return false;
 if(cv.width!==Math.round(W*dpr)||cv.height!==Math.round(H*dpr)){cv.width=Math.round(W*dpr);cv.height=Math.round(H*dpr)}
 const x=cv.getContext('2d'),rows=PK.rows,G=pkGeo(W,H,rows),T=PK_TAB[rows][PK.risk];let busy=false;x.setTransform(dpr,0,0,dpr,0,0);x.clearRect(0,0,W,H);
 for(let r=0;r<rows;r++)for(let j=0;j<r+3;j++){const[px,py]=G.peg(r,j),h=PK.hit[r+':'+j],k=h?Math.max(0,1-(now-h)/300):0;if(k>0)busy=true;
  if(k>0){x.fillStyle=`rgba(255,220,120,${(k*.5).toFixed(2)})`;x.beginPath();x.arc(px,py,G.pr+6*k,0,Math.PI*2);x.fill()}x.fillStyle=k>0?'#FFF2C0':'#E8E4F2';x.beginPath();x.arc(px,py,G.pr,0,Math.PI*2);x.fill()}
 const sw=G.dx*.9,sh=Math.min(28,G.dy*.9);T.forEach((m,k)=>{const sx=G.slot(k),l=PK.land[k],e=l?Math.max(0,1-(now-l)/400):0;if(e>0)busy=true;const yy=G.slotY+e*6;
  x.fillStyle=pkCol(m);x.shadowColor=pkCol(m);x.shadowBlur=e*16;csRR(x,sx-sw/2,yy,sw,sh,5);x.fill();x.shadowBlur=0;x.fillStyle='rgba(0,0,0,.25)';x.fillRect(sx-sw/2,yy+sh-3,sw,3);
  x.fillStyle='#1B0E05';x.font=`800 ${Math.max(8,Math.min(12,sw*.32))}px system-ui,sans-serif`;x.textAlign='center';x.textBaseline='middle';x.fillText(m>=100?Math.round(m):m,sx,yy+sh/2-1)});
 for(const b of PK.balls){if(b.done)continue;if(b.rows!==rows){b.done=true;continue}const p=pkBall(b,G,now);if(!p){busy=true;continue}busy=true;
  if(p.seg!==b.seg&&p.seg<rows&&p.seg>=0){b.seg=p.seg;let c=0;for(let i=0;i<p.seg;i++)c+=b.r.path[i]?1:-1;const j=(c+p.seg+2)/2;PK.hit[p.seg+':'+Math.round(j)]=now;csSnd('peg',.6)}
  const g=x.createRadialGradient(p.x-G.br*.3,p.y-G.br*.3,1,p.x,p.y,G.br);g.addColorStop(0,'#FFF8E0');g.addColorStop(.5,'#FFD35C');g.addColorStop(1,'#E08A0E');x.fillStyle=g;x.shadowColor='#FFB020';x.shadowBlur=10;x.beginPath();x.arc(p.x,p.y,G.br,0,Math.PI*2);x.fill();x.shadowBlur=0;
  if(p.end){b.done=true;const k=b.r.slot;PK.land[k]=now;PK.hist.unshift(+b.r.mult);pkHist();const big=b.r.win>=b.bet*15;csSnd(b.r.win>b.bet?'cash':'tick',.7);if(b.r.win>0)csWin(b.r.coins,b.bet,b.r.win,{x:cv.getBoundingClientRect().left+G.slot(k),y:cv.getBoundingClientRect().top+G.slotY});else{csTrack(b.bet,0);setCoins(b.r.coins)}if(!big&&b.r.win>0)gBuzz(12)}}
 PK.balls=PK.balls.filter(b=>!b.done);return busy}
function pkHist(){const h=$('#pk_hist');if(h)h.innerHTML=PK.hist.slice(0,6).map((m,k)=>`<span style="--c:${pkCol(m)}" class="${k?'':'new'}">${m}×</span>`).join('')}
