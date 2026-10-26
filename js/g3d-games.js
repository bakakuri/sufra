/* the 3D scenes of the five games. each scene is built once; on every render the game's state becomes a list of objects
   (matched with what is already on the table, so moves animate) and a list of flat marks (selection, targets, last move) */
const G3S={},G3B={},G3U={};
const GOLD=lin('#F4BC4C'),GOLDS=lin('#FFD27A'),RED=lin('#FF5A5F'),INK=lin('#20140c'),PALE=lin('#FFF4D6'),MINT=lin('#7CF0B4');
function g3Show(id){const el=$('.g3',view);if(!el)return;const k=id==='jko'?'joker':id==='dmo'?'domino':id,pl=gPlaceOf(k),key=pl&&pl!==GPDEF[k]?k+':'+pl:k,sc=G3S[key]||(G3S[key]=G3B[k]());sc.host=id;
 const want=G3D.intro||G3W.intro,intro=want===id;if(intro){G3D.intro=null;G3W.intro=null}
 if(!g3Mount(el,sc))return;if(sc.envK)envApply(sc);if(typeof gAmb==='function')gAmb(sc.envK||null,sc.envT,k,sc.wx&&sc.wx.k);try{G3U[id](sc)}catch(e){try{console.warn('3D sync',e)}catch(x){}}if(intro)g3StartIntro(sc);g3Insets(sc);g3Draw(sc,performance.now());g3Labels(sc);g3Need()}
const snd=(k,v)=>{if(typeof gSnd==='function')gSnd(k,v)};
/* a piece that lands knocks on the wood and leaves a ring; one put in a tray knocks softly */
const woodLand=y=>(o,sc)=>{const soft=(o.s.length?o.s[0]:o.s)<.9;snd(soft?'soft':'wood',soft?.7:1);if(!soft)g3Ripple(sc,[o.p[0],y+.006,o.p[2]],1.1)};
const mkModel=sc=>g3Model(sc,'mk',[[gPlane(1,1),g3Mat({t:g3T('marks',()=>g3Tex(marksCv(),{af:false})),unlit:true,vary:true}),false]],null);
function g3Table(sc,o={}){const g=gPlane(o.w||44,o.d||44,o.rep||6,o.rep||6);sc.statics.push({parts:[{mesh:g3Mesh(g),mat:g3Mat({t:woodTex(o.wood||'table'),sh:18,sp:.1,gl:.06}),cast:false}],M:m4.trs([0,o.y||0,0],qt.id(),1),cast:false})}
function g3Static(sc,g,mat,p,q,cast=true){sc.statics.push({parts:[{mesh:g3Mesh(g),mat,cast}],M:m4.trs(p,q||qt.id(),1),cast})}
const pieceMat=w=>w?g3Mat({t:woodTex('boxv'),uv:[0,0,2,1],sh:70,sp:.45,gl:.55}):g3Mat({t:woodTex('ebonyv'),uv:[0,0,2,1],sh:90,sp:.6,gl:.75});
WOOD.boxv=Object.assign({},WOOD.box,{dir:'v'});WOOD.ebonyv=Object.assign({},WOOD.ebony,{dir:'v'});
const blob=(x,y,z,s,a=.42)=>({m:'mk',p:[x,y+.002,z],s:[s,1,s],uv:MK.blob,c:[0,0,0],a});

/* ---------- chess ---------- */
const CHT=.42;
G3B.chess=()=>{const sc=g3Scene({hug:1,cam:{yaw:0,pitch:.9,pp:0,fov:.76,tgt:[0,.25,.3],box:[[-4.75,0,-5.7],[4.75,1.2,5.9]],anchorB:1,dy:0,dp:0,dz:1,my:.97,mxp:.995},shR:8.5,spot:[0,0,7.6,.85]});
 gEnvBuild(sc,'chess');mkModel(sc);const W=9.5,T=CHT;
 const bt=g3T('bchess',()=>g3Tex(boardCv({size:W,border:.75,frame:'frame',light:'maple',dark:'wenge',inlay:'rgba(226,184,96,.95)',ink:'rgba(244,214,156,.9)',coords:1})));
 sc.statics.push({parts:[{mesh:g3Mesh(gBox(W,T,W,.07,4,null,[0])),mat:g3Mat({t:bt,sh:70,sp:.35,gl:.3}),cast:true},{mesh:g3Mesh(gBox(W,T,W,.07,4,(f,u,v)=>[u*2.5,v*.35],[1,2,3,4,5])),mat:g3Mat({t:woodTex('frame'),sh:60,sp:.35,gl:.3}),cast:true}],M:m4.trs([0,T/2,0],qt.id(),1),cast:true});
 chessSet(sc,gStyleOf('chess'));
 sc.refl={y:T,rect:[-4,-4,4,4],k:.3,fade:1.4};
 sc.tap=ray=>{const o=g3HitObj(sc,ray,o=>o.pick);let i=o?o.pick.i:null;if(i==null){const p=g3HitY(ray,CHT);i=p?chAt(p):null;if(i==null)return}g3Act('chm',{i:String(i)})};
 /* drag a piece to a square; the square under it lights up when the move is legal */
 sc.drag={y:T,lift:.6,start:o=>{if(CH.sel!==o.pick.i)g3Act('chm',{i:String(o.pick.i)})},
  move:(o,p)=>{const i=chAt(p);if(i==null||i===o.pick.i)return null;const ok=CH.moves.some(m=>m.f===o.pick.i&&m.t===i),[x,z]=chXZ(i);return{m:'mk',p:[x,T+.006,z],s:[1.02,1,1.02],uv:MK.sq,c:ok?GOLD:PALE,a:ok?1:.35,add:true}},
  drop:(o,p)=>{sc.dragAt=performance.now();const i=p?chAt(p):null;if(i!=null&&i!==o.pick.i)g3Act('chm',{i:String(i)})}};
 return sc};
const chAt=p=>{const c=Math.floor(p[0]+4),r=Math.floor(p[2]+4);return c<0||c>7||r<0||r>7?null:r*8+c};
const chXZ=i=>[(i&7)-3.5,(i>>3)-3.5];
G3U.chess=sc=>{const G=CH,st=G.st,c=G.ctx,T=CHT;sc.cam.yaw=c.side===-1?Math.PI:0;const L=[],M=[],mine=G.mine(),from=new Set(mine?G.moves.map(m=>m.f):[]);
 st.b.forEach((p,i)=>{if(!p)return;const t=p.toLowerCase(),w=isW(p),[x,z]=chXZ(i),sel=G.sel===i;L.push({m:(w?'w':'b')+t,p:[x,T,z],q:t==='n'?qt.ax(0,1,0,w?(i&7)<4?Math.PI-.62:.62:(i&7)<4?Math.PI+.62:-.62):qt.id(),pick:{i},drag:from.has(i),lift:sel?.22:0,glow:sel?[.14,.1,.03]:null});M.push(blob(x,T,z,1.05,.38))});
 /* a capture throws sparks where it happened */
 const n=st.b.filter(Boolean).length;if(sc.pc!=null&&n<sc.pc&&st.last.length===2){const[x,z]=chXZ(st.last[1]);g3Sparks(sc,[x,T+.02,z],null,12,330)}sc.pc=n;
 for(const col of[1,-1])chTaken(st.b,-col).forEach((t,k)=>{const x=(-4.2+k*.6)*col,z=5.3*col;L.push({m:(col===1?'b':'w')+t,p:[x,0,z],s:.62,q:t==='n'?qt.ax(0,1,0,col===1?-Math.PI/2:Math.PI/2):qt.id()});M.push(blob(x,0,z,.7,.3))});
 const mk=(i,uv,col,a,s,o)=>{const[x,z]=chXZ(i);M.push(Object.assign({m:'mk',p:[x,T+.004,z],s:[s,1,s],uv,c:col,a},o||{}))};
 st.last.forEach(i=>mk(i,MK.dot,GOLDS,.38,1.25));
 if(G.inCheck()&&!st.over){const k=chKing(st.b,st.turn);if(k>=0)mk(k,MK.dot,RED,.85,1.5,{add:true,pulse:true})}
 if(G.sel!=null){mk(G.sel,MK.sq,GOLD,1,1.02,{add:true});for(const m of G.moves.filter(m=>m.f===G.sel))(st.b[m.t]||m.ep)?mk(m.t,MK.ring,GOLD,.95,.95,{add:true}):mk(m.t,MK.dot,GOLD,.9,.38,{add:true})}
 if(sc.sty!==gStyleOf('chess'))chessSet(sc,gStyleOf('chess'));oppAdd(sc,'chess',G,L,c.side===-1?1:-1);mkBig(M);
 mhPush(sc,L,{on:mhShow(c),yaw:c.side===-1?Math.PI:0,y:-1.3,S:1.35,rest:[[-3.6,8.9],[3.6,8.9]]});
 const mvk=st.last.join()+'|'+st.turn+'|'+(G.mv?G.mv.length:0);let reach=null;if(sc.mvk!==mvk){if(sc.mvk!=null&&st.last.length===2&&sc.mh&&mhMover(c,st.turn)&&performance.now()-(sc.dragAt||0)>900)reach=st.last.map(chXZ);sc.mvk=mvk}
 const at=(d,xz)=>!!xz&&Math.abs(d.p[0]-xz[0])<.01&&Math.abs(d.p[2]-xz[1])<.01&&Math.abs(d.p[1]-T)<.01;
 sc.marks=M;g3Set(sc,L,{delay:(o,d)=>d.s<1&&d.m.length===2?280:reach&&at(d,reach[1])?MH_WAIT:0,dur:(o,d,far)=>d.m[1]==='n'&&far>1?560:Math.min(620,280+90*Math.sqrt(far))});
 if(reach){const[f,t]=reach,far=Math.hypot(t[0]-f[0],t[1]-f[1]),pc=st.b[st.last[1]]||'';mhCarry(sc,[{p:[f[0],T,f[1]]},{p:[t[0],T,t[1]],d:pc.toLowerCase()==='n'&&far>1?560:mhDur(far),arc:far>.7?Math.min(1.5,.3+far*.13):0}])}
 if(st.over){const k=st.why==='mate'?chKing(st.b,st.turn):-1,i=k>=0?k:st.last[1];if(i!=null&&i>=0){const[x,z]=chXZ(i);g3CineGo(sc,G,[x,T,z])}}};

/* ---------- checkers ---------- */
const CKT=.42;
G3B.shashi=()=>{const sc=g3Scene({hug:1,cam:{yaw:0,pitch:.9,pp:0,fov:.76,tgt:[0,.2,.3],box:[[-4.75,0,-5.6],[4.75,.8,5.8]],anchorB:1,dy:0,dp:0,dz:1,my:.97,mxp:.995},shR:8.5,spot:[0,0,7.6,.85]});
 gEnvBuild(sc,'shashi');mkModel(sc);const W=9.5,T=CKT;
 const bt=g3T('bck',()=>g3Tex(boardCv({size:W,border:.75,frame:'rose',light:'birch',dark:'mahog',inlay:'rgba(226,184,96,.95)',ink:'rgba(244,220,170,.9)',coords:1})));
 sc.statics.push({parts:[{mesh:g3Mesh(gBox(W,T,W,.07,4,null,[0])),mat:g3Mat({t:bt,sh:70,sp:.35,gl:.3}),cast:true},{mesh:g3Mesh(gBox(W,T,W,.07,4,(f,u,v)=>[u*2.5,v*.35],[1,2,3,4,5])),mat:g3Mat({t:woodTex('rose'),sh:60,sp:.35,gl:.3}),cast:true}],M:m4.trs([0,T/2,0],qt.id(),1),cast:true});
 const man=g3Mesh(manGeo()),two=g3Mesh(gMerge(manGeo(),gXf(manGeo(),[0,.13,0],qt.id()))),crown=g3Mesh(gXf(gLathe(arc(.2,0,.035,-Math.PI/2,Math.PI*1.5,14).map(([r,y])=>[r,y]),36),[0,.262,0],qt.id()));
 const wm=g3Mat({c:'#F4EADA',sh:80,sp:.5,gl:.6}),bm=g3Mat({c:'#2A1C17',sh:90,sp:.6,gl:.75}),gm=g3Mat({c:'#E2A93F',sh:120,sp:.9,gl:.9});
 for(const[k,parts,e]of[['w',[[man,wm]],.08],['b',[[man,bm]],.08],['W',[[two,wm],[crown,gm]],.15],['B',[[two,bm],[crown,gm]],.15]])g3Model(sc,k,parts,[.4,e,.4],[0,e-.01,0]).land=woodLand(T);
 sc.refl={y:T,rect:[-4,-4,4,4],k:.3,fade:1};
 const at=p=>{const c=Math.floor(p[0]+4),r=Math.floor(p[2]+4);return c<0||c>7||r<0||r>7||(r+c)%2===0?null:[r,c]};
 sc.tap=ray=>{const o=g3HitObj(sc,ray,o=>o.pick);let q=o?[o.pick.r,o.pick.c]:null;if(!q){const p=g3HitY(ray,CKT);q=p?at(p):null}if(q)g3Act('ck',{r:String(q[0]),c:String(q[1])})};
 sc.drag={y:T,lift:.5,start:o=>{const s=CK.sel;if(!s||s[0]!==o.pick.r||s[1]!==o.pick.c)g3Act('ck',{r:String(o.pick.r),c:String(o.pick.c)})},
  move:(o,p)=>{const q=at(p);if(!q||(q[0]===o.pick.r&&q[1]===o.pick.c))return null;const ok=CK.targets().includes(q.join());return{m:'mk',p:[q[1]-3.5,T+.006,q[0]-3.5],s:[1.02,1,1.02],uv:MK.sq,c:ok?GOLD:PALE,a:ok?1:.35,add:true}},
  drop:(o,p)=>{sc.dragAt=performance.now();const q=p?at(p):null;if(q&&!(q[0]===o.pick.r&&q[1]===o.pick.c))g3Act('ck',{r:String(q[0]),c:String(q[1])})}};
 return sc};
G3U.shashi=sc=>{const G=CK,c=G.ctx,T=CKT;sc.cam.yaw=c.side===-1?Math.PI:0;const L=[],M=[],xz=(r,cc)=>[cc-3.5,r-3.5];
 const mv=JSON.stringify(G.last),fresh=mv!==sc.lm&&G.last.length>1;sc.lm=mv;const end=G.last[G.last.length-1];
 const from=new Set(G.mine()?G.moves.map(m=>m.path[0].join()):[]);
 if(fresh&&G.lcap&&G.lcap.length&&end){const[x,z]=xz(end[0],end[1]);g3Sparks(sc,[x,T+.02,z],null,10,240+G.last.length*240)}
 for(let r=0;r<8;r++)for(let cc=0;cc<8;cc++){const p=G.b[r][cc];if(!p)continue;const[x,z]=xz(r,cc),sel=G.sel&&G.sel[0]===r&&G.sel[1]===cc,d={m:Math.abs(p)===2?(p>0?'W':'B'):(p>0?'w':'b'),p:[x,T,z],pick:{r,c:cc},drag:from.has(r+','+cc),lift:sel?.16:0,glow:sel?[.12,.09,.03]:null};
  if(fresh&&end&&end[0]===r&&end[1]===cc&&G.last.length>2){d.path=G.last.slice(1).map(([a,b])=>{const[px,pz]=xz(a,b);return[px,T,pz]});d.hops=d.path.map(()=>.55);d.dur=300*d.path.length;
   const[sx,sz]=xz(G.last[0][0],G.last[0][1]);d.from={p:[sx,T,sz],a:1}}
  L.push(d);M.push(blob(x,T,z,.95,.36))}
 /* taken men stand in stacks by the side of whoever took them */
 for(const s of[1,-1]){const n=12-G.cnt(-s);for(let k=0;k<n;k++){const x=(3.2+Math.floor(k/6)*.95)*s,z=5.25*s,y=(k%6)*.13;L.push({m:s===1?'b':'w',p:[x,y,z],cast:true});if(k%6===0)M.push(blob(x,0,z,.9,.3))}}
 const mk=(r,cc,uv,col,a,s,o)=>{const[x,z]=xz(r,cc);M.push(Object.assign({m:'mk',p:[x,T+.004,z],s:[s,1,s],uv,c:col,a},o||{}))};
 G.last.forEach(([r,cc],i)=>mk(r,cc,MK.dot,GOLDS,i===G.last.length-1||i===0?.38:.25,i===G.last.length-1||i===0?1.25:.55));
 const mine=G.mine(),must=mine&&G.moves.length&&G.moves[0].caps.length;
 if(must&&!G.sel)for(const k of new Set(G.moves.map(m=>m.path[0].join()))){const[r,cc]=k.split(',').map(Number);mk(r,cc,MK.ring,GOLD,.9,1.05,{add:true,pulse:true})}
 if(G.sel){mk(G.sel[0],G.sel[1],MK.sq,GOLD,1,1.02,{add:true});for(const k of G.targets()){const[r,cc]=k.split(',').map(Number);mk(r,cc,MK.dot,GOLD,.9,.4,{add:true})}}
 oppAdd(sc,'shashi',G,L,c.side===-1?1:-1);mkBig(M);mhPush(sc,L,{on:mhShow(c),yaw:c.side===-1?Math.PI:0,y:-1.3,S:1.35,rest:[[-3.6,8.9],[3.6,8.9]]});
 const hand=fresh&&!!sc.mh&&sc.lm0!=null&&mhMover(c,G.turn)&&performance.now()-(sc.dragAt||0)>900,hw=hand?MH_WAIT:0;sc.lm0=mv;
 sc.marks=M;const caps=(G.lcap||[]).map(([r,cc])=>xz(r,cc)),endXZ=end?xz(end[0],end[1]):null;
 g3Set(sc,L,{gone:o=>fresh&&G.last.length&&Math.abs(o.p[0]-(G.last[0][1]-3.5))<.01&&Math.abs(o.p[2]-(G.last[0][0]-3.5))<.01?{a:0,dur:1}:null,
  delay:(o,d)=>{if(!fresh)return 0;if(hw&&endXZ&&Math.abs(d.p[0]-endXZ[0])<.01&&Math.abs(d.p[2]-endXZ[1])<.01&&d.m!=='mk')return hw;const k=caps.findIndex(([x,z])=>Math.abs(o.p[0]-x)<.01&&Math.abs(o.p[2]-z)<.01);return k<0?0:180+k*300+hw}});
 if(hand){const pts=G.last.map(([r,cc])=>{const[x,z]=xz(r,cc);return[x,T,z]}),hop=G.last.length>2;mhCarry(sc,pts.map((p,i)=>({p,d:i?(hop?300:mhDur(Math.hypot(p[0]-pts[0][0],p[2]-pts[0][2]))):0,arc:hop?.55:.3})))}
 if(G.over&&endXZ)g3CineGo(sc,G,[endXZ[0],T,endXZ[1]])};

/* ---------- nardi ---------- */
const NT=.35,NRIM=.13;
const nCol=di=>di>=12?{col:di<18?di-12:di-11,top:1}:{col:di>=6?11-di:12-di,top:0};
/* nardi is seen from your own stool: low over the board, the other player big across it, the yard behind him */
G3B.nardi=()=>{const sc=g3Scene({hug:1,cam:{yaw:0,pitch:.86,pp:0,fov:.78,tgt:[.8,.2,.35],box:[[-7,0,-6.1],[8.6,.9,6.75]],anchorB:1,dy:0,dp:0,dz:1,mxp:.995},shR:10.5,shC:[.8,0,0],spot:[.8,0,10,.65],yawMax:.5});
 gEnvBuild(sc,'nardi');mkModel(sc);const fr=g3Mat({t:woodTex('frame'),sh:60,sp:.35,gl:.32});
 const top=g3T('bnardi:classic',()=>g3Tex(nardiCv('classic')));sc.boardM=g3Mat({t:top,sh:55,sp:.3,gl:.25});sc.sty='classic';
 sc.statics.push({parts:[{mesh:g3Mesh(gBox(15.6,NT,12.2,.08,3,null,[0])),mat:sc.boardM,cast:true},{mesh:g3Mesh(gBox(15.6,NT,12.2,.08,3,(f,u,v)=>[u*3,v*.3],[1,2,3,4,5])),mat:fr,cast:true}],M:m4.trs([.8,NT/2,0],qt.id(),1),cast:true});
 const rim=(x,z,w,d,h=NRIM)=>g3Static(sc,gBox(w,h,d,.05,3,(f,u,v)=>[u*Math.max(1,w/3),v*Math.max(1,d/3)]),fr,[x,NT+h/2,z]);
 rim(.8,-5.85,15.6,.5);rim(.8,5.85,15.6,.5);rim(-6.75,0,.5,11.2);rim(0,0,1,11.2,NRIM+.02);rim(6.725,0,.45,11.2);rim(8.375,0,.45,11.2);
 const ck=g3Mesh(checkerGeo());g3Model(sc,'w',[[ck,g3Mat({c:'#F2E8D6',sh:80,sp:.5,gl:.6})]],[.44,.09,.44],[0,.08,0]).land=woodLand(NT);g3Model(sc,'b',[[ck,g3Mat({c:'#3a1714',sh:90,sp:.6,gl:.75})]],[.44,.09,.44],[0,.08,0]).land=woodLand(NT);
 g3Model(sc,'die',[[dieGeo(.62),g3Mat({t:g3T('dice',()=>g3Tex(diceCv(),{af:false})),sh:90,sp:.5,gl:.45})]],[.31,.31,.31]).land=()=>snd('soft',.8);
 sc.refl={y:NT,rect:[-6.5,-5.6,6.5,5.6],k:.2,fade:.9};
 sc.tap=ray=>{const p=g3HitY(ray,NT),k=p?nKAt(p):null;if(k!=null)g3Act('npt',{k})};
 sc.drag={y:NT,lift:.55,start:o=>{if(NR.sel!==o.pick.f)g3Act('npt',{k:String(o.pick.f)})},
  move:(o,p)=>{const k=nKAt(p);if(k==null||k===String(o.pick.f))return null;const id=k==='off'||k==='bar'?k:+k,ok=NR.opts(NR.ctx.side,o.pick.f).some(x=>x.to===id);if(!ok)return null;
   if(id==='off')return{m:'mk',p:[7.55,NT+.006,3],s:[1.2,1,5.4],uv:MK.sq,c:GOLD,a:1,add:true};const flip=NR.ctx.side===-1,{col,top}=nCol(flip?23-id:id);return{m:'mk',p:[col-6,NT+.006,top?-3.15:3.15],s:[1,1,4.9],uv:MK.sq,c:GOLD,a:1,add:true}},
  drop:(o,p)=>{sc.dragAt=performance.now();const k=p?nKAt(p):null;if(k!=null&&k!==String(o.pick.f))g3Act('npt',{k})}};
 return sc};
/* which point (or the bar, or the tray) a spot on the board belongs to */
function nKAt(p){const flip=NR.ctx.side===-1,[x,z]=[p[0],p[2]];if(z<-5.7||z>5.7)return null;if(x>6.9&&x<8.3)return 'off';if(x<-6.6||x>6.6)return null;
 const col=Math.round(x+6);if(col===6)return 'bar';const top=z<0,di=top?(col<6?12+col:col+11):(col<6?11-col:12-col);return String(flip?(NR.v==='long'?(di+12)%24:23-di):di)}
function nSlot(di,k){const{col,top}=nCol(di),lay=Math.floor(k/5),idx=k%5;return[col-6,NT+lay*.165,top?-5.1+idx*.9+lay*.45:5.1-idx*.9-lay*.45]}
G3U.nardi=sc=>{const G=NR,c=G.ctx,me=c.side,flip=me===-1,L=[],M=[],dI=i=>flip?(G.v==='long'?(i+12)%24:23-i):i,sty=gStyleOf('nardi');if(sc.sty!==sty){sc.sty=sty;sc.boardM.t=g3T('bnardi:'+sty,()=>g3Tex(nardiCv(sty)))}
 const can=new Set(G.mine()&&G.rolled?G.legal().map(m=>m.f):[]);
 for(let i=0;i<24;i++){const v=G.p[i],n=Math.abs(v);for(let k=0;k<n;k++){const p=nSlot(dI(i),k),top=k===n-1,mv=top&&can.has(i),sel=top&&G.sel===i;L.push({m:v>0?'w':'b',p,pick:mv?{f:i}:null,drag:mv,lift:sel?.18:0,glow:sel?[.12,.09,.03]:null})}}
 for(const s of[me,-me])for(let k=0;k<G.bar[s];k++){const mv=s===me&&k===G.bar[s]-1&&can.has('bar'),sel=mv&&G.sel==='bar';L.push({m:s===1?'w':'b',p:[0,NT+NRIM+.02+Math.floor(k/4)*.165,(s===me?1:-1)*(1.05+(k%4)*.9)],pick:mv?{f:'bar'}:null,drag:mv,lift:sel?.18:0,glow:sel?[.12,.09,.03]:null,refl:false})}
 for(const s of[me,-me])for(let k=0;k<G.off[s];k++)L.push({m:s===1?'w':'b',p:[7.55,NT+.44,(s===me?1:-1)*(5.3-k*.172)],q:qt.ax(1,0,0,Math.PI/2)});
 /* dice: the mover's dice lie in their half; a fresh roll is thrown from their edge and tumbles */
 const all=G.last.length===2?(G.last[0]===G.last[1]?[G.last[0],G.last[0],G.last[0],G.last[0]]:G.last.slice()):[],left=G.dice.slice();
 const used=all.map(v=>{const k=left.indexOf(v);if(k>=0){left.splice(k,1);return false}return true});
 const sig=G.rolled?G.turn+':'+G.last.join(','):'';G.rollAnim=0;let myThrow=false;if(sig&&sig!==sc.rsig){const was=sc.rsig!=null;sc.rsig=sig;sc.roll=(sc.roll||0)+1;sc.dside=G.turn===me?1:-1;myThrow=was&&!G.open&&mhShow(c)&&(c.mode==='local'||G.turn===me)&&myHandsOn()}if(sc.dside==null)sc.dside=G.turn===me?1:-1;
 const side=sc.dside,R=rng((sc.roll||0)*977+7),thrower=side;
 all.forEach((v,i)=>{const x=side*(all.length>2?1.9+i*.82:2.7+i*1.05),z=all.length>2?(i%2?.12:-.12):(i?.14:-.1),yaw=(R()-.5)*1.2,q=qt.mul(qt.ax(0,1,0,yaw),dieUp(v)),d={k:'d'+(sc.roll||0)+'-'+i,m:'die',p:[x,NT+.31,z],q,dim:used[i]?.42:1};
  if(sc.roll&&sc.rolled!==sc.roll){const from=[x+side*(1.5+R()),NT+2.4,thrower*4.6];d.from={p:from,q:qt.mul(qt.ax(R(),R(),R(),R()*6),q)};
   d.path=[[x+side*.5*(R()-.2),NT+.31,z*.5+thrower*1.2],[x,NT+.31,z]];d.hops=[.15,.55];d.spin=[R()-.5,R()-.5,R()-.5,2+Math.floor(R()*2)];d.ez='out';d.dur=1000+i*90;d.delay=i*40+(myThrow?200:0)}
  L.push(d)});
 if(sc.roll)sc.rolled=sc.roll;
 /* marks: the chosen point, where it can go, and which checkers can move */
 const mine=G.mine()&&G.rolled,sel=G.sel,mk=(p,uv,col,a,s,o)=>M.push(Object.assign({m:'mk',p,s,uv,c:col,a},o||{}));
 const ptMark=(i,col,a)=>{const{col:cc,top}=nCol(dI(i));mk([cc-6,NT+.003,top?-3.15:3.15],MK.sq,col,a,[.98,1,4.9],{add:true})};
 if(mine&&sel!==null){if(sel==='bar')mk([0,NT+NRIM+.04,3],MK.sq,GOLD,1,[1,1,5],{add:true});else ptMark(sel,GOLD,.95);
  for(const o of G.opts(me,sel)){if(o.to==='off'){mk([7.55,NT+.005,3],MK.sq,GOLD,.95,[1.1,1,5.2],{add:true,pulse:true});continue}const n=Math.abs(G.p[o.to]),p=nSlot(dI(o.to),G.p[o.to]*me<0?0:n);mk([p[0],p[1]+.01,p[2]],MK.dot,GOLD,.95,[.62,1,.62],{add:true,pulse:true})}}
 if(mine&&G.hint&&G.hint.length){const h=G.hint[0];if(h.f!=='bar')ptMark(h.f,MINT,.75);if(h.to==='off')mk([7.55,NT+.005,3],MK.sq,MINT,.8,[1.1,1,5.2],{add:true});else ptMark(h.to,MINT,.75)}
 if(mine&&sel!==null){}else if(mine&&G.legal().length){const from=new Set(G.legal().map(m=>m.f));for(const f of from){if(f==='bar'){const k=G.bar[me]-1;mk([0,NT+NRIM+.03+Math.floor(k/4)*.165+.17,1.05+(k%4)*.9],MK.ring,GOLD,.9,[1.05,1,1.05],{add:true,pulse:true});continue}
   const n=Math.abs(G.p[f]),p=nSlot(dI(f),n-1);mk([p[0],p[1]+.17,p[2]],MK.ring,GOLD,.9,[1.05,1,1.05],{add:true,pulse:true})}}
 oppAdd(sc,'nardi',G,L,-1);mkBig(M);mhPush(sc,L,{on:mhShow(c),yaw:0,y:-1.5,S:1.7,rest:[[-3.2,10.2],[5.4,10.2]]});
 /* the checker I just moved: where it came from and where it went */
 let reach=null;if(sc.mvn!==G.mvN){if(sc.mvn!=null&&sc.mh&&G.lastTo!=null&&G.lastFrom!=null&&(c.mode==='local'||G.lastBy===me)&&performance.now()-(sc.dragAt||0)>900){const s=G.lastBy,f=G.lastFrom,t=G.lastTo,sg=s===me?1:-1;
   const fp=f==='bar'?(k=>[0,NT+NRIM+.02+Math.floor(k/4)*.165,sg*(1.05+(k%4)*.9)])(G.bar[s]):nSlot(dI(f),Math.abs(G.p[f])),tp=t==='off'?(k=>[7.55,NT+.44,sg*(5.3-k*.172)])(G.off[s]-1):nSlot(dI(t),Math.abs(G.p[t])-1);reach=[fp,tp]}sc.mvn=G.mvN}
 const near=(a,b)=>!!b&&Math.abs(a[0]-b[0])<.01&&Math.abs(a[1]-b[1])<.01&&Math.abs(a[2]-b[2])<.01;
 sc.marks=M;g3Set(sc,L,{gone:o=>o.m==='die'?{a:0,dur:220}:null,delay:(o,d)=>reach&&d.m!=='die'&&near(d.p,reach[1])?MH_WAIT:d.m!=='die'&&Math.abs(d.p[0])<.01&&o.p[0]!==0?260:0});
 if(reach)mhCarry(sc,[{p:reach[0]},{p:reach[1],d:mhDur(v3.len(v3.sub(reach[1],reach[0]))),arc:.6}]);if(myThrow)mhThrow(sc,[4.4,NT+.6,4.4]);
 if(G.over)g3CineGo(sc,G,[7.55,NT,(G.over===me?1:-1)*3.2])};

/* ---------- cards: the joker table, seen from your own chair ----------
   a round table in a dim room under one lamp. the three others sit at it, hold their cards and look at whoever is playing.
   your own cards are held in front of you at the bottom of the screen; played cards fly to the middle and the trick sweeps to its winner */
const CDW=.92,CDH=1.28,JR=8.1,JA=.8,JTS=2.3;
/* seats counted from me: 0 me, 1 left, 2 across, 3 right. the side seats sit a little toward the far side, so a phone held upright still sees all three */
const JSP=[[0,JR],[-JR*Math.sin(JA),-JR*Math.cos(JA)],[0,-JR],[JR*Math.sin(JA),-JR*Math.cos(JA)]];
const JYAW=JSP.map(([x,z])=>Math.atan2(-x,-z));
const JTRK=JSP.map(([x,z],i)=>{const l=Math.hypot(x,z);return i===0?[0,1.95]:[x/l*1.95,z/l*1.9]}),JTJ=[-.05,.12,.03,-.1];
const lerpN=(a,b,t)=>a+(b-a)*t;
/* the eye sits above your chair; how wide it sees follows the screen, so the three players stay in view held upright or on its side */
function jkCam(asp){const t=clamp((asp-.55)/1.0,0,1),eye=[0,lerpN(5.9,8.2,t),lerpN(8.3,12.4,t)],tgt=[0,lerpN(.2,1.5,t),lerpN(-1.6,-2.2,t)];
 /* on a wide screen the panels take a column on the right, so the table moves into the space left of it */
 const W=(G3D.cv&&G3D.cv.clientWidth)||800,side=asp>=1.25?Math.min(380,W*.4)/W:0;
 const hh=lerpN(.58,.8,t)*(1-side*.45);let fov=2*Math.atan(Math.tan(hh)/asp);fov=clamp(fov,.72,1.8);return{eye,tgt,fov,sy:lerpN(.05,0,t),sx:-side}}
/* a point on the screen (nx, ny from -1 to 1) at distance d in front of the eye, and the turn that makes a card face the eye */
function jkScr(asp,nx,ny,d){const C=jkCam(asp),F=v3.norm(v3.sub(C.tgt,C.eye)),R=v3.norm(v3.cross(F,[0,1,0])),U=v3.cross(R,F),t=Math.tan(C.fov/2);
 return v3.add(C.eye,v3.add(v3.mul(F,d),v3.add(v3.mul(R,(nx-C.sx)*t*asp*d),v3.mul(U,(ny-C.sy)*t*d))))}
const jkFace=asp=>{const C=jkCam(asp),F=v3.norm(v3.sub(C.tgt,C.eye));return qt.ax(1,0,0,-Math.atan2(-F[1],-F[2]))};
/* who sits where: bots get a look of their own; people online get one picked from their name */
const JLOOK={'სუფრა ბოტი':{style:'short',mus:1,hat:1,skin:'#E4B08C',hair:'#9A948C',brow:'#6E675F',shirt:'#2C4A6E'},'ანა':{style:'pony',fem:1,skin:'#F1C9AC',hair:'#4A2A18',shirt:'#3F6E8C'},'გიორგი':{style:'curly',skin:'#E6B593',hair:'#24170F',shirt:'#7A3B2E'},'ლევანი':{style:'short',beard:1,mus:1,skin:'#DCA683',hair:'#2B1E16',shirt:'#4E5E3A'},'ნინო':{style:'long',fem:1,skin:'#EFC2A2',hair:'#2A1A12',shirt:'#8E3047'},'ლუკა':{style:'short',glasses:1,skin:'#E2AF8C',hair:'#1E140F',shirt:'#2F5D8A'},'დათო':{style:'bald',mus:1,skin:'#D69C77',hair:'#6F6862',brow:'#4A3F38',shirt:'#3E6B47'}};
function jkLook(nm,h){if(JLOOK[nm])return JLOOK[nm];let k=0;for(const ch of String(nm||''))k=(k*31+ch.charCodeAt(0))>>>0;
 const sk=['#EBC0A0','#DDA984','#F2CDB0','#C99169'],hr=['#24170F','#1A120D','#4E3220','#2E2219'];
 return{style:k%5===0?'bald':'short',mus:k%3===0,skin:sk[k%4],hair:hr[(k>>3)%4],shirt:`hsl(${h??(k%360)} 38% 36%)`}}
const hex=c=>{if(c[0]==='#')return c;const d=document.createElement('canvas').getContext('2d');d.fillStyle=c;return d.fillStyle};
function jkPerson(sc,key,L){if(sc.models['pb:'+key])return;const g=personGeo(L),fem=!!L.fem;
 const skin=g3Mat({c:L.skin,sh:14,sp:.12,gl:.03}),shirt=g3Mat({c:hex(L.shirt),t:g3T('knit',()=>g3Tex(knitCv(),{rep:true})),uv:[0,0,7,5],sh:6,sp:.05,gl:0}),hair=g3Mat({c:L.hair,sh:12,sp:.09,gl:.02}),chair=g3Mat({t:woodTex('walnut'),uv:[0,0,1,1],sh:50,sp:.3,gl:.25});
 /* the face texture holds two pictures, eyes open and shut; a blink shows the second for a moment */
 const face=g3Mat({t:g3T('face:'+key,()=>g3Tex(faceCv({skin:L.skin,hair:L.hair,brow:L.brow,fem,bald:L.style==='bald'}))),uv:[0,0,.5,1],vary:true,sh:14,sp:.12,gl:.03});
 g3Model(sc,'pb:'+key,[[g.body.shirt,shirt],[g.body.skin,skin],[g.body.chair,chair]],null);
 g3Model(sc,'ph:'+key,[[g.head.face,face],[g.head.skin,skin],...(g.head.hair?[[g.head.hair,hair]]:[]),...(g.head.frame?[[g.head.frame,g3Mat({c:'#1C1A1A',sh:80,sp:.6,gl:.4})]]:[]),...(g.head.hat?[[g.head.hat,g3Mat({c:'#4A443C',sh:8,sp:.04,gl:0})]]:[])],null);
 for(const s of[-1,1])g3Model(sc,'pk:'+key+':'+s,[[g.arms[s].sleeve,shirt],[g.arms[s].hand,skin]],null)}
/* a person at the table: body, head (turned by hq), and the two forearms that turn at the elbow; id names the seat */
function pplPush(L,id,key,p,qB,s,hq,o={}){const S=s||1,at=v=>v3.add(p,qt.rot(qB,v3.mul(v,S))),b={refl:false,life:1,dur:o.dur||650};if(o.cast===false)b.cast=false;if(o.now)b.now=1;
 L.push(Object.assign({k:'pb'+id,m:'pb:'+key,p,q:qB,s:S},b),Object.assign({k:'ph'+id,m:'ph:'+key,p:at(HPIV),q:qt.mul(qB,hq),s:S,blink:1},b,{dur:o.hdur||600}));
 for(const sd of[-1,1])L.push(Object.assign({k:(sd<0?'pkl':'pkr')+id,m:'pk:'+key+':'+sd,p:at(ELB(sd)),q:qB,s:S,side:sd},b))}
/* ---------- the opponent across the board ----------
   chess, checkers and nardi get the other player on the far side: the same people as at the card table, a little bigger.
   they watch the board, lean in while they think, look up at you when the game ends, and act out their reactions */
const OPPS={chess:{z:8.6,s:1.45,y:-.55,x:0,e:5.25},shashi:{z:8.6,s:1.45,y:-.55,x:0,e:5.25},nardi:{z:10.15,s:1.55,y:-.6,x:.8,e:6.45}};
const oppOn=()=>typeof store==='undefined'||store.get('gppl',true)!==false;
function oppLookOf(c){const s=-c.side,a=c.avs&&c.avs[s],nm=String((c.names&&c.names[s])||'მოთამაშე').replace(/ \(ბოტი\)$/,'');if(c.olk&&typeof c.olk==='object')return c.olk;if(a&&a.look&&typeof a.look==='object')return a.look;return jkLook(nm,a&&(a.h??a.hue))}
function oppAdd(sc,id,G,L,far){const o=OPPS[id],c=G.ctx,cm=sc.cam;if(!o||!c||!oppOn()||c.mode==='puzzle'||c.mode==='local'){if(cm.p0!=null){cm.pitch=cm.p0;cm.pp=cm.pp0;cm.tgt=cm.t0.slice()}cm.extraW=null;sc.people=null;sc.anchors=null;return}
 sc.anchors=[['.g3op',[o.x-far*2.9*o.s,o.y+4.7*o.s,far*o.z]]];const lk=oppLook(oppLookOf(c)),key='o:'+lkKey(lk);jkPerson(sc,key,lk);
 const yaw=far<0?0:Math.PI,ts=G.turnSide?G.turnSide():null,over=G.res&&G.res(),think=!over&&ts===-c.side,lean=think?.08:0,qB=qt.mul(qt.ax(0,1,0,yaw),qt.ax(1,0,0,lean)),p=[o.x,o.y,far*o.z];
 const pitch=over?0:think?.34:.1;
 /* on a wide screen the camera tips down a little less and keeps the head in the picture */
 if(cm.p0==null){cm.p0=cm.pitch;cm.pp0=cm.pp||0;cm.t0=cm.tgt.slice()}cm.pitch=cm.p0-.12;cm.pp=cm.pp0+.12;const wide=(G3D.asp||1)>=.8;cm.tgt=wide?[cm.t0[0],cm.t0[1]+.9,cm.t0[2]+far*1.7]:cm.t0.slice();if(!sc.onResize)sc.onResize=()=>{try{G3U[sc.host](sc)}catch(e){}};const hz=far*(o.z-.2*o.s),S=o.s;cm.extraW=[[o.x-1.5*S,o.y+5.9*S,hz],[o.x+1.5*S,o.y+5.9*S,hz],[o.x-2.6*S,o.y+3.2*S,far*o.z],[o.x+2.6*S,o.y+3.2*S,far*o.z]];
 pplPush(L,'o',key,p,qB,o.s,qt.e(pitch,0,0),{cast:false,dur:700});
 sc.people=who=>who===-c.side?'o':null}
/* a look as stored or sent: only known styles and colours pass */
const LKS=['short','curly','long','pony','bald'],hexOk=v=>typeof v==='string'&&/^#[0-9a-fA-F]{6}$/.test(v);
function oppLook(L){const o=L&&typeof L==='object'?L:{};return{style:LKS.includes(o.style)?o.style:'short',fem:o.fem?1:0,mus:o.mus?1:0,beard:o.beard?1:0,glasses:o.glasses?1:0,hat:o.hat?1:0,skin:hexOk(o.skin)?o.skin:'#E2AF8C',hair:hexOk(o.hair)?o.hair:'#2A1A12',brow:hexOk(o.brow)?o.brow:undefined,shirt:hexOk(o.shirt)?o.shirt:(typeof o.shirt==='string'&&/^hsl\(/.test(o.shirt)?o.shirt:'#2F5D8A')}}
const lkKey=L=>[L.style,L.fem,L.mus,L.beard,L.glasses,L.hat,L.skin,L.hair,L.brow||'',L.shirt].join('|');
G3B.joker=()=>{const sc=g3Scene({cam:{fixed:jkCam,tgt:[0,0,0],fov:1,dy:0,dp:0,dz:1},orbit:false,zoom:false,shR:12,shC:[0,0,-1.6],spot:[0,2.4,11,.62],bg:[.035,.024,.02],
  light:{d:v3.norm([-.22,1,.4]),c:[2.35,2.08,1.72],sky:[.26,.22,.2],gnd:[.12,.08,.06],exp:1.0},
  anchors:[['.seat.left',[...[JSP[1][0]*.97,6.25,JSP[1][1]*.97]]],['.seat.top',[0,6.35,-JR*.97]],['.seat.right',[JSP[3][0]*.97,6.25,JSP[3][1]*.97]]]});
 /* the room and the table: plank floor, papered walls on three sides, felt, a turned mahogany rim and a pedestal */
 roundRoom(sc,5.45,g3T('felt',()=>g3Tex(feltCv({a:'#2E7D59',b:'#123B29',ring:1}))));envRoom(sc);
 mkModel(sc);
 const atl=jkAtlas(),back=cardUV(38);sc.c4=jkC4()+':'+gStyleOf('joker');
 g3Model(sc,'card',[[gQuad(CDW,CDH),g3Mat({t:atl,cut:true,vary:true,sh:30,sp:.18,gl:.1})],[gQuad(CDW,CDH,true),g3Mat({t:atl,uv:back,cut:true,sh:30,sp:.2,gl:.12})]],[CDW/2,CDH/2,.03]).land=()=>snd('card');
 g3Model(sc,'deck',[[gBox(CDW,1,CDH,0,1,(f,u,v)=>f===0?[back[0]+u*back[2],back[1]+v*back[3]]:[268/2048,170/2048]),g3Mat({t:atl,sh:20,sp:.15,gl:.1})]],null);
 /* the first touch lifts a card, the second plays it; a card dragged up onto the table is played too */
 sc.hoverAll=true;
 sc.tap=ray=>{const o=g3HitObj(sc,ray,o=>o.pick&&o.pick.i!=null);if(!o)return;if(sc.csel===o.pick.k){sc.csel=null;g3Act(sc.act||'jcard',{i:String(o.pick.i)});return}sc.csel=o.pick.k;snd('card',.6);G3U[sc.host](sc);g3Need()};
 sc.drag={y:.4,lift:.5,dz:0,start:o=>{sc.csel=o.pick.k},drop:(o,p)=>{if(p&&Math.hypot(p[0],p[2])<5.2){sc.csel=null;g3Act(sc.act||'jcard',{i:String(o.pick.i)})}}};
 sc.onResize=()=>{try{G3U[sc.host](sc)}catch(e){}};sc.people=seatOf;
 return sc};
/* the card faces come in two decks; switching in the menu swaps the picture on the cards already on the table */
const jkC4=()=>typeof c4On==='function'&&c4On();
const jkAtlas=()=>{const c4=jkC4(),st=gStyleOf('joker');return g3T('cards2'+(c4?'q':'')+(st==='geo'?'g':''),()=>g3Tex(cardsCv(c4,st),{af:true}))};
function jkDeck(sc){const c4=jkC4()+':'+gStyleOf('joker');if(sc.c4===c4)return;sc.c4=c4;const t=jkAtlas();for(const m of['card','deck'])if(sc.models[m])sc.models[m].parts.forEach(p=>{p.mat.t=t})}
/* what the people at the table do for a reaction: the head nods, shakes or tips back; laughing and a toast move the whole body */
const GEST={clap:{h:{ax:'x',a:.1,f:2,d:1800},k:{ax:'y',a:.5,f:4,abs:1,b:.12,bf:4,d:1800}},nod:{h:{ax:'x',a:.2,f:2,d:1100}},laugh:{h:{ax:'x',a:.1,f:5,d:1300,b:.09,bf:10},bd:{b:.09,bf:10,d:1300}},wow:{h:{ax:'x',a:-.32,f:.5,d:1300}},cheer:{h:{ax:'x',a:.16,f:1.5,d:1500,b:.24,bf:3},bd:{b:.24,bf:3,d:1500}},shake:{h:{ax:'y',a:.3,f:3,d:1200}}};
function g3Gest(who,kind){const sc=G3D.sc;if(!sc||!sc.people||!G3D.cv||!G3D.cv.isConnected)return;const r=sc.people(who);if(r==null)return;const W=GEST[kind]||GEST.nod;g3Wig(sc,'k:ph'+r,W.h);if(W.bd)for(const p of['pb','pkl','pkr'])g3Wig(sc,'k:'+p+r,W.bd);if(W.k){g3Wig(sc,'k:pkl'+r,W.k);g3Wig(sc,'k:pkr'+r,Object.assign({},W.k,{a:-W.k.a}))}}
const seatOf=who=>typeof who==='string'&&/^r[123]$/.test(who)?+who[1]:null;
const lblModel=(sc,t)=>sc.models['l:'+t]||g3Model(sc,'l:'+t,[[gPlane(2.3,.58),g3Mat({t:labelTex(t),unlit:true})]],null);
const FACEUP=yaw=>qt.mul(qt.ax(0,1,0,yaw),qt.ax(1,0,0,-Math.PI/2)),FACEDN=yaw=>qt.mul(qt.ax(0,1,0,yaw),qt.ax(1,0,0,Math.PI/2));
/* a seat's frame: where it is, how it faces, and its lean toward the table while thinking */
const jkSeatQ=(r,lean)=>qt.mul(qt.ax(0,1,0,JYAW[r]),qt.ax(1,0,0,lean||0));
const jkLocal=(r,lean,p)=>{const q=jkSeatQ(r,lean),v=qt.rot(q,p);return[JSP[r][0]+v[0],v[1],JSP[r][1]+v[2]]};
/* the fan of cards a player holds, faces toward them, backs toward the table */
function jkFanAt(r,lean,i,n){const sp=Math.min(.16,1.2/Math.max(n,1)),ph=(i-(n-1)/2)*sp,R=2.6,q0=qt.mul(jkSeatQ(r,lean),qt.mul(qt.ax(0,1,0,Math.PI),qt.ax(1,0,0,-.5)));
 const rt=qt.rot(q0,[1,0,0]),up=qt.rot(q0,[0,1,0]),nr=qt.rot(q0,[0,0,1]),c=jkLocal(r,lean,[0,1.95,2.5]);
 return{p:v3.add(c,v3.add(v3.mul(rt,Math.sin(ph)*R),v3.add(v3.mul(up,(Math.cos(ph)-1)*R+.1),v3.mul(nr,-i*.008)))),q:qt.mul(q0,qt.ax(0,0,1,-ph))}}
/* where a player's eyes go: the one thinking looks at their cards, the rest at the one thinking, everyone at a finished trick */
function jkGaze(r,V,rel){const cur=V.cur!=null&&V.cur>=0?rel(V.cur):null,me=JSP[r];let tx,tz,pitch=.14;
 if(V.win!=null){tx=0;tz=0;pitch=.34}else if(cur===r){return{yaw:0,pitch:.42}}else if(cur!=null){tx=cur===0?0:JSP[cur][0];tz=cur===0?JR:JSP[cur][1];pitch=cur===0?.2:.1}else{tx=0;tz=0;pitch=.28}
 const f=[-me[0],-me[1]],d=[tx-me[0],tz-me[1]],a=Math.atan2(f[0]*d[1]-f[1]*d[0],f[0]*d[0]+f[1]*d[1]);return{yaw:clamp(-a,-.75,.75),pitch}}
/* one picture of the table for both kinds of game */
function jkScene(sc,V){const L=[],M=[],rel=p=>(p-V.base+4)%4,asp=G3D.asp||.5;sc.act=V.act;jkDeck(sc);
 const deal=V.deal!==sc.deal;if(deal)sc.deal=V.deal;const dealer=V.dealer!=null?rel(V.dealer):2,dp=dealer===0?[0,1.4,6.6]:jkLocal(dealer,0,[0,1.6,2.6]),cur=V.cur!=null&&V.cur>=0?rel(V.cur):null;
 /* the three others */
 for(const r of[1,2,3]){const id=V.ids[(r+V.base)%4],L0=id.lk?oppLook(id.lk):jkLook(id.n,id.h),key=(id.k||id.n||'p'+r)+(id.lk?':'+lkKey(L0):'');jkPerson(sc,key,L0);
  const lean=cur===r&&V.win==null?.07:0,g=jkGaze(r,V,rel);
  pplPush(L,r,key,[JSP[r][0],0,JSP[r][1]],jkSeatQ(r,lean),1,qt.e(g.pitch,g.yaw,0));
  const cnt=V.counts[r]||0;for(let i=0;i<cnt;i++){const f=jkFanAt(r,lean,i,cnt),d={k:'h'+r+'-'+i,m:'card',p:f.p,q:f.q,s:.95,uv:cardUV(38),refl:false,dur:500};
   if(deal){d.from={p:dp,q:FACEDN(0),s:.9};d.delay=(i*4+r)*40;d.dur=520}L.push(d)}}
 /* my hand, held in front of me at the bottom of the screen */
 const n=V.hand.length;if(!V.mine||!V.hand.some(cd=>'c'+cardIdx(cd)===sc.csel))sc.csel=null;
 if(n){const tall=asp<.8,hs=tall?.165:.19,dd=2.4,C=jkCam(asp),t=Math.tan(C.fov/2),s=hs*2*t*dd/CDH,cw=CDW*s/(t*asp*dd),room=(2+2*C.sx)*.8,spc=Math.min(cw*.62,(room-cw*1.1)/Math.max(1,n-1)),qf=jkFace(asp);
  V.hand.forEach((cd,i)=>{const ok=V.legal.includes(cd),key='c'+cardIdx(cd),sel=sc.csel===key,nx=C.sx+(i-(n-1)/2)*spc,lift=V.legal.length?(sel?.5:ok?.13:-.03):0,
    ny=-1+hs*1.06-(nx-C.sx)*(nx-C.sx)*.07+lift*hs*2,p=jkScr(asp,nx,ny,dd-i*.004),d={k:key,m:'card',p,q:qt.mul(qf,qt.ax(0,0,1,-(nx-C.sx)*.2)),s,uv:cardUV(cardIdx(cd)),dim:V.legal.length&&!ok?.5:1,pick:V.mine&&ok?{i,k:key}:null,drag:V.mine&&ok,glow:sel?[.12,.09,.03]:V.hint===cd?[.05,.16,.1]:null,refl:false,cast:false,dur:420};
   if(deal){d.from={p:dp,q:FACEDN(0),s:.9};d.delay=i*70;d.dur=560}L.push(d)})}
 /* the trick, each card in front of whoever played it, all turned to read from my chair */
 V.trick.forEach((e,k)=>{const r=rel(e.p),[tx,tz]=JTRK[r],idx=cardIdx(e.card),p=[tx,.012+k*.008,tz],won=V.win!=null&&rel(V.win)===r&&V.trick.length===4,d={k:'c'+idx,m:'card',p,q:FACEUP(JTJ[r]),s:JTS,uv:cardUV(idx),glow:won?[.2,.14,.04]:null,cast:true};
  if(r!==0||!sc.objs.has('k:c'+idx)){const f=r===0?{p:jkScr(asp,0,-.55,2.4),q:jkFace(asp),s:.6}:{p:jkLocal(r,0,[0,1.95,2.5]),q:qt.mul(jkSeatQ(r,0),qt.mul(qt.ax(0,1,0,Math.PI),qt.ax(1,0,0,-.5))),s:.95};d.from=f;d.dur=560;d.arc=1.4}
  L.push(d);if(won)M.push({m:'mk',p:[tx,.01,tz],s:[JTS*1.25,1,JTS*1.6],uv:MK.blob,c:[1,.78,.3],a:.55,add:true});
  else if(V.win==null&&k===V.trick.length-1)M.push({m:'mk',p:[tx,.009,tz],s:[JTS*1.1,1,JTS*1.45],uv:MK.blob,c:[1,.9,.6],a:.28,add:true});
  if(e.card.j){const t=(e.jm==='hi'?'მაღალი':'დაბალი')+(e.js?' '+SY[e.js]:'');lblModel(sc,t);L.push({k:'lb'+idx,m:'l:'+t,p:[tx,.05+k*.008,tz+1.45],q:qt.id(),s:1.15,cast:false,now:1})}});
 /* tricks already taken lie in a little pile in front of each player */
 for(let r=0;r<4;r++){const tk=V.taken[(r+V.base)%4]||0;if(!tk)continue;const h=.035*tk,pp=r===0?[2.7,h/2+.01,3.6]:(()=>{const v=jkLocal(r,0,[-1.7,0,3.9]);return[v[0],h/2+.01,v[2]]})();
  L.push({k:'pile'+r,m:'deck',p:pp,s:[1.05,h,1.05],q:qt.ax(0,1,0,(r===0?0:JYAW[r])+.2),dur:400})}
 /* the deck and the trump card under it, by the dealer */
 if(V.trumpCard&&V.deckN>0&&['bid','play'].includes(V.phase)){const h=Math.max(.02,V.deckN*.008),c=dealer===0?[-2.6,0,3.1]:jkLocal(dealer,0,[1.9,0,4.1]),yw=dealer===0?0:JYAW[dealer];
  L.push({k:'tc',m:'card',p:[c[0],.008,c[2]],q:FACEUP(yw+Math.PI/2),s:1.35,uv:cardUV(cardIdx(V.trumpCard)),cast:false});L.push({k:'deck',m:'deck',p:[c[0]+.35*Math.cos(yw),h/2+.02,c[2]-.35*Math.sin(yw)],s:[1.3,h,1.3],q:qt.ax(0,1,0,yw+.06)})}
 sc.jw=V.win!=null?rel(V.win):sc.jw;
 sc.marks=M;g3Set(sc,L,{gone:o=>{if(o.m==='card'&&o.id.startsWith('k:c')){const w=sc.jw??0,p=w===0?[2.7,.2,3.6]:jkLocal(w,0,[-1.7,.2,3.9]);return{p,a:0,dur:560,delay:150,s:1.05,q:FACEDN(w===0?0:JYAW[w])}}if(o.id.startsWith('k:h'))return{a:0,dur:160};return{a:0,dur:250}}})}
G3U.joker=sc=>{const G=JK,V={hint:typeof jkPlayHint==='function'?(m=>m&&m.c)(jkPlayHint()):null,base:0,act:'jcard',hand:[],legal:[],counts:[0,0,0,0],taken:[0,0,0,0],trick:[],win:null,deal:null,dealer:null,cur:null,phase:G.phase,mine:false,trumpCard:null,deckN:0,ids:G.ids.map((x,i)=>i===0?{n:ME.name}:{n:x.n,h:x.h,k:x.n})};
 if(G.hands){const tr=G.phase==='trump'&&G.cur===0;V.hand=tr?G.first3[0]:G.phase==='trump'?[]:G.hands[0];V.legal=G.phase==='play'&&G.cur===0&&G.win==null?G.legal(0):[];V.mine=V.legal.length>0;
  V.counts=[0,1,2,3].map(p=>G.phase==='trump'?(p===0?0:3):G.hands[p].length);V.taken=G.taken||V.taken;V.trick=G.trick;V.win=G.win;V.cur=G.cur;V.dealer=G.dealer;V.deal=G.len+':'+G.h+':'+G.dealer;V.trumpCard=G.trumpCard;V.deckN=36-4*G.n}
 jkScene(sc,V)};
G3U.jko=sc=>{const s=JO.st,me=JO.seat,V={base:me>=0?me:0,act:'jkocard',hand:[],legal:[],counts:[0,0,0,0],taken:[0,0,0,0],trick:[],win:null,deal:null,dealer:null,cur:null,phase:s?s.phase:'wait',mine:false,trumpCard:null,deckN:0,
  ids:[0,1,2,3].map(p=>{const u=JO.t&&JO.t.seats[p];if(u){const pr=typeof PC!=='undefined'&&PC.get(u);return{n:u===ME.id?ME.name:(pr&&pr.name)||'მოთამაშე',h:pr&&pr.hue,k:u,lk:(JO.looks&&JO.looks[u])||(pr&&pr.look)||null}}const b=s&&s.bots&&s.bots[p];return{n:b||'ბოტი',h:b?joBotHue(b):30,k:'b'+(b||p)}})};
 if(s&&s.counts){V.hand=me>=0?JO.hand:[];const myTurn=me>=0&&s.cur===me&&s.win==null&&!JO.wait&&s.phase==='play';V.legal=myTurn?JK.legal.call({hands:{[me]:JO.hand},trick:s.trick,trump:s.trump},me):[];V.mine=V.legal.length>0;
  V.counts=[0,1,2,3].map(r=>s.counts[(r+V.base)%4]||0);V.taken=s.taken||V.taken;V.trick=s.trick||[];V.win=s.win;V.cur=s.cur;V.dealer=s.dealer;V.deal=s.deal;V.trumpCard=s.trumpCard;V.deckN=36-4*s.n}
 jkScene(sc,V)};

/* ---------- domino ----------
   a round table with the other three sitting at it: the partner across, the two opponents on either side, toward the far side so a phone held upright sees them.
   each stands their tiles on the table in front of them; the line of play runs across the middle */
const DL=1.12,DW=.56,DT=.19,DB=4.2,DRT=6.9,DSR=9.45,DJA=.76;
const DSP=[[0,DSR],[-DSR*Math.sin(DJA),-DSR*Math.cos(DJA)],[0,-DSR],[DSR*Math.sin(DJA),-DSR*Math.cos(DJA)]],DYAW=DSP.map(([x,z])=>Math.atan2(-x,-z));
const dSeatQ=(r,lean)=>qt.mul(qt.ax(0,1,0,DYAW[r]),qt.ax(1,0,0,lean||0));
const dLocal=(r,lean,p)=>{const v=qt.rot(dSeatQ(r,lean),p);return[DSP[r][0]+v[0],v[1],DSP[r][1]+v[2]]};
/* the room and a round table, shared by the card table and the domino table: plank floor, papered walls, felt, a turned rim and a pedestal */
function roundRoom(sc,R,felt,o={}){if(o.room!==false){g3Static(sc,gPlane(60,60,8,8),g3Mat({t:woodTex('table'),sh:16,sp:.12,gl:.08}),[0,-11,0],null,false);
 const wall=g3Mat({t:g3T('wall',()=>g3Tex(wallCv(),{rep:true})),uv:[0,0,4,3],sh:4,sp:.02,gl:0});
 g3Static(sc,gQuad(60,40),wall,[0,9,-20],null,false);g3Static(sc,gQuad(60,40),wall,[-20,9,0],qt.ax(0,1,0,Math.PI/2),false);g3Static(sc,gQuad(60,40),wall,[20,9,0],qt.ax(0,1,0,-Math.PI/2),false);
 g3Static(sc,gBox(60,.6,.5,.1),g3Mat({t:woodTex('walnut'),sh:40,sp:.25,gl:.2}),[0,-2,-19.7],null,false)}
 const k=R/5.45;g3Static(sc,gDisc(R,96),g3Mat({t:felt,sh:6,sp:.04,gl:0}),[0,0,0],null,false);
 g3Static(sc,gLathe([[5.4,-1.2],[5.42,-.02],[5.45,.02],[5.6,.1],[5.95,.16],[6.22,.1],[6.3,0],[6.25,-.16],[6.1,-.24],[5.8,-.3],[5.7,-1.2],[0,-1.2]].map(([r,y])=>[r*k,y]),120,.6),g3Mat({t:woodTex('mahog'),uv:[0,0,8,1],sh:70,sp:.4,gl:.4}),[0,0,0]);
 g3Static(sc,gLathe([[0,-11],[3.2,-11],[3.3,-10.6],[1.1,-9.8],[.9,-6],[1.3,-2.2],[2.4,-1.4],[0,-1.3]],48),g3Mat({t:woodTex('mahog'),uv:[0,0,4,1],sh:60,sp:.35,gl:.3}),[0,0,0])}
/* domino, like the card table, from your own chair: your tiles big along the near edge, the line in the middle, your partner across and the other two at the sides.
   the camera has to keep the whole line (it never runs wider than DB, and turns back within a few rows), your tiles and your partner's head */
G3B.domino=()=>{const sc=g3Scene({cam:{yaw:0,pitch:.56,pp:.1,fov:.92,tgt:[0,0,-.5],box:[[-7.2,0,-7.4],[7.2,.8,6.8]],anchorB:1,
  fitp:[[-4.7,0,-3.6],[4.7,0,-3.6],[-4.7,0,3.4],[4.7,0,3.4],[-2.7,.9,5.7],[2.7,.9,5.7],[0,5.4,-9.45]],
  fitw:[[-4.7,0,-3.6],[4.7,0,-3.6],[-4.7,0,3.4],[4.7,0,3.4],[-2.7,.9,5.7],[2.7,.9,5.7],[DSP[1][0]-1.4,5.3,DSP[1][1]],[DSP[3][0]+1.4,5.3,DSP[3][1]]],extraW:[[-1.6,6.1,-9.3],[1.6,6.1,-9.3]],dy:0,dp:0,dz:1,my:.96,mxp:1},shR:11,shC:[0,0,-1],spot:[0,0,9.5,.6],yawMax:.4,bg:[.03,.022,.02],
  light:{d:v3.norm([-.22,1,.4]),c:[2.35,2.08,1.72],sky:[.26,.22,.2],gnd:[.12,.08,.06],exp:1.0},
  anchors:[['.seat.top',[0,6.35,-DSR*.97]],['.seat.left',[DSP[1][0]*.97,6.25,DSP[1][1]*.97]],['.seat.right',[DSP[3][0]*.97,6.25,DSP[3][1]*.97]]]});
 mkModel(sc);roundRoom(sc,DRT,g3T('dfelt',()=>g3Tex(feltCv({a:'#245a73',b:'#0f2a38',ring:1}))),{room:false});envYardS(sc);sc.people=seatOf;
 const atl=g3T('domino',()=>g3Tex(dominoCv())),iv=g3Mat({c:'#F2EAD8',sh:90,sp:.55,gl:.55});
 const tile=[[gBox(DL,DT,DW,.04,3,null,[0]),g3Mat({t:atl,vary:true,sh:90,sp:.55,gl:.55})],[gBox(DL,DT,DW,.04,3,null,[1]),g3Mat({t:atl,uv:dmUV(28),sh:80,sp:.5,gl:.5})],[gBox(DL,DT,DW,.04,3,null,[2,3,4,5]),iv]];
 g3Model(sc,'tile',tile,[DL/2,DT/2,DW/2]).land=(o,sc)=>{snd('tile');if(o.p[1]<.2)g3Ripple(sc,[o.p[0],.01,o.p[2]],1.3)};
 g3Model(sc,'ghost',[[gBox(DL,DT,DW,.04,3),g3Mat({c:'#F4BC4C',unlit:true,a:1})]],[DL/2,DT,DW/2]);
 sc.hoverAll=true;
 /* the same table serves the game against the computer (dmt, dmend) and the table with friends (dmot, dmoend) */
 sc.tap=ray=>{const o=g3HitObj(sc,ray,o=>o.pick);if(!o)return;const a=sc.dA||'dm';if(o.pick.e)g3Act(a+'end',{e:o.pick.e});else if(o.pick.i!=null)g3Act(a==='dm'?'dmt':'dmot',{i:String(o.pick.i)})};
 sc.drag={y:.4,lift:.4,drop:(o,p)=>{if(!p||p[2]>4.3)return;const G=sc.dG||DM,a=sc.dA||'dm',i=o.pick.i,pl=G.places(G.hands[0][i]);if(!pl.length)return;if(pl.length===1){g3Act(a==='dm'?'dmt':'dmot',{i:String(i)});return}
  const{slots}=dmLayout(G),e=pl.slice().sort((a,b)=>Math.hypot(slots[a].x-p[0],slots[a].z-p[2])-Math.hypot(slots[b].x-p[0],slots[b].z-p[2]))[0];G.sel=i;if(a!=='dm'&&typeof DMO!=='undefined')DMO.sel=i;g3Act(a+'end',{e})}};
 sc.drag.start=()=>{sc.dragAt=performance.now()+6e4};const d0=sc.drag.drop;sc.drag.drop=(o,p)=>{sc.dragAt=performance.now();d0(o,p)};
 return sc};
/* where each tile of the line lies: from the first tile outward, along a row until the edge, then a turn and back */
function dmLayout(G){const out=[],slots={};if(!G.root)return{out,slots};const rt=G.root.t,rd=rt[0]===rt[1];
 out.push({t:rt,near:rt[0],x:0,z:0,yaw:rd?Math.PI/2:0,lo:Math.min(...rt)});
 const arm=(list,d0,turns,key)=>{let d=d0,P=[d0[0]*(rd?DW/2:DL/2),d0[1]*(rd?DW/2:DL/2)],run=0,ti=0;
  const place=(x,ghost)=>{const dbl=x?x.n===x.f:false,hor=d[1]===0;let ext=hor&&dbl?DW:DL;
   if(hor&&Math.abs(P[0]+d[0]*ext)>DB||(!hor&&run>=1)){const nd=turns[ti++%turns.length];P=[P[0]+d[0]*DW/2-nd[0]*DW/2,P[1]+d[1]*DW/2-nd[1]*DW/2];d=nd;run=0;ext=DL}
   const cross=d[1]===0&&dbl,yaw0=Math.atan2(-d[1],d[0]),c=[P[0]+d[0]*ext/2,P[1]+d[1]*ext/2];
   if(ghost)return{x:c[0],z:c[1],yaw:yaw0};P=[P[0]+d[0]*ext,P[1]+d[1]*ext];run++;
   const lo=Math.min(x.n,x.f);return{t:x.t,x:c[0],z:c[1],yaw:cross?yaw0+Math.PI/2:yaw0+(x.n===lo?0:Math.PI),lo}};
  list.forEach(x=>out.push(place(x)));slots[key]=place(null,true)};
 arm(G.R,[1,0],[[0,1],[-1,0],[0,1],[1,0]],'R');arm(G.L,[-1,0],[[0,-1],[1,0],[0,-1],[-1,0]],'L');return{out,slots}}
const DSTAND=(yaw,tilt)=>qt.mul(qt.ax(0,1,0,yaw),qt.mul(qt.ax(1,0,0,Math.PI/2-tilt),qt.ax(0,1,0,Math.PI/2)));
/* where each player stands their tiles: mine along the near edge, the others' on the table in front of them, turned to face them */
const DRACK={0:{c:[0,.52,5.25],yaw:0,dir:[1,0,0],sp:.7,tilt:.5}};
for(const r of[1,2,3]){const[x,z]=DSP[r],l=Math.hypot(x,z),u=[x/l,z/l],yaw=Math.atan2(u[0],u[1]);DRACK[r]={c:[u[0]*6.05,.52,u[1]*6.05],yaw,dir:[Math.cos(yaw),0,-Math.sin(yaw)],sp:.62,tilt:.22}}
const dRack=(s,i,n)=>{const r=DRACK[s];return v3.add(r.c,v3.mul(r.dir,(i-(n-1)/2)*r.sp))};
G3U.domino=sc=>dmScene(sc,DM,'dm',r=>({n:DMN[r].n,h:DMN[r].h,k:'d:'+DMN[r].n}));
/* the table with friends: the same scene, turned so that I sit at the near edge */
G3U.dmo=sc=>{if(typeof DMO==='undefined'||!DMO.st||!DMO.st.phase)return;const base=DMO.seat>=0?DMO.seat:0;dmScene(sc,dmoView(),'dmo',r=>dmoWho((r+base)%4))};
function dmScene(sc,G,act,who){sc.dG=G;sc.dA=act;const L=[],M=[],{out,slots}=dmLayout(G),mine=G.phase==='play'&&G.cur===0,ok=new Set(mine?G.moves(0).map(m=>m.i):[]);
 const deal=G.round!==sc.round;if(deal)sc.round=G.round;
 const flat=(t,x,z,yaw)=>({p:[x,DT/2,z],q:qt.ax(0,1,0,yaw),uv:dmUV(dmIdx(t[0],t[1]))});
 out.forEach(o=>{const f=flat(o.t,o.x,o.z,o.yaw),key='t'+dmIdx(o.t[0],o.t[1]),d=Object.assign({k:key,m:'tile'},f);
  if(!sc.objs.has('k:'+key)){const by=G.last&&G.last.t&&dmIdx(G.last.t[0],G.last.t[1])===dmIdx(o.t[0],o.t[1])?G.last.p:null;if(by!=null&&by!==0){const n=G.hands[by].length;d.from={p:dRack(by,n,n+1),q:DSTAND(DRACK[by].yaw,DRACK[by].tilt)};d.arc=.9;d.dur=560}}
  L.push(d);M.push({m:'mk',p:[o.x,.003,o.z],s:[1.35,1,1.35],uv:MK.blob,c:[0,0,0],a:.22,q:qt.ax(0,1,0,o.yaw)})});
 const n=G.hands[0].length;G.hands[0].forEach((t,i)=>{const lift=G.sel===i?.32:ok.has(i)?.12:0,p=v3.add(dRack(0,i,n),[0,lift,0]),d={k:'t'+dmIdx(t[0],t[1]),m:'tile',p,q:DSTAND(0,DRACK[0].tilt),uv:dmUV(dmIdx(t[0],t[1])),dim:mine&&!ok.has(i)?.6:1,glow:G.sel===i?[.12,.09,.02]:null,pick:mine?{i}:null,drag:mine&&ok.has(i)};
  if(deal){d.from={p:[0,1.2,0],q:DSTAND(0,0),a:0};d.delay=i*70;d.dur=520}L.push(d)});
 const SE=typeof dmSeats==='function'?dmSeats(G.np||4):[0,1,2,3];
 if(G.baz&&G.baz.length){const es=[2,3,1].find(s=>!SE.includes(s)),R0=DRACK[es],nb=G.baz.length,q=qt.mul(qt.ax(0,1,0,R0.yaw+Math.PI/2),qt.ax(1,0,0,Math.PI)),inw=v3.norm([-R0.c[0],0,-R0.c[2]]);
  for(let k=0;k<nb;k++){const row=Math.floor(k/7),i=k%7,n=Math.min(7,nb-row*7),p=v3.add(v3.add([R0.c[0],DT/2,R0.c[2]],v3.mul(R0.dir,(i-(n-1)/2)*.62)),v3.mul(inw,.3+row*1.2));L.push({k:'bz'+k,m:'tile',p,q,uv:dmUV(28)})}}
 for(const s of[1,2,3]){const cnt=G.hands[s].length;for(let i=0;i<cnt;i++){const d={k:'h'+s+'-'+i,m:'tile',p:dRack(s,i,cnt),q:DSTAND(DRACK[s].yaw,DRACK[s].tilt),uv:dmUV(28)};if(deal){d.from={p:[0,1.2,0],q:DSTAND(0,0),a:0};d.delay=(n+i*3+s)*45;d.dur=520}L.push(d)}}
 /* the three at the table: whoever's turn it is leans in and looks at their tiles, the others watch them */
 for(const r of[1,2,3]){if(!SE.includes(r))continue;const id=who(r),lk=id.lk?oppLook(id.lk):jkLook(id.n,id.h),key=(id.k||id.n)+(id.lk?':'+lkKey(lk):'');jkPerson(sc,key,lk);const think=G.phase==='play'&&G.cur===r,lean=think?.07:0;
  let yaw=0,pitch=.3;if(think)pitch=.44;else if(G.phase==='play'&&G.cur!=null&&G.cur>=0){const t=G.cur===0?[0,DSR]:DSP[G.cur],me=DSP[r],f=[-me[0],-me[1]],d=[t[0]-me[0],t[1]-me[1]];yaw=clamp(-Math.atan2(f[0]*d[1]-f[1]*d[0],f[0]*d[0]+f[1]*d[1]),-.75,.75);pitch=G.cur===0?.22:.12}
  pplPush(L,r,key,[DSP[r][0],0,DSP[r][1]],dSeatQ(r,lean),1,qt.e(pitch,yaw,0))}
 if(mine&&G.sel!=null){for(const e of G.places(G.hands[0][G.sel]))if(slots[e]){const g=slots[e];L.push({k:'g'+e,m:'ghost',p:[g.x,DT/2,g.z],q:qt.ax(0,1,0,g.yaw),a:.5,cast:false,pick:{e},now:1})}}
 mhPush(sc,L,{on:mhShow(G.ctx),yaw:0,y:-1.6,S:1.4,rest:[[-3.4,8.6],[3.4,8.6]]});
 /* a tile I just put down: the hand takes it from my row and lays it on the line */
 let reach=null;const lk=G.last&&G.last.t?G.round+':'+dmIdx(G.last.t[0],G.last.t[1]):null;if(lk!==sc.dml){if(sc.dml!==undefined&&lk&&G.last.p===0&&sc.mh&&performance.now()-(sc.dragAt||0)>900){const key='t'+dmIdx(G.last.t[0],G.last.t[1]),ob=sc.objs.get('k:'+key),to=out.find(o=>dmIdx(o.t[0],o.t[1])===dmIdx(G.last.t[0],G.last.t[1]));if(ob&&to)reach={key,f:ob.p.slice(),t:[to.x,DT/2,to.z]}}sc.dml=lk}
 sc.marks=M;g3Set(sc,L,{delay:(o,d)=>reach&&d.k===reach.key?MH_WAIT:0,gone:o=>o.id.startsWith('k:h')?{a:0,dur:180}:o.m==='ghost'?{a:0,dur:120}:{p:[o.p[0]*.3,1,o.p[2]*.3],a:0,dur:500}});
 if(reach)mhCarry(sc,[{p:reach.f},{p:reach.t,d:mhDur(v3.len(v3.sub(reach.t,reach.f))),arc:.9}]);
 if(G.phase==='over'){const l=G.last&&G.last.t?out.find(o=>dmIdx(o.t[0],o.t[1])===dmIdx(G.last.t[0],G.last.t[1])):null;g3CineGo(sc,G,l?[l.x,0,l.z]:[0,0,0])}}

/* ---------- my character in the editor: sitting at the edge of a small table, turned a little toward you ---------- */
G3B.look=()=>{const sc=g3Scene({cam:{fixed:asp=>({eye:[0,5.2,2.6],tgt:[0,3.35,-4.3],fov:clamp(2*Math.atan(Math.tan(.34)/Math.min(1,asp*1.35)),.6,1.1),sx:0,sy:0}),tgt:[0,0,0],fov:1,dy:0,dp:0,dz:1},orbit:false,zoom:false,shR:8,shC:[0,0,-3],spot:[0,-2,10,.35],bg:[.05,.036,.028],
  light:{d:v3.norm([-.3,1,.85]),c:[2.3,2.05,1.75],sky:[.32,.28,.25],gnd:[.12,.09,.07],exp:1.0}});
 roundRoom(sc,1.7,g3T('felt',()=>g3Tex(feltCv({a:'#2E7D59',b:'#123B29',ring:1}))));return sc};
G3U.look=sc=>{const lk=oppLook(sc.lk||{}),key='me:'+lkKey(lk);jkPerson(sc,key,lk);const p=[0,0,-4.3],q=qt.ax(0,1,0,.3);
 const L=[];pplPush(L,0,key,p,q,1,qt.e(-.05,-.2,0),{now:1});g3Set(sc,L)};

/* ---------- surroundings: where each game is played ----------
   joker in a room with a rug on the wall, domino in a Sololaki yard, chess at a desk among books,
   nardi in an old Tbilisi courtyard, checkers on a wooden balcony over the city. day or evening, as chosen (or by the clock) */
const envTime=()=>{const v=typeof store!=='undefined'?store.get('genv','auto'):'auto';if(v==='day'||v==='eve')return v;const h=new Date().getHours();return h>=7&&h<19?'day':'eve'};
const LT={
 room:{eve:{d:[-.22,1,.4],c:[2.35,2.08,1.72],sky:[.26,.22,.2],gnd:[.12,.08,.06],exp:1,bg:[.035,.024,.02],sp:1},day:{d:[-.55,1,.35],c:[2.3,2.25,2.15],sky:[.6,.6,.62],gnd:[.22,.18,.14],exp:1.18,bg:[.1,.09,.08],sp:.3}},
 desk:{eve:{d:[-.45,1.25,.55],c:[2.4,2.12,1.75],sky:[.27,.25,.26],gnd:[.12,.09,.06],exp:1,bg:[.04,.03,.025],sp:1},day:{d:[-.6,1.2,.35],c:[2.2,2.15,2.05],sky:[.45,.47,.52],gnd:[.16,.13,.1],exp:1.05,bg:[.12,.11,.1],sp:.5}},
 out:{eve:{d:[.5,.9,.45],c:[2.2,1.7,1.25],sky:[.22,.22,.32],gnd:[.12,.08,.06],exp:1.02,bg:[.05,.05,.09],sp:.9},day:{d:[-.4,1.3,.45],c:[2.6,2.45,2.15],sky:[.5,.58,.7],gnd:[.2,.17,.13],exp:1.02,bg:[.55,.7,.85],sp:.35}}};
function envSet(sc,kind){sc.envK=kind;sc.envSw=[];sc.spot0=sc.spot.slice()}
function envDone(sc){sc.envT=null;envApply(sc)}
function envApply(sc){if(!sc.envK)return;const t=envTime();if(sc.envT===t)return;sc.envT=t;const P=LT[sc.envK][t];
 sc.light={d:v3.norm(P.d),c:P.c,sky:P.sky,gnd:P.gnd,exp:P.exp};sc.bg=P.bg;sc.spot=[sc.spot0[0],sc.spot0[1],sc.spot0[2],sc.spot0[3]*P.sp];for(const f of sc.envSw)try{f(t)}catch(e){}}
/* a material whose picture changes with the time of day */
function envMat(sc,key,cv,o={}){const m=g3Mat(Object.assign({t:g3T(key+':eve',()=>g3Tex(cv(false))),sh:6,sp:.05,gl:0},o));sc.envSw.push(t=>{m.t=g3T(key+':'+t,()=>g3Tex(cv(t==='day')))});return m}
const P3=(sc,g,m,p,q,cast=true)=>g3Static(sc,g,m,p,q||qt.id(),cast);
/* a table: a top whose surface is at y=0, its edge, four legs, and the floor far below */
function envTable(sc,{w,d,cx=0,top,edge,floor}){P3(sc,gBox(w,.7,d,.12,3,(f,u,v)=>[u*3,v*3],[0]),top,[cx,-.35,0]);P3(sc,gBox(w,.7,d,.12,3,(f,u,v)=>[u*4,v*.4],[1,2,3,4,5]),edge,[cx,-.35,0]);
 for(const sx of[-1,1])for(const sz of[-1,1])P3(sc,gBox(.9,10.4,.9,.1,2),edge,[cx+sx*(w/2-1),-5.9,sz*(d/2-1)],null,false);
 P3(sc,gPlane(90,90,12,12),floor,[0,-11,0],null,false)}
/* props, each a few turned shapes */
const clay=()=>g3Mat({c:'#A8532E',sh:20,sp:.12,gl:.08}),silver=()=>g3Mat({c:'#D8D4CC',sh:120,sp:.9,gl:.8}),wine=()=>g3Mat({c:'#4A0C14',sh:120,sp:.7,gl:.6}),glassM=()=>g3Mat({c:'#DDE6E8',sh:140,sp:1,gl:.9,a:.55});
function jugAt(sc,p,s=1){const g=gLathe([[0,0],[.42,0],[.6,.25],[.72,.7],[.68,1.15],[.44,1.5],[.26,1.75],[.24,2.1],[.32,2.22],[.28,2.26],[.2,2.2],[0,2.2]].map(([r,y])=>[r*s,y*s]),28);
 const h=gSweep(Array.from({length:12},(_,i)=>{const a=-.2+i/11*2.6;return[0,(1.2+Math.cos(a)*.75)*s,(-.58-Math.sin(a)*.55)*s]}),()=>.07*s,8);P3(sc,gMerge(g,h),clay(),p,qt.ax(0,1,0,2.2))}
function hornAt(sc,p,yaw,k=1){const path=Array.from({length:18},(_,i)=>{const t=i/17;return[t*2.6*k,(.3+Math.sin(t*Math.PI)*.35+t*t*.5)*k,Math.sin(t*2.2)*.25*k]});const q=qt.ax(0,1,0,yaw);
 P3(sc,gSweep(path,t=>(.3*(1-t)+.04)*k,16),g3Mat({c:'#5A3A22',sh:60,sp:.4,gl:.35}),p,q);P3(sc,gXf(gTorus(.31*k,.05*k,20,6),path[0],qt.ax(0,0,1,Math.PI/2)),silver(),p,q)}
function wineGlassAt(sc,p){P3(sc,gLathe([[0,0],[.34,0],[.36,.03],[.05,.08],[.04,.75],[.12,.86],[.3,1.05],[.34,1.4],[.31,1.6],[.29,1.6],[.31,1.4],[.27,1.07],[.1,.9],[0,.88]],24),glassM(),p);P3(sc,gLathe([[0,.92],[.25,1.05],[.29,1.25],[0,1.25]],20),wine(),p)}
function teaGlassAt(sc,p){P3(sc,gLathe([[0,0],[.75,0],[.78,.04],[.75,.07],[0,.07]],28),g3Mat({c:'#F2EEE6',sh:90,sp:.5,gl:.4}),p);
 P3(sc,gLathe([[0,.07],[.22,.07],[.3,.25],[.2,.55],[.18,.7],[.27,1.0],[.3,1.06],[0,1.06]],24),g3Mat({c:'#8A3A12',sh:140,sp:1,gl:.85}),p)}
function plateAt(sc,p,r,col){P3(sc,gLathe([[0,0],[r*.7,0],[r,.12],[r*.98,.16],[r*.7,.06],[0,.06]],32),g3Mat({c:col||'#EFE9DF',sh:90,sp:.5,gl:.35}),p)}
/* შოთი: the long Georgian loaf from the clay oven, pointed at both ends */
function breadAt(sc,p,yaw){const g=gScale3(gLathe(Array.from({length:15},(_,i)=>{const t=i/14,y=-1.15+t*2.3;return[Math.max(0,Math.pow(Math.sin(t*Math.PI),1.25)*.36),y]}),20),1,1,.62);
 P3(sc,gXf(g,[0,.2,0],qt.ax(0,0,1,Math.PI/2)),g3Mat({c:'#C98A48',sh:10,sp:.06,gl:.02}),p,qt.ax(0,1,0,yaw))}
function grapesAt(sc,p){const R=rng(9),g=[];for(let k=0;k<26;k++){const t=k/26,y=.2+(1-t)*.6,r=(1-t)*.34;const a=k*2.4;g.push(gEll(.13,.13,.13,[Math.cos(a)*r,y,Math.sin(a)*r],null,10))}
 plateAt(sc,p,.75);P3(sc,gMerge(...g),g3Mat({c:'#5B2A52',sh:80,sp:.5,gl:.35}),[p[0],p[1]+.05,p[2]])}
function applesAt(sc,p){plateAt(sc,p,.9,'#E8DFC8');[[0,0,0,'#B32C22'],[.42,0,.2,'#7FA03A'],[-.3,0,.34,'#C9442A'],[.05,.38,.12,'#B83A24']].forEach(([x,y,z,c])=>P3(sc,gEll(.3,.27,.3,[0,.3,0],null,16),g3Mat({c,sh:60,sp:.35,gl:.25}),[p[0]+x,p[1]+y,p[2]+z]))}
function cupAt(sc,p){plateAt(sc,p,.5);P3(sc,gLathe([[0,.06],[.18,.06],[.26,.2],[.28,.42],[.26,.42],[.24,.22],[0,.22]],20),g3Mat({c:'#F5F1EA',sh:90,sp:.5,gl:.4}),p);P3(sc,gDisc(.25,20),g3Mat({c:'#2A160C',sh:60,sp:.4,gl:.3}),[p[0],p[1]+.39,p[2]],null,false)}
function clockAt(sc,p,yaw){const q=qt.ax(0,1,0,yaw),w=g3Mat({t:woodTex('walnut'),sh:50,sp:.3,gl:.25}),face=g3Mat({c:'#F4EFE4',sh:40,sp:.2,gl:.1}),dark=g3Mat({c:'#1A1616',sh:60,sp:.4,gl:.3});
 P3(sc,gBox(2.6,.9,.9,.08,2),w,v3.add(p,[0,.45,0]),q);for(const s of[-1,1]){const c=v3.add(p,qt.rot(q,[s*.62,.5,.46]));P3(sc,gXf(gDisc(.33,24),[0,0,0],qt.ax(1,0,0,Math.PI/2)),face,c,q,false);
  P3(sc,gCap([0,0,0],[0,.16,0],.09,.09,10),dark,v3.add(p,qt.rot(q,[s*.62,.9,0])),q)}}
function bankLampAt(sc,p){const brass=g3Mat({c:'#C9A050',sh:120,sp:.8,gl:.6});P3(sc,gLathe([[0,0],[.6,0],[.62,.12],[.4,.2],[0,.2]],24),brass,p);P3(sc,gCap([0,.2,0],[0,1.6,0],.06,.06,10),brass,p);
 const sh=gScale3(gLathe([[0,0],[.9,0],[.86,.12],[.5,.48],[0,.52]],28,.4),1,1,.55);P3(sc,sh,g3Mat({c:'#1E6A44',sh:90,sp:.6,gl:.5,two:true}),v3.add(p,[0,1.55,.2]));
 const bulb=g3Mat({c:'#FFE6B0',e:'#FFDFA0',sh:10,sp:0,gl:0});P3(sc,gEll(.22,.16,.22,[0,0,0],null,12),bulb,v3.add(p,[0,1.5,.2]),null,false);sc.envSw.push(t=>{bulb.e=lin(t==='day'?'#5a4a30':'#FFDFA0')})}
function hangLampAt(sc,p){const sh=g3Mat({c:'#7A3A1E',sh:30,sp:.2,gl:.1,two:true}),bulb=g3Mat({c:'#FFE6B0',e:'#FFE2A8',sh:10,sp:0,gl:0});
 P3(sc,gCap([0,0,0],[0,6,0],.04,.04,6),g3Mat({c:'#222'}),p,null,false);P3(sc,gLathe([[1.8,0],[1.6,.3],[.6,1.2],[.2,1.4],[0,1.42]],32,.3),sh,v3.add(p,[0,-1.4,0]),null,false);
 P3(sc,gEll(.42,.42,.42,[0,0,0],null,14),bulb,v3.add(p,[0,-1.1,0]),null,false);sc.envSw.push(t=>{bulb.e=lin(t==='day'?'#806a48':'#FFE2A8')})}
function railAt(sc,p,len,yaw,h=3.2){const q=qt.ax(0,1,0,yaw),wood=g3Mat({t:woodTex('oak'),sh:30,sp:.2,gl:.1}),n=Math.floor(len/.75),bal=gLathe([[0,0],[.16,0],[.16,.2],[.1,.32],[.16,.9],[.08,1.6],[.13,2.2],[.1,2.6],[0,2.6]].map(([r,y])=>[r,y*h/3.2]),12);
 const parts=[];for(let k=0;k<=n;k++)parts.push(gXf(gMerge(bal),[-len/2+k*len/n,0,0],qt.id()));
 P3(sc,gMerge(...parts),wood,p,q);P3(sc,gBox(len+.4,.24,.46,.05,2),wood,v3.add(p,qt.rot(q,[0,h*.84,0])),q);P3(sc,gBox(len+.4,.2,.36,.05,2),wood,p,q)}
function stringLightsAt(sc,a,b,n=14){const bulb=g3Mat({c:'#FFE9B8',e:'#FFD98A',sh:10,sp:0,gl:0}),pts=[];for(let k=0;k<=n;k++){const t=k/n,pp=v3.lerp(a,b,t);pp[1]-=Math.sin(t*Math.PI)*1.6;pts.push(pp)}
 P3(sc,gSweep(pts,()=>.03,5),g3Mat({c:'#1A1A1A'}),[0,0,0],null,false);P3(sc,gMerge(...pts.slice(1,-1).map(pp=>gEll(.16,.2,.16,pp,null,8))),bulb,[0,0,0],null,false);sc.envSw.push(t=>{bulb.e=lin(t==='day'?'#7a6a50':'#FFD98A')})}
function vineAt(sc,p,w,h,c){const m=g3Mat({t:g3T('leaf',()=>g3Tex(leafCv())),c:c||'#ffffff',cut:true,two:true,sh:20,sp:.1,gl:.05}),R=rng(61),g=[];
 for(let k=0;k<Math.floor(w*h*1.6);k++){const s=.7+R()*.6;g.push(gXf(gQuad(s,s),[(R()-.5)*w,(R()-.5)*h,R()*.4],qt.mul(qt.ax(0,0,1,R()*6.28),qt.ax(1,0,0,(R()-.5)*.8))))}P3(sc,gMerge(...g),m,p,null,false)}
function treeAt(sc,p){P3(sc,gLathe([[0,0],[1.1,0],[.8,.6],[.7,9],[.5,13],[0,13]],16),g3Mat({c:'#4A3A2E',sh:10,sp:.05,gl:0}),p,null,false);const ss=gSeasonNow();
 /* bare in winter: a few branches instead of the crown */
 if(ss==='winter'){const R=rng(47),g=[];for(let k=0;k<9;k++){const a=k*.7,y=8+R()*5;g.push(gCap([0,y,0],[Math.cos(a)*(3+R()*2),y+3+R()*2,Math.sin(a)*(3+R()*2)],.32,.1,6))}P3(sc,gMerge(...g),g3Mat({c:'#4A3A2E',sh:10,sp:.05,gl:0}),p,null,false);return}
 const R=rng(43),g=[];for(let k=0;k<22;k++)g.push(gEll(2+R()*1.6,1.6+R()*1.2,2+R()*1.6,[(R()-.5)*7,12+R()*6,(R()-.5)*7],null,12));P3(sc,gMerge(...g),g3Mat({c:ss==='autumn'?'#B07A2A':'#3E6A32',sh:12,sp:.05,gl:0}),p,null,false)}
const wallQ=(sc,m,p,w,h,yaw)=>P3(sc,gQuad(w,h),m,p,qt.ax(0,1,0,yaw||0),false);

/* the five places */
function envRoom(sc){envSet(sc,'room');const rug=g3Mat({t:g3T('rug',()=>g3Tex(rugCv())),sh:4,sp:.02,gl:0});wallQ(sc,rug,[0,8,-19.6],7,14);
 const sb=g3Mat({t:woodTex('walnut'),sh:40,sp:.25,gl:.2});P3(sc,gBox(9,.45,1.6,.1,2),sb,[11.5,4.2,-19.1],null,false);jugAt(sc,[9.2,4.43,-19.1],1.4);hornAt(sc,[11.4,4.43,-19],-.25);if(gNewYear())chichilakiAt(sc,[14.6,4.43,-19.0],1.15);
 wallQ(sc,envMat(sc,'win',windowCv),[-19.9,8,-6],8,14,Math.PI/2);hangLampAt(sc,[0,19,-1.5]);
 jugAt(sc,[4.55,0,1.25],.8);wineGlassAt(sc,[3.75,0,2.15]);wineGlassAt(sc,[4.85,0,.2]);plateAt(sc,[-4.35,0,1.05],1);breadAt(sc,[-4.35,.06,1.05],.9);hornAt(sc,[-4.6,0,2.35],2.2,.62);envDone(sc)}
function envYardS(sc){envSet(sc,'out');const brick=g3Mat({t:g3T('brick',()=>g3Tex(brickCv(),{rep:true})),uv:[0,0,8,5],sh:8,sp:.04,gl:0}),plaster=g3Mat({t:g3T('pl:ochre',()=>g3Tex(plasterCv('#C9A77A'))),sh:6,sp:.03,gl:0});
 wallQ(sc,brick,[0,8,-21],60,40);for(const x of[-9,9])wallQ(sc,envMat(sc,'win',windowCv),[x,6,-20.9],5,9);wallQ(sc,plaster,[-21,8,0],60,40,Math.PI/2);treeAt(sc,[17,-11,-14]);
 P3(sc,gPlane(90,90,12,12),g3Mat({t:g3T('tiles',()=>g3Tex(tilesCv(),{rep:true})),sh:10,sp:.05,gl:0}),[0,-11,0],null,false);(gNewYear()?colorLightsAt:stringLightsAt)(sc,[-20,16,-20.5],[20,16,-20.5]);
 const wk=wxSetup(sc,{w:46,h:32,y0:-11,z0:-20,z1:12});if(gSeasonNow()==='autumn'&&wk!=='snow')leavesAt(sc,4,-4,30,24);
 jugAt(sc,[5.45,0,3.25],.7);wineGlassAt(sc,[4.7,0,4.05]);plateAt(sc,[-5.1,0,3.5],.95);grapesAt(sc,[-5.1,.06,3.5]);envDone(sc)}
function envDesk(sc){envSet(sc,'desk');const top=g3Mat({t:woodTex('walnut'),sh:50,sp:.3,gl:.25});envTable(sc,{w:22,d:16,top,edge:top,floor:g3Mat({t:woodTex('table'),sh:16,sp:.12,gl:.08})});
 P3(sc,gBox(13.2,.03,12.6,.02,2,null,[0]),g3Mat({t:g3T('leather',()=>g3Tex(leatherCv())),sh:20,sp:.1,gl:.05}),[0,.005,0],null,false);
 const books=g3Mat({t:g3T('books',()=>g3Tex(booksCv())),sh:8,sp:.04,gl:0});wallQ(sc,books,[0,4,-20],40,26);wallQ(sc,g3Mat({t:g3T('pl:green',()=>g3Tex(plasterCv('#5E6E5A'))),sh:6,sp:.03,gl:0}),[-20,4,0],40,26,Math.PI/2);
 wallQ(sc,envMat(sc,'win',windowCv),[-19.9,6,-3],7,12,Math.PI/2);bankLampAt(sc,[-8.6,0,-5.8]);cupAt(sc,[7.6,0,4.6]);clockAt(sc,[8.2,0,-.4],-Math.PI/2);if(gNewYear())chichilakiAt(sc,[8.8,0,-5.2],.9);envDone(sc)}
function envCourt(sc){envSet(sc,'out');const top=g3Mat({t:woodTex('oak'),sh:16,sp:.1,gl:.05}),edge=g3Mat({t:woodTex('table'),sh:16,sp:.1,gl:.05});
 envTable(sc,{w:24,d:18,cx:.8,top,edge,floor:g3Mat({t:g3T('tiles',()=>g3Tex(tilesCv(),{rep:true})),sh:10,sp:.05,gl:0})});
 const pl=g3Mat({t:g3T('pl:teal',()=>g3Tex(plasterCv('#7FA6A0'))),sh:6,sp:.03,gl:0});wallQ(sc,pl,[0,8,-24],70,44);wallQ(sc,g3Mat({t:g3T('pl:ochre',()=>g3Tex(plasterCv('#C9A77A'))),sh:6,sp:.03,gl:0}),[-24,8,0],70,44,Math.PI/2);
 for(const x of[-12,0,12])wallQ(sc,envMat(sc,'win',windowCv),[x,3,-23.9],5,9);railAt(sc,[0,8,-21.5],40,0);P3(sc,gBox(42,.5,5,.1,2),g3Mat({t:woodTex('oak'),sh:30,sp:.2,gl:.1}),[0,7.75,-22],null,false);
 {const ss=gSeasonNow(),vc=ss==='autumn'?'#F0A050':null;if(ss!=='winter'){vineAt(sc,[0,13,-21],40,5,vc);vineAt(sc,[-20,4,-21],4,16,vc)}(gNewYear()?colorLightsAt:stringLightsAt)(sc,[-22,17,-22],[22,17,-22]);
  const wk=wxSetup(sc,{w:48,h:32,y0:-11,z0:-21,z1:12});if(ss==='autumn'&&wk!=='snow')leavesAt(sc,.8,-4,34,26)}
 teaGlassAt(sc,[10.4,0,4.6]);teaGlassAt(sc,[11.2,0,3.2]);plateAt(sc,[-8.9,0,5.2],.95);grapesAt(sc,[-8.9,.06,5.2]);envDone(sc)}
function envBalcony(sc){envSet(sc,'out');const top=g3Mat({t:g3T('oilcloth',()=>g3Tex(oilclothCv(),{rep:true})),uv:[0,0,1,1],sh:40,sp:.25,gl:.15}),edge=g3Mat({t:woodTex('oak'),sh:16,sp:.1,gl:.05});
 envTable(sc,{w:20,d:16,top,edge,floor:g3Mat({t:woodTex('oak'),sh:16,sp:.1,gl:.05})});railAt(sc,[0,-11,-15],36,0,7);railAt(sc,[-18,-11,0],30,Math.PI/2,7);
 wallQ(sc,envMat(sc,'sky',skylineCv,{unlit:true}),[0,4,-40],120,60);wallQ(sc,g3Mat({t:g3T('pl:white',()=>g3Tex(plasterCv('#E4DCCB'))),sh:6,sp:.03,gl:0}),[22,4,0],70,40,-Math.PI/2);wxSetup(sc,{w:48,h:32,y0:-11,z0:-34,z1:12});
 applesAt(sc,[-7.8,0,4.6]);wineGlassAt(sc,[7.6,0,4.8]);envDone(sc)}
/* chess sets: the classic turned box and ebony; the same shapes carved in olive and rosewood; a modern set of plain forms in matte ivory and charcoal */
const gStyleOf=g=>typeof gStyle==='function'?gStyle(g):'classic';
WOOD.olive=Object.assign({},WOOD.box,{base:'#D8BE8C',seed:61,lines:90,fig:.42,wave:.07,dir:'v'});WOOD.rosev=Object.assign({},WOOD.rose,{seed:63,dir:'v'});
function pieceGeoModern(t){const SG=40,L=p=>PL(p,SG),top=(y,r)=>PL(arc(0,y,r,-Math.PI/2,Math.PI/2,10),SG),base=r=>[[0,0],[r,0],[r,.05],[r*.72,.1]];
 if(t==='p')return gMerge(L([...base(.3),[.13,.3],[0,.32]]),top(.42,.12));
 if(t==='r')return L([...base(.34),[.25,.14],[.25,.6],[.29,.63],[.29,.74],[0,.74]]);
 if(t==='b')return gMerge(L([...base(.33),[.2,.14],[.07,.74],[0,.78]]),top(.82,.06));
 if(t==='q')return gMerge(L([...base(.36),[.2,.14],[.13,.72],[.25,.86],[.25,.9],[0,.9]]),top(.96,.07));
 if(t==='k')return gMerge(L([...base(.36),[.21,.14],[.15,.82],[.22,.9],[0,.92]]),gXf(gBox(.07,.26*KY,.07,.01,2),[0,1.06*KY,0],qt.id()),gXf(gBox(.2,.07,.07,.01,2),[0,1.08*KY,0],qt.id()));
 const g=gExtrude([[-.2,0],[.2,0],[.2,.36],[.33,.46],[.33,.58],[.06,.7],[-.2,.52]].map(([x,y])=>[x*KR,y*KY]),.26,.03);gXf(g,[0,.14*KY,0],qt.id());return gMerge(L([...base(.34),[.25,.14],[0,.14]]),g)}
function chessSet(sc,style){sc.sty=style;const geo=style==='modern'?pieceGeoModern:pieceGeo,mat=w=>style==='carved'?g3Mat({t:woodTex(w?'olive':'rosev'),uv:[0,0,2,1],sh:60,sp:.4,gl:.45}):style==='modern'?g3Mat({c:w?'#EEE9DF':'#2C2B2E',sh:24,sp:.14,gl:.06}):pieceMat(w);
 for(const t of'pnbrqk'){const g=g3Mesh(geo(t)),h={p:.6,n:.8,b:.88,r:.72,q:.95,k:1.12}[t]*KY;for(const c of'wb'){const md=g3Model(sc,c+t,[[g,mat(c==='w')]],[.36,h/2,.36],[0,h/2,0]);md.land=woodLand(CHT)}}}
/* a portrait of a character for the profile: the editor's scene drawn once into a hidden box and kept as a picture */
const G3PIC=new Map();
function g3Portrait(look){const lk=oppLook(look),k=lkKey(lk);if(G3PIC.has(k))return G3PIC.get(k);if(!g3Init())return null;
 const box=document.createElement('div');box.style.cssText='position:fixed;left:-10000px;top:0;width:300px;height:330px';document.body.appendChild(box);
 let url=null;try{const sc=G3S.look||(G3S.look=G3B.look());sc.host='look';sc.lk=lk;if(g3Mount(box,sc)){G3U.look(sc);g3Size();g3Draw(sc,performance.now());url=G3D.cv.toDataURL('image/jpeg',.86)}}catch(e){url=null}
 box.remove();if(url)G3PIC.set(k,url);return url}

/* ---------- my own hands ----------
   they rest at the near edge of the table and reach in when I move: take the piece, carry it, put it down and come back;
   for the dice they swing up and throw. a move made by dragging needs no hand, the finger already did it */
const myHandsOn=()=>typeof store==='undefined'||store.get('ghands',true)!==false;
function mhModels(sc){const lk=oppLook(typeof myLook==='function'?myLook():{}),key=lk.skin+'|'+lk.shirt;if(sc.mhKey===key)return;sc.mhKey=key;
 const skin=g3Mat({c:lk.skin,sh:14,sp:.12,gl:.03}),knit=g3Mat({c:hex(lk.shirt),t:g3T('knit',()=>g3Tex(knitCv(),{rep:true})),uv:[0,0,4,3],sh:6,sp:.05,gl:0});
 for(const s of[-1,1]){const hand=gXf(handGeo(-s),[0,0,0],qt.ax(0,1,0,Math.PI)),arm=gMerge(gCap([0,.04,.1],[s*.34,.66,3.7],.29,.42,12),gXf(gTorus(.34,.1,18,6),[0,.04,.22],qt.ax(1,0,0,Math.PI/2)));
  g3Model(sc,'mh'+s,[[hand,skin],[arm,knit]],null)}}
/* the hands are shown when this phone is the one playing: against the computer, online, or two people sharing it */
const mhShow=c=>!!c&&(c.mode==='local'||isPlayer(c))&&!c.gone;
const mhMover=(c,turnNow)=>c.mode==='local'||turnNow===-c.side;
/* rest: [left, right] as [x, z] in my own frame (z toward me); y: the table top; S: how big */
function mhPush(sc,L,o){sc.mh=null;if(!o.on||!myHandsOn())return;mhModels(sc);const q0=qt.ax(0,1,0,o.yaw||0),H={q0,S:o.S,rest:{},rq:{}};
 for(const s of[-1,1]){const r=o.rest[s<0?0:1],p=v3.add(qt.rot(q0,[r[0],0,r[1]]),[0,o.y+.12*o.S,0]),q=qt.mul(q0,qt.ax(0,1,0,s*.26));H.rest[s]=p;H.rq[s]=q;L.push({k:'mh'+s,m:'mh'+s,p,q,s:o.S,refl:false,dur:450})}sc.mh=H}
/* where the wrist goes so that the fingertips are over a point */
const mhAt=(H,s,P,up)=>v3.add(P,qt.rot(H.q0,[s*.1*H.S,(up??.4)*H.S,.8*H.S]));
const mhSide=(H,P)=>qt.rot(qt.inv(H.q0),P)[0]<-2.2?-1:1;
/* reach for a point, carry along the given stops (each with its time), let go and come home */
function mhCarry(sc,stops,o={}){const H=sc.mh;if(!H||!stops.length)return;const s=o.s||mhSide(H,stops[0].p),h=sc.objs.get('k:mh'+s);if(!h)return;const q=qt.mul(H.q0,qt.ax(0,1,0,s*.1));
 const K=[{p:mhAt(H,s,stops[0].p,1),q,d:o.d0||230,arc:.25},{p:mhAt(H,s,stops[0].p,.4),q,d:110}];
 for(let i=1;i<stops.length;i++)K.push({p:mhAt(H,s,stops[i].p,.4),q,d:stops[i].d||380,arc:stops[i].arc??.5});
 K.push({p:mhAt(H,s,stops[stops.length-1].p,1),q,d:140},{p:H.rest[s],q:H.rq[s],d:430,arc:.18});g3Kf(h,K)}
/* the dice: the right hand comes up from the edge, throws, and goes back */
function mhThrow(sc,P){const H=sc.mh;if(!H)return;const h=sc.objs.get('k:mh1');if(!h)return;const q=qt.mul(H.q0,qt.ax(1,0,0,-.35));
 g3Kf(h,[{p:v3.add(P,qt.rot(H.q0,[.6,.2*H.S,2.2])),q,d:220,arc:.2},{p:v3.add(P,qt.rot(H.q0,[-.2,.55*H.S,-.6])),q:H.q0,d:150},{p:H.rest[1],q:H.rq[1],d:420,arc:.2}])}
/* the time a carried piece takes, the same rule the board uses */
const mhDur=far=>Math.min(620,280+90*Math.sqrt(far));
const MH_WAIT=340;

/* ---------- the closing shot: when a game ends the camera turns slowly round the last move and comes in close ---------- */
function g3CineGo(sc,G,f){const c=G&&G.ctx;if(!c||!c.finAt||c.cined||RM()||performance.now()-c.finAt>1600)return;c.cined=1;
 const I={t0:performance.now()+180,d:window.__cineD||2700,f,s:Math.random()<.5?1:-1,tg:sc.cam.tgt.slice()};sc.intro=null;sc.cine=I;if(typeof gClipStart==='function')try{I.end=gClipStart(G,sc,I)}catch(e){}g3Need()}

/* ---------- seasons and weather ----------
   in winter it may snow and in spring and autumn it may rain, the same for everyone on the same day (or as chosen in the menu).
   autumn turns the vines; from mid-December to mid-January a ჩიჩილაკი stands in the rooms and the lights in the yards are coloured */
const gSeasonNow=()=>{const m=new Date().getMonth();return m===11||m<2?'winter':m<5?'spring':m<8?'summer':'autumn'};
const gNewYear=()=>{const d=new Date(),m=d.getMonth(),dd=d.getDate();return(m===11&&dd>=15)||(m===0&&dd<=14)};
function wxKind(){const v=typeof store!=='undefined'?store.get('gwx','auto'):'auto';if(v==='clear')return null;if(v==='snow'||v==='rain')return v;
 const d=new Date(),h=hashS(d.getFullYear()+'-'+d.getMonth()+'-'+d.getDate()),s=gSeasonNow();return s==='winter'?(h<.5?'snow':null):s==='summer'?(h<.07?'rain':null):(h<.28?'rain':null)}
function wxSetup(sc,o){const k=wxKind();sc.wx=k?Object.assign({k},o):null;if(k==='snow')P3(sc,gPlane(90,90,4,4),g3Mat({c:'#F4F7FA',sh:30,sp:.2,gl:.05,a:.82}),[0,-10.96,0],null,false);return k}
/* ჩიჩილაკი: shaved hazel curls hanging round a stick, a pomegranate and two sweets on top */
function chichilakiAt(sc,p,k=1){const m=g3Mat({c:'#F1E6CF',sh:22,sp:.12,gl:.06}),R=rng(17),g=[gCap([0,0,0],[0,3.4*k,0],.07*k,.05*k,6)];
 for(let t=0;t<4;t++)for(let i=0;i<16;i++){const a=i/16*6.28+t*.2,y=(3.1-t*.62)*k,r=(.18+t*.2)*k,l=(.55+t*.12+R()*.2)*k,dir=[Math.cos(a),0,Math.sin(a)],tip=v3.add([dir[0]*r,y,dir[2]*r],[dir[0]*l*.55,-l,dir[2]*l*.55]);
  g.push(gCap([dir[0]*r*.3,y,dir[2]*r*.3],tip,.06*k,.035*k,5))}
 P3(sc,gMerge(...g),m,p);P3(sc,gEll(.2*k,.2*k,.2*k,[0,3.55*k,0],null,12),g3Mat({c:'#A8182A',sh:60,sp:.4,gl:.3}),p);
 for(const s of[-1,1])P3(sc,gCap([s*.22*k,3.45*k,0],[s*.32*k,2.85*k,0],.07*k,.07*k,6),g3Mat({c:'#7A3A18',sh:30,sp:.2,gl:.1}),p)}
/* the yard's string of lights in colour for the new year */
function colorLightsAt(sc,a,b,n=16){const cols=['#FF6B6B','#FFD166','#5BD38A','#64B5FF','#E58CFF'],pts=[];for(let k=0;k<=n;k++){const t=k/n,pp=v3.lerp(a,b,t);pp[1]-=Math.sin(t*Math.PI)*1.6;pts.push(pp)}
 P3(sc,gSweep(pts,()=>.03,5),g3Mat({c:'#1A1A1A'}),[0,0,0],null,false);
 cols.forEach((c,ci)=>{const ms=pts.slice(1,-1).filter((_,i)=>i%cols.length===ci);if(!ms.length)return;const m=g3Mat({c,e:c,sh:10,sp:0,gl:0});P3(sc,gMerge(...ms.map(pp=>gEll(.17,.21,.17,pp,null,8))),m,[0,0,0],null,false);sc.envSw.push(t=>{m.e=lin(t==='day'?'#5a5040':c)})})}
/* leaves fallen on the yard in autumn */
function leavesAt(sc,cx,cz,w,d,n=70){const R=rng(29),g=[];for(let i=0;i<n;i++){const s=.6+R()*.5;g.push(gXf(gQuad(s,s),[cx+(R()-.5)*w,-10.95+R()*.02,cz+(R()-.5)*d],qt.mul(qt.ax(0,1,0,R()*6.28),qt.ax(1,0,0,-Math.PI/2))))}
 P3(sc,gMerge(...g),g3Mat({t:g3T('leaf',()=>g3Tex(leafCv())),c:'#E89040',cut:true,two:true,sh:10,sp:.05,gl:0}),[0,0,0],null,false)}

/* ---------- the career places, and a choice of place for the two-player boards ----------
   each builds its own table (the size the game needs), floor and backdrop; all three are outdoors */
const GTBL={nardi:{w:24,d:18,cx:.8},chess:{w:22,d:16,cx:0},shashi:{w:20,d:16,cx:0}};
function palmAt(sc,p,h=13,lean=.3){const R=rng(Math.round(p[0]*13+p[2]*7)),seg=[];for(let i=0;i<=10;i++){const t=i/10;seg.push([Math.sin(t*1.3)*lean*h*.25,t*h,0])}
 P3(sc,gSweep(seg,t=>.55-.25*t,10),g3Mat({c:'#8A6A48',sh:8,sp:.04,gl:0}),p,qt.ax(0,1,0,R()*6.28),false);const top=v3.add(p,seg[10]),fr=[];
 for(let k=0;k<9;k++){const a=k/9*6.28+R()*.3,pts=[];for(let i=0;i<=8;i++){const t=i/8;pts.push([Math.cos(a)*t*5,-t*t*2.6+t*.8,Math.sin(a)*t*5])}fr.push(gSweep(pts,t=>.42*(1-t)+.05,4))}
 P3(sc,gMerge(...fr),g3Mat({c:'#3F7A3A',sh:12,sp:.06,gl:0}),top,null,false)}
function lampPostAt(sc,p){const iron=g3Mat({c:'#2A2A2E',sh:60,sp:.4,gl:.3}),bulb=g3Mat({c:'#FFF1CC',e:'#FFE0A0',sh:10,sp:0,gl:0});P3(sc,gCap([0,0,0],[0,14,0],.18,.14,8),iron,p,null,false);P3(sc,gEll(.7,.85,.7,[0,14.7,0],null,14),bulb,p,null,false);sc.envSw.push(t=>{bulb.e=lin(t==='day'?'#6a6050':'#FFE0A0')})}
function envSea(sc,g){envSet(sc,'out');const T=GTBL[g]||GTBL.chess,top=g3Mat({t:woodTex('oak'),sh:16,sp:.1,gl:.05}),edge=g3Mat({t:woodTex('table'),sh:16,sp:.1,gl:.05});
 envTable(sc,Object.assign({top,edge,floor:g3Mat({t:g3T('tiles',()=>g3Tex(tilesCv(),{rep:true})),sh:10,sp:.05,gl:0})},T));
 wallQ(sc,envMat(sc,'sea',seaCv,{unlit:true}),[0,15,-46],150,72);railAt(sc,[0,-11,-19],60,0,7);palmAt(sc,[-19,-11,-14],15,.4);palmAt(sc,[21,-11,-17],13,-.3);lampPostAt(sc,[-26,-11,-8]);
 teaGlassAt(sc,[T.cx+9.6,0,4.6]);applesAt(sc,[T.cx-8.4,0,4.8]);wxSetup(sc,{w:52,h:32,y0:-11,z0:-30,z1:12});envDone(sc)}
function envValley(sc,g){envSet(sc,'out');const T=GTBL[g]||GTBL.chess,top=g3Mat({t:woodTex('walnut'),sh:30,sp:.2,gl:.15}),edge=g3Mat({t:woodTex('walnut'),sh:30,sp:.2,gl:.15});
 envTable(sc,Object.assign({top,edge,floor:g3Mat({t:woodTex('oak'),sh:16,sp:.1,gl:.05})},T));
 wallQ(sc,envMat(sc,'valley',valleyCv,{unlit:true}),[0,9,-46],150,72);railAt(sc,[0,-11,-17],44,0,7);railAt(sc,[-22,-11,0],34,Math.PI/2,7);vineAt(sc,[-21,6,-12],3,12,gSeasonNow()==='autumn'?'#F0A050':null);
 jugAt(sc,[T.cx+9,0,3.6],.75);wineGlassAt(sc,[T.cx+8,0,5]);wineGlassAt(sc,[T.cx+10.2,0,5.2]);plateAt(sc,[T.cx-8.6,0,4.8],.95);grapesAt(sc,[T.cx-8.6,.06,4.8]);wxSetup(sc,{w:52,h:32,y0:-11,z0:-30,z1:12});envDone(sc)}
function envCity(sc,g){envSet(sc,'out');const T=GTBL[g]||GTBL.chess,top=g3Mat({t:woodTex('oak'),sh:16,sp:.1,gl:.05}),edge=g3Mat({t:woodTex('table'),sh:16,sp:.1,gl:.05});
 envTable(sc,Object.assign({top,edge,floor:g3Mat({t:g3T('tiles',()=>g3Tex(tilesCv(),{rep:true})),sh:10,sp:.05,gl:0})},T));
 wallQ(sc,envMat(sc,'city',cityCv,{unlit:true}),[0,7,-46],150,72);railAt(sc,[0,-11,-18],60,0,7);lampPostAt(sc,[-22,-11,-12]);lampPostAt(sc,[22,-11,-12]);(gNewYear()?colorLightsAt:stringLightsAt)(sc,[-22,11,-17],[22,11,-17]);
 teaGlassAt(sc,[T.cx+9.6,0,4.6]);teaGlassAt(sc,[T.cx+10.4,0,3.2]);wxSetup(sc,{w:52,h:32,y0:-11,z0:-30,z1:12});envDone(sc)}
const GPLACE={court:{f:sc=>envCourt(sc),n:'ძველი თბილისის ეზო'},balcony:{f:sc=>envBalcony(sc),n:'ხის აივანი'},desk:{f:sc=>envDesk(sc),n:'მაგიდა წიგნებთან'},sea:{f:envSea,n:'ბათუმის ბულვარი'},valley:{f:envValley,n:'სიღნაღის აივანი'},city:{f:envCity,n:'მთაწმინდა'}};
const GPDEF={nardi:'court',shashi:'balcony',chess:'desk'};
/* which place a board stands in: a career game brings its own; otherwise the place picked in the menu (once it is open), or the usual one */
function gPlaceOf(g){if(!GPDEF[g])return null;const G=GAME[g],c=G&&G.ctx;if(c&&c.place&&GPLACE[c.place])return c.place;const v=typeof store!=='undefined'?store.get('gplace:'+g,null):null;return v&&GPLACE[v]&&(typeof gPlaceOpen!=='function'||gPlaceOpen(v))?v:GPDEF[g]}
const gEnvBuild=(sc,g)=>{const k=gPlaceOf(g)||GPDEF[g];(GPLACE[k]||GPLACE[GPDEF[g]]).f(sc,g)};
/* bigger, brighter marks when big buttons are on */
function mkBig(M){if(typeof gBigOn!=='function'||!gBigOn())return;for(const m of M){if(m.uv!==MK.dot&&m.uv!==MK.ring)continue;m.s=Array.isArray(m.s)?[m.s[0]*1.3,m.s[1],m.s[2]*1.3]:m.s*1.3;m.a=Math.min(1,(m.a??1)*1.3)}}
