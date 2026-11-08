/* the 3D casino tables, with the board games' engine: blackjack at the night-lounge table with Nino dealing from the shoe,
   and the roulette wheel on the same table, its rotor turning and the ball running round. Each scene is built once and follows
   its page: BJ (the round) and RLT (the wheel and the ball, worked out in js/cs-table.js) */
const CSG3B={};
function csG3Show(id){const el=$('.g3-'+id,view);if(!el)return;const key='cs:'+id,sc=G3S[key]||(G3S[key]=CSG3B[id]());sc.host=id;
 if(!g3Mount(el,sc))return;if(sc.envK)envApply(sc);if(typeof gAmb==='function')gAmb(sc.envK||null,sc.envT,'joker',null);
 try{G3U[id](sc)}catch(e){try{console.warn('3D casino',e)}catch(x){}}try{g3Insets(sc)}catch(e){}g3Need()}

/* ---------- a whole deck: ace to king of four suits, ten to a row, and the back ---------- */
const BJW=204.8,BJH=288,BJK=.8,BJR=['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
const bjIdx=c=>c?'SHDC'.indexOf(c.slice(-1))*13+BJR.indexOf(c.slice(0,-1)):52;
const bjUV=i=>[(i%10)*BJW/2048,Math.floor(i/10)*BJH/2048,BJW/2048,BJH/2048];
function bjCardsCv(){const c=cvs(2048,2048),x=c.getContext('2d'),FS='"Noto Sans Georgian","DejaVu Sans",system-ui,sans-serif',F='"Noto Serif Georgian",Georgia,"Times New Roman",serif';
 const PIP={2:[[.5,.2],[.5,.8]],3:[[.5,.2],[.5,.5],[.5,.8]],4:[[.25,.22],[.75,.22],[.25,.78],[.75,.78]],5:[[.25,.22],[.75,.22],[.5,.5],[.25,.78],[.75,.78]],
  6:[[.25,.22],[.75,.22],[.25,.5],[.75,.5],[.25,.78],[.75,.78]],7:[[.25,.22],[.75,.22],[.5,.36],[.25,.5],[.75,.5],[.25,.78],[.75,.78]],8:[[.25,.22],[.75,.22],[.5,.36],[.25,.5],[.75,.5],[.5,.64],[.25,.78],[.75,.78]],
  9:[[.25,.2],[.75,.2],[.25,.4],[.75,.4],[.5,.5],[.25,.6],[.75,.6],[.25,.8],[.75,.8]],10:[[.25,.2],[.75,.2],[.5,.3],[.25,.4],[.75,.4],[.25,.6],[.75,.6],[.5,.7],[.25,.8],[.75,.8]]};
 const face=(i,draw)=>{x.save();x.translate((i%10)*BJW,Math.floor(i/10)*BJH);x.scale(BJK,BJK);rrect(x,3,3,250,354,24);x.fillStyle='#FFFDF8';x.fill();x.strokeStyle='rgba(60,40,20,.28)';x.lineWidth=2.5;x.stroke();x.clip();draw();x.restore()};
 for(const S of 'SHDC')BJR.forEach((r,ri)=>{const s=S.toLowerCase(),col=S==='H'||S==='D'?'#CE1430':'#17110E';
  face('SHDC'.indexOf(S)*13+ri,()=>{x.fillStyle=col;x.textAlign='center';x.textBaseline='alphabetic';
   const corner=()=>{x.font=`800 ${r==='10'?70:86}px ${FS}`;if(r==='10'){x.save();x.translate(46,88);x.scale(.78,1);x.fillText(r,0,0);x.restore()}else x.fillText(r,46,88);suitPath(x,s,46,134,58)};
   corner();x.save();x.translate(256,360);x.rotate(Math.PI);corner();x.restore();
   if(PIP[ri+1])for(const[u,v]of PIP[ri+1]){x.save();x.translate(80+u*96,46+v*268);if(v>.55)x.rotate(Math.PI);suitPath(x,s,0,0,31);x.restore()}
   else if(r==='A'){suitPath(x,s,128,180,104);x.save();x.globalAlpha=.33;x.strokeStyle=col;x.lineWidth=3;x.beginPath();x.arc(128,180,68,0,Math.PI*2);x.stroke();x.restore()}
   else{const g=x.createLinearGradient(0,60,0,300);g.addColorStop(0,'#FBEFD2');g.addColorStop(1,'#F0D9A6');x.fillStyle=g;rrect(x,86,46,84,268,10);x.fill();x.strokeStyle=col;x.lineWidth=3;x.stroke();x.lineWidth=1.2;rrect(x,92,52,72,256,6);x.stroke();
    x.fillStyle=col;x.font=`700 80px ${F}`;x.fillText(r,128,198);suitPath(x,s,128,254,28);suitPath(x,s,128,102,28)}})});
 face(52,()=>{x.fillStyle='#7A1430';x.fillRect(0,0,256,360);x.strokeStyle='rgba(232,190,100,.9)';x.lineWidth=4;rrect(x,16,16,224,328,14);x.stroke();
  x.save();rrect(x,24,24,208,312,10);x.clip();x.strokeStyle='rgba(232,190,100,.28)';x.lineWidth=2;for(let k=-360;k<616;k+=22){x.beginPath();x.moveTo(k,0);x.lineTo(k+360,360);x.stroke();x.beginPath();x.moveTo(k+360,0);x.lineTo(k,360);x.stroke()}x.restore();
  x.fillStyle='#7A1430';x.beginPath();x.arc(128,180,62,0,Math.PI*2);x.fill();x.strokeStyle='rgba(232,190,100,.95)';x.lineWidth=4;x.stroke();x.fillStyle=goldFill(x,146,210);crownPath(x,128,182,70)});
 return c}

/* ---------- chips: a lathe with the colour, the edge marks and a ring on top ---------- */
const CHIPR=.3,CHIPH=.072;
const CHIPP=[[0,CHIPH],[CHIPR-.03,CHIPH],[CHIPR-.008,CHIPH-.006],[CHIPR,CHIPH-.02],[CHIPR,.02],[CHIPR-.008,.006],[CHIPR-.03,0],[0,0]];
function chipCv(col,edge){const c=cvs(256,64),x=c.getContext('2d');x.fillStyle=col;x.fillRect(0,0,256,64);x.fillStyle=edge;
 for(let k=0;k<8;k++)x.fillRect(k*32+4,25,16,14);for(let k=0;k<16;k++){x.fillRect(k*16+2,39,8,4);x.fillRect(k*16+2,21,8,4)}
 x.fillStyle='rgba(255,255,255,.5)';x.fillRect(0,52,256,1.6);x.fillRect(0,11,256,1.6);return c}
function csChipModels(sc){for(const[v,col,edge]of RL_CHIPS)if(!sc.models['chip'+v])g3Model(sc,'chip'+v,[[gLathe(CHIPP,36,.5),g3Mat({t:g3T('chip'+v,()=>g3Tex(chipCv(col,edge))),sh:70,sp:.4,gl:.3})]],null).land=()=>snd('chip',.45)}
const csChipList=v=>{const out=[];for(const[d]of RL_CHIPS.slice().reverse())while(v>=d&&out.length<10){out.push(d);v-=d}return out.reverse()};

/* the felt of the blackjack table: navy, the gold words round the arc, the place for the bet */
function bjFeltCv(){const c=luxFeltCv(),x=c.getContext('2d'),S=1024;x.save();x.fillStyle='#172C52';x.beginPath();x.arc(S/2,S/2-S*.3,S*.1,0,Math.PI*2);x.fill();x.restore();
 x.fillStyle='rgba(226,186,98,.82)';x.textAlign='center';x.textBaseline='middle';x.font='700 30px "Noto Sans Georgian","DejaVu Sans",sans-serif';
 /* the words follow a wide curve across the middle, read from the player's side */
 const arc=(t,R,dy)=>{const n=[...t],cy=S/2-R+dy,step=24/R;n.forEach((ch,i)=>{const a=Math.PI/2-(i-(n.length-1)/2)*step;x.save();x.translate(S/2+Math.cos(a)*R,cy+Math.sin(a)*R);x.rotate(a-Math.PI/2);x.fillText(ch,0,0);x.restore()})};
 arc('ბლექჯეკი იხდის 3:2-ს',S*.62,S*.02);x.font='600 22px "Noto Sans Georgian","DejaVu Sans",sans-serif';x.fillStyle='rgba(226,186,98,.6)';arc('დილერი ჩერდება 17-ზე',S*.62,S*.065);
 x.strokeStyle='rgba(226,186,98,.6)';x.lineWidth=3;x.beginPath();x.arc(S/2,S/2+S*.285,S*.045,0,Math.PI*2);x.stroke();return c}
function bjTable(sc){P3(sc,gDisc(5.45,96),g3Mat({t:g3T('bjfelt',()=>g3Tex(bjFeltCv())),sh:8,sp:.06,gl:0}),[0,0,0],null,false);
 P3(sc,gLathe([[5.4,-1.2],[5.42,-.02],[5.45,.02],[5.6,.1],[5.95,.16],[6.22,.1],[6.3,0],[6.25,-.16],[6.1,-.24],[5.8,-.3],[5.7,-1.2],[0,-1.2]],120,.6),g3Mat({c:'#15161D',sh:120,sp:.65,gl:.55}),[0,0,0]);
 P3(sc,gTorus(5.47,.04,120,6),goldM(),[0,.04,0],null,false);P3(sc,gTorus(6.28,.045,120,6),goldM(),[0,-.02,0],null,false);
 P3(sc,gLathe([[0,-11],[3.2,-11],[3.3,-10.6],[1.1,-9.8],[.9,-6],[1.3,-2.2],[2.4,-1.4],[0,-1.3]],48),blackM(),[0,0,0])}

/* ---------- blackjack ---------- */
const BJ_SHOE=[2.55,.62,-2.7];
/* closer than the card games' eye: two hands and the dealer fill the view */
const bjCam=asp=>({eye:[0,5.5,6.3],tgt:[0,.35,-1.5],fov:Math.max(.98,2*Math.atan(Math.tan(.44)/asp)),sy:0,sx:0});
CSG3B.csbj=()=>{const sc=g3Scene({cam:{fixed:bjCam,tgt:[0,0,0],fov:1,dy:0,dp:0,dz:1},orbit:false,zoom:false,shR:12,shC:[0,0,-1.6],spot:[0,2.4,11,.62],bg:[.035,.024,.02],
  light:{d:v3.norm([-.22,1,.4]),c:[2.35,2.08,1.72],sky:[.26,.22,.2],gnd:[.12,.08,.06],exp:1.0}});
 bjTable(sc);envLounge(sc);mkModel(sc);if(castPic())castLoad();csChipModels(sc);
 const atl=g3T('bjcards',()=>g3Tex(bjCardsCv())),back=bjUV(52);
 g3Model(sc,'bjc',[[gQuad(CDW,CDH),g3Mat({t:atl,cut:true,vary:true,sh:30,sp:.18,gl:.1})],[gQuad(CDW,CDH,true),g3Mat({t:atl,uv:back,cut:true,sh:30,sp:.2,gl:.12})]],[CDW/2,CDH/2,.03]).land=()=>snd('card',.8);
 /* the shoe on the dealer's left, cards showing their backs at its mouth; the tray for the chips in front of her */
 const lac=g3Mat({c:'#14161C',sh:110,sp:.6,gl:.45}),q=qt.ax(0,1,0,-.45);P3(sc,gBox(1.15,.7,1.7,.08,2),lac,[2.75,.35,-2.95],q);
 P3(sc,gXf(gQuad(.92,.62),[0,0,0],qt.ax(1,0,0,-.55)),g3Mat({t:atl,uv:back,sh:30,sp:.2,gl:.1}),[2.42,.58,-2.32],q,false);P3(sc,gTorus(.5,.03,24,5),goldM(),[2.75,.71,-2.95],q,false);
 P3(sc,gBox(3.2,.16,.9,.05,2),lac,[0,.08,-3.55]);for(let k=0;k<6;k++)P3(sc,gBox(.42,.04,.62,.02,1),g3Mat({c:'#0E0F14',sh:40,sp:.2,gl:.1}),[-1.25+k*.5,.17,-3.55],null,false);
 sc.seen={id:null,p:0,d:0};sc.onResize=()=>{try{G3U.csbj(sc)}catch(e){}};sc.people=w=>w==='dealer'?2:null;return sc};
G3U.csbj=sc=>{const r=BJ.r,L=[],bet=r?r.bet:csBet('bj');if(castPic()&&castModel(sc))castPush(L,2,'f2',r&&r.state==='open'?.05:0);
 if(sc.seen.id!==(r&&r.id)){sc.seen={id:r&&r.id,p:0,d:0,open:true}}
 const S0=sc.seen;let lost=false;
 if(r){const open=r.state==='open',dc=open?[r.d[0],null]:r.d,first=S0.p===0&&S0.d===0;
  /* the first four go round in turn: you, the dealer, you, the dealer (face down) */
  const lay=(cards,z,who,seen)=>cards.forEach((c,k)=>{const n=cards.length,yaw=k%2?.035:-.03,o={k:r.id+who+k,m:'bjc',p:[(k-(n-1)/2)*.68,.012+k*.005,z],q:c?FACEUP(yaw):FACEDN(yaw),uv:bjUV(bjIdx(c)),from:{p:BJ_SHOE,q:FACEDN(-.45)},arc:.9,dur:520};
   if(k>=seen)o.delay=first&&k<2?(who==='p'?k*520:k*520+260):who==='d'?(k-seen)*520+(S0.open&&!open?520:0):0;
   if(who==='d'&&k===1&&!open&&S0.open){o.arc=.55;o.dur=480}L.push(o)});
  lay(r.p,1.5,'p',S0.p);lay(dc,-1.85,'d',S0.d);
  const[,k]=BJ_END[r.end]||[];lost=!open&&k==='lose';
  if(!open&&r.win>r.bet)csChipList(r.win-r.bet).forEach((v,k)=>L.push({k:'w'+r.id+'_'+k,m:'chip'+v,p:[.78,k*CHIPH,3.05],q:qt.ax(0,1,0,k*.7),from:{p:[0,.5,-3.2]},delay:900+k*70,arc:.6,dur:620}));
  sc.seen={id:r.id,p:r.p.length,d:dc.length,open}}
 if(!lost)csChipList(bet).forEach((v,k)=>L.push({k:'b'+k+':'+v,m:'chip'+v,p:[0,k*CHIPH,3.05],q:qt.ax(0,1,0,k*.9),from:{p:[0,.6,6.2]},delay:k*50,arc:.4,dur:420}));
 sc.lost=lost;
 g3Set(sc,L,{gone:o=>o.m==='bjc'?{p:[-2.7,.5,-3],q:FACEDN(.6),dur:520,a:0,arc:.6}:o.m.startsWith('chip')?(sc.lost?{p:[0,.3,-3.5],dur:620,a:0,arc:.5}:{p:[0,.4,6.5],dur:520,a:0}):null})};

/* ---------- roulette ---------- */
/* the wheel: the wooden bowl and its track stand still; the rotor (pockets, frets, the cone and the gold turret) turns; the ball runs */
const RLW={rim:3.62,trk:3.08,pk:2.02,num:2.7,yT:.5,yP:.3,ball:.12};
function rlDiscCv(){const S=1024,c=cvs(S,S),x=c.getContext('2d'),k=S/2/RLW.num,cx=S/2,A=Math.PI*2/37;x.fillStyle='#2A1204';x.fillRect(0,0,S,S);
 const ring=(r0,r1,dark)=>RL_ORDER.forEach((n,i)=>{const a=i*A-Math.PI/2,c0=rlCol(n);x.fillStyle=c0==='g'?(dark?'#0A6A38':'#0E8A4B'):c0==='r'?(dark?'#9E0C22':'#C8102E'):(dark?'#0E0E12':'#1B1B22');
  x.beginPath();x.arc(cx,cx,r1*k,a-A/2,a+A/2);x.arc(cx,cx,r0*k,a+A/2,a-A/2,true);x.closePath();x.fill()});
 ring(1.78,2.26,true);ring(2.26,RLW.num,false);
 const g=x.createRadialGradient(cx,cx,1.78*k,cx,cx,2.26*k);g.addColorStop(0,'rgba(0,0,0,.45)');g.addColorStop(.5,'rgba(0,0,0,0)');g.addColorStop(1,'rgba(0,0,0,.3)');x.fillStyle=g;x.beginPath();x.arc(cx,cx,2.26*k,0,Math.PI*2);x.arc(cx,cx,1.78*k,0,Math.PI*2,true);x.fill();
 x.fillStyle='#fff';x.textAlign='center';x.textBaseline='middle';x.font='800 34px "DejaVu Sans",system-ui,sans-serif';
 RL_ORDER.forEach((n,i)=>{const a=i*A-Math.PI/2;x.save();x.translate(cx+Math.cos(a)*2.48*k,cx+Math.sin(a)*2.48*k);x.rotate(a+Math.PI/2);x.fillText(String(n),0,0);x.restore()});
 x.strokeStyle='#E9B44C';x.lineWidth=4;for(const r of[2.26,RLW.num-.02])x.beginPath(),x.arc(cx,cx,r*k,0,Math.PI*2),x.stroke();
 x.lineWidth=2.5;RL_ORDER.forEach((n,i)=>{const a=i*A-Math.PI/2+A/2;x.beginPath();x.moveTo(cx+Math.cos(a)*2.26*k,cx+Math.sin(a)*2.26*k);x.lineTo(cx+Math.cos(a)*RLW.num*k,cx+Math.sin(a)*RLW.num*k);x.stroke()});return c}
const rlCam=asp=>{const t=clamp((asp-.8)/1.2,0,1);return{eye:[0,lerpN(9.4,8.2,t),lerpN(6.2,5.4,t)],tgt:[0,.1,-.35],fov:clamp(2*Math.atan(Math.tan(.4)/Math.min(1,asp)),.62,1.25),sy:0,sx:0}};
CSG3B.csrl=()=>{const sc=g3Scene({cam:{fixed:rlCam,tgt:[0,0,0],fov:1,dy:0,dp:0,dz:1},orbit:false,zoom:false,shR:7,shC:[0,0,0],spot:[0,2.4,9,.6],bg:[.035,.024,.02],
  light:{d:v3.norm([-.3,1,.45]),c:[2.4,2.14,1.78],sky:[.26,.22,.2],gnd:[.12,.08,.06],exp:1.0}});
 luxTable(sc);envLounge(sc);mkModel(sc);
 const wood=g3Mat({t:woodTex('walnut'),c:'#7A4A2A',sh:110,sp:.55,gl:.4}),track=g3Mat({c:'#5A2E12',sh:140,sp:.7,gl:.6}),gold=goldM();
 /* the bowl: outer rim, the track wall, the sloping track down to the rotor */
 P3(sc,gLathe([[RLW.rim,0],[RLW.rim+.02,.42],[RLW.rim-.04,.6],[RLW.rim-.24,.64],[RLW.rim-.27,.56]],96,.5),wood,[0,0,0]);
 P3(sc,gLathe([[RLW.rim-.27,.56],[RLW.trk+.1,RLW.yT],[RLW.num+.06,RLW.yP+.06],[RLW.num+.04,RLW.yP-.04]],96,.5),track,[0,0,0]);
 P3(sc,gTorus(RLW.rim-.06,.03,96,6),gold,[0,.6,0],null,false);
 /* eight diamonds on the track */
 for(let k=0;k<8;k++){const a=k*Math.PI/4+Math.PI/8;P3(sc,gEll(.07,.04,.15),gold,[Math.cos(a)*(RLW.trk-.18),RLW.yT-.04,Math.sin(a)*(RLW.trk-.18)],qt.ax(0,1,0,-a))}
 /* the rotor: the numbered disc, 37 frets, the cone and the turret with its cross */
 const A=Math.PI*2/37,frets=gMerge(...RL_ORDER.map((n,i)=>{const a=i*A-Math.PI/2+A/2;return gXf(gBox(.5,.09,.025,.008,1),[Math.cos(a)*2.02,RLW.yP+.045,Math.sin(a)*2.02],qt.ax(0,1,0,-a))}));
 const cone=gLathe([[1.8,RLW.yP+.01],[1.76,RLW.yP+.05],[1.1,RLW.yP+.2],[.55,RLW.yP+.32],[.48,RLW.yP+.34]],64,.5);
 const tur=gLathe([[.48,RLW.yP+.34],[.4,RLW.yP+.4],[.26,RLW.yP+.44],[.15,RLW.yP+.7],[.1,RLW.yP+.9],[.17,RLW.yP+1],[.12,RLW.yP+1.08],[0,RLW.yP+1.1]],40,.5);
 const cross=gMerge(...[0,1,2,3].map(j=>{const a=j*Math.PI/2;return gMerge(gXf(gBox(.9,.05,.05,.02,1),[Math.cos(a)*.48,RLW.yP+.62,Math.sin(a)*.48],qt.ax(0,1,0,-a)),gEll(.07,.07,.07,[Math.cos(a)*.95,RLW.yP+.62,Math.sin(a)*.95]))}));
 g3Model(sc,'rotor',[[gXf(gDisc(RLW.num,111),[0,RLW.yP,0],qt.id()),g3Mat({t:g3T('rldisc',()=>g3Tex(rlDiscCv())),sh:90,sp:.45,gl:.35})],[frets,gold],[cone,g3Mat({c:'#4A2410',t:woodTex('walnut'),sh:120,sp:.6,gl:.45})],[gMerge(tur,cross),gold]],null);
 g3Model(sc,'ball',[[gEll(RLW.ball,RLW.ball,RLW.ball,[0,0,0],null,20),g3Mat({c:'#F4F6F8',sh:180,sp:1.2,gl:.85})]],null);
 sc.onTick=now=>{const st=rlNow(now),o=sc.objs.get('k:rotor');if(o){o.q=qt.ax(0,1,0,-st.rot*Math.PI/180);o.tw=null}const b=sc.objs.get('k:ball');
  if(b){const p=rlBallP(st);if(p){b.p=p;b.a=1}else b.a=0;b.tw=null}return st.live};
 sc.onResize=()=>{try{G3U.csrl(sc)}catch(e){}};return sc};
/* the ball's place: from the pocket (r 0) to the track (r 1), a hop on top */
function rlBallP(st){const b=st.ball;if(!b)return null;const a=(b.phi+st.rot-90)*Math.PI/180,R=RLW.pk+b.r*(RLW.trk-RLW.pk)+b.h*.14,y=lerpN(RLW.yP,RLW.yT-.02,b.r)+RLW.ball+b.h*.2;return[Math.cos(a)*R,y,Math.sin(a)*R]}
G3U.csrl=sc=>{const st=rlNow(performance.now()),p=rlBallP(st);
 g3Set(sc,[{k:'rotor',m:'rotor',p:[0,0,0],q:qt.ax(0,1,0,-st.rot*Math.PI/180),now:true},{k:'ball',m:'ball',p:p||[0,RLW.yT,RLW.trk],a:p?1:0,now:true,cast:true}])};
