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
function nardiCv(style){const S=2048,c=cvs(S,S),x=c.getContext('2d'),sx=S/(NB.x1-NB.x0),sz=S/(NB.z1-NB.z0),X=v=>(v-NB.x0)*sx,Z=v=>(v-NB.z0)*sz,orn=style==='orn';
 x.drawImage(woodCv(S,S,orn?WOOD.ebony:WOOD.frame),0,0);
 const fw=woodCv(1024,1024,Object.assign({},WOOD.walnut,orn?{base:'#6a4428',seed:52,lines:120,fig:.3}:{base:'#b27f52',seed:51,lines:110,fig:.25}));x.drawImage(fw,X(-6.5),Z(-5.6),13*sx,11.2*sz);
 x.save();x.globalAlpha=.2;const sh=x.createLinearGradient(0,Z(-5.6),0,Z(5.6));sh.addColorStop(0,'#000');sh.addColorStop(.5,'rgba(0,0,0,0)');sh.addColorStop(1,'#000');x.fillStyle=sh;x.fillRect(X(-6.5),Z(-5.6),13*sx,11.2*sz);x.restore();
 const Lw=orn?pearlCv(512):woodCv(512,512,WOOD.maple),Dw=orn?woodCv(512,512,WOOD.ebony):woodCv(512,512,WOOD.rose);
 for(let col=0;col<13;col++){if(col===6)continue;for(const top of[1,0]){const cx=col-6,di=top?(col<6?12+col:18+col-7):(col<6?11-col:5-(col-7)),src=di%2?Dw:Lw;
   const y0=top?-5.55:5.55,y1=top?-.75:.75;x.save();x.beginPath();x.moveTo(X(cx-.46),Z(y0));x.lineTo(X(cx+.46),Z(y0));x.lineTo(X(cx),Z(y1));x.closePath();x.clip();x.drawImage(src,(col*61)%300,(top*170+col*23)%300,180,420,X(cx-.5),Z(Math.min(y0,y1)),sx,4.8*sz);x.restore();
   x.strokeStyle='rgba(214,170,88,.85)';x.lineWidth=3;x.beginPath();x.moveTo(X(cx-.46),Z(y0));x.lineTo(X(cx),Z(y1));x.lineTo(X(cx+.46),Z(y0));x.stroke();
   /* inlaid: small diamonds of mother-of-pearl down the dark points, a gold dot near the tip of the light ones */
   if(orn){const k=top?1:-1;if(di%2)for(let t=0;t<4;t++){const yy=y0+k*(.55+t*.95),w=.11*(1-t*.18);x.fillStyle='rgba(236,230,214,.9)';x.beginPath();x.moveTo(X(cx),Z(yy-k*.16));x.lineTo(X(cx+w),Z(yy));x.lineTo(X(cx),Z(yy+k*.16));x.lineTo(X(cx-w),Z(yy));x.fill()}
    else{x.fillStyle='rgba(212,168,80,.95)';x.beginPath();x.arc(X(cx),Z(y1-k*.55),4,0,Math.PI*2);x.fill()}}}}
 if(orn){/* a gold border of interlace round the playing field, and the sun of Georgia, the borjgali, on the bar */
  ornBand(x,X(-6.5),Z(-5.62),13*sx,14,'rgba(222,184,96,.95)');ornBand(x,X(-6.5),Z(5.62)-14,13*sx,14,'rgba(222,184,96,.95)');
  for(const zz of[-2.6,2.6])borjgali(x,X(0),Z(zz),.34*sx,'rgba(236,230,214,.95)')}
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
function cardsCv(c4,style){const geoS=style==='geo',c=cvs(CATL,CATL),x=c.getContext('2d'),F='"Noto Serif Georgian",Georgia,"Times New Roman",serif',FS='"Noto Sans Georgian","DejaVu Sans",system-ui,sans-serif';
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
   else if(geoS){/* the Georgian deck: a parchment panel with interlace, and a crown, a tiara or a feathered cap over the letter */
    const g=x.createLinearGradient(0,60,0,300);g.addColorStop(0,'#FFF4DC');g.addColorStop(1,'#F2DDB0');x.fillStyle=g;rrect(x,82,40,92,280,12);x.fill();x.strokeStyle=col;x.lineWidth=3;x.stroke();
    ornBand(x,90,50,76,16,col);ornBand(x,90,294,76,16,col);courtIcon(x,r,128,CH_/2-44,col);x.fillStyle=col;x.font=`700 70px ${F}`;x.fillText(t,128,CH_/2+42);suitPath(x,s,128,CH_/2+88,26)}
   else{const g=x.createLinearGradient(0,60,0,300);g.addColorStop(0,'#FBEFD2');g.addColorStop(1,'#F0D9A6');x.fillStyle=g;rrect(x,86,46,84,268,10);x.fill();x.strokeStyle=col;x.lineWidth=3;x.stroke();x.lineWidth=1.2;rrect(x,92,52,72,256,6);x.stroke();
    x.fillStyle=col;x.font=`700 80px ${F}`;x.fillText(t,128,CH_/2+18);suitPath(x,s,128,CH_/2+74,28);suitPath(x,s,128,CH_/2-78,28)}})}
 for(const j of[1,2])face(35+j,()=>{const col=j===1?'#CE1430':'#1F2F6B',g=x.createRadialGradient(CW/2,CH_/2,10,CW/2,CH_/2,150);g.addColorStop(0,j===1?'#FFE3EA':'#E2E8FF');g.addColorStop(1,'#FFFDF8');x.fillStyle=g;x.fillRect(0,0,CW,CH_);
  if(geoS){borjgali(x,CW/2,CH_/2-24,72,col);x.fillStyle=col;x.font=`700 34px ${F}`;x.textAlign='center';x.fillText('ჯოკერი',CW/2,CH_/2+76)}
  else{jesterAt(x,CW/2+16,CH_/2+18,.82,j===1?['#D62A3A','#F4C430','#2A6FD6']:['#2A6FD6','#3DAA5C','#8E44AD']);x.fillStyle=col;x.font=`800 27px ${FS}`;x.textAlign='center';[...'ჯოკერი'].forEach((ch,i)=>x.fillText(ch,34,128+i*31))}x.fillStyle=col;
  const corner=()=>{x.save();x.translate(46,64);x.beginPath();for(let k=0;k<10;k++){const a=-Math.PI/2+k*Math.PI/5,rr=k%2?15:36;x.lineTo(Math.cos(a)*rr,Math.sin(a)*rr)}x.closePath();x.fill();x.restore()};
  corner();x.save();x.translate(CW,CH_);x.rotate(Math.PI);corner();x.restore()});
 if(geoS)face(38,()=>{/* the back: deep red, a gold interlace frame, small crosses in a lattice and the borjgali in the middle */
  x.fillStyle='#5E0F24';x.fillRect(0,0,CW,CH_);x.strokeStyle='rgba(232,190,100,.9)';x.lineWidth=4;rrect(x,14,14,CW-28,CH_-28,14);x.stroke();
  ornBand(x,24,24,CW-48,18,'rgba(232,190,100,.85)');ornBand(x,24,CH_-42,CW-48,18,'rgba(232,190,100,.85)');
  x.fillStyle='rgba(232,190,100,.35)';for(let i=0;i<6;i++)for(let k=0;k<9;k++){const X=36+i*37+(k%2)*18,Y=62+k*30;x.fillRect(X-1.5,Y-6,3,12);x.fillRect(X-6,Y-1.5,12,3)}
  x.fillStyle='#5E0F24';x.beginPath();x.arc(CW/2,CH_/2,58,0,Math.PI*2);x.fill();x.strokeStyle='rgba(232,190,100,.95)';x.lineWidth=3;x.stroke();borjgali(x,CW/2,CH_/2,46,'rgba(232,190,100,.95)')});
 else face(38,()=>{x.fillStyle='#7A1430';x.fillRect(0,0,CW,CH_);x.strokeStyle='rgba(232,190,100,.9)';x.lineWidth=4;rrect(x,16,16,CW-32,CH_-32,14);x.stroke();
  x.save();rrect(x,24,24,CW-48,CH_-48,10);x.clip();x.strokeStyle='rgba(232,190,100,.28)';x.lineWidth=2;for(let k=-CH_;k<CW+CH_;k+=22){x.beginPath();x.moveTo(k,0);x.lineTo(k+CH_,CH_);x.stroke();x.beginPath();x.moveTo(k+CH_,0);x.lineTo(k,CH_);x.stroke()}x.restore();
  x.fillStyle='#7A1430';x.beginPath();x.arc(CW/2,CH_/2,62,0,Math.PI*2);x.fill();x.strokeStyle='rgba(232,190,100,.95)';x.lineWidth=4;x.stroke();x.lineWidth=1.5;x.beginPath();x.arc(CW/2,CH_/2,54,0,Math.PI*2);x.stroke();
  x.fillStyle=goldFill(x,CH_/2-34,CH_/2+30);crownPath(x,CW/2,CH_/2+2,70)});
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
const EYEA=.43;
function personGeo(o){const S=v=>v,body={shirt:[],skin:[],chair:[]},head={face:[],skin:[],hair:[],eyes:[],gold:[]};
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
 head.skin.push(o.e3?gEll(.17,.22,.2,[0,.9,1.15]):gEll(.15,.24,.17,[0,.93,1.16]));
 /* eyeballs of their own: big, a little proud of the face and turned out a touch; they catch the light like real ones */
 if(o.e3)for(const s of[-1,1]){const th=s*EYEA,y=.12,r=headR(y),S0=[Math.sin(th)*r,y,Math.cos(th)*r*1.06],l=Math.hypot(S0[0],S0[2]),C=[S0[0]-S0[0]/l*.165+HC[0],y+HC[1],S0[2]-S0[2]/l*.165+HC[2]];head.eyes.push(gEll(.27,.27,.27,C,qt.ax(0,1,0,s*.12),24))}
 /* small gold hoops for the ladies */
 if(o.e3&&o.fem)for(const s of[-1,1])head.gold.push(gXf(gTorus(.11,.026,18,6),[s*1.03,.52,.04],qt.mul(qt.ax(0,1,0,s*.55),qt.ax(0,0,1,Math.PI/2))));
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
 const frame=[],gw=o.e3?1.25:1,gx=o.e3?.43:.36,gz=o.e3?1.16:1.1;if(o.glasses){for(const s of[-1,1]){frame.push(gXf(gTorus(.2*gw,.03,22,6),[s*gx,1.17,gz],qt.mul(qt.ax(0,1,0,s*.12),qt.ax(1,0,0,Math.PI/2))));frame.push(gCap([s*(gx+.2*gw),1.2,gz-.08],[s*.98,1.22,.35],.025,.025,6))}frame.push(gCap([-(gx-.2*gw),1.2,gz+.02],[gx-.2*gw,1.2,gz+.02],.025,.025,6))}
 /* a flat cap */
 const hat=[];if(o.hat){hat.push(gEll(1.12,.36,1.2,[0,HC[1]+.98,HC[2]-.08]),gEll(.86,.07,.52,[0,HC[1]+.86,HC[2]+.98],qt.ax(1,0,0,.12)))}
 const m=a=>a.length?gMerge(...a):null;return{body:{shirt:m(body.shirt),skin:m(body.skin),chair:m(body.chair)},head:{face:m(head.face),skin:m(head.skin),hair:m(head.hair),frame:m(frame),hat:m(hat),eyes:m(head.eyes),gold:m(head.gold)},arms}}
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
 const U=128,ey=headV(.12)*256,by=headV(.4)*256,my=headV(-.56)*256,cy=headV(-.24)*256,dx=o.e3?Math.round(EYEA/(Math.PI*2)*512):30;
 for(const s of[-1,1]){const g=x.createRadialGradient(U+s*38,cy,1,U+s*38,cy,17);g.addColorStop(0,'rgba(226,112,100,.32)');g.addColorStop(1,'rgba(226,112,100,0)');x.fillStyle=g;x.fillRect(U+s*38-18,cy-18,36,36)}
 for(const s of[-1,1]){const ex=U+s*dx;
  /* with eyeballs of their own the face only holds the hollow they sit in and a fuller brow, the same open or shut */
  if(o.e3){const sg=x.createRadialGradient(ex,ey,6,ex,ey,24);sg.addColorStop(0,'rgba(90,40,30,.5)');sg.addColorStop(1,'rgba(90,40,30,0)');x.fillStyle=sg;x.beginPath();x.ellipse(ex,ey,24,22,0,0,Math.PI*2);x.fill();
   const bY=headV(.47)*256;x.strokeStyle=o.brow||o.hair;x.lineCap='round';x.lineWidth=o.fem?4:6.5;x.beginPath();x.moveTo(ex-13,bY+(s<0?5:2));x.quadraticCurveTo(ex+s*2,bY-6,ex+13,bY+(s<0?2:5));x.stroke();continue}
  if(shut){x.strokeStyle='rgba(40,22,14,.85)';x.lineWidth=o.fem?2.6:2;x.lineCap='round';x.beginPath();x.ellipse(ex,ey-1,9.6,4,0,Math.PI*.05,Math.PI*.95);x.stroke();
   x.strokeStyle=o.brow||o.hair;x.lineWidth=o.fem?2.6:4;x.beginPath();x.moveTo(ex-11,by+3);x.quadraticCurveTo(ex,by-2.5,ex+11,by+2.5);x.stroke();continue}
  x.fillStyle='#FBF7F2';x.beginPath();x.ellipse(ex,ey,9.5,5,0,0,Math.PI*2);x.fill();
  x.fillStyle=o.eye||'#4A2E1E';x.beginPath();x.ellipse(ex,ey+.4,5.4,4.6,0,0,Math.PI*2);x.fill();x.fillStyle='#120B08';x.beginPath();x.ellipse(ex,ey+.4,2.6,2.3,0,0,Math.PI*2);x.fill();
  x.fillStyle='rgba(255,255,255,.9)';x.beginPath();x.arc(ex-1.6,ey-1.4,1.3,0,Math.PI*2);x.fill();
  x.strokeStyle='rgba(40,22,14,.85)';x.lineWidth=o.fem?2.6:1.8;x.beginPath();x.ellipse(ex,ey,9.8,5.4,0,Math.PI*1.05,Math.PI*1.95);x.stroke();
  x.strokeStyle=o.brow||o.hair;x.lineCap='round';x.lineWidth=o.fem?2.6:4;x.beginPath();x.moveTo(ex-11,by+2);x.quadraticCurveTo(ex,by-3.5,ex+11,by+1.5);x.stroke()}
 if(o.e3){/* a wide warm smile with a hint of the lower lip and dimples */x.fillStyle='rgba(150,60,55,.85)';x.beginPath();x.moveTo(U-16,my-3);x.quadraticCurveTo(U,my+9,U+16,my-3);x.quadraticCurveTo(U,my+3,U-16,my-3);x.fill();
  x.fillStyle='rgba(200,110,100,.35)';x.beginPath();x.ellipse(U,my+7,8,2.6,0,0,Math.PI*2);x.fill();x.strokeStyle='rgba(140,70,60,.45)';x.lineWidth=1.6;for(const s of[-1,1]){x.beginPath();x.arc(U+s*19,my-5,3,s>0?Math.PI*.6:-Math.PI*.4,s>0?Math.PI*1.2:Math.PI*.2);x.stroke()}}
 else{x.strokeStyle='#9A4A40';x.lineWidth=2.6;x.lineCap='round';x.beginPath();x.moveTo(U-12,my-1);x.quadraticCurveTo(U,my+5,U+12,my-1);x.stroke()}
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
/* mother-of-pearl: pale, with a shimmer of pink, green and blue */
function pearlCv(S){const c=cvs(S,S),x=c.getContext('2d'),R=rng(37),g=x.createLinearGradient(0,0,S,S);g.addColorStop(0,'#F4EEE6');g.addColorStop(.3,'#E9E4F0');g.addColorStop(.55,'#E4F0EA');g.addColorStop(.8,'#F2E6E8');g.addColorStop(1,'#EDEBE4');x.fillStyle=g;x.fillRect(0,0,S,S);
 for(let k=0;k<70;k++){const X=R()*S,Y=R()*S,r=10+R()*40,h=[330,160,210,40][k%4];x.fillStyle=`hsla(${h},40%,80%,.18)`;x.beginPath();x.ellipse(X,Y,r,r*.4,R()*3,0,Math.PI*2);x.fill()}return c}
/* Georgian interlace along a band: two ribbons weaving over and under */
function ornBand(x,X0,Y0,len,h,col){x.save();x.strokeStyle=col;x.lineWidth=Math.max(2,h*.18);const n=Math.max(4,Math.round(len/(h*2.2))),w=len/n;
 for(let k=0;k<n;k++){const cx=X0+w*(k+.5),cy=Y0+h/2;x.beginPath();x.ellipse(cx,cy,w*.45,h*.42,0,0,Math.PI*2);x.stroke();x.beginPath();x.moveTo(cx-w*.5,Y0+h*.15);x.bezierCurveTo(cx-w*.1,Y0+h*.15,cx+w*.1,Y0+h*.85,cx+w*.5,Y0+h*.85);x.stroke()}x.restore()}
/* the borjgali: seven curved rays turning round a centre */
function borjgali(x,cx,cy,r,col){x.save();x.translate(cx,cy);x.fillStyle=col;for(let k=0;k<7;k++){x.save();x.rotate(k*Math.PI*2/7);x.beginPath();x.moveTo(0,0);
 x.bezierCurveTo(r*.15,-r*.35,r*.55,-r*.55,r*.95,-r*.25);x.bezierCurveTo(r*.7,-r*.25,r*.45,-r*.05,r*.28,r*.12);x.closePath();x.fill();x.restore()}x.beginPath();x.arc(0,0,r*.16,0,Math.PI*2);x.fill();x.restore()}
/* the court cards of the Georgian deck: a crown for the king, a tiara for the queen, a feathered cap for the jack */
function courtIcon(x,r,cx,cy,col){x.save();x.translate(cx,cy);x.fillStyle=col;x.strokeStyle=col;x.lineWidth=3;
 if(r===13){x.beginPath();x.moveTo(-36,22);x.lineTo(-40,-14);x.lineTo(-20,4);x.lineTo(0,-24);x.lineTo(20,4);x.lineTo(40,-14);x.lineTo(36,22);x.closePath();x.fill();x.fillStyle='#FFF4DC';for(const a of[-20,0,20]){x.beginPath();x.arc(a,12,4,0,Math.PI*2);x.fill()}}
 else if(r===12){x.beginPath();x.moveTo(-38,20);x.quadraticCurveTo(0,-8,38,20);x.lineTo(30,24);x.quadraticCurveTo(0,4,-30,24);x.closePath();x.fill();for(const a of[-22,0,22]){x.beginPath();x.moveTo(a-7,a?10:2);x.lineTo(a,a?-6:-20);x.lineTo(a+7,a?10:2);x.fill()}x.fillStyle='#FFF4DC';x.beginPath();x.arc(0,-6,4,0,Math.PI*2);x.fill()}
 else{x.beginPath();x.ellipse(0,10,34,14,0,0,Math.PI*2);x.fill();x.beginPath();x.moveTo(-26,8);x.quadraticCurveTo(-4,-26,24,4);x.closePath();x.fill();x.beginPath();x.moveTo(18,0);x.quadraticCurveTo(44,-30,30,-42);x.quadraticCurveTo(34,-18,14,-4);x.fill()}
 x.restore()}
/* ---------- backdrops for the career places ---------- */
/* the sea at Batumi: sky, the Adjara hills on the left, the water to the horizon, a low sun in the evening */
function seaCv(day){const W=2048,H=1024,c=cvs(W,H),x=c.getContext('2d'),R=rng(201),hz=H*.56,g=x.createLinearGradient(0,0,0,hz);
 if(day){g.addColorStop(0,'#6FAEE6');g.addColorStop(1,'#D8ECF8')}else{g.addColorStop(0,'#1A2244');g.addColorStop(.6,'#7A4A6A');g.addColorStop(1,'#F2A060')}x.fillStyle=g;x.fillRect(0,0,W,hz);
 if(!day){const s=x.createRadialGradient(W*.62,hz-10,10,W*.62,hz-10,260);s.addColorStop(0,'rgba(255,220,150,1)');s.addColorStop(.18,'rgba(255,170,90,.9)');s.addColorStop(1,'rgba(255,140,80,0)');x.fillStyle=s;x.fillRect(0,0,W,hz);x.fillStyle='#FFD7A0';x.beginPath();x.arc(W*.62,hz,58,Math.PI,0);x.fill()}
 for(let i=0;i<9;i++){x.fillStyle=day?`rgba(255,255,255,${.35+R()*.3})`:`rgba(255,190,170,${.15+R()*.2})`;const cx=R()*W,cy=R()*hz*.6,w=120+R()*260;for(let k=0;k<6;k++){x.beginPath();x.ellipse(cx+(R()-.5)*w,cy+(R()-.5)*30,w*.25,18+R()*14,0,0,6.28);x.fill()}}
 const hill=(col,base,amp,seed,to)=>{const r=rng(seed);x.fillStyle=col;x.beginPath();x.moveTo(0,hz);for(let X=0;X<=to;X+=12)x.lineTo(X,hz-base-amp*(Math.sin(X/180+r())*.5+.5)*(1-X/to));x.lineTo(to,hz);x.fill()};
 hill(day?'#7E97B2':'#3A3456',60,170,3,W*.42);hill(day?'#5E7A64':'#2A2440',20,110,5,W*.3);
 const sea=x.createLinearGradient(0,hz,0,H);if(day){sea.addColorStop(0,'#3F8CC4');sea.addColorStop(1,'#1C5A86')}else{sea.addColorStop(0,'#5A4A70');sea.addColorStop(1,'#1A2240')}x.fillStyle=sea;x.fillRect(0,hz,W,H-hz);
 for(let i=0;i<900;i++){const y=hz+Math.pow(R(),1.6)*(H-hz),w=6+(y-hz)/(H-hz)*60;x.fillStyle=day?`rgba(255,255,255,${.12+R()*.2})`:`rgba(255,200,150,${.06+R()*.12})`;x.fillRect(R()*W,y,w,1.5+(y-hz)/(H-hz)*3)}
 if(!day){for(let i=0;i<220;i++){const y=hz+R()*(H-hz),sp=(y-hz)/(H-hz);x.fillStyle=`rgba(255,200,120,${.5-sp*.35})`;x.fillRect(W*.62+(R()-.5)*(40+sp*260),y,10+sp*40,2)}
  x.fillStyle='rgba(255,255,255,.85)';for(let k=0;k<40;k++)x.fillRect(R()*W,R()*hz*.4,1.6,1.6)}return c}
/* Sighnaghi: the Alazani valley in fields and vineyards, the snowy Caucasus across it */
function valleyCv(day){const W=2048,H=1024,c=cvs(W,H),x=c.getContext('2d'),R=rng(203),hz=H*.47,g=x.createLinearGradient(0,0,0,hz);
 if(day){g.addColorStop(0,'#78B2E4');g.addColorStop(1,'#DDEEF6')}else{g.addColorStop(0,'#141C3C');g.addColorStop(.7,'#5A4466');g.addColorStop(1,'#D08A62')}x.fillStyle=g;x.fillRect(0,0,W,hz);
 /* the range: blue rock, white tops */
 const pk=[];for(let X=0;X<=W;X+=10)pk.push([X,hz-60-Math.abs(Math.sin(X/210))*120-Math.abs(Math.sin(X/77+1))*55-R()*8]);
 x.fillStyle=day?'#8A9EBA':'#3C3A5A';x.beginPath();x.moveTo(0,hz+10);pk.forEach(([X,Y])=>x.lineTo(X,Y));x.lineTo(W,hz+10);x.fill();
 x.fillStyle=day?'#F6F8FB':'#C9B8C8';x.beginPath();pk.forEach(([X,Y],i)=>{const sn=Y+18+Math.sin(X/33)*8;if(i===0)x.moveTo(X,Y);x.lineTo(X,Y)});for(let i=pk.length-1;i>=0;i--){const[X,Y]=pk[i];x.lineTo(X,Y+22+Math.abs(Math.sin(X/41))*26)}x.fill();
 /* the valley floor, patches getting bigger toward us */
 x.fillStyle=day?'#7C9A4E':'#2E3A30';x.fillRect(0,hz,W,H-hz);const greens=day?['#86A65A','#6E8E44','#A8B060','#C2B46A','#5F8240','#94A858']:['#2E3A30','#283428','#3A3E2E','#34382C'];
 for(let row=0;row<26;row++){const y0=hz+Math.pow(row/26,1.7)*(H-hz),y1=hz+Math.pow((row+1)/26,1.7)*(H-hz);let X=-R()*200;while(X<W){const w=80+R()*240*(1+row/8);x.fillStyle=greens[Math.floor(R()*greens.length)];x.fillRect(X,y0,w,y1-y0+1);
   if(day&&R()<.35){x.strokeStyle='rgba(60,80,30,.35)';x.lineWidth=1;for(let k=4;k<w;k+=8){x.beginPath();x.moveTo(X+k,y0);x.lineTo(X+k+(k-w/2)*.05,y1);x.stroke()}}X+=w+2}}
 for(let k=0;k<70;k++){const X=R()*W,y=hz+6+R()*120,s=3+R()*5;x.fillStyle=day?'#B4533A':'rgba(255,200,120,.9)';x.fillRect(X,y,s,s*.7)}
 x.fillStyle='rgba(255,255,255,.18)';x.fillRect(0,hz,W,6);if(!day){x.fillStyle='rgba(255,255,255,.8)';for(let k=0;k<50;k++)x.fillRect(R()*W,R()*hz*.5,1.6,1.6)}return c}
/* Tbilisi from the mountain: the old town and the river below, hills around, a tall lattice tower on the ridge */
function cityCv(day){const W=2048,H=1024,c=cvs(W,H),x=c.getContext('2d'),R=rng(207),hz=H*.42,g=x.createLinearGradient(0,0,0,H);
 if(day){g.addColorStop(0,'#74AEE2');g.addColorStop(.42,'#D6E8F2');g.addColorStop(1,'#C9BCA4')}else{g.addColorStop(0,'#050A1E');g.addColorStop(.42,'#1E2448');g.addColorStop(1,'#0C0E1C')}x.fillStyle=g;x.fillRect(0,0,W,H);
 if(!day){x.fillStyle='rgba(255,255,255,.85)';for(let k=0;k<160;k++)x.fillRect(R()*W,R()*hz*.8,1.4,1.4)}
 x.fillStyle=day?'#8FA27A':'#141830';x.beginPath();x.moveTo(0,hz+40);for(let X=0;X<=W;X+=12)x.lineTo(X,hz+20-Math.sin(X/260)*50-Math.sin(X/90)*14);x.lineTo(W,H);x.lineTo(0,H);x.fill();
 /* the river */
 x.fillStyle=day?'#6E8E9A':'#0A0C18';x.beginPath();x.moveTo(0,H*.78);for(let X=0;X<=W;X+=20)x.lineTo(X,H*.74+Math.sin(X/300)*30);x.lineTo(W,H*.8);for(let X=W;X>=0;X-=20)x.lineTo(X,H*.79+Math.sin(X/300)*30);x.fill();
 /* the town: roofs by day, windows and street lights by night */
 for(let k=0;k<900;k++){const y=hz+30+Math.pow(R(),.8)*(H-hz-60),X=R()*W,w=10+R()*26*(y/H),h=8+R()*18*(y/H);if(Math.abs(y-(H*.765+Math.sin(X/300)*30))<26)continue;
  if(day){x.fillStyle=`rgb(${200+R()*40|0},${185+R()*30|0},${160+R()*30|0})`;x.fillRect(X,y,w,h);x.fillStyle=R()<.6?'#A4503A':'#7A6A60';x.fillRect(X-1,y-3,w+2,4)}
  else{x.fillStyle=`rgba(255,${180+R()*60|0},${90+R()*80|0},${.55+R()*.45})`;x.fillRect(X,y,2+R()*2.5,2+R()*2)}}
 if(!day)for(let k=0;k<26;k++){const X=k/26*W+R()*30;x.fillStyle='rgba(255,210,140,.8)';for(let j=0;j<16;j++)x.fillRect(X+j*6,H*.735+Math.sin((X+j*6)/300)*30,2,2)}
 /* the tower on the ridge, a mast of crossed lines with red lights */
 const tx=W*.8,ty=hz+16;x.strokeStyle=day?'#8A8F96':'#6A6E80';x.lineWidth=2;for(let k=0;k<14;k++){const a=k/14,b=(k+1)/14,w0=26*(1-a)+3,w1=26*(1-b)+3,y0=ty-a*230,y1=ty-b*230;x.beginPath();x.moveTo(tx-w0,y0);x.lineTo(tx+w1,y1);x.moveTo(tx+w0,y0);x.lineTo(tx-w1,y1);x.moveTo(tx-w0,y0);x.lineTo(tx-w1,y1);x.moveTo(tx+w0,y0);x.lineTo(tx+w1,y1);x.stroke()}
 if(!day){x.fillStyle='#FF4A3A';for(let k=0;k<5;k++)x.fillRect(tx-2,ty-k*55-4,4,4)}return c}
/* ---------- Easter table art ----------
   a red-dyed egg (onion skins and madder give the deep red; leaves pressed on before dyeing leave pale prints), cracked at
   the pointed end, the round end or both; white linen with a red cross-stitch border; green sprouts (ჯეჯილი) on a plate */
function eggCv(col,pat,ct,cb){const W=256,H=256,c=cvs(W,H),x=c.getContext('2d'),R=rng(col.charCodeAt(2)*31+pat*7);
 const g=x.createLinearGradient(0,0,0,H);g.addColorStop(0,'#5A0A0E');g.addColorStop(.12,col);g.addColorStop(.88,col);g.addColorStop(1,'#4A080C');x.fillStyle=g;x.fillRect(0,0,W,H);
 for(let k=0;k<900;k++){x.fillStyle=`rgba(${R()<.5?'40,0,0':'255,190,170'},${.03+R()*.05})`;x.fillRect(R()*W,R()*H,1+R()*2,1+R()*2)}
 x.fillStyle='rgba(250,232,218,.52)';
 if(pat===1)for(let k=0;k<5;k++){const cx=20+k*52+R()*14,cy=70+R()*110,s=14+R()*10,a=R()*Math.PI;x.save();x.translate(cx,cy);x.rotate(a);for(const sd of[-1,1]){x.beginPath();x.moveTo(0,0);x.quadraticCurveTo(sd*s*.6,-s*.6,0,-s*1.6);x.quadraticCurveTo(sd*s*.15,-s*.6,0,0);x.fill()}x.fillRect(-.8,0,1.6,s*.6);x.restore()}
 if(pat===2)for(let k=0;k<26;k++){x.beginPath();x.arc(R()*W,30+R()*(H-60),2.5+R()*2.5,0,Math.PI*2);x.fill()}
 const crack=(y0,dir)=>{x.strokeStyle='rgba(30,8,6,.92)';x.lineWidth=3;x.lineJoin='round';for(let n=0;n<3;n++){x.beginPath();let px=n*85+R()*30,py=y0;x.moveTo(px,py);for(let k=0;k<9;k++){px+=8+R()*10;py+=dir*(R()*14-3);x.lineTo(px,py)}x.stroke()}
  x.fillStyle='rgba(245,230,214,.85)';for(let k=0;k<10;k++){x.beginPath();const px=R()*W,py=y0+dir*R()*14;x.moveTo(px,py);x.lineTo(px+6+R()*6,py+dir*(2+R()*6));x.lineTo(px+R()*4,py+dir*(8+R()*6));x.fill()}};
 /* the texture runs from the pointed end (top) to the round end (bottom) */
 if(ct)crack(18,1);if(cb)crack(H-18,-1);return c}
function clothCv(){const S=1024,c=cvs(S,S),x=c.getContext('2d'),R=rng(311);x.fillStyle='#F3EEE4';x.fillRect(0,0,S,S);
 for(let k=0;k<5000;k++){x.fillStyle=`rgba(${R()<.5?'255,255,255':'180,170,150'},${.05+R()*.06})`;x.fillRect(R()*S,R()*S,1+R()*3,1)}
 const ring=(r,col,w)=>{x.strokeStyle=col;x.lineWidth=w;x.beginPath();x.arc(S/2,S/2,r,0,Math.PI*2);x.stroke()};
 ring(S*.455,'#B0182A',10);ring(S*.415,'#B0182A',4);
 /* cross-stitched diamonds between the two red lines */
 x.strokeStyle='#B0182A';x.lineWidth=2.4;for(let k=0;k<72;k++){const a=k/72*Math.PI*2,r=S*.435,cx=S/2+Math.cos(a)*r,cy=S/2+Math.sin(a)*r,s=7;x.save();x.translate(cx,cy);x.rotate(a);
  x.beginPath();x.moveTo(-s,0);x.lineTo(0,-s);x.lineTo(s,0);x.lineTo(0,s);x.closePath();x.stroke();x.beginPath();x.moveTo(-3,-3);x.lineTo(3,3);x.moveTo(3,-3);x.lineTo(-3,3);x.stroke();x.restore()}
 return c}
function sproutsCv(){const S=512,c=cvs(S,S),x=c.getContext('2d'),R=rng(77);x.fillStyle='#3B5E1E';x.beginPath();x.arc(S/2,S/2,S/2,0,Math.PI*2);x.fill();
 for(let k=0;k<4200;k++){const a=R()*Math.PI*2,r=Math.sqrt(R())*S*.49,px=S/2+Math.cos(a)*r,py=S/2+Math.sin(a)*r,l=6+R()*12,t=R()*Math.PI*2,gC=110+R()*90|0;
  x.strokeStyle=`rgb(${60+R()*50|0},${gC},${30+R()*30|0})`;x.lineWidth=1.4+R();x.beginPath();x.moveTo(px,py);x.lineTo(px+Math.cos(t)*l,py+Math.sin(t)*l);x.stroke()}return c}
function pascaCv(){const S=256,c=cvs(S,S),x=c.getContext('2d'),R=rng(12);x.fillStyle='#FBF6EC';x.fillRect(0,0,S,S);
 const col=['#E2463F','#F2B84B','#4FA3E0','#62C27A','#E06AA8'];for(let k=0;k<420;k++){x.fillStyle=col[k%5];x.save();x.translate(R()*S,R()*S);x.rotate(R()*Math.PI);x.fillRect(-3,-1,6,2);x.restore()}return c}

/* ---------- the night lounge for the card table ----------
   navy felt with a gold ring and a crown, a city at night through tall windows (painted soft, as a camera focused on the table sees it),
   shelves lit from below, and eyes with a gloss of their own for the people at the table */
function crownPath(x,cx,cy,w){const h=w*.72;x.save();x.translate(cx,cy);x.beginPath();
 x.moveTo(-w/2,h*.3);x.lineTo(-w*.56,-h*.24);x.lineTo(-w*.26,h*.02);x.lineTo(0,-h*.44);x.lineTo(w*.26,h*.02);x.lineTo(w*.56,-h*.24);x.lineTo(w/2,h*.3);x.closePath();x.fill();
 x.beginPath();x.moveTo(-w*.52,h*.38);x.lineTo(w*.52,h*.38);x.lineTo(w*.5,h*.56);x.lineTo(-w*.5,h*.56);x.closePath();x.fill();
 for(const[px,py,r]of[[-w*.56,-h*.24,.07],[0,-h*.44,.085],[w*.56,-h*.24,.07]]){x.beginPath();x.arc(px,py-h*.08,w*r,0,Math.PI*2);x.fill()}x.restore()}
function goldFill(x,y0,y1){const g=x.createLinearGradient(0,y0,0,y1);g.addColorStop(0,'#FFE7A3');g.addColorStop(.45,'#E0B24E');g.addColorStop(.55,'#C08A2A');g.addColorStop(1,'#F3CF77');return g}
/* the felt: deep navy, lighter where the lamp falls, a fine nap, one gold ring with the crown on its far side */
function luxFeltCv(){const S=1024,c=cvs(S,S),x=c.getContext('2d'),R=rng(141),g=x.createRadialGradient(S/2,S*.52,S*.04,S/2,S/2,S*.52);
 g.addColorStop(0,'#24406E');g.addColorStop(.55,'#172C52');g.addColorStop(1,'#0B1630');x.fillStyle=g;x.fillRect(0,0,S,S);
 x.globalCompositeOperation='overlay';x.globalAlpha=.32;x.drawImage(noiseCv(512,512,R,80,175),0,0,S,S);x.globalAlpha=.18;x.drawImage(noiseCv(1024,1024,R,60,200),0,0);x.globalCompositeOperation='source-over';x.globalAlpha=1;
 const ring=(r,w,a)=>{x.strokeStyle=`rgba(226,186,98,${a})`;x.lineWidth=w;x.beginPath();x.arc(S/2,S/2,r,0,Math.PI*2);x.stroke()};
 x.save();x.beginPath();x.rect(0,0,S,S);x.arc(S/2,S/2-S*.3,S*.07,0,Math.PI*2,true);x.clip('evenodd');ring(S*.3,4,.62);ring(S*.286,1.5,.38);x.restore();ring(S*.466,3,.32);
 x.fillStyle='rgba(226,186,98,.72)';crownPath(x,S/2,S/2-S*.3+4,S*.085);
 x.fillStyle='rgba(226,186,98,.28)';for(let i=0;i<64;i++){const a=i/64*Math.PI*2;x.beginPath();x.arc(S/2+Math.cos(a)*S*.452,S/2+Math.sin(a)*S*.452,2.2,0,Math.PI*2);x.fill()}
 return c}
/* soft out of focus: drawn small, then let the scaling smear it */
function softCv(src,k){const s=cvs(Math.max(2,src.width/k|0),Math.max(2,src.height/k|0)),sx=s.getContext('2d');sx.imageSmoothingQuality='high';sx.drawImage(src,0,0,s.width,s.height);
 const o=cvs(src.width,src.height),ox=o.getContext('2d');ox.imageSmoothingQuality='high';ox.drawImage(s,0,0,o.width,o.height);return o}
function bokeh(x,X,Y,r,col,a){const g=x.createRadialGradient(X,Y,0,X,Y,r);g.addColorStop(0,col.replace('A',a*.85));g.addColorStop(.72,col.replace('A',a*.75));g.addColorStop(.86,col.replace('A',a));g.addColorStop(1,col.replace('A',0));x.fillStyle=g;x.beginPath();x.arc(X,Y,r,0,Math.PI*2);x.fill()}
/* the city at night through a wall of glass: towers with lit windows, a glow on the horizon, lights out of focus, the window frames sharp */
function luxCityCv(day,seed=211){const W=2048,H=1024,src=cvs(W,H),x=src.getContext('2d'),R=rng(seed),hz=H*.62,g=x.createLinearGradient(0,0,0,H);
 if(day){g.addColorStop(0,'#6E9CCB');g.addColorStop(.6,'#B9D2E6');g.addColorStop(1,'#D8E3EA')}else{g.addColorStop(0,'#050A1C');g.addColorStop(.5,'#0E1A3C');g.addColorStop(.75,'#2A2A5A');g.addColorStop(1,'#3A2C4E')}
 x.fillStyle=g;x.fillRect(0,0,W,H);
 if(!day){const gl=x.createRadialGradient(W*.6,hz,10,W*.6,hz,W*.55);gl.addColorStop(0,'rgba(255,150,90,.35)');gl.addColorStop(1,'rgba(255,150,90,0)');x.fillStyle=gl;x.fillRect(0,0,W,H)}
 /* three rows of buildings, the far ones paler */
 for(const[row,n,hmin,hmax,col]of[[0,46,60,240,day?'#8AA2BC':'#17203F'],[1,30,140,420,day?'#6E869F':'#111833'],[2,14,320,640,day?'#556B82':'#0B1126']]){
  for(let k=0;k<n;k++){const w=40+R()*(row*60+60),X=R()*W-w/2,h=hmin+R()*(hmax-hmin),Y=hz+30*row-h;x.fillStyle=col;x.fillRect(X,Y,w,h+H);
   if(R()<.3&&row>0){x.fillRect(X+w*.4,Y-40-R()*60,w*.12,60+R()*60)}
   if(!day){const cw=row===2?14:9,ch=row===2?18:11;for(let yy=Y+10;yy<hz+30*row+20;yy+=ch+6)for(let xx=X+6;xx<X+w-cw;xx+=cw+6)if(R()<(row===2?.38:.3)){const t=R();x.fillStyle=t<.6?`rgba(255,${190+R()*40|0},${110+R()*50|0},${.55+R()*.4})`:t<.85?`rgba(170,200,255,${.4+R()*.4})`:`rgba(255,240,220,${.6+R()*.3})`;x.fillRect(xx,yy,cw,ch)}
    if(R()<.4){x.fillStyle='rgba(255,70,70,.9)';x.beginPath();x.arc(X+w/2,Y-4,4,0,Math.PI*2);x.fill()}}
   else{x.fillStyle='rgba(255,255,255,.12)';for(let yy=Y+10;yy<hz;yy+=22)x.fillRect(X+4,yy,w-8,3)}}}
 /* a street far below, its lights in a ribbon */
 if(!day)for(let k=0;k<160;k++){const X=R()*W,Y=hz+150+R()*120;x.fillStyle=R()<.5?'rgba(255,200,120,.9)':'rgba(255,90,80,.8)';x.fillRect(X,Y,6,3)}
 const out=softCv(src,day?3:4),o=out.getContext('2d');
 /* lights near and far, out of focus */
 if(!day)for(let k=0;k<70;k++){const t=R(),col=t<.55?'rgba(255,190,110,A)':t<.8?'rgba(140,180,255,A)':'rgba(255,120,170,A)';bokeh(o,R()*W,hz-200+R()*(H-hz+200),14+R()*48,col,.12+R()*.3)}
 else for(let k=0;k<14;k++)bokeh(o,R()*W,R()*H*.7,20+R()*50,'rgba(255,255,255,A)',.06+R()*.1);
 /* a sheen on the glass */
 const sh=o.createLinearGradient(0,0,W,H);sh.addColorStop(0,'rgba(255,255,255,0)');sh.addColorStop(.42,'rgba(255,255,255,.05)');sh.addColorStop(.5,'rgba(255,255,255,0)');o.fillStyle=sh;o.fillRect(0,0,W,H);
 /* the frames: posts and a rail, dark bronze, with a thin catch of light on one side */
 for(let k=0;k<=4;k++){const X=k*W/4;o.fillStyle='#0B0D12';o.fillRect(X-16,0,32,H);o.fillStyle='rgba(255,210,150,.22)';o.fillRect(X-16,0,3,H)}
 o.fillStyle='#0B0D12';o.fillRect(0,H*.12-12,W,24);o.fillRect(0,H-26,W,26);o.fillStyle='rgba(255,210,150,.18)';o.fillRect(0,H*.12-12,W,3);
 return out}
/* shelves lit from beneath: decanters, bottles and a few books, soft as if behind the players */
function luxShelfCv(){const W=1024,H=1024,src=cvs(W,H),x=src.getContext('2d'),R=rng(223);x.fillStyle='#120B08';x.fillRect(0,0,W,H);
 const rows=4;for(let r=0;r<rows;r++){const y0=40+r*H/rows,y1=y0+H/rows-40;const g=x.createLinearGradient(0,y0,0,y1);g.addColorStop(0,'#2A1A10');g.addColorStop(1,'#5A3818');x.fillStyle=g;x.fillRect(30,y0,W-60,y1-y0);
  const lg=x.createRadialGradient(W/2,y0,10,W/2,y0,W*.6);lg.addColorStop(0,'rgba(255,190,110,.55)');lg.addColorStop(1,'rgba(255,190,110,0)');x.fillStyle=lg;x.fillRect(30,y0,W-60,y1-y0);
  let X=50;while(X<W-90){const t=R(),w=t<.5?40+R()*30:t<.8?24+R()*12:60+R()*40,h=t<.5?120+R()*80:t<.8?100+R()*40:60+R()*30;const Y=y1-h;
   if(t<.5){/* a bottle: body, shoulders and a neck */const col=['#3B1A0E','#1E3A24','#5A2A10','#2A2030','#704018'][R()*5|0];x.fillStyle=col;x.beginPath();x.moveTo(X,y1);x.lineTo(X,Y+h*.45);x.quadraticCurveTo(X,Y+h*.3,X+w*.35,Y+h*.25);x.lineTo(X+w*.35,Y);x.lineTo(X+w*.65,Y);x.lineTo(X+w*.65,Y+h*.25);x.quadraticCurveTo(X+w,Y+h*.3,X+w,Y+h*.45);x.lineTo(X+w,y1);x.fill();
    x.fillStyle='rgba(255,220,160,.55)';x.fillRect(X+w*.18,Y+h*.5,4,h*.4);x.fillStyle='rgba(255,210,150,.35)';x.fillRect(X+w*.2,Y+h*.62,w*.6,h*.16)}
   else if(t<.8){x.fillStyle=['#6A2A20','#20304E','#2E4A30','#6A5020'][R()*4|0];x.fillRect(X,Y,w,h);x.fillStyle='rgba(230,190,110,.5)';x.fillRect(X,Y+12,w,3);x.fillRect(X,Y+h-16,w,3)}
   else{x.fillStyle='rgba(220,170,80,.9)';x.beginPath();x.ellipse(X+w/2,Y+h*.55,w/2,h*.45,0,0,Math.PI*2);x.fill();x.fillStyle='rgba(255,240,200,.6)';x.fillRect(X+w*.3,Y+h*.3,5,h*.4)}
   X+=w+8+R()*18}
  x.fillStyle='#2A170C';x.fillRect(20,y1,W-40,16);x.fillStyle='rgba(255,200,120,.9)';x.fillRect(30,y1+14,W-60,4);
  const lb=x.createLinearGradient(0,y1+16,0,y1+60);lb.addColorStop(0,'rgba(255,190,110,.45)');lb.addColorStop(1,'rgba(255,190,110,0)');x.fillStyle=lb;x.fillRect(30,y1+16,W-60,44)}
 const out=softCv(src,3),o=out.getContext('2d');for(let k=0;k<18;k++)bokeh(o,60+R()*(W-120),R()*H,10+R()*26,'rgba(255,196,120,A)',.12+R()*.2);
 o.fillStyle='#0E0805';o.fillRect(0,0,24,H);o.fillRect(W-24,0,24,H);return out}
/* dark walnut panels with a thin brass line round each */
function luxPanelCv(){const S=1024,c=cvs(S,S),x=c.getContext('2d');x.drawImage(woodCv(S,S,Object.assign({},WOOD.walnut,{seed:61})),0,0);x.fillStyle='rgba(8,6,10,.62)';x.fillRect(0,0,S,S);
 for(let k=0;k<2;k++){const X=k*S/2+30,w=S/2-60;x.strokeStyle='rgba(212,168,84,.55)';x.lineWidth=3;x.strokeRect(X,40,w,S-80);x.strokeStyle='rgba(0,0,0,.5)';x.lineWidth=6;x.strokeRect(X+6,46,w-12,S-92)}return c}
/* a monstera leaf with its holes and splits, cut out by alpha */
function monsteraCv(){const S=512,c=cvs(S,S),x=c.getContext('2d'),R=rng(229);x.translate(S/2,S*.92);
 const g=x.createLinearGradient(0,0,0,-S*.85);g.addColorStop(0,'#1F4A2A');g.addColorStop(1,'#3E7A3E');x.fillStyle=g;x.beginPath();x.moveTo(0,0);x.bezierCurveTo(S*.48,-S*.12,S*.5,-S*.72,0,-S*.86);x.bezierCurveTo(-S*.5,-S*.72,-S*.48,-S*.12,0,0);x.fill();
 x.globalCompositeOperation='destination-out';for(const s of[-1,1])for(let k=0;k<5;k++){const y=-S*(.16+k*.13),L=S*(.22+R()*.06);x.lineWidth=10;x.beginPath();x.moveTo(s*L*.55,y);x.lineTo(s*L*1.2,y-14);x.stroke();x.beginPath();x.ellipse(s*L*.42,y+6,12,6,s*.3,0,Math.PI*2);x.fill()}
 x.globalCompositeOperation='source-over';x.strokeStyle='rgba(170,220,140,.5)';x.lineWidth=5;x.beginPath();x.moveTo(0,0);x.quadraticCurveTo(6,-S*.4,0,-S*.82);x.stroke();
 x.lineWidth=2;for(const s of[-1,1])for(let k=0;k<6;k++){const y=-S*(.12+k*.12);x.beginPath();x.moveTo(0,y);x.quadraticCurveTo(s*S*.12,y-20,s*S*.32,y-36);x.stroke()}return c}
/* a mug's wrap: navy glaze, a gold crown and a gold rim line */
function mugCv(){const W=512,H=256,c=cvs(W,H),x=c.getContext('2d');x.fillStyle='#12203E';x.fillRect(0,0,W,H);x.fillStyle=goldFill(x,0,H);x.fillRect(0,0,W,10);crownPath(x,W*.25,H*.52,86);return c}
/* the card box: black with a gold crown on the lid */
function cardBoxCv(){const S=256,c=cvs(S,S),x=c.getContext('2d');x.fillStyle='#14161C';x.fillRect(0,0,S,S);x.strokeStyle='rgba(220,178,90,.8)';x.lineWidth=5;x.strokeRect(14,14,S-28,S-28);x.fillStyle=goldFill(x,80,180);crownPath(x,S/2,S/2+6,96);return c}
/* an eye for a 3D eyeball, in two halves like the face: open, and shut for a blink.
   the iris sits on the front of the ball (u .25 of each half); the lid in skin colour covers the top, a dark lash line on its edge */
function eyeCv(o){const W=512,H=256,c=cvs(W,H),x=c.getContext('2d'),skin=o.skin||'#E2AF8C',fem=!!o.fem;
 const lid=(X0,edge)=>{x.fillStyle=skin;x.beginPath();x.moveTo(X0,0);x.lineTo(X0+256,0);x.lineTo(X0+256,edge+18);for(let u=256;u>=0;u-=8){const d=(u-64)/64;x.lineTo(X0+u,edge+Math.min(26,d*d*9))}x.closePath();x.fill();
  const sh=x.createLinearGradient(0,edge,0,edge+30);sh.addColorStop(0,'rgba(60,30,20,.38)');sh.addColorStop(1,'rgba(60,30,20,0)');x.fillStyle=sh;x.fillRect(X0+10,edge,118,30);
  x.strokeStyle='#1A0E0A';x.lineCap='round';x.lineWidth=fem?7:4.5;x.beginPath();for(let u=10;u<=118;u+=4){const d=(u-64)/64;const y=edge+Math.min(26,d*d*9);u===10?x.moveTo(X0+u,y):x.lineTo(X0+u,y)}x.stroke();
  if(fem){x.lineWidth=3;for(let u=24;u<=110;u+=10){const d=(u-64)/64,y=edge+d*d*9;x.beginPath();x.moveTo(X0+u,y);x.lineTo(X0+u+(u-64)*.12,y-9);x.stroke()}}};
 /* open: the white with a faint shadow toward its edges, the iris in rings and streaks, the pupil, two catch lights */
 const sc=x.createRadialGradient(64,132,6,64,132,120);sc.addColorStop(0,'#FFFDF9');sc.addColorStop(.6,'#F3EDE6');sc.addColorStop(1,'#C9B6AA');x.fillStyle=sc;x.fillRect(0,0,256,H);
 const ic=o.eye||'#5A3620',ig=x.createRadialGradient(64,128,4,64,128,52);ig.addColorStop(0,ic);ig.addColorStop(.7,ic);ig.addColorStop(1,'#140A06');
 x.save();x.translate(64,128);x.scale(1,1.95);x.fillStyle=ig;x.beginPath();x.arc(0,0,27,0,Math.PI*2);x.fill();
 x.strokeStyle='rgba(255,230,190,.25)';x.lineWidth=1.2;for(let k=0;k<28;k++){const a=k/28*Math.PI*2;x.beginPath();x.moveTo(Math.cos(a)*9,Math.sin(a)*9);x.lineTo(Math.cos(a)*24,Math.sin(a)*24);x.stroke()}
 x.fillStyle='#07040A';x.beginPath();x.arc(0,0,11.5,0,Math.PI*2);x.fill();x.restore();
 x.fillStyle='rgba(255,255,255,.97)';x.beginPath();x.ellipse(54,104,9,16,0,0,Math.PI*2);x.fill();x.fillStyle='rgba(255,255,255,.75)';x.beginPath();x.ellipse(73,150,4,7.5,0,0,Math.PI*2);x.fill();
 lid(0,64);x.fillStyle=skin;x.fillRect(0,208,256,48);x.fillStyle='rgba(90,40,30,.28)';x.fillRect(10,204,118,4);
 /* shut: all lid, the lash line low and curved */
 x.fillStyle=skin;x.fillRect(256,0,256,H);const sg=x.createLinearGradient(0,100,0,140);sg.addColorStop(0,'rgba(90,45,30,0)');sg.addColorStop(1,'rgba(90,45,30,.25)');x.fillStyle=sg;x.fillRect(266,100,118,40);
 x.strokeStyle='#1A0E0A';x.lineWidth=fem?6.5:4.5;x.lineCap='round';x.beginPath();for(let u=12;u<=116;u+=4){const d=(u-64)/64,y=138-d*d*-8+(1-d*d)*6;u===12?x.moveTo(256+u,y):x.lineTo(256+u,y)}x.stroke();return c}
/* the joker: a laughing jester in a three-horned cap with bells, a ruff, a diamond suit; the word down the side */
function jesterAt(x,cx,cy,k,pal){x.save();x.translate(cx,cy);x.scale(k,k);
 /* the suit below the ruff */
 x.save();x.beginPath();x.moveTo(-70,60);x.quadraticCurveTo(-80,140,-90,180);x.lineTo(90,180);x.quadraticCurveTo(80,140,70,60);x.closePath();x.clip();
 for(let i=-5;i<5;i++)for(let j=0;j<6;j++){x.fillStyle=(i+j)%2?pal[0]:pal[1];x.beginPath();x.moveTo(i*30,60+j*30);x.lineTo(i*30+15,75+j*30);x.lineTo(i*30,90+j*30);x.lineTo(i*30-15,75+j*30);x.fill()}x.restore();
 /* the ruff */
 x.fillStyle='#FFFFFF';x.strokeStyle='#D9A441';x.lineWidth=3;x.beginPath();for(let k2=0;k2<=16;k2++){const a=Math.PI*(1+k2/16),r=k2%2?62:84;x.lineTo(Math.cos(a)*r*1.05,58-Math.sin(a)*r*.38)}for(let k2=16;k2>=0;k2--){const a=Math.PI*(1+k2/16);x.lineTo(Math.cos(a)*40,70-Math.sin(a)*12)}x.closePath();x.fill();x.stroke();
 /* the face */
 const fg=x.createRadialGradient(-14,-18,8,0,0,62);fg.addColorStop(0,'#FFE2C6');fg.addColorStop(1,'#EDB48C');x.fillStyle=fg;x.beginPath();x.ellipse(0,0,50,56,0,0,Math.PI*2);x.fill();
 for(const s of[-1,1]){x.fillStyle='rgba(235,96,96,.4)';x.beginPath();x.ellipse(s*30,16,11,8,0,0,Math.PI*2);x.fill();
  x.fillStyle='#FFFFFF';x.beginPath();x.ellipse(s*18,-10,12,15,0,0,Math.PI*2);x.fill();x.fillStyle='#3B2414';x.beginPath();x.arc(s*18+2,-8,7.5,0,Math.PI*2);x.fill();x.fillStyle='#000';x.beginPath();x.arc(s*18+2,-8,3.6,0,Math.PI*2);x.fill();
  x.fillStyle='#fff';x.beginPath();x.arc(s*18-1,-12,2.6,0,Math.PI*2);x.fill();x.strokeStyle='#3B2414';x.lineWidth=3.5;x.lineCap='round';x.beginPath();x.moveTo(s*8,-30);x.quadraticCurveTo(s*18,-38,s*30,-30);x.stroke()}
 x.fillStyle='#E07A6A';x.beginPath();x.ellipse(0,6,7,6,0,0,Math.PI*2);x.fill();
 x.fillStyle='#7A1E22';x.beginPath();x.moveTo(-24,20);x.quadraticCurveTo(0,52,24,20);x.quadraticCurveTo(0,30,-24,20);x.fill();x.fillStyle='#F07080';x.beginPath();x.ellipse(0,36,9,5,0,0,Math.PI*2);x.fill();
 /* the cap: three horns curling out, each ending in a bell */
 const horns=[[-1,pal[0]],[0,pal[2]],[1,pal[1]]];for(const[s,col]of horns){x.fillStyle=col;x.strokeStyle='rgba(0,0,0,.25)';x.lineWidth=2;x.beginPath();
  if(s===0){x.moveTo(-26,-46);x.quadraticCurveTo(-6,-120,10,-150);x.quadraticCurveTo(14,-110,26,-46)}else{x.moveTo(s*12,-48);x.quadraticCurveTo(s*70,-90,s*92,-60);x.quadraticCurveTo(s*62,-70,s*44,-34)}x.closePath();x.fill();x.stroke()}
 x.fillStyle=pal[1];x.beginPath();x.ellipse(0,-44,54,14,0,Math.PI,0);x.fill();x.fillStyle='#D9A441';x.fillRect(-52,-46,104,9);
 for(const[bx,by]of[[-92,-58],[10,-150],[92,-58]]){const bg=x.createRadialGradient(bx-3,by-3,1,bx,by,11);bg.addColorStop(0,'#FFF1B8');bg.addColorStop(1,'#C08A2A');x.fillStyle=bg;x.beginPath();x.arc(bx,by,10,0,Math.PI*2);x.fill()}
 x.restore()}
/* ---------- paint for the sculpted heads ----------
   the face is projected from the front: u = .5 + x/2.6, v = .5 - (y + .05)/2.9 in the head's own frame (its centre at 0) */
const FUV=(x,y)=>[(.5+x/2.6)*512,(.5-(y+.05)/2.9)*512];
function face2Cv(o){const S=512,c=cvs(S,S),x=c.getContext('2d'),R=rng(((o.skin||'').charCodeAt(2)||7)*13+(o.fem?5:0)),E=o.eye3||{x:.37,y:.03,r:.24};
 x.fillStyle=o.skin;x.fillRect(0,0,S,S);
 /* light and colour across the face: a warmer middle, rosy cheeks and nose tip, a cooler jaw for the men */
 const rad=(px,py,r,col)=>{const[X,Y]=FUV(px,py),k=r/2.6*512,g=x.createRadialGradient(X,Y,0,X,Y,k);g.addColorStop(0,col);g.addColorStop(1,col.replace(/[\d.]+\)$/,'0)'));x.fillStyle=g;x.fillRect(X-k,Y-k,k*2,k*2)};
 for(const s of[-1,1])rad(s*.44,-.24,.32,o.fem?'rgba(236,104,104,.38)':'rgba(226,110,96,.28)');rad(0,-.26,.16,'rgba(230,110,96,.3)');rad(0,.55,.5,'rgba(255,240,225,.12)');
 for(const s of[-1,1])rad(s*.9,-.03,.18,'rgba(220,110,96,.35)');
 if(!o.fem&&!o.old){x.save();x.globalAlpha=.07;for(let k=0;k<2600;k++){const a=R()*Math.PI,r=.55+R()*.3,px=Math.cos(a)*r*.85,py=-.55-Math.sin(a)*r*.75;if(py>-.45&&Math.abs(px)<.3)continue;const[X,Y]=FUV(px,py);x.fillStyle='#2A3040';x.fillRect(X,Y,1.6,1.6)}x.restore()}
 /* soft shadow round each eye socket */
 for(const s of[-1,1])rad(s*E.x,E.y+.04,E.r+.12,'rgba(130,64,52,.12)');
 /* eyebrows: thick at the inner end, tapering out, a little arched */
 x.fillStyle=o.brow||o.hair;for(const s of[-1,1]){const P0=FUV(s*.12,.33),P1=FUV(s*.35,.42),P2=FUV(s*.58,.31),w0=o.fem?8:14,w1=o.fem?4:8;
  x.beginPath();x.moveTo(P0[0],P0[1]-w0/2);x.quadraticCurveTo(P1[0],P1[1]-w0*.8,P2[0],P2[1]-w1/2);x.quadraticCurveTo(P2[0]+s*2,P2[1],P2[0],P2[1]+w1/2);x.quadraticCurveTo(P1[0],P1[1]+w0*.4,P0[0],P0[1]+w0/2);x.closePath();x.fill()}
 /* lines of an older face */
 if(o.old){x.strokeStyle='rgba(120,60,45,.32)';x.lineWidth=2.2;for(const yy of[.62,.72]){const a=FUV(-.32,yy),b=FUV(0,yy+.03),d=FUV(.32,yy);x.beginPath();x.moveTo(a[0],a[1]);x.quadraticCurveTo(b[0],b[1]-6,d[0],d[1]);x.stroke()}
  for(const s of[-1,1]){const a=FUV(s*.17,-.3),b=FUV(s*.26,-.52);x.beginPath();x.moveTo(a[0],a[1]);x.quadraticCurveTo(a[0]+s*8,(a[1]+b[1])/2,b[0],b[1]);x.stroke();const e=FUV(s*(E.x+E.r+.05),E.y);for(let k=-1;k<=1;k++){x.beginPath();x.moveTo(e[0],e[1]+k*7);x.lineTo(e[0]+s*13,e[1]+k*9);x.stroke()}}}
 /* lips: a deeper rose, the line between them dark */
 const lip=o.fem?'rgba(196,96,100,.6)':'rgba(176,100,90,.4)';x.fillStyle=lip;const L0=FUV(-.19,-.55),L1=FUV(0,-.5),L2=FUV(.19,-.55),L3=FUV(0,-.67);
 x.beginPath();x.moveTo(L0[0],L0[1]);x.quadraticCurveTo(L1[0]-14,L1[1]-6,L1[0],L1[1]+2);x.quadraticCurveTo(L1[0]+14,L1[1]-6,L2[0],L2[1]);x.quadraticCurveTo(L1[0],L1[1]+10,L0[0],L0[1]);x.fill();
 x.beginPath();x.moveTo(L0[0]+3,L0[1]+2);x.quadraticCurveTo(L3[0],L3[1]+8,L2[0]-3,L2[1]+2);x.quadraticCurveTo(L1[0],L1[1]+12,L0[0]+3,L0[1]+2);x.fill();
 x.strokeStyle='rgba(70,24,24,.75)';x.lineWidth=2.4;x.lineCap='round';const M0=FUV(-.2,-.54),M1=FUV(0,-.6),M2=FUV(.2,-.54);x.beginPath();x.moveTo(M0[0],M0[1]);x.quadraticCurveTo(M1[0],M1[1]+5,M2[0],M2[1]);x.stroke();
 x.globalCompositeOperation='multiply';x.globalAlpha=.06;x.drawImage(noiseCv(128,128,R,200,255),0,0,S,S);x.globalAlpha=1;x.globalCompositeOperation='source-over';return c}
/* the eyeball for a head with lids of its own: open (white, iris, pupil, catch lights, the lid's shadow at the top), and shut for a blink */
function eye2Cv(o){const W=512,H=256,c=cvs(W,H),x=c.getContext('2d'),skin=o.skin||'#E2AF8C';
 const sc=x.createRadialGradient(64,132,6,64,132,128);sc.addColorStop(0,'#FFFFFF');sc.addColorStop(.55,'#F4F0EA');sc.addColorStop(1,'#C9B4A8');x.fillStyle=sc;x.fillRect(0,0,256,H);
 const ic=o.eye||'#6A4222',ig=x.createRadialGradient(64,128,3,64,128,56);ig.addColorStop(0,'#1A0E08');ig.addColorStop(.25,ic);ig.addColorStop(.75,ic);ig.addColorStop(1,'#120A06');
 x.save();x.translate(64,128);x.scale(1,1.95);x.fillStyle=ig;x.beginPath();x.arc(0,0,28,0,Math.PI*2);x.fill();
 x.strokeStyle='rgba(255,235,200,.28)';x.lineWidth=1.1;for(let k=0;k<36;k++){const a=k/36*Math.PI*2;x.beginPath();x.moveTo(Math.cos(a)*10,Math.sin(a)*10);x.lineTo(Math.cos(a)*25,Math.sin(a)*25);x.stroke()}
 x.fillStyle='#050308';x.beginPath();x.arc(0,0,11,0,Math.PI*2);x.fill();x.restore();
 const lg=x.createLinearGradient(0,30,0,118);lg.addColorStop(0,'rgba(60,28,20,.55)');lg.addColorStop(1,'rgba(60,28,20,0)');x.fillStyle=lg;x.fillRect(0,0,256,118);
 /* the lash line just under the lid's edge (the lid stands at about this height on the ball) */
 const lv=Math.round((90-Math.asin(o.fem?.68:.62)*180/Math.PI)/180*256);x.fillStyle='rgba(22,10,8,.95)';x.fillRect(0,lv-2,256,o.fem?9:6);
 x.fillStyle='rgba(255,255,255,.98)';x.beginPath();x.ellipse(53,112,8,15,0,0,Math.PI*2);x.fill();x.fillStyle='rgba(255,255,255,.7)';x.beginPath();x.ellipse(74,150,3.5,7,0,0,Math.PI*2);x.fill();
 x.fillStyle=skin;x.fillRect(256,0,256,H);x.strokeStyle='rgba(30,14,10,.8)';x.lineWidth=o.fem?6:4;x.lineCap='round';x.beginPath();x.moveTo(256+14,146);x.quadraticCurveTo(256+64,156,256+114,146);x.stroke();return c}
/* hair: fine strands and clumps in grey, tinted by the hair colour */
function hairCv(){const S=256,c=cvs(S,S),x=c.getContext('2d'),R=rng(331);x.fillStyle='#C4C4C4';x.fillRect(0,0,S,S);
 for(let k=0;k<520;k++){const X=R()*S,w=1+R()*3,a=.12+R()*.3;x.strokeStyle=R()<.5?`rgba(0,0,0,${a})`:`rgba(255,255,255,${a*.8})`;x.lineWidth=w;x.beginPath();x.moveTo(X,-10);x.bezierCurveTo(X+(R()-.5)*30,S*.3,X+(R()-.5)*30,S*.7,X+(R()-.5)*20,S+10);x.stroke()}return c}
