/* the 3D scenes of the five games. each scene is built once; on every render the game's state becomes a list of objects
   (matched with what is already on the table, so moves animate) and a list of flat marks (selection, targets, last move) */
const G3S={},G3B={},G3U={};
const GOLD=lin('#F4BC4C'),GOLDS=lin('#FFD27A'),RED=lin('#FF5A5F'),INK=lin('#20140c'),PALE=lin('#FFF4D6'),MINT=lin('#7CF0B4');
function g3Show(id){const el=$('.g3',view);if(!el)return;const k=id==='jko'?'joker':id,sc=G3S[k]||(G3S[k]=G3B[k]());sc.host=id;
 const want=G3D.intro||G3W.intro,intro=want===id;if(intro){G3D.intro=null;G3W.intro=null}
 if(!g3Mount(el,sc))return;try{G3U[id](sc)}catch(e){try{console.warn('3D sync',e)}catch(x){}}if(intro)g3StartIntro(sc);g3Insets(sc);g3Draw(sc,performance.now());g3Labels(sc);g3Need()}
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
G3B.chess=()=>{const sc=g3Scene({hug:1,cam:{yaw:0,pitch:.9,pp:.16,fov:.56,tgt:[0,.25,.3],box:[[-4.75,0,-5.7],[4.75,1.2,5.7]],dy:0,dp:0,dz:1,my:.97,mxp:.995},shR:8.5,spot:[0,0,7.6,.85]});
 g3Table(sc);mkModel(sc);const W=9.5,T=CHT;
 const bt=g3T('bchess',()=>g3Tex(boardCv({size:W,border:.75,frame:'frame',light:'maple',dark:'wenge',inlay:'rgba(226,184,96,.95)',ink:'rgba(244,214,156,.9)',coords:1})));
 sc.statics.push({parts:[{mesh:g3Mesh(gBox(W,T,W,.07,4,null,[0])),mat:g3Mat({t:bt,sh:70,sp:.35,gl:.3}),cast:true},{mesh:g3Mesh(gBox(W,T,W,.07,4,(f,u,v)=>[u*2.5,v*.35],[1,2,3,4,5])),mat:g3Mat({t:woodTex('frame'),sh:60,sp:.35,gl:.3}),cast:true}],M:m4.trs([0,T/2,0],qt.id(),1),cast:true});
 for(const t of'pnbrqk'){const g=g3Mesh(pieceGeo(t)),h={p:.6,n:.8,b:.88,r:.72,q:.95,k:1.12}[t]*KY;
  for(const c of'wb'){const md=g3Model(sc,c+t,[[g,pieceMat(c==='w')]],[.36,h/2,.36],[0,h/2,0]);md.land=woodLand(T)}}
 sc.refl={y:T,rect:[-4,-4,4,4],k:.3,fade:1.4};
 sc.tap=ray=>{const o=g3HitObj(sc,ray,o=>o.pick);let i=o?o.pick.i:null;if(i==null){const p=g3HitY(ray,CHT);i=p?chAt(p):null;if(i==null)return}g3Act('chm',{i:String(i)})};
 /* drag a piece to a square; the square under it lights up when the move is legal */
 sc.drag={y:T,lift:.6,start:o=>{if(CH.sel!==o.pick.i)g3Act('chm',{i:String(o.pick.i)})},
  move:(o,p)=>{const i=chAt(p);if(i==null||i===o.pick.i)return null;const ok=CH.moves.some(m=>m.f===o.pick.i&&m.t===i),[x,z]=chXZ(i);return{m:'mk',p:[x,T+.006,z],s:[1.02,1,1.02],uv:MK.sq,c:ok?GOLD:PALE,a:ok?1:.35,add:true}},
  drop:(o,p)=>{const i=p?chAt(p):null;if(i!=null&&i!==o.pick.i)g3Act('chm',{i:String(i)})}};
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
 sc.marks=M;g3Set(sc,L,{delay:(o,d)=>d.s<1?280:0,dur:(o,d,far)=>d.m[1]==='n'&&far>1?560:Math.min(620,280+90*Math.sqrt(far))})};

/* ---------- checkers ---------- */
const CKT=.42;
G3B.shashi=()=>{const sc=g3Scene({hug:1,cam:{yaw:0,pitch:.92,pp:.14,fov:.56,tgt:[0,.2,.3],box:[[-4.75,0,-5.6],[4.75,.8,5.6]],dy:0,dp:0,dz:1,my:.97,mxp:.995},shR:8.5,spot:[0,0,7.6,.85]});
 g3Table(sc);mkModel(sc);const W=9.5,T=CKT;
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
  drop:(o,p)=>{const q=p?at(p):null;if(q&&!(q[0]===o.pick.r&&q[1]===o.pick.c))g3Act('ck',{r:String(q[0]),c:String(q[1])})}};
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
 sc.marks=M;const caps=(G.lcap||[]).map(([r,cc])=>xz(r,cc));
 g3Set(sc,L,{gone:o=>fresh&&G.last.length&&Math.abs(o.p[0]-(G.last[0][1]-3.5))<.01&&Math.abs(o.p[2]-(G.last[0][0]-3.5))<.01?{a:0,dur:1}:null,
  delay:(o,d)=>{if(!fresh)return 0;const k=caps.findIndex(([x,z])=>Math.abs(o.p[0]-x)<.01&&Math.abs(o.p[2]-z)<.01);return k<0?0:180+k*300}})};

/* ---------- nardi ---------- */
const NT=.35,NRIM=.13;
const nCol=di=>di>=12?{col:di<18?di-12:di-11,top:1}:{col:di>=6?11-di:12-di,top:0};
G3B.nardi=()=>{const sc=g3Scene({hug:1,cam:{yaw:0,pitch:1.08,pp:.14,fov:.56,tgt:[.8,.2,.35],box:[[-7,0,-6.1],[8.6,.9,6.1]],dy:0,dp:0,dz:1,mxp:.995},shR:10.5,shC:[.8,0,0],spot:[.8,0,10,.65],yawMax:.5});
 g3Table(sc);mkModel(sc);const fr=g3Mat({t:woodTex('frame'),sh:60,sp:.35,gl:.32});
 const top=g3T('bnardi',()=>g3Tex(nardiCv()));
 sc.statics.push({parts:[{mesh:g3Mesh(gBox(15.6,NT,12.2,.08,3,null,[0])),mat:g3Mat({t:top,sh:55,sp:.3,gl:.25}),cast:true},{mesh:g3Mesh(gBox(15.6,NT,12.2,.08,3,(f,u,v)=>[u*3,v*.3],[1,2,3,4,5])),mat:fr,cast:true}],M:m4.trs([.8,NT/2,0],qt.id(),1),cast:true});
 const rim=(x,z,w,d,h=NRIM)=>g3Static(sc,gBox(w,h,d,.05,3,(f,u,v)=>[u*Math.max(1,w/3),v*Math.max(1,d/3)]),fr,[x,NT+h/2,z]);
 rim(.8,-5.85,15.6,.5);rim(.8,5.85,15.6,.5);rim(-6.75,0,.5,11.2);rim(0,0,1,11.2,NRIM+.02);rim(6.725,0,.45,11.2);rim(8.375,0,.45,11.2);
 const ck=g3Mesh(checkerGeo());g3Model(sc,'w',[[ck,g3Mat({c:'#F2E8D6',sh:80,sp:.5,gl:.6})]],[.44,.09,.44],[0,.08,0]).land=woodLand(NT);g3Model(sc,'b',[[ck,g3Mat({c:'#3a1714',sh:90,sp:.6,gl:.75})]],[.44,.09,.44],[0,.08,0]).land=woodLand(NT);
 g3Model(sc,'die',[[dieGeo(.62),g3Mat({t:g3T('dice',()=>g3Tex(diceCv(),{af:false})),sh:90,sp:.5,gl:.45})]],[.31,.31,.31]).land=()=>snd('soft',.8);
 sc.refl={y:NT,rect:[-6.5,-5.6,6.5,5.6],k:.2,fade:.9};
 sc.tap=ray=>{const p=g3HitY(ray,NT),k=p?nKAt(p):null;if(k!=null)g3Act('npt',{k})};
 sc.drag={y:NT,lift:.55,start:o=>{if(NR.sel!==o.pick.f)g3Act('npt',{k:String(o.pick.f)})},
  move:(o,p)=>{const k=nKAt(p);if(k==null||k===String(o.pick.f))return null;const id=k==='off'||k==='bar'?k:+k,ok=NR.opts(NR.ctx.side,o.pick.f).some(x=>x.to===id);if(!ok)return null;
   if(id==='off')return{m:'mk',p:[7.55,NT+.006,3],s:[1.2,1,5.4],uv:MK.sq,c:GOLD,a:1,add:true};const flip=NR.ctx.side===-1,{col,top}=nCol(flip?23-id:id);return{m:'mk',p:[col-6,NT+.006,top?-3.15:3.15],s:[1,1,4.9],uv:MK.sq,c:GOLD,a:1,add:true}},
  drop:(o,p)=>{const k=p?nKAt(p):null;if(k!=null&&k!==String(o.pick.f))g3Act('npt',{k})}};
 return sc};
/* which point (or the bar, or the tray) a spot on the board belongs to */
function nKAt(p){const flip=NR.ctx.side===-1,[x,z]=[p[0],p[2]];if(z<-5.7||z>5.7)return null;if(x>6.9&&x<8.3)return 'off';if(x<-6.6||x>6.6)return null;
 const col=Math.round(x+6);if(col===6)return 'bar';const top=z<0,di=top?(col<6?12+col:col+11):(col<6?11-col:12-col);return String(flip?23-di:di)}
function nSlot(di,k){const{col,top}=nCol(di),lay=Math.floor(k/5),idx=k%5;return[col-6,NT+lay*.165,top?-5.1+idx*.9+lay*.45:5.1-idx*.9-lay*.45]}
G3U.nardi=sc=>{const G=NR,c=G.ctx,me=c.side,flip=me===-1,L=[],M=[],dI=i=>flip?23-i:i;
 const can=new Set(G.mine()&&G.rolled?G.legal().map(m=>m.f):[]);
 for(let i=0;i<24;i++){const v=G.p[i],n=Math.abs(v);for(let k=0;k<n;k++){const p=nSlot(dI(i),k),top=k===n-1,mv=top&&can.has(i),sel=top&&G.sel===i;L.push({m:v>0?'w':'b',p,pick:mv?{f:i}:null,drag:mv,lift:sel?.18:0,glow:sel?[.12,.09,.03]:null})}}
 for(const s of[me,-me])for(let k=0;k<G.bar[s];k++){const mv=s===me&&k===G.bar[s]-1&&can.has('bar'),sel=mv&&G.sel==='bar';L.push({m:s===1?'w':'b',p:[0,NT+NRIM+.02+Math.floor(k/4)*.165,(s===me?1:-1)*(1.05+(k%4)*.9)],pick:mv?{f:'bar'}:null,drag:mv,lift:sel?.18:0,glow:sel?[.12,.09,.03]:null,refl:false})}
 for(const s of[me,-me])for(let k=0;k<G.off[s];k++)L.push({m:s===1?'w':'b',p:[7.55,NT+.44,(s===me?1:-1)*(5.3-k*.172)],q:qt.ax(1,0,0,Math.PI/2)});
 /* dice: the mover's dice lie in their half; a fresh roll is thrown from their edge and tumbles */
 const all=G.last.length===2?(G.last[0]===G.last[1]?[G.last[0],G.last[0],G.last[0],G.last[0]]:G.last.slice()):[],left=G.dice.slice();
 const used=all.map(v=>{const k=left.indexOf(v);if(k>=0){left.splice(k,1);return false}return true});
 const sig=G.rolled?G.turn+':'+G.last.join(','):'';G.rollAnim=0;if(sig&&sig!==sc.rsig){sc.rsig=sig;sc.roll=(sc.roll||0)+1;sc.dside=G.turn===me?1:-1}if(sc.dside==null)sc.dside=G.turn===me?1:-1;
 const side=sc.dside,R=rng((sc.roll||0)*977+7),thrower=side;
 all.forEach((v,i)=>{const x=side*(all.length>2?1.9+i*.82:2.7+i*1.05),z=all.length>2?(i%2?.12:-.12):(i?.14:-.1),yaw=(R()-.5)*1.2,q=qt.mul(qt.ax(0,1,0,yaw),dieUp(v)),d={k:'d'+(sc.roll||0)+'-'+i,m:'die',p:[x,NT+.31,z],q,dim:used[i]?.42:1};
  if(sc.roll&&sc.rolled!==sc.roll){const from=[x+side*(1.5+R()),NT+2.4,thrower*4.6];d.from={p:from,q:qt.mul(qt.ax(R(),R(),R(),R()*6),q)};
   d.path=[[x+side*.5*(R()-.2),NT+.31,z*.5+thrower*1.2],[x,NT+.31,z]];d.hops=[.15,.55];d.spin=[R()-.5,R()-.5,R()-.5,2+Math.floor(R()*2)];d.ez='out';d.dur=1000+i*90;d.delay=i*40}
  L.push(d)});
 if(sc.roll)sc.rolled=sc.roll;
 /* marks: the chosen point, where it can go, and which checkers can move */
 const mine=G.mine()&&G.rolled,sel=G.sel,mk=(p,uv,col,a,s,o)=>M.push(Object.assign({m:'mk',p,s,uv,c:col,a},o||{}));
 const ptMark=(i,col,a)=>{const{col:cc,top}=nCol(dI(i));mk([cc-6,NT+.003,top?-3.15:3.15],MK.sq,col,a,[.98,1,4.9],{add:true})};
 if(mine&&sel!==null){if(sel==='bar')mk([0,NT+NRIM+.04,3],MK.sq,GOLD,1,[1,1,5],{add:true});else ptMark(sel,GOLD,.95);
  for(const o of G.opts(me,sel)){if(o.to==='off'){mk([7.55,NT+.005,3],MK.sq,GOLD,.95,[1.1,1,5.2],{add:true,pulse:true});continue}const n=Math.abs(G.p[o.to]),p=nSlot(dI(o.to),G.p[o.to]*me<0?0:n);mk([p[0],p[1]+.01,p[2]],MK.dot,GOLD,.95,[.62,1,.62],{add:true,pulse:true})}}
 else if(mine&&G.legal().length){const from=new Set(G.legal().map(m=>m.f));for(const f of from){if(f==='bar'){const k=G.bar[me]-1;mk([0,NT+NRIM+.03+Math.floor(k/4)*.165+.17,1.05+(k%4)*.9],MK.ring,GOLD,.9,[1.05,1,1.05],{add:true,pulse:true});continue}
   const n=Math.abs(G.p[f]),p=nSlot(dI(f),n-1);mk([p[0],p[1]+.17,p[2]],MK.ring,GOLD,.9,[1.05,1,1.05],{add:true,pulse:true})}}
 sc.marks=M;g3Set(sc,L,{gone:o=>o.m==='die'?{a:0,dur:220}:null,delay:(o,d)=>d.m!=='die'&&Math.abs(d.p[0])<.01&&o.p[0]!==0?260:0})};

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
const JLOOK={'ნინო':{style:'long',fem:1,skin:'#EFC2A2',hair:'#2A1A12',shirt:'#8E3047'},'ლუკა':{style:'short',skin:'#E2AF8C',hair:'#1E140F',shirt:'#2F5D8A'},'დათო':{style:'bald',mus:1,skin:'#D69C77',hair:'#6F6862',brow:'#4A3F38',shirt:'#3E6B47'}};
function jkLook(nm,h){if(JLOOK[nm])return JLOOK[nm];let k=0;for(const ch of String(nm||''))k=(k*31+ch.charCodeAt(0))>>>0;
 const sk=['#EBC0A0','#DDA984','#F2CDB0','#C99169'],hr=['#24170F','#1A120D','#4E3220','#2E2219'];
 return{style:k%5===0?'bald':'short',mus:k%3===0,skin:sk[k%4],hair:hr[(k>>3)%4],shirt:`hsl(${h??(k%360)} 38% 36%)`}}
const hex=c=>{if(c[0]==='#')return c;const d=document.createElement('canvas').getContext('2d');d.fillStyle=c;return d.fillStyle};
function jkPerson(sc,key,L){if(sc.models['pb:'+key])return;const g=personGeo(L),fem=!!L.fem;
 const skin=g3Mat({c:L.skin,sh:14,sp:.12,gl:.03}),shirt=g3Mat({c:hex(L.shirt),sh:6,sp:.05,gl:0}),hair=g3Mat({c:L.hair,sh:12,sp:.09,gl:.02}),chair=g3Mat({t:woodTex('walnut'),uv:[0,0,1,1],sh:50,sp:.3,gl:.25});
 const face=g3Mat({t:g3T('face:'+key,()=>g3Tex(faceCv({skin:L.skin,hair:L.hair,brow:L.brow,fem}))),sh:14,sp:.12,gl:.03});
 g3Model(sc,'pb:'+key,[[g.body.shirt,shirt],[g.body.skin,skin],[g.body.chair,chair]],null);
 g3Model(sc,'ph:'+key,[[g.head.face,face],[g.head.skin,skin],...(g.head.hair?[[g.head.hair,hair]]:[])],null)}
G3B.joker=()=>{const sc=g3Scene({cam:{fixed:jkCam,tgt:[0,0,0],fov:1,dy:0,dp:0,dz:1},orbit:false,zoom:false,shR:12,shC:[0,0,-1.6],spot:[0,2.4,11,.62],bg:[.035,.024,.02],
  light:{d:v3.norm([-.22,1,.4]),c:[2.35,2.08,1.72],sky:[.26,.22,.2],gnd:[.12,.08,.06],exp:1.0},
  anchors:[['.seat.left',[...[JSP[1][0]*.97,6.25,JSP[1][1]*.97]]],['.seat.top',[0,6.35,-JR*.97]],['.seat.right',[JSP[3][0]*.97,6.25,JSP[3][1]*.97]]]});
 /* the room: plank floor, papered walls on three sides */
 g3Static(sc,gPlane(60,60,8,8),g3Mat({t:woodTex('table'),sh:16,sp:.12,gl:.08}),[0,-11,0],null,false);
 const wall=g3Mat({t:g3T('wall',()=>g3Tex(wallCv(),{rep:true})),uv:[0,0,4,3],sh:4,sp:.02,gl:0});
 const wq=(w,h)=>{const g=gQuad(w,h);return g};
 g3Static(sc,wq(60,40),wall,[0,9,-20],null,false);g3Static(sc,wq(60,40),wall,[-20,9,0],qt.ax(0,1,0,Math.PI/2),false);g3Static(sc,wq(60,40),wall,[20,9,0],qt.ax(0,1,0,-Math.PI/2),false);
 g3Static(sc,gBox(60,.6,.5,.1),g3Mat({t:woodTex('walnut'),sh:40,sp:.25,gl:.2}),[0,-2,-19.7],null,false);
 /* the table: felt, a turned mahogany rim and a pedestal */
 const felt=g3T('felt',()=>g3Tex(feltCv({a:'#2E7D59',b:'#123B29',ring:1})));
 g3Static(sc,gDisc(5.45,96),g3Mat({t:felt,sh:6,sp:.04,gl:0}),[0,0,0],null,false);
 g3Static(sc,gLathe([[5.4,-1.2],[5.42,-.02],[5.45,.02],[5.6,.1],[5.95,.16],[6.22,.1],[6.3,0],[6.25,-.16],[6.1,-.24],[5.8,-.3],[5.7,-1.2],[0,-1.2]],120,.6),g3Mat({t:woodTex('mahog'),uv:[0,0,8,1],sh:70,sp:.4,gl:.4}),[0,0,0]);
 g3Static(sc,gLathe([[0,-11],[3.2,-11],[3.3,-10.6],[1.1,-9.8],[.9,-6],[1.3,-2.2],[2.4,-1.4],[0,-1.3]],48),g3Mat({t:woodTex('mahog'),uv:[0,0,4,1],sh:60,sp:.35,gl:.3}),[0,0,0]);
 mkModel(sc);
 const atl=jkAtlas(),back=cardUV(38);sc.c4=jkC4();
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
const jkAtlas=()=>{const c4=jkC4();return g3T('cards2'+(c4?'q':''),()=>g3Tex(cardsCv(c4),{af:true}))};
function jkDeck(sc){const c4=jkC4();if(sc.c4===c4)return;sc.c4=c4;const t=jkAtlas();for(const m of['card','deck'])if(sc.models[m])sc.models[m].parts.forEach(p=>{p.mat.t=t})}
/* what the people at the table do for a reaction: the head nods, shakes or tips back; laughing and a toast move the whole body */
const GEST={nod:{h:{ax:'x',a:.2,f:2,d:1100}},laugh:{h:{ax:'x',a:.1,f:5,d:1300},bd:{b:.09,bf:10,d:1300}},wow:{h:{ax:'x',a:-.32,f:.5,d:1300}},cheer:{h:{ax:'x',a:.16,f:1.5,d:1500},bd:{b:.24,bf:3,d:1500}},shake:{h:{ax:'y',a:.3,f:3,d:1200}}};
function g3Gest(who,kind){const sc=G3D.sc;if(!sc||!sc.people||!G3D.cv||!G3D.cv.isConnected)return;const r=sc.people(who);if(r==null)return;const W=GEST[kind]||GEST.nod;g3Wig(sc,'k:ph'+r,W.h);if(W.bd)g3Wig(sc,'k:pb'+r,W.bd)}
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
 for(const r of[1,2,3]){const id=V.ids[(r+V.base)%4],L0=jkLook(id.n,id.h),key=(id.k||id.n||'p'+r);jkPerson(sc,key,L0);
  const lean=cur===r&&V.win==null?.07:0,g=jkGaze(r,V,rel);
  L.push({k:'pb'+r,m:'pb:'+key,p:[JSP[r][0],0,JSP[r][1]],q:jkSeatQ(r,lean),dur:650,refl:false});
  L.push({k:'ph'+r,m:'ph:'+key,p:jkLocal(r,lean,HPIV),q:qt.mul(jkSeatQ(r,lean),qt.e(g.pitch,g.yaw,0)),dur:600,refl:false});
  const cnt=V.counts[r]||0;for(let i=0;i<cnt;i++){const f=jkFanAt(r,lean,i,cnt),d={k:'h'+r+'-'+i,m:'card',p:f.p,q:f.q,s:.95,uv:cardUV(38),refl:false,dur:500};
   if(deal){d.from={p:dp,q:FACEDN(0),s:.9};d.delay=(i*4+r)*40;d.dur=520}L.push(d)}}
 /* my hand, held in front of me at the bottom of the screen */
 const n=V.hand.length;if(!V.mine||!V.hand.some(cd=>'c'+cardIdx(cd)===sc.csel))sc.csel=null;
 if(n){const tall=asp<.8,hs=tall?.165:.19,dd=2.4,C=jkCam(asp),t=Math.tan(C.fov/2),s=hs*2*t*dd/CDH,cw=CDW*s/(t*asp*dd),room=(2+2*C.sx)*.8,spc=Math.min(cw*.62,(room-cw*1.1)/Math.max(1,n-1)),qf=jkFace(asp);
  V.hand.forEach((cd,i)=>{const ok=V.legal.includes(cd),key='c'+cardIdx(cd),sel=sc.csel===key,nx=C.sx+(i-(n-1)/2)*spc,lift=V.legal.length?(sel?.5:ok?.13:-.03):0,
    ny=-1+hs*1.06-(nx-C.sx)*(nx-C.sx)*.07+lift*hs*2,p=jkScr(asp,nx,ny,dd-i*.004),d={k:key,m:'card',p,q:qt.mul(qf,qt.ax(0,0,1,-(nx-C.sx)*.2)),s,uv:cardUV(cardIdx(cd)),dim:V.legal.length&&!ok?.5:1,pick:V.mine&&ok?{i,k:key}:null,drag:V.mine&&ok,glow:sel?[.12,.09,.03]:null,refl:false,cast:false,dur:420};
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
G3U.joker=sc=>{const G=JK,V={base:0,act:'jcard',hand:[],legal:[],counts:[0,0,0,0],taken:[0,0,0,0],trick:[],win:null,deal:null,dealer:null,cur:null,phase:G.phase,mine:false,trumpCard:null,deckN:0,ids:G.ids.map((x,i)=>i===0?{n:ME.name}:{n:x.n,h:x.h,k:x.n})};
 if(G.hands){const tr=G.phase==='trump'&&G.cur===0;V.hand=tr?G.first3[0]:G.phase==='trump'?[]:G.hands[0];V.legal=G.phase==='play'&&G.cur===0&&G.win==null?G.legal(0):[];V.mine=V.legal.length>0;
  V.counts=[0,1,2,3].map(p=>G.phase==='trump'?(p===0?0:3):G.hands[p].length);V.taken=G.taken||V.taken;V.trick=G.trick;V.win=G.win;V.cur=G.cur;V.dealer=G.dealer;V.deal=G.len+':'+G.h+':'+G.dealer;V.trumpCard=G.trumpCard;V.deckN=36-4*G.n}
 jkScene(sc,V)};
G3U.jko=sc=>{const s=JO.st,me=JO.seat,V={base:me>=0?me:0,act:'jkocard',hand:[],legal:[],counts:[0,0,0,0],taken:[0,0,0,0],trick:[],win:null,deal:null,dealer:null,cur:null,phase:s?s.phase:'wait',mine:false,trumpCard:null,deckN:0,
  ids:[0,1,2,3].map(p=>{const u=JO.t&&JO.t.seats[p];if(u){const pr=typeof PC!=='undefined'&&PC.get(u);return{n:u===ME.id?ME.name:(pr&&pr.name)||'მოთამაშე',h:pr&&pr.hue,k:u}}const b=s&&s.bots&&s.bots[p];return{n:b||'ბოტი',h:b?joBotHue(b):30,k:'b'+(b||p)}})};
 if(s&&s.counts){V.hand=me>=0?JO.hand:[];const myTurn=me>=0&&s.cur===me&&s.win==null&&!JO.wait&&s.phase==='play';V.legal=myTurn?JK.legal.call({hands:{[me]:JO.hand},trick:s.trick,trump:s.trump},me):[];V.mine=V.legal.length>0;
  V.counts=[0,1,2,3].map(r=>s.counts[(r+V.base)%4]||0);V.taken=s.taken||V.taken;V.trick=s.trick||[];V.win=s.win;V.cur=s.cur;V.dealer=s.dealer;V.deal=s.deal;V.trumpCard=s.trumpCard;V.deckN=36-4*s.n}
 jkScene(sc,V)};

/* ---------- domino ---------- */
const DL=1.12,DW=.56,DT=.19,DB=4.75;
G3B.domino=()=>{const sc=g3Scene({cam:{yaw:0,pitch:1.0,pp:.1,fov:.58,tgt:[0,0,.45],box:[[-6.4,0,-6.3],[6.4,.8,6.5]],boxp:[[-5.9,0,-6.1],[5.9,.8,6.4]],dy:0,dp:0,dz:1,my:.96,mxp:1},shR:9,spot:[0,0,8,.6],yawMax:.4,bg:[.03,.022,.02],
  anchors:[['.seat.top',[0,0,-7.7]],['.seat.left',[-5.1,0,-3.35]],['.seat.right',[5.1,0,-3.35]]]});
 g3Table(sc,{y:-.6});mkModel(sc);
 const felt=g3T('dfelt',()=>g3Tex(feltCv({a:'#245a73',b:'#0f2a38',ring:1})));const tw=g3Mat({t:woodTex('walnut'),sh:40,sp:.2,gl:.14});
 g3Static(sc,gBox(13.4,.6,13.4,.25,4,(f,u,v)=>[u*3,v*.4],[1,2,3,4,5]),tw,[0,-.3,0]);
 g3Static(sc,gBox(13.4,.6,13.4,.25,4,(f,u,v)=>[u*3,v*3],[0]),tw,[0,-.3,0]);
 g3Static(sc,gBox(12.2,.02,12.2,.4,3,null,[0]),g3Mat({t:felt,sh:6,sp:.04,gl:0}),[0,-.002,0],null,false);
 const atl=g3T('domino',()=>g3Tex(dominoCv())),iv=g3Mat({c:'#F2EAD8',sh:90,sp:.55,gl:.55});
 const tile=[[gBox(DL,DT,DW,.04,3,null,[0]),g3Mat({t:atl,vary:true,sh:90,sp:.55,gl:.55})],[gBox(DL,DT,DW,.04,3,null,[1]),g3Mat({t:atl,uv:dmUV(28),sh:80,sp:.5,gl:.5})],[gBox(DL,DT,DW,.04,3,null,[2,3,4,5]),iv]];
 g3Model(sc,'tile',tile,[DL/2,DT/2,DW/2]).land=(o,sc)=>{snd('tile');if(o.p[1]<.2)g3Ripple(sc,[o.p[0],.01,o.p[2]],1.3)};
 g3Model(sc,'ghost',[[gBox(DL,DT,DW,.04,3),g3Mat({c:'#F4BC4C',unlit:true,a:1})]],[DL/2,DT,DW/2]);
 sc.hoverAll=true;
 sc.tap=ray=>{const o=g3HitObj(sc,ray,o=>o.pick);if(!o)return;if(o.pick.e)g3Act('dmend',{e:o.pick.e});else if(o.pick.i!=null)g3Act('dmt',{i:String(o.pick.i)})};
 sc.drag={y:.4,lift:.4,drop:(o,p)=>{if(!p||p[2]>4.3)return;const G=DM,i=o.pick.i,pl=G.places(G.hands[0][i]);if(!pl.length)return;if(pl.length===1){g3Act('dmt',{i:String(i)});return}
  const{slots}=dmLayout(G),e=pl.slice().sort((a,b)=>Math.hypot(slots[a].x-p[0],slots[a].z-p[2])-Math.hypot(slots[b].x-p[0],slots[b].z-p[2]))[0];G.sel=i;g3Act('dmend',{e})}};
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
const DRACK={0:{c:[0,.52,5.25],yaw:0,dir:[1,0,0],sp:.7,tilt:.5},1:{c:[-5.45,.52,.1],yaw:-Math.PI/2,dir:[0,0,1],sp:.62,tilt:.22},2:{c:[0,.52,-5.3],yaw:Math.PI,dir:[-1,0,0],sp:.62,tilt:.22},3:{c:[5.45,.52,.1],yaw:Math.PI/2,dir:[0,0,-1],sp:.62,tilt:.22}};
const dRack=(s,i,n)=>{const r=DRACK[s];return v3.add(r.c,v3.mul(r.dir,(i-(n-1)/2)*r.sp))};
G3U.domino=sc=>{const G=DM,L=[],M=[],{out,slots}=dmLayout(G),mine=G.phase==='play'&&G.cur===0,ok=new Set(mine?G.moves(0).map(m=>m.i):[]);
 const deal=G.round!==sc.round;if(deal)sc.round=G.round;
 const flat=(t,x,z,yaw)=>({p:[x,DT/2,z],q:qt.ax(0,1,0,yaw),uv:dmUV(dmIdx(t[0],t[1]))});
 out.forEach(o=>{const f=flat(o.t,o.x,o.z,o.yaw),key='t'+dmIdx(o.t[0],o.t[1]),d=Object.assign({k:key,m:'tile'},f);
  if(!sc.objs.has('k:'+key)){const by=G.last&&G.last.t&&dmIdx(G.last.t[0],G.last.t[1])===dmIdx(o.t[0],o.t[1])?G.last.p:null;if(by!=null&&by!==0){const n=G.hands[by].length;d.from={p:dRack(by,n,n+1),q:DSTAND(DRACK[by].yaw,DRACK[by].tilt)};d.arc=.9;d.dur=560}}
  L.push(d);M.push({m:'mk',p:[o.x,.003,o.z],s:[1.35,1,1.35],uv:MK.blob,c:[0,0,0],a:.22,q:qt.ax(0,1,0,o.yaw)})});
 const n=G.hands[0].length;G.hands[0].forEach((t,i)=>{const lift=G.sel===i?.32:ok.has(i)?.12:0,p=v3.add(dRack(0,i,n),[0,lift,0]),d={k:'t'+dmIdx(t[0],t[1]),m:'tile',p,q:DSTAND(0,DRACK[0].tilt),uv:dmUV(dmIdx(t[0],t[1])),dim:mine&&!ok.has(i)?.6:1,glow:G.sel===i?[.12,.09,.02]:null,pick:mine?{i}:null,drag:mine&&ok.has(i)};
  if(deal){d.from={p:[0,1.2,0],q:DSTAND(0,0),a:0};d.delay=i*70;d.dur=520}L.push(d)});
 for(const s of[1,2,3]){const cnt=G.hands[s].length;for(let i=0;i<cnt;i++){const d={k:'h'+s+'-'+i,m:'tile',p:dRack(s,i,cnt),q:DSTAND(DRACK[s].yaw,DRACK[s].tilt),uv:dmUV(28)};if(deal){d.from={p:[0,1.2,0],q:DSTAND(0,0),a:0};d.delay=(n+i*3+s)*45;d.dur=520}L.push(d)}}
 if(mine&&G.sel!=null){for(const e of G.places(G.hands[0][G.sel]))if(slots[e]){const g=slots[e];L.push({k:'g'+e,m:'ghost',p:[g.x,DT/2,g.z],q:qt.ax(0,1,0,g.yaw),a:.5,cast:false,pick:{e},now:1})}}
 sc.marks=M;g3Set(sc,L,{gone:o=>o.id.startsWith('k:h')?{a:0,dur:180}:o.m==='ghost'?{a:0,dur:120}:{p:[o.p[0]*.3,1,o.p[2]*.3],a:0,dur:500}})};
