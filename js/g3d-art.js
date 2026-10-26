/* art for the 3D boards, all drawn in code: wood with real grain, felt, inlaid boards, cards, dice, domino tiles and the pieces */
const cvs=(w,h)=>{const c=document.createElement('canvas');c.width=w;c.height=h;return c};
function rng(seed){let s=(seed>>>0)||1;return()=>{s^=s<<13;s^=s>>>17;s^=s<<5;return(s>>>0)/4294967296}}
function noiseCv(w,h,R,lo=0,hi=255){const n=cvs(w,h),x=n.getContext('2d'),id=x.createImageData(w,h);for(let i=0;i<w*h;i++){const v=lo+R()*(hi-lo);id.data[i*4]=id.data[i*4+1]=id.data[i*4+2]=v;id.data[i*4+3]=255}x.putImageData(id,0,0);return n}
/* wood: a base colour, a slow figure, two layers of bent grain lines and pores */
function woodCv(w,h,o){const R=rng(o.seed||7),c=cvs(w,h),x=c.getContext('2d');x.fillStyle=o.base;x.fillRect(0,0,w,h);x.imageSmoothingEnabled=true;try{x.imageSmoothingQuality='high'}catch(e){}
 x.globalCompositeOperation='multiply';x.globalAlpha=o.fig??.32;x.drawImage(noiseCv(7,5,R,120,255),0,0,w,h);
 const strips=96,sw=w/strips;
 for(const[rows,al,lo]of[[o.lines||150,o.g1??.5,110],[(o.lines||150)*3.4,o.g2??.3,150]]){const n=noiseCv(1,Math.round(rows),R,lo,255),amp=h*(o.wave??.018),ph=R()*6,fr=1+R()*1.6;x.globalAlpha=al;
  for(let s=0;s<=strips;s++){const X=s*sw,dy=Math.sin(X/w*Math.PI*2*fr+ph)*amp+Math.sin(X/w*11.3+ph*1.7)*amp*.35;x.drawImage(n,0,0,1,n.height,X,dy-amp*1.6,sw+1,h+amp*3.2)}}
 if(o.tint){x.globalCompositeOperation='overlay';x.globalAlpha=.35;x.fillStyle=o.tint;x.fillRect(0,0,w,h)}
 x.globalCompositeOperation='source-over';x.globalAlpha=1;x.fillStyle=o.pore||'rgba(30,14,4,.22)';for(let i=0;i<w*h/(o.pores||700);i++)x.fillRect(R()*w,R()*h,1.5+R()*5,1);
 if(o.dir==='v'){const r=cvs(h,w),rx=r.getContext('2d');rx.translate(h,0);rx.rotate(Math.PI/2);rx.drawImage(c,0,0);return r}return c}
const WOOD={
 walnut:{base:'#7a5034',seed:11,lines:120,fig:.35},
 table:{base:'#4a2f1f',seed:21,lines:80,fig:.45,wave:.035,g1:.42,g2:.25},
 maple:{base:'#f2dcb4',seed:3,lines:170,g1:.35,g2:.22,fig:.22,pore:'rgba(90,50,20,.12)'},
 wenge:{base:'#6a4027',seed:5,lines:160,g1:.55,g2:.32,fig:.3},
 rose:{base:'#6e3420',seed:9,lines:140,fig:.38,tint:'#7a1c10'},
 frame:{base:'#5a301b',seed:13,lines:130,fig:.4},
 birch:{base:'#f4e2c0',seed:17,lines:200,g1:.28,g2:.18,fig:.2,pore:'rgba(90,60,30,.1)'},
 mahog:{base:'#8a3f26',seed:19,lines:150,g1:.5,g2:.3,fig:.32},
 oak:{base:'#b98a5a',seed:23,lines:130,fig:.3},
 box:{base:'#EAD3A8',seed:29,lines:110,g1:.2,g2:.14,fig:.16,pore:'rgba(120,80,40,.07)',wave:.04},
 ebony:{base:'#3a2a24',seed:31,lines:110,g1:.4,g2:.25,fig:.25,pore:'rgba(0,0,0,.2)',wave:.04}};
const G3T={};
const g3T=(k,f)=>G3T[k]||(G3T[k]=f());
const woodTex=k=>g3T('w:'+k,()=>g3Tex(woodCv(1024,1024,WOOD[k]),{rep:'m'}));
/* a square board: frame, 64 squares cut from two woods with the grain turned now and then, an inlay line and the letters */
function boardCv(o){const S=1024,c=cvs(S,S),x=c.getContext('2d'),B=S*o.border/o.size,q=(S-2*B)/8;x.drawImage(woodCv(S,S,WOOD[o.frame]),0,0);
 const Lw=woodCv(512,512,WOOD[o.light]),Dw=woodCv(512,512,WOOD[o.dark]);
 for(let r=0;r<8;r++)for(let f=0;f<8;f++){const dk=(r+f)%2===1,src=dk?Dw:Lw,X=B+f*q,Y=B+r*q,ox=(r*37+f*91)%380,oy=(r*53+f*17)%380;x.save();x.beginPath();x.rect(X,Y,q,q);x.clip();
  if((r+f*3)%4===0){x.translate(X+q/2,Y+q/2);x.rotate(Math.PI/2);x.drawImage(src,ox,oy,q,q,-q/2,-q/2,q,q)}else x.drawImage(src,ox,oy,q,q,X,Y,q,q);x.restore()}
 x.strokeStyle='rgba(20,8,2,.45)';x.lineWidth=1.4;x.beginPath();for(let i=0;i<=8;i++){x.moveTo(B+i*q,B);x.lineTo(B+i*q,B+8*q);x.moveTo(B,B+i*q);x.lineTo(B+8*q,B+i*q)}x.stroke();
 x.strokeStyle=o.inlay;x.lineWidth=S*.007;const g=S*.014;x.strokeRect(B-g,B-g,8*q+2*g,8*q+2*g);x.lineWidth=S*.0025;x.strokeRect(B-g*2.1,B-g*2.1,8*q+4.2*g,8*q+4.2*g);
 if(o.coords){x.fillStyle=o.ink;x.font=`600 ${Math.round(B*.4)}px Georgia,"Noto Serif Georgian",serif`;x.textAlign='center';x.textBaseline='middle';
  const t=(s,X,Y,rot)=>{x.save();x.translate(X,Y);x.rotate(rot);x.fillText(s,0,0);x.restore()};
  for(let i=0;i<8;i++){t('abcdefgh'[i],B+q*(i+.5),S-B*.52,0);t('abcdefgh'[i],B+q*(i+.5),B*.52,Math.PI);t(String(8-i),B*.52,B+q*(i+.5),0);t(String(8-i),S-B*.52,B+q*(i+.5),Math.PI)}}
 return c}
/* felt for the card table, with a gold ring near the edge */
function feltCv(o){const S=1024,c=cvs(S,S),x=c.getContext('2d'),R=rng(41);const g=x.createRadialGradient(S/2,S/2,S*.05,S/2,S/2,S*.52);g.addColorStop(0,o.a);g.addColorStop(1,o.b);x.fillStyle=g;x.fillRect(0,0,S,S);
 x.globalCompositeOperation='overlay';x.globalAlpha=.5;x.drawImage(noiseCv(512,512,R,90,170),0,0,S,S);x.globalAlpha=.25;x.drawImage(noiseCv(1024,1024,R,60,200),0,0);x.globalCompositeOperation='source-over';x.globalAlpha=1;
 if(o.ring){x.strokeStyle='rgba(222,184,96,.55)';x.lineWidth=5;x.beginPath();x.arc(S/2,S/2,S*.455,0,Math.PI*2);x.stroke();x.lineWidth=2;x.beginPath();x.arc(S/2,S/2,S*.44,0,Math.PI*2);x.stroke();
  x.fillStyle='rgba(222,184,96,.5)';for(let i=0;i<48;i++){const a=i/48*Math.PI*2;x.save();x.translate(S/2+Math.cos(a)*S*.4475,S/2+Math.sin(a)*S*.4475);x.rotate(a);x.fillRect(-5,-5,10,10);x.restore()}}
 return c}
/* the nardi board top: frame wood, a light field with inlaid points in two colours, the bar and the tray */
const NB={x0:-7,x1:8.6,z0:-6.1,z1:6.1};
function nardiCv(){const S=2048,c=cvs(S,S),x=c.getContext('2d'),sx=S/(NB.x1-NB.x0),sz=S/(NB.z1-NB.z0),X=v=>(v-NB.x0)*sx,Z=v=>(v-NB.z0)*sz;
 x.drawImage(woodCv(S,S,WOOD.frame),0,0);
 const fw=woodCv(1024,1024,Object.assign({},WOOD.walnut,{base:'#b27f52',seed:51,lines:110,fig:.25}));x.drawImage(fw,X(-6.5),Z(-5.6),13*sx,11.2*sz);
 x.save();x.globalAlpha=.2;const sh=x.createLinearGradient(0,Z(-5.6),0,Z(5.6));sh.addColorStop(0,'#000');sh.addColorStop(.5,'rgba(0,0,0,0)');sh.addColorStop(1,'#000');x.fillStyle=sh;x.fillRect(X(-6.5),Z(-5.6),13*sx,11.2*sz);x.restore();
 const Lw=woodCv(512,512,WOOD.maple),Dw=woodCv(512,512,WOOD.rose);
 for(let col=0;col<13;col++){if(col===6)continue;for(const top of[1,0]){const cx=col-6,di=top?(col<6?12+col:18+col-7):(col<6?11-col:5-(col-7)),src=di%2?Dw:Lw;
   const y0=top?-5.55:5.55,y1=top?-.75:.75;x.save();x.beginPath();x.moveTo(X(cx-.46),Z(y0));x.lineTo(X(cx+.46),Z(y0));x.lineTo(X(cx),Z(y1));x.closePath();x.clip();x.drawImage(src,(col*61)%300,(top*170+col*23)%300,180,420,X(cx-.5),Z(Math.min(y0,y1)),sx,4.8*sz);x.restore();
   x.strokeStyle='rgba(214,170,88,.85)';x.lineWidth=3;x.beginPath();x.moveTo(X(cx-.46),Z(y0));x.lineTo(X(cx),Z(y1));x.lineTo(X(cx+.46),Z(y0));x.stroke()}}
 x.fillStyle='#173d2b';x.fillRect(X(6.95),Z(-5.6),1.2*sx,11.2*sz);x.globalCompositeOperation='overlay';x.globalAlpha=.4;x.drawImage(noiseCv(128,512,rng(5),80,180),X(6.95),Z(-5.6),1.2*sx,11.2*sz);
 x.globalCompositeOperation='source-over';x.globalAlpha=1;return c}
/* suits drawn as shapes, so they look the same on every phone */
function suitPath(x,s,cx,cy,k){x.save();x.translate(cx,cy);x.scale(k,k);x.beginPath();
 if(s==='h'){x.moveTo(0,.46);x.bezierCurveTo(-.18,.3,-.52,.08,-.5,-.17);x.bezierCurveTo(-.48,-.46,-.12,-.52,0,-.26);x.bezierCurveTo(.12,-.52,.48,-.46,.5,-.17);x.bezierCurveTo(.52,.08,.18,.3,0,.46)}
 else if(s==='d'){x.moveTo(0,-.52);x.quadraticCurveTo(.18,-.2,.4,0);x.quadraticCurveTo(.18,.2,0,.52);x.quadraticCurveTo(-.18,.2,-.4,0);x.quadraticCurveTo(-.18,-.2,0,-.52)}
 else if(s==='s'){x.moveTo(0,-.52);x.bezierCurveTo(.16,-.32,.52,-.12,.5,.12);x.bezierCurveTo(.48,.36,.16,.4,.05,.22);x.quadraticCurveTo(.08,.42,.16,.52);x.lineTo(-.16,.52);x.quadraticCurveTo(-.08,.42,-.05,.22);x.bezierCurveTo(-.16,.4,-.48,.36,-.5,.12);x.bezierCurveTo(-.52,-.12,-.16,-.32,0,-.52)}
 else{for(const[a,b]of[[0,-.24],[-.25,.08],[.25,.08]]){x.moveTo(a+.215,b);x.arc(a,b,.215,0,Math.PI*2)}x.moveTo(-.05,.05);x.quadraticCurveTo(-.06,.38,-.17,.52);x.lineTo(.17,.52);x.quadraticCurveTo(.06,.38,.05,.05);x.closePath()}
 x.fill();x.restore()}
/* the card atlas: 8 columns by 5 rows of 256x360, faces by suit and rank, two jokers and the back */
const CW=256,CH_=360,CATL=2048;
const cardIdx=c=>c.j?35+c.j:SUITS.indexOf(c.s)*9+c.r-6;
const cardUV=i=>[(i%8)*CW/CATL,Math.floor(i/8)*CH_/CATL,CW/CATL,CH_/CATL];
function rrect(x,X,Y,w,h,r){x.beginPath();x.moveTo(X+r,Y);x.arcTo(X+w,Y,X+w,Y+h,r);x.arcTo(X+w,Y+h,X,Y+h,r);x.arcTo(X,Y+h,X,Y,r);x.arcTo(X,Y,X+w,Y,r);x.closePath()}
function cardsCv(c4){const c=cvs(CATL,CATL),x=c.getContext('2d'),F='"Noto Serif Georgian",Georgia,"Times New Roman",serif',FS='"Noto Sans Georgian","DejaVu Sans",system-ui,sans-serif';
 const face=(i,draw)=>{const X=(i%8)*CW,Y=Math.floor(i/8)*CH_;x.save();x.translate(X,Y);rrect(x,3,3,CW-6,CH_-6,24);x.fillStyle='#FFFDF8';x.fill();x.strokeStyle='rgba(60,40,20,.28)';x.lineWidth=2.5;x.stroke();x.clip();draw();x.restore()};
 /* big corner indices (rank over suit), as on cards made to be read across a table; pips sit in a narrower middle */
 const PIPL={6:[[.25,.22],[.75,.22],[.25,.5],[.75,.5],[.25,.78],[.75,.78]],7:[[.25,.22],[.75,.22],[.5,.36],[.25,.5],[.75,.5],[.25,.78],[.75,.78]],8:[[.25,.22],[.75,.22],[.5,.36],[.25,.5],[.75,.5],[.5,.64],[.25,.78],[.75,.78]],
  9:[[.25,.2],[.75,.2],[.25,.4],[.75,.4],[.5,.5],[.25,.6],[.75,.6],[.25,.8],[.75,.8]],10:[[.25,.2],[.75,.2],[.5,.3],[.25,.4],[.75,.4],[.25,.6],[.75,.6],[.5,.7],[.25,.8],[.75,.8]]};
 for(const s of SUITS)for(let r=6;r<=14;r++){if(r===6&&(s==='s'||s==='c'))continue;const col=c4?SC4[s]:isRed(s)?'#CE1430':'#17110E',t=rkTxt(r);
  face(SUITS.indexOf(s)*9+r-6,()=>{x.fillStyle=col;x.textAlign='center';x.textBaseline='alphabetic';
   const corner=()=>{x.font=`800 ${t==='10'?70:86}px ${FS}`;if(t==='10'){x.save();x.translate(46,88);x.scale(.78,1);x.fillText(t,0,0);x.restore()}else x.fillText(t,46,88);suitPath(x,s,46,134,58)};
   corner();x.save();x.translate(CW,CH_);x.rotate(Math.PI);corner();x.restore();
   if(r<=10){for(const[u,v]of PIPL[r]){const px=80+u*96,py=46+v*268;x.save();x.translate(px,py);if(v>.55)x.rotate(Math.PI);suitPath(x,s,0,0,31);x.restore()}}
   else if(r===14){suitPath(x,s,CW/2,CH_/2,104);x.save();x.globalAlpha=.33;x.strokeStyle=col;x.lineWidth=3;x.beginPath();x.arc(CW/2,CH_/2,68,0,Math.PI*2);x.stroke();x.restore()}
   else{const g=x.createLinearGradient(0,60,0,300);g.addColorStop(0,'#FBEFD2');g.addColorStop(1,'#F0D9A6');x.fillStyle=g;rrect(x,86,46,84,268,10);x.fill();x.strokeStyle=col;x.lineWidth=3;x.stroke();x.lineWidth=1.2;rrect(x,92,52,72,256,6);x.stroke();
    x.fillStyle=col;x.font=`700 80px ${F}`;x.fillText(t,128,CH_/2+18);suitPath(x,s,128,CH_/2+74,28);suitPath(x,s,128,CH_/2-78,28)}})}
 for(const j of[1,2])face(35+j,()=>{const col=j===1?'#CE1430':'#1F2F6B',g=x.createRadialGradient(CW/2,CH_/2,10,CW/2,CH_/2,150);g.addColorStop(0,j===1?'#FFE3EA':'#E2E8FF');g.addColorStop(1,'#FFFDF8');x.fillStyle=g;x.fillRect(0,0,CW,CH_);
  x.fillStyle=col;x.save();x.translate(CW/2,CH_/2-24);x.beginPath();for(let k=0;k<10;k++){const a=-Math.PI/2+k*Math.PI/5,rr=k%2?28:68;x.lineTo(Math.cos(a)*rr,Math.sin(a)*rr)}x.closePath();x.fill();x.restore();
  x.font=`700 34px ${F}`;x.textAlign='center';x.fillText('ჯოკერი',CW/2,CH_/2+76);
  const corner=()=>{x.save();x.translate(46,64);x.beginPath();for(let k=0;k<10;k++){const a=-Math.PI/2+k*Math.PI/5,rr=k%2?15:36;x.lineTo(Math.cos(a)*rr,Math.sin(a)*rr)}x.closePath();x.fill();x.restore()};
  corner();x.save();x.translate(CW,CH_);x.rotate(Math.PI);corner();x.restore()});
 face(38,()=>{x.fillStyle='#7A1430';x.fillRect(0,0,CW,CH_);x.strokeStyle='rgba(232,190,100,.9)';x.lineWidth=4;rrect(x,16,16,CW-32,CH_-32,14);x.stroke();
  x.save();rrect(x,24,24,CW-48,CH_-48,10);x.clip();x.strokeStyle='rgba(232,190,100,.28)';x.lineWidth=2;for(let k=-CH_;k<CW+CH_;k+=22){x.beginPath();x.moveTo(k,0);x.lineTo(k+CH_,CH_);x.stroke();x.beginPath();x.moveTo(k+CH_,0);x.lineTo(k,CH_);x.stroke()}x.restore();
  x.fillStyle='#7A1430';x.beginPath();x.arc(CW/2,CH_/2,62,0,Math.PI*2);x.fill();x.strokeStyle='rgba(232,190,100,.95)';x.lineWidth=4;x.stroke();
  x.fillStyle='rgba(232,190,100,.95)';x.save();x.translate(CW/2,CH_/2);for(let k=0;k<8;k++){x.rotate(Math.PI/4);x.beginPath();x.moveTo(0,-46);x.quadraticCurveTo(14,-14,0,0);x.quadraticCurveTo(-14,-14,0,-46);x.fill()}x.restore()});
 return c}
/* dice faces: ivory with carved pips, the one in red */
function diceCv(){const c=cvs(512,256),x=c.getContext('2d');for(let v=1;v<=6;v++){const X=((v-1)%4)*128,Y=Math.floor((v-1)/4)*128;x.fillStyle='#F6EFE0';x.fillRect(X,Y,128,128);
  const g=x.createRadialGradient(X+64,Y+64,30,X+64,Y+64,90);g.addColorStop(0,'rgba(255,255,255,.0)');g.addColorStop(1,'rgba(150,120,80,.18)');x.fillStyle=g;x.fillRect(X,Y,128,128);
  for(const k of PIPS[v]){const px=X+30+(k%3)*34,py=Y+30+Math.floor(k/3)*34,r=v===1?17:11.5,gg=x.createRadialGradient(px-2,py-3,1,px,py,r);gg.addColorStop(0,v===1?'#7a0a1c':'#000');gg.addColorStop(1,v===1?'#C8142F':'#2b211c');x.fillStyle=gg;x.beginPath();x.arc(px,py,r,0,Math.PI*2);x.fill()}}
 return c}
/* domino faces: 28 tiles, 256x128 each, ivory with black pips, a carved line and a brass pin */
const dmIdx=(a,b)=>{if(a>b)[a,b]=[b,a];let k=0;for(let i=0;i<a;i++)k+=7-i;return k+b-a};
const dmUV=i=>[(i%4)*.25,Math.floor(i/4)*.125,.25,.125];
function dominoCv(){const c=cvs(1024,1024),x=c.getContext('2d');
 for(let a=0;a<=6;a++)for(let b=a;b<=6;b++){const i=dmIdx(a,b),X=(i%4)*256,Y=Math.floor(i/4)*128;x.fillStyle='#F7F0E1';x.fillRect(X,Y,256,128);
  const g=x.createLinearGradient(0,Y,0,Y+128);g.addColorStop(0,'rgba(255,255,255,.35)');g.addColorStop(1,'rgba(120,90,50,.12)');x.fillStyle=g;x.fillRect(X,Y,256,128);
  x.fillStyle='rgba(70,50,30,.55)';x.fillRect(X+126,Y+16,4,96);
  const half=(v,ox)=>{for(const k of(v?PIPS[v]:[])){const px=X+ox+30+(k%3)*34,py=Y+30+Math.floor(k/3)*34,gg=x.createRadialGradient(px-2,py-3,1,px,py,11);gg.addColorStop(0,'#000');gg.addColorStop(1,'#2a201b');x.fillStyle=gg;x.beginPath();x.arc(px,py,10.5,0,Math.PI*2);x.fill()}};half(a,0);half(b,128);
  const pg=x.createRadialGradient(X+126,Y+61,1,X+128,Y+64,8);pg.addColorStop(0,'#fff3c4');pg.addColorStop(.5,'#d9a640');pg.addColorStop(1,'#8a5f1a');x.fillStyle=pg;x.beginPath();x.arc(X+128,Y+64,7.5,0,Math.PI*2);x.fill()}
 const X=0,Y=7*128+0;x.fillStyle='#F2EAD8';x.fillRect(X,Y,256,128);x.strokeStyle='rgba(160,120,60,.45)';x.lineWidth=3;rrect(x,X+18,Y+18,220,92,12);x.stroke();x.fillStyle='rgba(176,130,60,.55)';
 x.save();x.translate(X+128,Y+64);for(let k=0;k<4;k++){x.rotate(Math.PI/2);x.beginPath();x.moveTo(0,-26);x.quadraticCurveTo(8,-8,0,0);x.quadraticCurveTo(-8,-8,0,-26);x.fill()}x.restore();return c}
/* marks: a glowing square, a soft dot, a ring and a soft shadow, all white so any colour can be laid on top */
function marksCv(){const c=cvs(512,512),x=c.getContext('2d');
 x.save();x.shadowColor='#fff';x.shadowBlur=22;x.strokeStyle='#fff';x.lineWidth=16;rrect(x,30,30,196,196,22);x.stroke();x.restore();
 let g=x.createRadialGradient(384,128,4,384,128,110);g.addColorStop(0,'rgba(255,255,255,1)');g.addColorStop(.55,'rgba(255,255,255,.95)');g.addColorStop(.7,'rgba(255,255,255,.25)');g.addColorStop(1,'rgba(255,255,255,0)');x.fillStyle=g;x.fillRect(256,0,256,256);
 x.save();x.shadowColor='#fff';x.shadowBlur=14;x.strokeStyle='#fff';x.lineWidth=14;x.beginPath();x.arc(128,384,96,0,Math.PI*2);x.stroke();x.restore();
 g=x.createRadialGradient(384,384,10,384,384,124);g.addColorStop(0,'rgba(255,255,255,.95)');g.addColorStop(.5,'rgba(255,255,255,.5)');g.addColorStop(1,'rgba(255,255,255,0)');x.fillStyle=g;x.fillRect(256,256,256,256);return c}
const MK={sq:[0,0,.5,.5],dot:[.5,0,.5,.5],ring:[0,.5,.5,.5],blob:[.5,.5,.5,.5]};
/* a little text label lying on the table (the joker's call) */
function labelTex(txt){return g3T('l:'+txt,()=>{const c=cvs(512,128),x=c.getContext('2d');rrect(x,6,14,500,100,50);x.fillStyle='rgba(20,12,8,.72)';x.fill();x.strokeStyle='rgba(232,190,100,.9)';x.lineWidth=4;x.stroke();
 x.fillStyle='#F5E7C8';x.font='700 54px "Noto Sans Georgian",system-ui,sans-serif';x.textAlign='center';x.textBaseline='middle';x.fillText(txt,256,66);return g3Tex(c)})}

/* ---------- models ---------- */
const arc=(cx,cy,r,a0,a1,n)=>Array.from({length:n+1},(_,i)=>{const a=a0+(a1-a0)*i/n;return[cx+Math.cos(a)*r,cy+Math.sin(a)*r]});
const BASE=R=>[[0,0],[R,0],[R,.04],[R*.96,.058],[R*.9,.07],[R*.91,.088],[R*.86,.1],[R*.76,.125]];
const KR=1.07,KY=1.32,PL=(prof,sg)=>gLathe(prof.map(([r,y])=>[r*KR,y*KY]),sg);
function pieceGeo(t){const SG=44,gLathe=PL;
 if(t==='p')return gLathe([...BASE(.32),[.2,.15],[.15,.2],[.12,.26],[.105,.31],[.165,.325],[.175,.343],[.12,.36],[.095,.375],...arc(0,.465,.118,-1.0,Math.PI/2,12)],SG);
 if(t==='r'){const body=gLathe([...BASE(.36),[.24,.16],[.21,.3],[.2,.43],[.25,.45],[.26,.48],[.225,.5],[.235,.52],[.26,.55],[.26,.635],[.19,.635],[.19,.6],[0,.6]],SG);
  const ms=[];for(let k=0;k<6;k++){const a=k/6*Math.PI*2+Math.PI/6;ms.push(gXf(gBox(.13*KR,.1*KY,.075*KR,.012,2),[Math.cos(a)*.215*KR,.68*KY,Math.sin(a)*.215*KR],qt.ax(0,1,0,-a+Math.PI/2)))}return gMerge(body,...ms)}
 if(t==='b')return gLathe([...BASE(.35),[.22,.16],[.16,.3],[.13,.43],[.19,.445],[.2,.47],[.14,.49],[.15,.505],[.12,.52],[.15,.56],[.168,.62],[.16,.68],[.13,.74],[.08,.785],[.035,.805],[.045,.815],[.052,.84],[.04,.865],[0,.875]],SG);
 if(t==='q'){const body=gLathe([...BASE(.38),[.25,.16],[.17,.32],[.135,.5],[.2,.515],[.215,.545],[.15,.565],[.14,.6],[.19,.72],[.225,.8],[.205,.82],[.14,.8],[.105,.81],[.1,.85],[.06,.885],...arc(0,.93,.05,-1.1,Math.PI/2,8)],SG);
  const bs=[];for(let k=0;k<9;k++){const a=k/9*Math.PI*2;bs.push(gXf(PL(arc(0,0,.034,-Math.PI/2,Math.PI/2,8).map(([r,y])=>[r,y*KR/KY]),16),[Math.cos(a)*.21*KR,.835*KY,Math.sin(a)*.21*KR],qt.id()))}return gMerge(body,...bs)}
 if(t==='k'){const body=gLathe([...BASE(.38),[.25,.16],[.18,.36],[.145,.56],[.21,.575],[.225,.605],[.16,.625],[.15,.66],[.2,.78],[.21,.84],[.15,.86],[.1,.875],[.085,.92],[.05,.95],[.045,.965],[0,.97]],SG);
  return gMerge(body,gXf(gBox(.06,.2*KY,.06,.012,2),[0,1.06*KY,0],qt.id()),gXf(gBox(.17,.06,.06,.012,2),[0,1.09*KY,0],qt.id()))}
 if(t==='n'){const base=gLathe([...BASE(.36),[.26,.15],[.245,.18],[.255,.205],[.22,.225],[0,.225]],SG);
  const head=[[-.21,0],[.21,0],[.22,.06],[.19,.13],[.165,.2],[.17,.26],[.21,.31],[.27,.345],[.325,.37],[.355,.405],[.355,.44],[.33,.47],[.28,.5],[.2,.54],[.15,.58],[.12,.62],[.11,.675],[.07,.64],[.03,.665],[0,.62],[-.08,.57],[-.14,.5],[-.19,.41],[-.215,.31],[-.23,.2],[-.235,.1]];
  const g=gExtrude(head.map(([x,y])=>[x*KR,y*KY]),.3,.04);for(let k=0;k<g.p.length;k+=3){const x=g.p[k],f=1-.3*clamp((x+.1)/.5,0,1);g.p[k+2]*=f}gXf(g,[0,.2*KY,0],qt.id());return gMerge(base,g)}}
function manGeo(h=.13,r=.4){return gLathe([[0,0],[r*.95,0],[r,h*.12],[r,h*.3],[r*.975,h*.36],[r,h*.44],[r*.975,h*.52],[r,h*.6],[r*.975,h*.68],[r,h*.76],[r,h*.88],[r*.95,h],[r*.78,h],[r*.72,h*.93],[r*.64,h*.9],[r*.3,h*.92],[0,h*.94]],40,.7)}
function checkerGeo(){const r=.44,h=.16;return gLathe([[0,0],[r*.94,0],[r,h*.18],[r,h*.82],[r*.94,h],[r*.74,h],[r*.7,h*.86],[r*.64,h*.86],[r*.6,h*.97],[0,h*.97]],44,.7)}
/* a die: the face that shows v points up; +y 1, -y 6, +z 2, -z 5, +x 3, -x 4 */
const DFACE=[1,6,2,5,3,4];
function dieGeo(s){return gBox(s,s,s,s*.15,5,(fi,u,v)=>{const k=DFACE[fi]-1;return[((k%4)+.04+u*.92)/4,(Math.floor(k/4)+.04+v*.92)/2]})}
const dieUp=v=>({1:qt.id(),6:qt.ax(1,0,0,Math.PI),2:qt.ax(1,0,0,-Math.PI/2),5:qt.ax(1,0,0,Math.PI/2),3:qt.ax(0,0,1,Math.PI/2),4:qt.ax(0,0,1,-Math.PI/2)})[v];

/* ---------- people at the table ----------
   a seated player made of soft turned shapes: the body (torso, arms, hands and the chair behind) and the head, which turns on its own.
   local frame: +z looks at the middle of the table, y=0 is the table top. the head is built around its pivot at the top of the neck */
function gScale3(g,sx,sy,sz){for(let k=0;k<g.p.length;k+=3){g.p[k]*=sx;g.p[k+1]*=sy;g.p[k+2]*=sz;const n=v3.norm([g.n[k]/sx,g.n[k+1]/sy,g.n[k+2]/sz]);g.n[k]=n[0];g.n[k+1]=n[1];g.n[k+2]=n[2]}return g}
const qFromY=d=>{const n=v3.norm(d);if(n[1]>.9999)return qt.id();if(n[1]<-.9999)return qt.ax(1,0,0,Math.PI);const a=v3.cross([0,1,0],n);return qt.ax(a[0],a[1],a[2],Math.acos(n[1]))};
const semiP=(N=14,a0=-Math.PI/2,a1=Math.PI/2)=>Array.from({length:N+1},(_,i)=>{const a=a0+(a1-a0)*i/N;return[Math.abs(Math.cos(a))<1e-6?0:Math.cos(a),Math.sin(a)]});
function gEll(rx,ry,rz,p=[0,0,0],q=null,sg=26){return gXf(gScale3(gLathe(semiP(),sg),rx,ry,rz),p,q||qt.id())}
function gCap(a,b,r0,r1,sg=18){const d=v3.sub(b,a),L=v3.len(d),pr=[];for(let i=0;i<=5;i++){const t=-Math.PI/2+Math.PI/2*i/5;pr.push([i?Math.cos(t)*r0:0,Math.sin(t)*r0])}
 for(let i=0;i<=5;i++){const t=Math.PI/2*i/5;pr.push([i<5?Math.cos(t)*r1:0,L+Math.sin(t)*r1])}return gXf(gLathe(pr,sg),a,qFromY(d))}
const HEADP=[[0,-1.22],[.42,-1.16],[.7,-.98],[.88,-.7],[.97,-.36],[1.01,0],[1,.34],[.93,.66],[.78,.93],[.55,1.12],[.28,1.21],[0,1.24]];
const TORSOP=[[0,-2.8],[1.3,-2.8],[1.38,-1.6],[1.45,-.5],[1.55,.6],[1.68,1.5],[1.72,2.05],[1.55,2.45],[1.15,2.75],[.62,2.92],[0,2.96]];
const HPIV=[0,3.4,.1],HC=[0,1.05,.08];
/* the head's radius at a height (head-local, from the outline) */
function headR(y){const P=HEADP;if(y<=P[0][1])return 0;for(let i=1;i<P.length;i++)if(y<=P[i][1]){const k=(y-P[i-1][1])/(P[i][1]-P[i-1][1]);return P[i-1][0]+(P[i][0]-P[i-1][0])*k}return 0}
/* where a height on the head lands in the face picture (the lathe maps the outline length to v) */
function headV(y){const P=HEADP,len=[0];for(let i=1;i<P.length;i++)len.push(len[i-1]+Math.hypot(P[i][0]-P[i-1][0],P[i][1]-P[i-1][1]));const L=len[len.length-1];
 for(let i=1;i<P.length;i++)if(y<=P[i][1]){const k=(y-P[i-1][1])/(P[i][1]-P[i-1][1]);return 1-(len[i-1]+(len[i]-len[i-1])*k)/L}return 0}
function personGeo(o){const S=v=>v,body={shirt:[],skin:[],chair:[]},head={face:[],skin:[],hair:[]};
 body.shirt.push(gScale3(gLathe(TORSOP,36),1.2,1,.7));
 /* the upper arms belong to the body; each forearm with its cuff and hand turns at the elbow, so hands can clap */
 const arms={};for(const s of[-1,1]){body.shirt.push(gCap([s*1.82,2.15,0],ELB(s),.58,.5));const E=ELB(s),W=[s*.98,1.12,2.38],fa=v3.norm(v3.sub(W,E));
  arms[s]={sleeve:gMerge(gCap([0,0,0],v3.sub(W,E),.48,.38),gXf(gTorus(.43,.1,20,8),v3.sub(v3.add(W,v3.mul(fa,-.14)),E),qFromY(fa))),
   hand:gXf(handGeo(s),v3.sub(v3.add(W,v3.mul(fa,.1)),E),qBasis([-s*.7,-.06,1],[s*.3,1,0]))}}
 /* the collar round the neck */
 body.shirt.push(gXf(gTorus(.58,.15,28,8),[0,2.62,.05],qt.ax(1,0,0,.12)));
 body.skin.push(gCap([0,2.45,0],[0,3.42,.1],.47,.45));
 body.chair.push(gBox(4.2,4.3,.36,.15,3,null),gBox(4.9,.62,.56,.24,3,null),gBox(.5,6.4,.5,.2,3,null),gBox(.5,6.4,.5,.2,3,null));
 gXf(body.chair[0],[0,1.75,-1.82],qt.id());gXf(body.chair[1],[0,4.1,-1.82],qt.id());gXf(body.chair[2],[-2.3,1.1,-1.82],qt.id());gXf(body.chair[3],[2.3,1.1,-1.82],qt.id());
 /* the head, relative to the neck pivot */
 head.face.push(gXf(gScale3(gLathe(HEADP,40),1,1,1.06),HC,qt.id()));
 for(const s of[-1,1])head.skin.push(gEll(.2,.33,.12,[s*.99,1.0,0]));
 head.skin.push(gEll(.15,.24,.17,[0,.93,1.16]));
 /* hair is a shell over the head between two lines that change around it: high on the forehead, low at the nape */
 const hs=(top,bot,keep)=>{const g=geo(),sg=44,rows=9,cols=[];for(let j=0;j<=sg;j++){const th=j/sg*Math.PI*2,f=Math.sin(th);if(keep&&!keep(f)){cols.push(null);continue}const t0=top(f),b0=bot(f),col=[];
   for(let i=0;i<=rows;i++){const y=t0+(b0-t0)*i/rows,r=y>=1.3?0:headR(y)*1.05+.055,x=Math.cos(th)*r,z=Math.sin(th)*r*1.06,n=v3.norm([x/1.04,y/1.5,z/1.12]);col.push(gv(g,x+HC[0],y+HC[1],z+HC[2],n[0],n[1],n[2],j/sg,i/rows))}cols.push(col)}
  for(let j=0;j<sg;j++){const A=cols[j],B=cols[j+1];if(!A||!B)continue;for(let i=0;i<rows;i++)g.i.push(A[i],B[i],B[i+1],A[i],B[i+1],A[i+1])}return g};
 const crown=()=>1.32;
 const short=()=>hs(crown,f=>f>0?.12+.5*Math.pow(f,1.3):.12-.62*Math.pow(-f,.9));
 if(o.style==='long'){head.hair.push(hs(crown,f=>f>0?.62*Math.pow(f,1.4)-.05:-.05-.95*Math.pow(-f,.8)),gXf(gBox(2.0,2.5,.7,.34,3),[0,.05,-.62],qt.ax(1,0,0,.1)));
  for(const s of[-1,1])head.hair.push(gXf(gBox(.42,2.1,.58,.2,3),[s*1.0,.32,.12],qt.ax(0,0,1,s*.06)))}
 else if(o.style==='bald')head.hair.push(hs(f=>.42-.25*Math.max(f,0),f=>-.15-.4*Math.max(-f,0),f=>f<.3));
 else if(o.style==='pony'){head.hair.push(hs(crown,f=>f>0?.3+.42*Math.pow(f,1.3):.3-1.0*Math.pow(-f,.85)));
  /* hair drawn back into a tail with a band */
  head.hair.push(gCap([0,1.55,-.9],[0,-.35,-1.42],.3,.15,14),gXf(gTorus(.24,.08,16,6),[0,1.42,-.98],qt.ax(1,0,0,-.35)))}
 else if(o.style==='curly'){head.hair.push(hs(crown,f=>f>0?.22+.48*Math.pow(f,1.3):.2-.55*Math.pow(-f,.9)));
  /* curls: small round tufts over the crown and the sides */
  const R=rng(31);for(let k=0;k<64;k++){const th=R()*Math.PI*2,f=Math.sin(th),y=.35+R()*(f>.3?.85:1.0),r=headR(y)*1.07+.1;if(f>.55&&y<.75)continue;
   head.hair.push(gEll(.2+R()*.06,.18,.2+R()*.06,[Math.cos(th)*r+HC[0],y+HC[1],Math.sin(th)*r*1.06+HC[2]],null,8))}}
 else head.hair.push(short());
 if(o.mus)head.hair.push(gEll(.44,.11,.15,[0,.6,1.09],qt.ax(1,0,0,.1)));
 /* a beard round the jaw and the chin, leaving the mouth */
 if(o.beard)head.hair.push(hs(f=>.12-.74*Math.pow(Math.max(f,0),2),()=>-1.2,f=>f>-.25));
 /* glasses: two round frames on the nose */
 const frame=[];if(o.glasses){for(const s of[-1,1]){frame.push(gXf(gTorus(.2,.03,22,6),[s*.36,1.17,1.1],qt.ax(1,0,0,Math.PI/2)));frame.push(gCap([s*.56,1.2,1.0],[s*.98,1.22,.35],.025,.025,6))}frame.push(gCap([-.16,1.2,1.12],[.16,1.2,1.12],.025,.025,6))}
 /* a flat cap */
 const hat=[];if(o.hat){hat.push(gEll(1.12,.36,1.2,[0,HC[1]+.98,HC[2]-.08]),gEll(.86,.07,.52,[0,HC[1]+.86,HC[2]+.98],qt.ax(1,0,0,.12)))}
 const m=a=>a.length?gMerge(...a):null;return{body:{shirt:m(body.shirt),skin:m(body.skin),chair:m(body.chair)},head:{face:m(head.face),skin:m(head.skin),hair:m(head.hair),frame:m(frame),hat:m(hat)},arms}}
const ELB=s=>[s*2.3,.55,1.0];
/* the turn that sends +z along f with +y as near to up as it can */
function qBasis(f,up){const z=v3.norm(f),x=v3.norm(v3.cross(up,z)),y=v3.cross(z,x),tr=x[0]+y[1]+z[2];let S;
 if(tr>0){S=Math.sqrt(tr+1)*2;return[(y[2]-z[1])/S,(z[0]-x[2])/S,(x[1]-y[0])/S,.25*S]}
 if(x[0]>y[1]&&x[0]>z[2]){S=Math.sqrt(1+x[0]-y[1]-z[2])*2;return[.25*S,(y[0]+x[1])/S,(z[0]+x[2])/S,(y[2]-z[1])/S]}
 if(y[1]>z[2]){S=Math.sqrt(1+y[1]-x[0]-z[2])*2;return[(y[0]+x[1])/S,.25*S,(z[1]+y[2])/S,(z[0]-x[2])/S]}
 S=Math.sqrt(1+z[2]-x[0]-y[1])*2;return[(z[0]+x[2])/S,(z[1]+y[2])/S,.25*S,(x[1]-y[0])/S]}
/* a ring: a circle swept round the y axis */
function gTorus(R,r,sg=24,rs=8){return gLathe(Array.from({length:rs+1},(_,i)=>{const a=-Math.PI/2+i/rs*Math.PI*2;return[R+Math.cos(a)*r,Math.sin(a)*r]}),sg,.2)}
/* a hand, from the wrist: palm down, fingers forward along +z and a little curled, the thumb on the inside */
function handGeo(s){const g=[gEll(.27,.12,.3,[0,0,.27],null,14)],th=-s,lens=[.32,.36,.33,.26];
 [-.165,-.055,.055,.165].forEach((x,i)=>{const L=lens[th>0?3-i:i];g.push(gCap([x,-.01,.47],[x,-.1,.47+L],.066,.056,8))});
 g.push(gCap([th*.2,-.03,.16],[th*.38,-.08,.42],.075,.064,8));return gMerge(...g)}
/* knitted wool: ribs and rows of small V stitches, in grey so the shirt colour tints it */
function knitCv(){const S=256,c=cvs(S,S),x=c.getContext('2d'),R=rng(19);x.fillStyle='#e6e6e6';x.fillRect(0,0,S,S);
 for(let col=0;col<16;col++)for(let row=0;row<22;row++){const X=col*16,Y=row*11.64;x.strokeStyle=`rgba(0,0,0,${.12+R()*.06})`;x.lineWidth=2.2;x.beginPath();x.moveTo(X+2,Y+1);x.lineTo(X+8,Y+9);x.lineTo(X+14,Y+1);x.stroke();
  x.strokeStyle='rgba(255,255,255,.35)';x.lineWidth=1.2;x.beginPath();x.moveTo(X+3,Y+3);x.lineTo(X+8,Y+8);x.stroke()}
 for(let col=0;col<16;col++){x.fillStyle='rgba(0,0,0,.07)';x.fillRect(col*16,0,1.5,S)}return c}
/* the face painted on the head: brows, eyes with a catch light, a soft smile and warm cheeks */
function faceCv(o){const c=cvs(1024,256),x=c.getContext('2d');faceAt(x,o,false);x.save();x.translate(512,0);faceAt(x,o,true);x.restore();return c}
function faceAt(x,o,shut){x.fillStyle=o.skin;x.fillRect(0,0,512,256);
 /* under the hair the scalp is painted in the hair colour, so no skin shows through where the hair is thin */
 if(!o.bald&&o.hair){x.fillStyle=o.hair;x.fillRect(0,0,512,Math.round(headV(.98)*256))}
 const U=128,ey=headV(.12)*256,by=headV(.4)*256,my=headV(-.56)*256,cy=headV(-.24)*256,dx=30;
 for(const s of[-1,1]){const g=x.createRadialGradient(U+s*38,cy,1,U+s*38,cy,17);g.addColorStop(0,'rgba(226,112,100,.32)');g.addColorStop(1,'rgba(226,112,100,0)');x.fillStyle=g;x.fillRect(U+s*38-18,cy-18,36,36)}
 for(const s of[-1,1]){const ex=U+s*dx;
  if(shut){x.strokeStyle='rgba(40,22,14,.85)';x.lineWidth=o.fem?2.6:2;x.lineCap='round';x.beginPath();x.ellipse(ex,ey-1,9.6,4,0,Math.PI*.05,Math.PI*.95);x.stroke();
   x.strokeStyle=o.brow||o.hair;x.lineWidth=o.fem?2.6:4;x.beginPath();x.moveTo(ex-11,by+3);x.quadraticCurveTo(ex,by-2.5,ex+11,by+2.5);x.stroke();continue}
  x.fillStyle='#FBF7F2';x.beginPath();x.ellipse(ex,ey,9.5,5,0,0,Math.PI*2);x.fill();
  x.fillStyle=o.eye||'#4A2E1E';x.beginPath();x.ellipse(ex,ey+.4,5.4,4.6,0,0,Math.PI*2);x.fill();x.fillStyle='#120B08';x.beginPath();x.ellipse(ex,ey+.4,2.6,2.3,0,0,Math.PI*2);x.fill();
  x.fillStyle='rgba(255,255,255,.9)';x.beginPath();x.arc(ex-1.6,ey-1.4,1.3,0,Math.PI*2);x.fill();
  x.strokeStyle='rgba(40,22,14,.85)';x.lineWidth=o.fem?2.6:1.8;x.beginPath();x.ellipse(ex,ey,9.8,5.4,0,Math.PI*1.05,Math.PI*1.95);x.stroke();
  x.strokeStyle=o.brow||o.hair;x.lineCap='round';x.lineWidth=o.fem?2.6:4;x.beginPath();x.moveTo(ex-11,by+2);x.quadraticCurveTo(ex,by-3.5,ex+11,by+1.5);x.stroke()}
 x.strokeStyle='#9A4A40';x.lineWidth=2.6;x.lineCap='round';x.beginPath();x.moveTo(U-12,my-1);x.quadraticCurveTo(U,my+5,U+12,my-1);x.stroke();
 if(o.fem){x.fillStyle='rgba(176,64,72,.55)';x.beginPath();x.ellipse(U,my+1,9,3,0,0,Math.PI*2);x.fill()}}
/* the room around the table: patterned wallpaper above a wood panel, and a dark plank floor */
function wallCv(){const S=1024,c=cvs(S,S),x=c.getContext('2d'),R=rng(77);x.fillStyle='#3C2A22';x.fillRect(0,0,S,S);
 x.globalAlpha=.5;x.drawImage(noiseCv(256,256,R,90,160),0,0,S,S);x.globalAlpha=1;
 for(let i=0;i<8;i++){const X=i*128;x.fillStyle=i%2?'rgba(120,78,44,.16)':'rgba(0,0,0,.08)';x.fillRect(X,0,64,S)}
 x.fillStyle='rgba(214,170,100,.16)';for(let i=0;i<8;i++)for(let j=0;j<8;j++){const X=i*128+64,Y=j*128+(i%2)*64+32;x.save();x.translate(X,Y);x.beginPath();x.moveTo(0,-26);x.quadraticCurveTo(18,0,0,26);x.quadraticCurveTo(-18,0,0,-26);x.fill();x.restore()}
 return c}

/* ---------- surroundings: the rooms and yards the games are played in ---------- */
/* a hand-knotted Caucasian rug: red field, three hooked medallions, borders of small motifs, fringe at both ends */
function rugCv(){const W=512,H=1024,c=cvs(W,H),x=c.getContext('2d'),R=rng(83);x.fillStyle='#E9DCC0';x.fillRect(0,0,W,H);
 const fr=(y0,y1)=>{for(let X=10;X<W-10;X+=5){x.strokeStyle='rgba(225,212,184,.95)';x.lineWidth=2.4;x.beginPath();x.moveTo(X,y0);x.lineTo(X+(R()-.5)*3,y1);x.stroke()}};fr(0,40);fr(H-40,H);
 x.fillStyle='#22305E';x.fillRect(16,40,W-32,H-80);x.fillStyle='#E9DCC0';x.fillRect(46,70,W-92,H-140);x.fillStyle='#8C1C1E';x.fillRect(60,84,W-120,H-168);
 /* border motifs: small eight-pointed stars and diamonds */
 const star=(cx,cy,r,col)=>{x.fillStyle=col;x.beginPath();for(let k=0;k<16;k++){const a=k*Math.PI/8,rr=k%2?r*.45:r;x.lineTo(cx+Math.cos(a)*rr,cy+Math.sin(a)*rr)}x.closePath();x.fill()};
 for(let y=58;y<H-50;y+=34){star(31,y,9,y%68<34?'#B8322C':'#D9A441');star(W-31,y,9,y%68<34?'#D9A441':'#B8322C')}
 for(let X=58;X<W-50;X+=34){star(X,55,9,'#B8322C');star(X,H-55,9,'#D9A441')}
 /* the medallions: a stepped diamond with hooks, each in two colours */
 const med=(cy,a,b)=>{x.save();x.translate(W/2,cy);for(const[s,col]of[[150,a],[118,'#E9DCC0'],[96,b],[60,'#E9DCC0'],[38,a]]){x.fillStyle=col;x.beginPath();for(let k=0;k<4;k++){const ang=k*Math.PI/2;x.lineTo(Math.cos(ang)*s*.78,Math.sin(ang)*s)}x.closePath();x.fill()}
  x.strokeStyle='#E9DCC0';x.lineWidth=7;for(const s of[-1,1])for(const t of[-1,1]){x.beginPath();x.moveTo(s*70,t*70);x.lineTo(s*96,t*96);x.lineTo(s*112,t*80);x.stroke()}x.restore()};
 med(250,'#22305E','#D9A441');med(H/2,'#2E6B4A','#22305E');med(H-250,'#22305E','#D9A441');
 for(let k=0;k<40;k++)star(75+R()*(W-150),100+R()*(H-200),6+R()*4,['#D9A441','#22305E','#E9DCC0'][k%3]);
 x.globalCompositeOperation='multiply';x.globalAlpha=.25;x.drawImage(noiseCv(128,256,R,160,255),0,0,W,H);x.globalAlpha=1;x.globalCompositeOperation='source-over';return c}
/* a wall of books: five shelves of spines in old cloth colours, some with gilt bands */
function booksCv(){const S=1024,c=cvs(S,S),x=c.getContext('2d'),R=rng(57);x.fillStyle='#2A1A12';x.fillRect(0,0,S,S);const cols=['#5C1E22','#23402E','#1E2C4A','#6B4A28','#7C6A3A','#3E2A40','#8A3A28','#2E3A3A','#B59A6A'];
 for(let r=0;r<5;r++){const y0=r*204+14,y1=y0+184;x.fillStyle='#4A3022';x.fillRect(0,y1,S,20);x.fillStyle='rgba(0,0,0,.35)';x.fillRect(0,y0,S,8);let X=6;
  while(X<S-20){const w=14+R()*26,h=120+R()*60,col=cols[Math.floor(R()*cols.length)],lean=R()<.06;x.save();x.translate(X,y1);if(lean)x.rotate(-.08);x.fillStyle=col;x.fillRect(0,-h,w,h);
   x.fillStyle='rgba(255,255,255,.06)';x.fillRect(1,-h,w*.3,h);x.fillStyle='rgba(0,0,0,.25)';x.fillRect(w-3,-h,3,h);if(R()<.6){x.fillStyle='rgba(222,186,104,.75)';x.fillRect(0,-h+14,w,3);x.fillRect(0,-h+22,w,2);x.fillRect(0,-24,w,3)}
   x.restore();X+=w+(R()<.1?18:1.5)}}
 x.globalCompositeOperation='multiply';x.globalAlpha=.25;x.drawImage(noiseCv(256,256,R,150,255),0,0,S,S);x.globalAlpha=1;x.globalCompositeOperation='source-over';return c}
/* old red brick with pale mortar */
function brickCv(){const S=512,c=cvs(S,S),x=c.getContext('2d'),R=rng(23);x.fillStyle='#C9B79E';x.fillRect(0,0,S,S);
 for(let r=0;r<16;r++)for(let k=-1;k<9;k++){const w=64,h=32,X=k*w+(r%2)*32,Y=r*h,v=R();x.fillStyle=`rgb(${150+v*40|0},${70+v*25|0},${52+v*18|0})`;x.fillRect(X+2,Y+2,w-4,h-4);x.fillStyle='rgba(0,0,0,.12)';x.fillRect(X+2,Y+h-7,w-4,5)}
 x.globalCompositeOperation='multiply';x.globalAlpha=.4;x.drawImage(noiseCv(128,128,R,120,255),0,0,S,S);x.globalAlpha=1;x.globalCompositeOperation='source-over';return c}
/* lime plaster in a colour, weathered */
function plasterCv(col){const S=512,c=cvs(S,S),x=c.getContext('2d'),R=rng(71);x.fillStyle=col;x.fillRect(0,0,S,S);
 x.globalCompositeOperation='multiply';x.globalAlpha=.35;x.drawImage(noiseCv(64,64,R,150,255),0,0,S,S);x.globalAlpha=.25;x.drawImage(noiseCv(256,256,R,170,255),0,0,S,S);
 x.globalAlpha=1;x.globalCompositeOperation='source-over';for(let k=0;k<14;k++){const X=R()*S,Y=R()*S,g=x.createRadialGradient(X,Y,2,X,Y,30+R()*60);g.addColorStop(0,'rgba(90,70,50,.18)');g.addColorStop(1,'rgba(90,70,50,0)');x.fillStyle=g;x.fillRect(0,0,S,S)}return c}
/* square stone flags with dark joints */
function tilesCv(){const S=512,c=cvs(S,S),x=c.getContext('2d'),R=rng(13);x.fillStyle='#4A4440';x.fillRect(0,0,S,S);
 for(let i=0;i<4;i++)for(let j=0;j<4;j++){const v=R();x.fillStyle=`rgb(${118+v*30|0},${108+v*26|0},${96+v*22|0})`;x.fillRect(i*128+4,j*128+4,120,120)}
 x.globalCompositeOperation='multiply';x.globalAlpha=.45;x.drawImage(noiseCv(128,128,R,110,255),0,0,S,S);x.globalAlpha=1;x.globalCompositeOperation='source-over';return c}
/* a kitchen oilcloth: red check with small white flowers */
function oilclothCv(){const S=512,c=cvs(S,S),x=c.getContext('2d');x.fillStyle='#F4EEE4';x.fillRect(0,0,S,S);
 x.fillStyle='rgba(196,46,52,.55)';for(let k=0;k<8;k++){x.fillRect(k*64,0,32,S);x.fillRect(0,k*64,S,32)}
 for(let i=0;i<8;i++)for(let j=0;j<8;j++){const X=i*64+48,Y=j*64+48;x.fillStyle='#FFFFFF';for(let p=0;p<5;p++){const a=p*Math.PI*2/5;x.beginPath();x.arc(X+Math.cos(a)*5,Y+Math.sin(a)*5,4,0,Math.PI*2);x.fill()}x.fillStyle='#E7B53C';x.beginPath();x.arc(X,Y,3,0,Math.PI*2);x.fill()}return c}
/* green leather with a gilt line, for the writing desk under the chess board */
function leatherCv(){const S=512,c=cvs(S,S),x=c.getContext('2d'),R=rng(5);x.fillStyle='#1F4A36';x.fillRect(0,0,S,S);x.globalCompositeOperation='multiply';x.globalAlpha=.4;x.drawImage(noiseCv(256,256,R,150,255),0,0,S,S);
 x.globalAlpha=1;x.globalCompositeOperation='source-over';x.strokeStyle='rgba(214,176,96,.85)';x.lineWidth=5;x.strokeRect(18,18,S-36,S-36);x.lineWidth=2;x.strokeRect(30,30,S-60,S-60);return c}
/* a window: painted frame, six panes; the day shows sky and a cloud, the evening a deep blue with a lamp's reflection */
function windowCv(day){const W=256,H=512,c=cvs(W,H),x=c.getContext('2d');const g=x.createLinearGradient(0,0,0,H);if(day){g.addColorStop(0,'#8EC2EA');g.addColorStop(1,'#D8ECF6')}else{g.addColorStop(0,'#0E1A33');g.addColorStop(1,'#2A3550')}
 x.fillStyle=g;x.fillRect(0,0,W,H);if(day){x.fillStyle='rgba(255,255,255,.85)';for(const[a,b,r]of[[80,140,34],[120,128,40],[160,146,30]]){x.beginPath();x.arc(a,b,r,0,Math.PI*2);x.fill()}}
 else{x.fillStyle='rgba(255,214,140,.9)';for(let k=0;k<14;k++){x.fillRect(20+((k*53)%210),330+((k*37)%120),4,6)}const r=x.createRadialGradient(170,120,4,170,120,70);r.addColorStop(0,'rgba(255,200,120,.35)');r.addColorStop(1,'rgba(255,200,120,0)');x.fillStyle=r;x.fillRect(0,0,W,H)}
 x.fillStyle='#EDE6DA';x.fillRect(0,0,W,18);x.fillRect(0,H-18,W,18);x.fillRect(0,0,18,H);x.fillRect(W-18,0,18,H);x.fillRect(W/2-7,0,14,H);x.fillRect(0,H/3-6,W,12);x.fillRect(0,H*2/3-6,W,12);
 x.fillStyle='rgba(0,0,0,.15)';x.fillRect(18,18,4,H-36);return c}
/* sky over Tbilisi: hills on the far side, roofs, and in the evening windows lit */
function skylineCv(day){const W=1024,H=512,c=cvs(W,H),x=c.getContext('2d'),R=rng(97),g=x.createLinearGradient(0,0,0,H);
 if(day){g.addColorStop(0,'#7FB4E0');g.addColorStop(.7,'#CFE4F0');g.addColorStop(1,'#E8E0D0')}else{g.addColorStop(0,'#0B1430');g.addColorStop(.6,'#2B2A4A');g.addColorStop(1,'#6A4A4A')}x.fillStyle=g;x.fillRect(0,0,W,H);
 x.fillStyle=day?'#6E8A6A':'#1E2030';x.beginPath();x.moveTo(0,H);for(let X=0;X<=W;X+=16)x.lineTo(X,280+Math.sin(X/130)*40+Math.sin(X/47)*12);x.lineTo(W,H);x.fill();
 for(let k=0;k<60;k++){const X=R()*W,w=20+R()*40,h=30+R()*70,Y=H-h-R()*60;x.fillStyle=day?`rgb(${200+R()*40|0},${180+R()*30|0},${150+R()*30|0})`:'#262236';x.fillRect(X,Y,w,h+80);x.fillStyle=day?'#9A4A36':'#1A1626';x.beginPath();x.moveTo(X-4,Y);x.lineTo(X+w/2,Y-14);x.lineTo(X+w+4,Y);x.fill();
  if(!day)for(let m=0;m<3;m++)if(R()<.6){x.fillStyle='rgba(255,206,120,.9)';x.fillRect(X+4+R()*(w-10),Y+8+R()*(h-10),4,5)}}
 if(!day){x.fillStyle='rgba(255,255,255,.8)';for(let k=0;k<50;k++)x.fillRect(R()*W,R()*200,1.5,1.5)}return c}
/* a grape leaf, cut out by its alpha */
function leafCv(){const S=256,c=cvs(S,S),x=c.getContext('2d');x.translate(S/2,S/2);x.fillStyle='#4E7A2E';x.beginPath();
 for(let k=0;k<=60;k++){const a=k/60*Math.PI*2,lobe=1+.22*Math.cos(a*5),r=100*lobe*(a>Math.PI*1.38&&a<Math.PI*1.62?.55:1);x.lineTo(Math.cos(a)*r,Math.sin(a)*r)}x.closePath();x.fill();
 x.strokeStyle='rgba(200,230,140,.45)';x.lineWidth=3;for(let k=0;k<5;k++){const a=-Math.PI/2+k*Math.PI*2/5;x.beginPath();x.moveTo(0,0);x.lineTo(Math.cos(a)*90,Math.sin(a)*90);x.stroke()}return c}
/* a tube along a path, with a radius at every point: the drinking horn and the jug's handle */
function gSweep(path,rad,sg=14){const g=geo(),n=path.length,rings=[];for(let i=0;i<n;i++){const a=path[Math.max(0,i-1)],b=path[Math.min(n-1,i+1)],t=v3.norm(v3.sub(b,a)),up=Math.abs(t[1])>.9?[1,0,0]:[0,1,0],u=v3.norm(v3.cross(t,up)),w=v3.cross(u,t),r=rad(i/(n-1)),ring=[];
  for(let j=0;j<=sg;j++){const ang=j/sg*Math.PI*2,nv=v3.add(v3.mul(u,Math.cos(ang)),v3.mul(w,Math.sin(ang)));ring.push(gv(g,path[i][0]+nv[0]*r,path[i][1]+nv[1]*r,path[i][2]+nv[2]*r,nv[0],nv[1],nv[2],j/sg,i/(n-1)))}rings.push(ring)}
 for(let i=0;i<n-1;i++)for(let j=0;j<sg;j++){const A=rings[i],B=rings[i+1];g.i.push(A[j],B[j],B[j+1],A[j],B[j+1],A[j+1])}return g}
